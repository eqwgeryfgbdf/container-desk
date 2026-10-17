import Foundation
import Darwin

extension RegistryLiveTests {
    @MainActor func testLoopbackPush(sourceOverride:String?=nil,expectedLayers:Int=0)async throws {
        let s=Store();await s.start();let cli=try XCTUnwrap(s.cli)
        let baseline=Dictionary(uniqueKeysWithValues:s.containers.map{($0.id,$0.state)})
        let registryImage="docker.io/library/registry:3",hadRegistry=s.images.contains{$0.id==registryImage}
        let prefix="cd-qa-registry-"+UUID().uuidString.lowercased().prefix(8),source=sourceOverride ?? "docker.io/library/cd-qa-"+UUID().uuidString.lowercased().prefix(8)+":empty"
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(prefix)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:directory)}
        let archive=directory.appendingPathComponent("image.tar")
        let fd=socket(AF_INET,SOCK_STREAM,0);guard fd>=0 else{throw DeskError.message("socket failed")}
        var address=sockaddr_in();address.sin_len=UInt8(MemoryLayout<sockaddr_in>.size);address.sin_family=sa_family_t(AF_INET);address.sin_addr.s_addr=inet_addr("127.0.0.1")
        let bound=withUnsafePointer(to:&address){$0.withMemoryRebound(to:sockaddr.self,capacity:1){Darwin.bind(fd,$0,socklen_t(MemoryLayout<sockaddr_in>.size))}}
        guard bound==0 else{close(fd);throw DeskError.message("bind failed")}
        var size=socklen_t(MemoryLayout<sockaddr_in>.size)
        _=withUnsafeMutablePointer(to:&address){$0.withMemoryRebound(to:sockaddr.self,capacity:1){getsockname(fd,$0,&size)}}
        let port=UInt16(bigEndian:address.sin_port);close(fd)
        let target="127.0.0.1:\(port)/qa/image:smoke"
        func command(_ args:[String])async throws->CommandResult{try await ProcessRunner.checked(cli,args,timeout:180)}
        func cleanup()async throws {
            let containers=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            if let c=containers.first(where:{$0.id==prefix}) {if c.running{_=try await command(["stop","--",prefix])};_=try await command(["delete","--",prefix])}
            let images=try ResourceItem.parseImages((try await command(["image","list","--format","json"])).data)
            for name in [target]+(sourceOverride == nil ? [source]:[])+(hadRegistry ? []:[registryImage]) where images.contains(where:{$0.id==name}) {
                let inventory=try await command(["image","list","--format","json"])
                let fresh=try await command(["list","--all","--format","json"])
                try ResourceSafety.validateDeletion(kind:.image,id:name,inventory:inventory.data,containers:fresh.data)
                _=try await command(["image","delete","--",name])
            }
        }
        do {
            if sourceOverride == nil {
            let fixture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/empty-oci.py")
            _=try await ProcessRunner.checked("/usr/bin/python3",[fixture.path,archive.path,source])
            _=try await command(["image","load","--input",archive.path])
            }
            if !hadRegistry {_=try await command(["image","pull","--arch","arm64","--progress","plain","--",registryImage])}
            _=try await command(["create","--name",prefix,"--cpus","1","--memory","256M","--publish","127.0.0.1:\(port):5000","--",registryImage])
            _=try await command(["start","--",prefix])
            var ready=false
            for _ in 0..<30 {
                let result=try await ProcessRunner.run("/usr/bin/curl",["--silent","--fail","--max-time","2","http://127.0.0.1:\(port)/v2/"])
                if result.code==0{ready=true;break};try await Task.sleep(for:.milliseconds(250))
            }
            try XCTAssertTrue(ready,"Loopback test registry ready")
            await s.refresh();s.pushImage(source:source,target:target,localHTTP:true)
            let deadline=Date().addingTimeInterval(120)
            while s.operationRunning {guard Date()<deadline else{s.cancelOperation();throw DeskError.message("Push timeout")};try await Task.sleep(for:.milliseconds(100))}
            try XCTAssertEqual(s.operationResult,"operationComplete",s.operationOutput)
            let response=try await ProcessRunner.checked("/usr/bin/curl",["--silent","--fail","--max-time","5","-H","Accept: application/vnd.oci.image.manifest.v1+json","http://127.0.0.1:\(port)/v2/qa/image/manifests/smoke"])
            var manifest=try XCTUnwrap(JSONSerialization.jsonObject(with:response.data) as? [String:Any])
            if let descriptors=manifest["manifests"] as? [[String:Any]] {
                let digest=try XCTUnwrap(descriptors.first?["digest"] as? String)
                try XCTAssertTrue(digest.range(of:"^sha256:[a-f0-9]{64}$",options:.regularExpression) != nil)
                let child=try await ProcessRunner.checked("/usr/bin/curl",["--silent","--fail","--max-time","5","-H","Accept: application/vnd.oci.image.manifest.v1+json","http://127.0.0.1:\(port)/v2/qa/image/manifests/"+digest])
                manifest=try XCTUnwrap(JSONSerialization.jsonObject(with:child.data) as? [String:Any])
            }
            try XCTAssertEqual((manifest["layers"] as? [Any])?.count,expectedLayers)
            try await cleanup()
            let after=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            try XCTAssertEqual(Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)}),baseline)
            print("PASS: real image push to a disposable loopback Distribution registry, manifest HTTP readback, tag/image/container cleanup and original-state preservation")
        }catch{try await cleanup();throw error}
    }
}
