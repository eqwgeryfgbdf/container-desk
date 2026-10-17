import Foundation
import Darwin

/// Disposable integration only; never stops or deletes pre-existing containers.
@main struct WorkflowIntegration {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.contains("--run") else {print("Pass --run to create two disposable test containers.");return}
        let s=Store();await s.start()
        guard s.connected,let cli=s.cli else {throw DeskError.message("Engine unavailable")}
        let baseline=Dictionary(uniqueKeysWithValues:s.containers.map{($0.id,$0.state)})
        guard let image=s.images.first(where:{$0.id.contains("python") && $0.detail.contains("arm64")})?.id else {throw DeskError.message("Existing arm64 Python image required")}
        let prefix="cd-qa-"+UUID().uuidString.lowercased().prefix(8)
        let names=[prefix+"-a",prefix+"-b"],volume=prefix+"-data"
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(prefix)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try "host marker".write(to:directory.appendingPathComponent("marker"),atomically:true,encoding:.utf8)
        defer {try? FileManager.default.removeItem(at:directory)}
        func command(_ args:[String]) async throws -> CommandResult {try await ProcessRunner.checked(cli,args,timeout:120)}
        func inventory() async throws -> [ContainerItem] {try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)}
        func settle() async throws {
            let deadline=Date().addingTimeInterval(90)
            while s.refreshing || s.busy {guard Date()<deadline else {throw DeskError.message("Refresh timeout")};try await Task.sleep(for:.milliseconds(100))}
            await s.refresh()
        }
        func batch(_ verb:BatchVerb,_ items:[ContainerItem],expected:String="operationComplete") async throws {
            s.batchOperation(BatchRequest(verb:verb,items:items))
            let deadline=Date().addingTimeInterval(180)
            while s.operationRunning {guard Date()<deadline else {s.cancelOperation();throw DeskError.message("Batch timeout")};try await Task.sleep(for:.milliseconds(100))}
            guard s.operationResult==expected else {throw DeskError.message("Unexpected batch result \(s.operationResult ?? "nil"): \(s.operationOutput)")}
            try await settle()
        }
        func cleanup() async throws {
            for c in try await inventory() where names.contains(c.id) {
                if c.running {_=try await command(["stop","--",c.id])}
                _=try await command(["delete","--",c.id])
            }
            let volumes=try ResourceItem.parseResources((try await command(["volume","list","--format","json"])).data)
            if volumes.contains(where:{$0.id==volume}) {_=try await command(["volume","delete","--",volume])}
        }
        func freePort() throws -> Int {
            let fd=socket(AF_INET,SOCK_STREAM,0);guard fd>=0 else {throw DeskError.message("socket failed")};defer{close(fd)}
            var address=sockaddr_in();address.sin_len=UInt8(MemoryLayout<sockaddr_in>.size);address.sin_family=sa_family_t(AF_INET);address.sin_addr.s_addr=inet_addr("127.0.0.1")
            let bound=withUnsafePointer(to:&address){$0.withMemoryRebound(to:sockaddr.self,capacity:1){Darwin.bind(fd,$0,socklen_t(MemoryLayout<sockaddr_in>.size))}}
            guard bound==0 else{throw DeskError.message("bind failed")}
            var length=socklen_t(MemoryLayout<sockaddr_in>.size)
            let result=withUnsafeMutablePointer(to:&address){$0.withMemoryRebound(to:sockaddr.self,capacity:1){getsockname(fd,$0,&length)}}
            guard result==0 else{throw DeskError.message("getsockname failed")};return Int(UInt16(bigEndian:address.sin_port))
        }
        do {
            _=try await command(["volume","create","-s","1G","--",volume])
            let p1=try freePort();var p2=try freePort();while p2==p1 {p2=try freePort()}
            for (index,name) in names.enumerated() {
                var create=CreateRequest();create.name=name;create.image=image;create.cpus=1;create.memoryMB=256;create.entrypoint="/bin/sh"
                if index==0 {
                    create.hostPort=String(p1);create.containerPort="8000"
                    create.additionalPorts=[PortMapping(host:String(p2),container:"8001"),PortMapping(host:String(p1),container:"5353",transport:"udp")]
                    create.mountSource=directory.path;create.mountTarget="/host-ro";create.readOnly=true
                    create.additionalMounts=[MountMapping(source:directory.path,target:"/host-rw"),MountMapping(kind:.volume,source:volume,target:"/qa")]
                    create.commandArguments="-c\nprintf 'QA ready\\nERROR test-marker\\n'; touch /qa/marker; python3 -m http.server 8000 --bind 0.0.0.0 >/dev/null 2>&1 & exec python3 -m http.server 8001 --bind 0.0.0.0"
                } else {create.commandArguments="-c\nprintf 'QA second\\n'; while :; do sleep 1; done"}
                guard await s.create(create) else{throw DeskError.message(s.error ?? "Create failed")}
                try await settle()
            }
            let created=try await inventory().filter{names.contains($0.id)}.sorted{$0.id<$1.id}
            guard created.count==2,created.allSatisfy({$0.state=="stopped"}),created[0].ports.count==3,created[0].mounts.count>=3 else{throw DeskError.message("Multi-mapping create/readback mismatch")}
            var missing=created[0];missing=ContainerItem(id:prefix+"-missing",state:"stopped",image:image,cpus:1,memory:268435456,ports:[],networks:[],mounts:[])
            try await batch(.start,[created[0],missing,created[1]],expected:"operationFailed")
            guard s.operationOutput.contains("resourceDisappeared"),s.operationOutput.contains(names[1]),s.containers.filter({names.contains($0.id)}).allSatisfy(\.running) else {throw DeskError.message("Partial failure prevented later targets or lost result")}
            for port in [p1,p2] {
                var connected=false
                for _ in 0..<20 {
                    let r=try await ProcessRunner.run("/usr/bin/curl",["--silent","--fail","--max-time","2","http://127.0.0.1:\(port)/"])
                    if r.code==0 {connected=true;break};try await Task.sleep(for:.milliseconds(300))
                }
                guard connected else {throw DeskError.message("Published HTTP port unavailable")}
            }
            _=try await command(["exec","--",names[0],"/bin/sh","-c","test -f /host-ro/marker && test -f /qa/marker && touch /host-rw/writable && ! touch /host-ro/must-not-write"])
            let logs=try await command(["logs","-n","500","--",names[0]])
            guard LogSnapshot.filtered(logs.text,query:"error").contains("ERROR test-marker") else {throw DeskError.message("Actual log filter failed")}
            let running=try await inventory().filter{names.contains($0.id)}.sorted{$0.id<$1.id}
            _=try await command(["stop","--",names[0]])
            try await batch(.restart,running,expected:"operationFailed")
            guard s.operationOutput.contains("batchStateChanged"),s.containers.first(where:{$0.id==names[0]})?.state=="stopped",s.containers.first(where:{$0.id==names[1]})?.running==true else {throw DeskError.message("Changed-state guard or restart continuation failed")}
            let stillRunning=try await inventory().filter{names.contains($0.id) && $0.running}
            try await batch(.delete,stillRunning,expected:"operationFailed")
            guard s.operationOutput.contains("batchIneligible") else {throw DeskError.message("Running delete should be refused")}
            try await batch(.stop,stillRunning)
            let stopped=try await inventory().filter{names.contains($0.id)}
            try await batch(.delete,stopped)
            try await cleanup()
            let after=try await inventory()
            guard Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)})==baseline else {throw DeskError.message("Unrelated states changed")}
            print("PASS: three port mappings (two HTTP endpoints + UDP metadata); three mounts including read-only bind and named volume; real log search; batch partial failure continues, stale-state refusal, running-delete refusal, restart/stop/delete readback; cleanup. \(baseline.count) original container states unchanged.")
        } catch {try await cleanup();throw error}
    }
}
