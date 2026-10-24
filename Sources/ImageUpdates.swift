import Foundation
import CryptoKit
import Darwin

struct LocalImageVersion: Equatable {
    let digest:String
    let architectures:[String]
    init(_ data:Data)throws {
        guard let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]],rows.count==1,
              let c=rows[0]["configuration"] as? [String:Any],
              let digest=(c["descriptor"] as? [String:Any])?["digest"] as? String,
              digest.range(of:"^sha256:[a-f0-9]{64}$",options:.regularExpression) != nil,
              let variants=rows[0]["variants"] as? [[String:Any]] else{throw DeskError.message("imageUpdateInvalid")}
        let architectures=Set(variants.compactMap { v -> String? in
            guard let p=v["platform"] as? [String:Any],p["os"] as? String == "linux" else{return nil}
            return p["architecture"] as? String
        })
        guard !architectures.isEmpty,architectures.isSubset(of:["arm64","amd64"]) else{throw DeskError.message("imageUpdateInvalid")}
        self.digest=digest;self.architectures=architectures.sorted()
    }
}

struct ImageRefreshResult {
    let before:LocalImageVersion
    let after:LocalImageVersion
    let backup:String
    var changed:Bool{before.digest != after.digest}
}

struct ContainerUpdatePlan {
    let clone:ContainerClonePlan
    let sourceData:Data
    let image:String
    let version:LocalImageVersion
    let replacement:String
    let wasRunning:Bool
    let ports:[String]
    let healthURL:URL?
    static func fingerprint(_ data:Data)throws->String {
        guard let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]],rows.count==1,let c=rows[0]["configuration"] as? [String:Any] else{throw DeskError.message("imageUpdateInvalid")}
        return SHA256.hash(data:try JSONSerialization.data(withJSONObject:c,options:.sortedKeys)).map{String(format:"%02x",$0)}.joined()
    }
    init(container:Data,image:String,metadata:Data,replacement:String,health:String="")throws {
        let clone=try ContainerClonePlan(container,allowEmptyArguments:true)
        let version=try LocalImageVersion(metadata)
        guard clone.base.image==image,clone.imageDigest != version.digest,version.architectures.contains(clone.base.architecture) else{throw DeskError.message("containerUpdateNotNeeded")}
        let rows=try JSONSerialization.jsonObject(with:container) as! [[String:Any]]
        let config=rows[0]["configuration"] as! [String:Any]
        let known:Set<String>=["id","image","resources","platform","initProcess","networks","mounts","readOnly","ssh","useInit","virtualization","capAdd","capDrop","publishedSockets","labels","sysctls","runtimeHandler","dns","rosetta","publishedPorts","creationDate"]
        guard Set(config.keys).isSubset(of:known),Set((config["resources"] as? [String:Any] ?? [:]).keys).isSubset(of:["cpus","memoryInBytes","cpuOverhead"]) else{throw DeskError.message("cloneUnsupported")}
        let state=(rows[0]["status"] as? [String:Any])?["state"] as? String
        guard state=="running" || state=="stopped" else{throw DeskError.message("imageUpdateChanged")}
        // An empty original command must not accidentally inherit a new image CMD.
        if clone.arguments.isEmpty,!(try ImageDefaults(metadata,architecture:clone.base.architecture)).command.isEmpty {throw DeskError.message("cloneUnsupported")}
        var ports:[String]=[],allowedHosts=Set<String>(),allowedPorts=Set<Int>()
        for p in config["publishedPorts"] as? [[String:Any]] ?? [] {
            guard let host=p["hostAddress"] as? String,let hp=p["hostPort"] as? Int,let cp=p["containerPort"] as? Int,
                  (1...65535).contains(hp),(1...65535).contains(cp),let proto=p["proto"] as? String,["tcp","udp"].contains(proto),
                  (p["count"] as? Int ?? 1)==1 else{throw DeskError.message("cloneUnsupported")}
            var v4=in_addr(),v6=in6_addr()
            let ipv6=inet_pton(AF_INET6,host,&v6)==1
            guard ipv6 || inet_pton(AF_INET,host,&v4)==1 else{throw DeskError.message("cloneUnsupported")}
            ports.append("\(ipv6 ? "["+host+"]":host):\(hp):\(cp)/\(proto)")
            if proto=="tcp" {allowedPorts.insert(hp);allowedHosts.insert(host=="0.0.0.0" ? "127.0.0.1":host=="::" ? "::1":host)}
        }
        var healthURL:URL?
        if !health.isEmpty {
            guard state=="running",let c=URLComponents(string:health),["http","https"].contains(c.scheme ?? ""),c.user==nil,c.password==nil,c.fragment==nil,
                  let host=c.host,allowedHosts.contains(host.trimmingCharacters(in:CharacterSet(charactersIn:"[]"))),allowedPorts.contains(c.port ?? (c.scheme=="https" ? 443:80)),let url=c.url else{throw DeskError.message("imageUpdateHealthURL")}
            healthURL=url
        }
        var request=clone.request(environment:true,mounts:true,writable:true);request.name=replacement
        _=try request.arguments()
        guard replacement != clone.id else{throw DeskError.message("invalidName")}
        self.clone=clone;self.sourceData=container;self.image=image;self.version=version;self.replacement=replacement;self.wasRunning=state=="running";self.ports=ports;self.healthURL=healthURL
    }
    func arguments(image pin:String)throws->[String] {
        var r=clone.request(environment:true,mounts:true,writable:true);r.name=replacement;r.image=pin
        var result=try r.arguments()
        let index=result.firstIndex(of:"--")!
        result.insert(contentsOf:ports.flatMap{["--publish",$0]},at:index)
        return result
    }
}

