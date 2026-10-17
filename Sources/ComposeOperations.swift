import Foundation
import Darwin

struct ComposeProjectRecord:Codable,Identifiable,Equatable {
    let id:String
    let path:String
    var name:String
    var volumeGiB:Int
}
@MainActor final class ComposeProjectLibrary:ObservableObject {
    @Published var projects:[ComposeProjectRecord]=[]
    @Published var error:String?
    private let file:URL
    init(file:URL?=nil) {
        self.file=file ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ContainerDesk/compose-projects.json")
        do {
            if FileManager.default.fileExists(atPath:self.file.path){projects=try JSONDecoder().decode([ComposeProjectRecord].self,from:Data(contentsOf:self.file))}
        }catch{self.error="composeLibraryFailed"}
    }
    func add(_ url:URL)throws->ComposeProjectRecord {
        guard error==nil else{throw DeskError.message("composeLibraryFailed")}
        if let existing=projects.first(where:{$0.path==url.standardizedFileURL.path}){return existing}
        let id=UUID().uuidString.lowercased()
        let plan=try ComposePlanner(file:url,projectID:id).plan()
        let record=ComposeProjectRecord(id:id,path:url.standardizedFileURL.path,name:plan.name,volumeGiB:8)
        let updated=projects+[record]
        try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        try JSONEncoder().encode(updated).write(to:file,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        projects=updated;return record
    }
}

enum ComposeHosts {
    static func update(_ plan:ComposePlan,rows:[[String:Any]])throws {
        for service in plan.services {
            guard let networkIndex=service.createArguments.firstIndex(of:"--network") else{throw DeskError.message("composeStepFailed")}
            let network=service.createArguments[networkIndex+1]
            var text="127.0.0.1 localhost\n::1 localhost ip6-localhost\n"
            for peer in plan.services {
                guard let row=rows.first(where:{($0["id"] as? String ?? ($0["configuration"] as? [String:Any])?["id"] as? String)==peer.container}),
                      let config=row["configuration"] as? [String:Any],(config["labels"] as? [String:String])?[ComposePlan.ownerLabel]==plan.projectID,
                      let status=row["status"] as? [String:Any],status["state"] as? String=="running",let attachments=status["networks"] as? [[String:Any]],
                      let attachment=attachments.first(where:{$0["network"] as? String==network}),let cidr=attachment["ipv4Address"] as? String else{continue}
                guard let first=cidr.split(separator:"/").first else{throw DeskError.message("composeStepFailed")}
                let ip=String(first);var address=in_addr()
                guard inet_pton(AF_INET,ip,&address)==1 else{throw DeskError.message("composeStepFailed")}
                text+="\(ip) \(peer.name) \(peer.container)\n"
            }
            let parent=service.hostsFile.deletingLastPathComponent()
            try FileManager.default.createDirectory(at:parent,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            // Preserve the inode: virtiofs file mounts must see updated contents.
            // O_NOFOLLOW prevents replacing a symlink target on the host.
            let fd=open(service.hostsFile.path,O_WRONLY|O_CREAT|O_NOFOLLOW,0o600)
            guard fd>=0 else{throw DeskError.message("composeHostsFailed")}
            let handle=FileHandle(fileDescriptor:fd,closeOnDealloc:true)
            do {try handle.truncate(atOffset:0);try handle.write(contentsOf:Data(text.utf8));try handle.synchronize();try handle.close()}
            catch{try? handle.close();throw DeskError.message("composeHostsFailed")}
        }
    }
}

@MainActor extension Store {
    func composeOwned(_ projectID:String)async throws->[[String:Any]] {
        guard let cli else{throw DeskError.message("coreMissing")}
        return try ResourceSafety.rows((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data).filter { row in
            let config=row["configuration"] as? [String:Any] ?? [:]
            return (config["labels"] as? [String:String])?[ComposePlan.ownerLabel]==projectID
        }
    }
    func composeUp(_ plan:ComposePlan) {
        guard canMutate,let cli else{return}
        startOperation("composeUp") {
            var report=""
            @MainActor func record(_ message:String){report=String((report+message+"\n").suffix(50000));self.operationOutput=report}
            @MainActor func run(_ args:[String],_ caption:String,timeout:TimeInterval=600) async throws {
                try Task.checkCancellation();record(caption)
                let code=try await StreamingProcess.run(cli,args,timeout:timeout){self.operationOutput=report+$0}
                guard code==0 else{throw DeskError.message("composeStepFailed")}
            }
            func inventory()async throws->[[String:Any]]{try ResourceSafety.rows((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)}
            func config(_ row:[String:Any])->[String:Any]{row["configuration"] as? [String:Any] ?? [:]}
            func id(_ row:[String:Any])->String{row["id"] as? String ?? config(row)["id"] as? String ?? ""}
            func validateContainer(_ service:ComposeService,_ rows:[[String:Any]])throws {
                if let row=rows.first(where:{id($0)==service.container}) {
                    let labels=config(row)["labels"] as? [String:String] ?? [:]
                    guard labels[ComposePlan.ownerLabel]==plan.projectID else{throw DeskError.message("composeNameConflict")}
                    guard labels[ComposePlan.configLabel]==service.fingerprint else{throw DeskError.message("composeConfigurationChanged")}
                }
            }
            let before=try await inventory()
            for service in plan.services {
                try validateContainer(service,before)
                let args=service.createArguments
                if let i=args.firstIndex(of:"--cpus"),let cpu=Int(args[i+1]),cpu>(self.host.logicalCores ?? ProcessInfo.processInfo.activeProcessorCount){throw DeskError.message("allocationOutOfRange")}
                if let i=args.firstIndex(of:"--memory"),let memory=Int64(args[i+1].dropLast()),memory>Int64(self.host.memory/1048576){throw DeskError.message("allocationOutOfRange")}
            }
            // Preflight every referenced resource before creating the first one.
            for (kind,resources) in [("network",plan.networks),("volume",plan.volumes)] {
                let rows=try ResourceSafety.rows((try await ProcessRunner.checked(cli,[kind,"list","--format","json"])).data)
                for resource in resources {
                    let row=rows.first{let c=$0["configuration"] as? [String:Any] ?? $0;return (c["name"] as? String)==resource.name}
                    if resource.external {guard row != nil else{throw DeskError.message("composeExternalMissing")}}
                    else if let row {let c=row["configuration"] as? [String:Any] ?? row;guard (c["labels"] as? [String:String])?[ComposePlan.ownerLabel]==plan.projectID else{throw DeskError.message("composeNameConflict")}}
                }
            }
            try ComposeHosts.update(plan,rows:before)
            for (kind,resources) in [("network",plan.networks),("volume",plan.volumes)] {
                for resource in resources where !resource.external {
                    let rows=try ResourceSafety.rows((try await ProcessRunner.checked(cli,[kind,"list","--format","json"])).data)
                    let existing=rows.first{let c=$0["configuration"] as? [String:Any] ?? $0;return (c["name"] as? String)==resource.name}
                    if let existing {
                        let c=existing["configuration"] as? [String:Any] ?? existing
                        guard (c["labels"] as? [String:String])?[ComposePlan.ownerLabel]==plan.projectID else{throw DeskError.message("composeNameConflict")}
                    } else {
                        let args=[kind,"create"]+(kind=="volume" ? ["-s","\(plan.volumeGiB)G"]:[])+["--label",ComposePlan.ownerLabel+"="+plan.projectID,"--",resource.name]
                        try await run(args,self.t(kind=="volume" ? "createVolume":"createNetwork")+" · "+resource.name)
                    }
                }
            }
            for service in plan.services {
                try Task.checkCancellation()
                let rows=try await inventory();try validateContainer(service,rows)
                if !rows.contains(where:{id($0)==service.container}) {
                    let image=try await ProcessRunner.run(cli,["image","inspect","--",service.image])
                    if image.code != 0 {
                        if let build=service.buildArguments{try await run(build,self.t("build")+" · "+service.name,timeout:1800)}
                        else{try await run(["image","pull","--progress","plain","--arch","arm64","--",service.image],self.t("pull")+" · "+service.name,timeout:1800)}
                    }
                    try await run(service.createArguments,self.t("create")+" · "+service.container)
                }
                // Even an already running dependency must pass its requested
                // readiness probe on each explicit project start.
                for dependency in service.dependencies.keys {
                    guard let required=plan.services.first(where:{$0.name==dependency}) else{throw DeskError.message("composeStepFailed")}
                    let fresh=try await inventory()
                    guard fresh.contains(where:{id($0)==required.container && ($0["status"] as? [String:Any])?["state"] as? String=="running"}) else{throw DeskError.message("composeDependencyStopped")}
                }
                let current=try await inventory();try validateContainer(service,current)
                let row=current.first{ id($0)==service.container }
                let state=(row?["status"] as? [String:Any])?["state"] as? String
                if state != "running" {
                    guard state=="stopped" else{throw DeskError.message("batchStateChanged")}
                    try await run(["start","--",service.container],self.t("start")+" · "+service.container,timeout:120)
                }
                try ComposeHosts.update(plan,rows:try await inventory())
                if let health=service.health {
                    record(self.t("composeCheckingHealth")+" · "+service.name)
                    if health.startPeriod>0 {try await Task.sleep(for:.seconds(health.startPeriod))}
                    var ready=false
                    for attempt in 0..<health.retries {
                        try Task.checkCancellation()
                        // Suppress probe output: health commands can contain env values.
                        do {
                            let code=try await StreamingProcess.run(cli,["exec","--",service.container]+health.command,timeout:health.timeout){_ in}
                            if code==0{ready=true;break}
                        } catch is CancellationError {throw CancellationError()}
                          catch {if error.localizedDescription != "commandTimeout"{throw error}}
                        if attempt+1<health.retries {try await Task.sleep(for:.seconds(health.interval))}
                    }
                    guard ready else{throw DeskError.message("composeHealthFailed")}
                }
                let after=try await inventory()
                guard after.contains(where:{id($0)==service.container && ($0["status"] as? [String:Any])?["state"] as? String=="running"}) else{throw DeskError.message("batchUnconfirmed")}
                record(self.t("operationComplete")+" · "+service.name)
            }
            record(self.t("composeReady"));return 0
        }
    }
    func composeManage(_ projectID:String,ids:[String],remove:Bool) {
        guard canMutate,let cli,!ids.isEmpty else{return}
        startOperation(remove ? "composeDown":"composeStop") {
            var report="",failures=0
            for id in ids {
                do {
                    try Task.checkCancellation()
                    let owned=try await self.composeOwned(projectID)
                    guard let row=owned.first(where:{($0["id"] as? String ?? ($0["configuration"] as? [String:Any])?["id"] as? String)==id}) else{throw DeskError.message("composeNameConflict")}
                    let state=(row["status"] as? [String:Any])?["state"] as? String
                    if state=="running" {
                        let code=try await StreamingProcess.run(cli,["stop","--",id],timeout:120){self.operationOutput=report+$0}
                        guard code==0 else{throw DeskError.message("composeStepFailed")}
                    } else if state != "stopped" {throw DeskError.message("batchStateChanged")}
                    if remove {
                        try Task.checkCancellation()
                        let current=try await self.composeOwned(projectID)
                        guard current.contains(where:{($0["id"] as? String ?? ($0["configuration"] as? [String:Any])?["id"] as? String)==id && ($0["status"] as? [String:Any])?["state"] as? String=="stopped"}) else{throw DeskError.message("batchStateChanged")}
                        let code=try await StreamingProcess.run(cli,["delete","--",id],timeout:120){self.operationOutput=report+$0}
                        guard code==0 else{throw DeskError.message("composeStepFailed")}
                    }
                    let after=try await self.composeOwned(projectID)
                    let found=after.first{($0["id"] as? String ?? ($0["configuration"] as? [String:Any])?["id"] as? String)==id}
                    guard remove ? found==nil:(found?["status"] as? [String:Any])?["state"] as? String=="stopped" else{throw DeskError.message("batchUnconfirmed")}
                    report+=id+" · "+self.t("operationComplete")+"\n"
                } catch is CancellationError {self.operationOutput=report+self.t("batchCancelledNote");throw CancellationError()}
                  catch {failures+=1;report+=id+" · "+self.t(error.localizedDescription)+"\n"}
                self.operationOutput=report
            }
            self.operationOutput=report+self.t("composeRetainData");return failures==0 ? 0:1
        }
    }
}
