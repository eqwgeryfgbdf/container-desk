import Foundation
import Darwin

func check(_ value:Bool,_ message:String)throws {if !value{throw DeskError.message(message)}}
func json(_ object:Any)throws->Data{try JSONSerialization.data(withJSONObject:object,options:.sortedKeys)}
let oldDigest="sha256:"+String(repeating:"a",count:64),newDigest="sha256:"+String(repeating:"b",count:64)
func image(_ digest:String)throws->Data {try json([["configuration":["descriptor":["digest":digest]],"variants":[["platform":["architecture":"arm64","os":"linux"],"config":["config":["Cmd":["600"]]]]]]])}
func container(_ id:String="old",digest:String=oldDigest,reference:String="docker.io/library/test:latest",state:String="running")throws->Data {
    try json([["id":id,"status":["state":state],"configuration":["id":id,"image":["reference":reference,"descriptor":["digest":digest]],"resources":["cpus":1,"memoryInBytes":268435456],"platform":["architecture":"arm64","os":"linux"],"initProcess":["executable":"/bin/sleep","arguments":["600"],"environment":["TOKEN=fixture"],"workingDirectory":"/","user":["id":["uid":0,"gid":0]],"terminal":false],"networks":[["network":"default","options":["hostname":id]]],"mounts":[["source":"/tmp/fixture","destination":"/data","options":["ro"],"type":["virtiofs":[:]]]],"publishedPorts":[["hostAddress":"127.0.0.1","hostPort":18999,"containerPort":80,"proto":"tcp","count":1]],"runtimeHandler":"container-runtime-linux"]]])
}
@MainActor final class Fake {
    var images:[String:Data]=[:],containers:[String:Data]=[:]
    var calls:[[String]]=[]
    var fail:String?,cancel=false,pulledDigest=newDigest
    init()throws{images["docker.io/library/test:latest"]=try image(newDigest);containers["old"]=try container()}
    func setState(_ id:String,_ state:String)throws {var rows=try JSONSerialization.jsonObject(with:containers[id]!) as! [[String:Any]];rows[0]["status"]=["state":state];containers[id]=try json(rows)}
    func run(_ args:[String])async throws->Data {
        calls.append(args)
        if args.first==fail {if cancel{throw CancellationError()};throw DeskError.message("injected")}
        if args.first=="image" {
            if args[1]=="inspect",let data=images[args.last!] {return data}
            if args[1]=="tag" {images[args.last!]=images[args[3]];return Data()}
            if args[1]=="pull" {if fail=="pull" {throw DeskError.message("network")};images[args.last!]=try image(pulledDigest);return Data()}
        }
        if args.first=="inspect",let data=containers[args.last!] {return data}
        if args.first=="list" {return try json(try containers.values.flatMap{try JSONSerialization.jsonObject(with:$0) as! [[String:Any]]})}
        if args.first=="create" {
            let id=args[args.firstIndex(of:"--name")!+1],ref=args[args.firstIndex(of:"--")!+1]
            containers[id]=try container(id,digest:LocalImageVersion(images[ref]!).digest,reference:ref,state:"stopped");return Data()
        }
        if args.first=="start" || args.first=="stop" {try setState(args.last!,args.first=="start" ? "running":"stopped");return Data()}
        throw DeskError.message("unexpected command")
    }
    var workflow:ImageUpdateWorkflow{ImageUpdateWorkflow(command:run,probe:{_ in},pause:{})}
    func plan(health:String="")throws->ContainerUpdatePlan{try ContainerUpdatePlan(container:containers["old"]!,image:"docker.io/library/test:latest",metadata:images["docker.io/library/test:latest"]!,replacement:"new",health:health)}
    func state(_ id:String)throws->String {try ContainerItem.parse(containers[id]!).first!.state}
}

