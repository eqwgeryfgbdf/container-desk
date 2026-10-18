import Foundation

extension PlatformTests {
    @MainActor func testCloneLive()async throws {
        let store=Store();await store.start();let cli=try XCTUnwrap(store.cli)
        func run(_ args:[String])async throws->CommandResult{try await ProcessRunner.checked(cli,args)}
        let baseline=try ContainerItem.parse((try await run(["list","--all","--format","json"])).data)
        let suffix=String(UUID().uuidString.lowercased().prefix(8)),source="cd-clone-"+suffix,target="cd-clone-copy-"+suffix
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(source)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        try Data("preserved\n".utf8).write(to:directory.appendingPathComponent("sentinel"))
        defer{try? FileManager.default.removeItem(at:directory)}
        func cleanup()async throws {
            let rows=try ContainerItem.parse((try await run(["list","--all","--format","json"])).data)
            for id in [target,source] {if let row=rows.first(where:{$0.id==id}){if row.running{_=try await run(["stop","--",id])};_=try await run(["delete","--",id])}}
        }
        do {
            _=try await run(["create","--name",source,"--cpus","1","--memory","256M","--env","CLONE_TEST=fixture","--volume",directory.path+":/data:ro","docker.io/library/python:3.13-slim","sleep","600"])
            let original=try await run(["inspect","--",source]);let plan=try ContainerClonePlan(original.data)
            try XCTAssertEqual(plan.mounts.count,1)
            var request=plan.request(environment:true,mounts:true,writable:false);request.name=target
            let created=await store.create(request,origin:plan.origin(requireStopped:false))
            try XCTAssertTrue(created,store.error ?? "clone failed")
            let actual=try ContainerClonePlan((try await run(["inspect","--",target])).data)
            try XCTAssertEqual(actual.base.cpus,1);try XCTAssertEqual(actual.base.memoryMB,256)
            try XCTAssertEqual(actual.arguments,["600"]);try XCTAssertEqual(actual.mounts.first?.readOnly,true)
            try XCTAssertTrue(actual.environment.contains("CLONE_TEST=fixture"))
            try plan.origin(requireStopped:false).validate((try await run(["inspect","--",source])).data)
            _=try await run(["start","--",target])
            let contents=try await run(["exec","--",target,"cat","/data/sentinel"])
            try XCTAssertEqual(contents.text,"preserved\n")
            _=try await run(["stop","--",target])
            try await cleanup()
            let after=try ContainerItem.parse((try await run(["list","--all","--format","json"])).data)
            try XCTAssertEqual(Dictionary(uniqueKeysWithValues:baseline.map{($0.id,$0.state)}),Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)}))
            try XCTAssertEqual(try String(contentsOf:directory.appendingPathComponent("sentinel"),encoding:.utf8),"preserved\n")
            print("PASS: real independent clone preserves source, CPU/memory/command/env/read-only mount, starts correctly, reads retained data and removes only fixtures")
        }catch{try await cleanup();throw error}
    }
}
