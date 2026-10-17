import Foundation
import CryptoKit

struct ContainerSnapshotRequest {
    let container:String
    let image:String
    var includeEnvironment=false
    var acknowledgeRunning=false
}
struct ContainerSnapshotPlan {
    let id:String
    let architecture:String
    let configuration:[String:Any]
    let fingerprint:Data
    let running:Bool
    init(_ data:Data,includeEnvironment:Bool)throws {
        guard let row=try ResourceSafety.rows(data).first,
              let config=row["configuration"] as? [String:Any],let id=config["id"] as? String,
              let platform=config["platform"] as? [String:Any],platform["os"] as? String=="linux",
              let arch=platform["architecture"] as? String,["arm64","amd64"].contains(arch),
              let process=config["initProcess"] as? [String:Any],let executable=process["executable"] as? String,!executable.isEmpty,
              let arguments=process["arguments"] as? [String],let directory=process["workingDirectory"] as? String else{throw DeskError.message("snapshotUnsupported")}
        self.id=id;architecture=arch;fingerprint=try JSONSerialization.data(withJSONObject:config,options:.sortedKeys)
        let state=(row["status"] as? [String:Any])?["state"] as? String
        running=state=="running"
        guard ["running","stopped"].contains(state ?? "") else{throw DeskError.message("snapshotUnsupported")}
        var result:[String:Any] = ["Entrypoint":[executable],"Cmd":arguments,"WorkingDir":directory]
        if let user=process["user"] as? [String:Any] {
            if let raw=user["raw"] as? [String:Any],let value=raw["userString"] as? String {result["User"]=value}
            else if let ids=user["id"] as? [String:Any],let uid=ids["uid"] as? Int,let gid=ids["gid"] as? Int {result["User"]="\(uid):\(gid)"}
            else{throw DeskError.message("snapshotUnsupported")}
        } else {throw DeskError.message("snapshotUnsupported")}
        if includeEnvironment {
            guard let environment=process["environment"] as? [String] else{throw DeskError.message("snapshotUnsupported")}
            result["Env"]=environment
        }
        configuration=result
    }
}

/// Wrap the engine-exported root filesystem in a single-layer OCI image.
/// The tar is treated as an opaque blob and is never extracted onto the Mac.
struct SnapshotArchive {
    static func assemble(rootfs:URL,directory:URL,plan:ContainerSnapshotPlan,reference:String)async throws->URL {
        let task=Task.detached(priority:.utility) { ()throws->URL in
            let fm=FileManager.default,blobs=directory.appendingPathComponent("blobs/sha256")
            try fm.createDirectory(at:blobs,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let handle=try FileHandle(forReadingFrom:rootfs);defer{try? handle.close()}
            var hash=SHA256(),size:Int64=0
            while let chunk=try handle.read(upToCount:1024*1024),!chunk.isEmpty {
                try Task.checkCancellation();hash.update(data:chunk);size+=Int64(chunk.count)
            }
            guard size>0 else{throw DeskError.message("snapshotEmpty")}
            let digest=hash.finalize().map{String(format:"%02x",$0)}.joined()
            try fm.moveItem(at:rootfs,to:blobs.appendingPathComponent(digest))
            func blob(_ object:[String:Any])throws->[String:Any] {
                try Task.checkCancellation()
                let data=try JSONSerialization.data(withJSONObject:object,options:.sortedKeys)
                let id=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
                try data.write(to:blobs.appendingPathComponent(id),options:.atomic)
                return ["digest":"sha256:"+id,"size":data.count]
            }
            var config=try blob(["architecture":plan.architecture,"os":"linux","config":plan.configuration,"rootfs":["type":"layers","diff_ids":["sha256:"+digest]],"history":[["created_by":"Container Desk filesystem snapshot"]]])
            config["mediaType"]="application/vnd.oci.image.config.v1+json"
            var manifest=try blob(["schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","config":config,"layers":[["mediaType":"application/vnd.oci.image.layer.v1.tar","digest":"sha256:"+digest,"size":size]]])
            manifest["mediaType"]="application/vnd.oci.image.manifest.v1+json"
            manifest["annotations"]=["org.opencontainers.image.ref.name":reference]
            manifest["platform"]=["os":"linux","architecture":plan.architecture]
            try JSONSerialization.data(withJSONObject:["schemaVersion":2,"manifests":[manifest]],options:.sortedKeys).write(to:directory.appendingPathComponent("index.json"),options:.atomic)
            try Data(#"{"imageLayoutVersion":"1.0.0"}"#.utf8).write(to:directory.appendingPathComponent("oci-layout"),options:.atomic)
            return directory.appendingPathComponent("snapshot.oci.tar")
        }
        return try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})
    }
}
@MainActor extension Store {
    func snapshotContainer(_ request:ContainerSnapshotRequest) {
        guard canMutate,let cli else{return}
        startOperation("snapshotTitle",present:false) {
            let target=try DeploymentSource.image(request.image)
            func inspect()async throws->ContainerSnapshotPlan {
                let result=try await ProcessRunner.checked(cli,["inspect","--",request.container])
                let plan=try ContainerSnapshotPlan(result.data,includeEnvironment:request.includeEnvironment)
                guard plan.id==request.container else{throw DeskError.message("resourceDisappeared")}
                return plan
            }
            func checkTarget()async throws {
                let items=try ResourceItem.parseImages((try await ProcessRunner.checked(cli,["image","list","--format","json"])).data)
                guard !items.contains(where:{$0.id==target}) else{throw DeskError.message("imageTagExists")}
            }
            try await checkTarget()
            let plan=try await inspect()
            guard !plan.running || request.acknowledgeRunning else{throw DeskError.message("snapshotRunningRequired")}
            let directory=FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-snapshot-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
            defer{try? FileManager.default.removeItem(at:directory)}
            let rootfs=directory.appendingPathComponent("rootfs.tar")
            let export=try await StreamingProcess.run(cli,["export","--output",rootfs.path,"--",request.container]){_ in}
            guard export==0 else{throw DeskError.message("snapshotExportFailed")}
            try Task.checkCancellation()
            let after=try await inspect()
            guard after.fingerprint==plan.fingerprint,after.running==plan.running else{throw DeskError.message("snapshotChanged")}
            let archive=try await SnapshotArchive.assemble(rootfs:rootfs,directory:directory,plan:plan,reference:target)
            let packed=try await StreamingProcess.run("/usr/bin/tar",["-cf",archive.path,"-C",directory.path,"oci-layout","index.json","blobs"]){_ in}
            guard packed==0 else{throw DeskError.message("snapshotExportFailed")}
            try await checkTarget();try Task.checkCancellation()
            let loaded=try await StreamingProcess.run(cli,["image","load","--input",archive.path]){_ in}
            guard loaded==0 else{throw DeskError.message("snapshotLoadFailed")}
            let metadata=try await ProcessRunner.checked(cli,["image","inspect","--",target])
            guard try ImagePlatform.hasVariant(metadata.data,architecture:plan.architecture) else{throw DeskError.message("deployArchitectureMismatch")}
            await self.refreshImages()
            guard self.images.contains(where:{$0.id==target}) else{throw DeskError.message("resourceDisappeared")}
            return 0
        }
    }
}