@main struct ImageUpdateTests {
    @MainActor static func main()async throws {
        setbuf(stdout,nil)
        let f=try Fake();let p=try f.plan(health:"http://127.0.0.1:18999/health")
        let args=try p.arguments(image:p.image)
        try check(args.contains("127.0.0.1:18999:80/tcp") && args.contains("/tmp/fixture:/data:ro") && args.contains("TOKEN=fixture"),"ports/mounts/env preservation")
        for url in ["http://example.com:18999/","http://127.0.0.1:80/","http://user:password@127.0.0.1:18999/","file:///tmp/x"] {
            do{_=try f.plan(health:url);throw DeskError.message("accepted invalid health URL")}catch let e as DeskError{try check(e.description=="imageUpdateHealthURL","URL rejection")}
        }
        let receipt=try await f.workflow.apply(p)
        try check(try f.state("old")=="stopped" && f.state("new")=="running","successful replacement")
        let successor=ContainerUpdateReceipt(original:receipt.replacement,replacement:"newest",originalFingerprint:receipt.replacementFingerprint,replacementFingerprint:"unused",wasRunning:true,imagePin:"unused")
        let beforeRollback=f.calls.count
        do{try await f.workflow.rollback(receipt,history:[receipt,successor]);throw DeskError.message("accepted out-of-order rollback")}
        catch let e as DeskError{try check(e.description=="imageUpdateChanged","rollback chain refusal")}
        try check(f.calls.count==beforeRollback,"out-of-order rollback must not issue commands")
        try await f.workflow.rollback(receipt)
        try check(try f.state("old")=="running" && f.state("new")=="stopped","explicit rollback")
        for mode in ["create","cancel","health"] {
            let mock=try Fake();var workflow=mock.workflow
            if mode=="health"{workflow.probe={_ in throw DeskError.message("unhealthy")}}
            else{mock.fail="create";mock.cancel=mode=="cancel"}
            do{_=try await workflow.apply(mock.plan(health:"http://127.0.0.1:18999/"));throw DeskError.message("expected rollback")}
            catch let e as DeskError{try check(e.description=="imageUpdateRolledBack","failure/cancel compensation: "+e.description)}
            try check(try mock.state("old")=="running","original recovery")
            if mock.containers["new"] != nil{try check(try mock.state("new")=="stopped","failed replacement stopped")}
        }
        let stale=try Fake(),stalePlan=try Fake().plan();try stale.setState("old","stopped")
        do{_=try await stale.workflow.apply(stalePlan);throw DeskError.message("expected stale refusal")}catch let e as DeskError{try check(e.description=="imageUpdateChanged","stale refusal")}
        try check(!stale.calls.contains{$0.first=="stop" || $0.first=="create"},"stale plan must not mutate")
        let download=try Fake();download.images[p.image]=try image(oldDigest)
        let refreshed=try await download.workflow.refresh(p.image);try check(refreshed.changed,"new digest detected")
        let current=try await download.workflow.refresh(p.image);try check(!current.changed,"unchanged digest")
        download.fail="pull"
        do{_=try await download.workflow.refresh(p.image);throw DeskError.message("expected pull failure")}catch let e as DeskError{try check(e.description=="imageUpdatePullFailed","download recovery")}
        try check(try LocalImageVersion(download.images[p.image]!).digest==newDigest,"previous reference restored")
        do{_=try await download.workflow.refresh("test@"+oldDigest);throw DeskError.message("expected pinned refusal")}catch let e as DeskError{try check(e.description=="imageUpdatePinned","immutable refusal")}
        print("PASS: update planning, port/mount/env preservation, 4 invalid health URLs, replacement, rollback, create failure, cancellation, HTTP failure, stale refusal, changed/unchanged digests, failed pull recovery and immutable digest rejection")
        if CommandLine.arguments.contains("--live"){try await live()}
    }
    @MainActor static func live()async throws {
        let cli=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/container").path
        var pins=Set<String>()
        func run(_ args:[String])async throws->Data {
            if args.prefix(2)==["image","tag"],let last=args.last,last.contains("container-desk-backup/"){pins.insert(last)}
            return try await ProcessRunner.checked(cli,args,timeout:600).data
        }
        let before=try ContainerItem.parse(await run(["list","--all","--format","json"]))
        let initialImages=Set(try ResourceItem.parseImages(await run(["image","list","--format","json"])).map(\.id))
        let suffix=String(UUID().uuidString.lowercased().prefix(8)),old="cd-update-"+suffix,new="cd-update-new-"+suffix,failed="cd-update-fail-"+suffix
        let ref="docker.io/container-desk-test/"+suffix+":latest",v1="docker.io/library/busybox:1.36.1",v2="docker.io/library/busybox:1.37.0"
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(old)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:false)
        try "preserved".write(to:dir.appendingPathComponent("sentinel"),atomically:true,encoding:.utf8)
        defer{try? FileManager.default.removeItem(at:dir)}
        func cleanup()async {
            for name in [new,failed,old] {
                if let rows=try? ContainerItem.parse(await run(["list","--all","--format","json"])),let c=rows.first(where:{$0.id==name}) {
                    if c.running{_=try? await run(["stop","--",name])};_=try? await run(["delete","--",name])
                }
            }
            for image in pins.union([ref,v1,v2]).subtracting(initialImages){_=try? await run(["image","delete","--",image])}
        }
        do {
            for v in [v1,v2]{_=try await run(["image","pull","--arch","arm64","--",v])}
            _=try await run(["image","tag","--",v1,ref])
            // Unique loopback port: script selects an unused port without touching existing containers.
            let socketFD=socket(AF_INET,SOCK_STREAM,0);guard socketFD>=0 else{throw DeskError.message("socket")}
            var addr=sockaddr_in();addr.sin_len=UInt8(MemoryLayout<sockaddr_in>.size);addr.sin_family=sa_family_t(AF_INET);addr.sin_addr.s_addr=inet_addr("127.0.0.1")
            let bound=withUnsafePointer(to:&addr){$0.withMemoryRebound(to:sockaddr.self,capacity:1){bind(socketFD,$0,socklen_t(MemoryLayout<sockaddr_in>.size))}}
            guard bound==0 else{close(socketFD);throw DeskError.message("bind")}
            var length=socklen_t(MemoryLayout<sockaddr_in>.size)
            _=withUnsafeMutablePointer(to:&addr){$0.withMemoryRebound(to:sockaddr.self,capacity:1){getsockname(socketFD,$0,&length)}}
            let port=Int(UInt16(bigEndian:addr.sin_port));close(socketFD)
            _=try await run(["create","--name",old,"--cpus","1","--memory","256M","--publish","127.0.0.1:\(port):8080","--volume",dir.path+":/data:ro","--env","UPDATE_TEST=kept","--",ref,"sh","-c","mkdir -p /www; echo ready > /www/index.html; exec httpd -f -p 8080 -h /www"])
            _=try await run(["start","--",old])
            let original=try await run(["inspect","--",old])
            _=try await run(["image","tag","--",v2,ref])
            let meta=try await run(["image","inspect","--",ref])
            let plan=try ContainerUpdatePlan(container:original,image:ref,metadata:meta,replacement:new,health:"http://127.0.0.1:\(port)/")
            let workflow=ImageUpdateWorkflow(command:run)
            let receipt=try await workflow.apply(plan)
            let marker=try await run(["exec","--",new,"cat","/data/sentinel"])
            try check(String(decoding:marker,as:UTF8.self)=="preserved","mounted data")
            let env=try await run(["exec","--",new,"printenv","UPDATE_TEST"])
            try check(String(decoding:env,as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines)=="kept","environment")
            try await workflow.rollback(receipt)
            let unhealthy=try ContainerUpdatePlan(container:await run(["inspect","--",old]),image:ref,metadata:meta,replacement:failed,health:"http://127.0.0.1:\(port)/missing")
            var fast=workflow;fast.pause={try await Task.sleep(for:.milliseconds(300))}
            do{_=try await fast.apply(unhealthy);throw DeskError.message("expected unhealthy rollback")}catch let e as DeskError{try check(e.description=="imageUpdateRolledBack","real unhealthy recovery: "+e.description)}
            try check(try workflow.state(await run(["inspect","--",old]))=="running","original running after failure")
            let current=try await workflow.refresh(v2);try check(!current.changed,"real registry digest check")
            await cleanup()
            let after=try ContainerItem.parse(await run(["list","--all","--format","json"]))
            try check(Dictionary(uniqueKeysWithValues:before.map{($0.id,$0.state)})==Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)}),"production container state unchanged")
            try check(Set(try ResourceItem.parseImages(await run(["image","list","--format","json"])).map(\.id))==initialImages,"fixture images removed")
            print("PASS LIVE: BusyBox 1.36.1 → 1.37.0, HTTP 2xx, port/env/mount preservation, explicit rollback, HTTP 404 automatic rollback, real registry refresh; fixture cleanup and original container states verified")
        }catch{await cleanup();throw error}
    }
}