struct ContainerUpdateReceipt:Codable,Identifiable {
    var id:String{replacement}
    let original:String
    let replacement:String
    let originalFingerprint:String
    let replacementFingerprint:String
    let wasRunning:Bool
    let imagePin:String
}

/// Injectable commands let scripted tests exercise failure and cancellation paths.
@MainActor struct ImageUpdateWorkflow {
    typealias Command=([String])async throws->Data
    let command:Command
    var probe:(URL)async throws->Void = {try await UpdateHTTPProbe.check($0)}
    var pause:()async throws->Void = {try await Task.sleep(for:.seconds(1))}
    func version(_ name:String)async throws->LocalImageVersion {try LocalImageVersion(await command(["image","inspect","--",name]))}
    func refresh(_ image:String)async throws->ImageRefreshResult {
        guard ResourceRequest.validImage(image),!image.contains("@") else{throw DeskError.message("imageUpdatePinned")}
        let before=try await version(image)
        let backup="docker.io/container-desk-backup/"+UUID().uuidString.lowercased()+":previous"
        _=try await command(["image","tag","--",image,backup])
        guard try await version(backup)==before else{throw DeskError.message("imageUpdateChanged")}
        do {
            for arch in before.architectures {try Task.checkCancellation();_=try await command(["image","pull","--arch",arch,"--",image])}
            let after=try await version(image)
            guard Set(before.architectures).isSubset(of:after.architectures) else{throw DeskError.message("imageUpdateInvalid")}
            return ImageRefreshResult(before:before,after:after,backup:backup)
        } catch {
            // Cancellation must not cancel compensation. The backup also survives app exit.
            let restored=await Task { @MainActor in
                do {_=try await command(["image","tag","--",backup,image]);return try await version(image)==before}catch{return false}
            }.value
            throw DeskError.message(restored ? "imageUpdatePullFailed":"imageUpdateRecoveryFailed")
        }
    }
    func inspect(_ id:String)async throws->Data {try await command(["inspect","--",id])}
    func state(_ data:Data)throws->String {
        guard let item=try ContainerItem.parse(data).first else{throw DeskError.message("imageUpdateInvalid")};return item.state
    }
    func verifySource(_ plan:ContainerUpdatePlan)async throws {
        let current=try await inspect(plan.clone.id)
        guard try ContainerUpdatePlan.fingerprint(current)==ContainerUpdatePlan.fingerprint(plan.sourceData),try state(current)==(plan.wasRunning ? "running":"stopped") else{throw DeskError.message("imageUpdateChanged")}
    }
    func apply(_ plan:ContainerUpdatePlan)async throws->ContainerUpdateReceipt {
        try await verifySource(plan)
        guard try await version(plan.image)==plan.version else{throw DeskError.message("imageUpdateChanged")}
        let inventory=try ContainerItem.parse(await command(["list","--all","--format","json"]))
        guard !inventory.contains(where:{$0.id==plan.replacement}) else{throw DeskError.message("imageUpdateChanged")}
        let pin="docker.io/container-desk-backup/"+UUID().uuidString.lowercased()+":replacement"
        _=try await command(["image","tag","--",plan.image,pin])
        guard try await version(pin)==plan.version else{throw DeskError.message("imageUpdateChanged")}
        try await verifySource(plan)
        var attemptedStop=false,attemptedCreate=false
        do {
            try Task.checkCancellation()
            if plan.wasRunning {attemptedStop=true;_=try await command(["stop","--",plan.clone.id])}
            let stopped=try await inspect(plan.clone.id)
            guard try state(stopped)=="stopped",try ContainerUpdatePlan.fingerprint(stopped)==ContainerUpdatePlan.fingerprint(plan.sourceData) else{throw DeskError.message("imageUpdateChanged")}
            try Task.checkCancellation();attemptedCreate=true
            guard try await version(plan.image)==plan.version else{throw DeskError.message("imageUpdateChanged")}
            _=try await command(plan.arguments(image:plan.image))
            var created=try await inspect(plan.replacement)
            guard try ContainerClonePlan(created,allowEmptyArguments:true).imageDigest==plan.version.digest else{throw DeskError.message("imageUpdateInvalid")}
            if plan.wasRunning {
                _=try await command(["start","--",plan.replacement])
                // Require multiple observations; process liveness is not application health.
                for _ in 0..<3 {try await pause();guard try state(await inspect(plan.replacement))=="running" else{throw DeskError.message("imageUpdateUnhealthy")}}
                if let url=plan.healthURL {
                    var healthy=false
                    for _ in 0..<10 {
                        try Task.checkCancellation()
                        do {try await probe(url);healthy=true;break}catch is CancellationError{throw CancellationError()}catch{try await pause()}
                    }
                    guard healthy else{throw DeskError.message("imageUpdateUnhealthy")}
                }
            }
            created=try await inspect(plan.replacement)
            guard try state(created)==(plan.wasRunning ? "running":"stopped") else{throw DeskError.message("imageUpdateUnhealthy")}
            return try ContainerUpdateReceipt(original:plan.clone.id,replacement:plan.replacement,originalFingerprint:ContainerUpdatePlan.fingerprint(plan.sourceData),replacementFingerprint:ContainerUpdatePlan.fingerprint(created),wasRunning:plan.wasRunning,imagePin:pin)
        } catch {
            let stoppedAttempt=attemptedStop,createdAttempt=attemptedCreate
            let recovered=await Task { @MainActor in
                do {
                    if createdAttempt {
                        let rows=try ContainerItem.parse(await command(["list","--all","--format","json"]))
                        if rows.contains(where:{$0.id==plan.replacement}) {
                            let raw=try await inspect(plan.replacement)
                            let owned=try ContainerClonePlan(raw,allowEmptyArguments:true)
                            guard owned.base.image==plan.image,owned.imageDigest==plan.version.digest else{return false}
                            if try state(raw)=="running" {_=try await command(["stop","--",plan.replacement])}
                            guard try state(await inspect(plan.replacement))=="stopped" else{return false}
                        }
                    }
                    let old=try await inspect(plan.clone.id)
                    guard try ContainerUpdatePlan.fingerprint(old)==ContainerUpdatePlan.fingerprint(plan.sourceData) else{return false}
                    if stoppedAttempt,try state(old)=="stopped" {_=try await command(["start","--",plan.clone.id])}
                    return try state(await inspect(plan.clone.id))==(plan.wasRunning ? "running":"stopped")
                }catch{return false}
            }.value
            throw DeskError.message(recovered ? "imageUpdateRolledBack":"imageUpdateRecoveryFailed")
        }
    }
    func rollback(_ receipt:ContainerUpdateReceipt,history:[ContainerUpdateReceipt]=[])async throws {
        // Revert a chain newest-first; otherwise an older original can run beside
        // the current replacement against the same writable data.
        guard !history.contains(where:{$0.original==receipt.replacement}) else{throw DeskError.message("imageUpdateChanged")}
        try Task.checkCancellation()
        try await Task { @MainActor in
            try await restore(receipt)
        }.value
    }
    private func restore(_ receipt:ContainerUpdateReceipt)async throws {
        let old=try await inspect(receipt.original),new=try await inspect(receipt.replacement)
        guard try ContainerUpdatePlan.fingerprint(old)==receipt.originalFingerprint,try ContainerUpdatePlan.fingerprint(new)==receipt.replacementFingerprint,try state(old)=="stopped" else{throw DeskError.message("imageUpdateChanged")}
        if try state(new)=="running" {_=try await command(["stop","--",receipt.replacement])}
        guard try state(await inspect(receipt.replacement))=="stopped" else{throw DeskError.message("imageUpdateRecoveryFailed")}
        if receipt.wasRunning {_=try await command(["start","--",receipt.original])}
        guard try state(await inspect(receipt.original))==(receipt.wasRunning ? "running":"stopped") else{throw DeskError.message("imageUpdateRecoveryFailed")}
    }
}

final class UpdateHTTPProbe:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
    static func check(_ url:URL)async throws {
        let config=URLSessionConfiguration.ephemeral;config.httpCookieStorage=nil;config.urlCredentialStorage=nil;config.timeoutIntervalForResource=5
        let session=URLSession(configuration:config,delegate:UpdateHTTPProbe(),delegateQueue:nil);defer{session.invalidateAndCancel()}
        let (_,response)=try await session.bytes(for:URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:5))
        guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else{throw DeskError.message("imageUpdateUnhealthy")}
    }
}
