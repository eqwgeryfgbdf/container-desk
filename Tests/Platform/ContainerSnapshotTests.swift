import Foundation

extension PlatformTests {
    func testSnapshotPlan()throws {
        func fixture(user:[String:Any] = ["id":["uid":1001,"gid":1002]],state:String="stopped")throws->Data {
            try JSONSerialization.data(withJSONObject:[["configuration":["id":"snapshot-test","platform":["os":"linux","architecture":"arm64"],"initProcess":["executable":"/bin/sh","arguments":["-c","echo literal"],"workingDirectory":"/work","user":user,"environment":["TOKEN=do-not-copy"]]],"status":["state":state]]])
        }
        let omitted=try ContainerSnapshotPlan(fixture(),includeEnvironment:false)
        try XCTAssertEqual(omitted.configuration["User"] as? String,"1001:1002")
        try XCTAssertTrue(omitted.configuration["Env"]==nil)
        try XCTAssertEqual(omitted.configuration["Entrypoint"] as? [String],["/bin/sh"])
        let included=try ContainerSnapshotPlan(fixture(user:["raw":["userString":"app:app"]],state:"running"),includeEnvironment:true)
        try XCTAssertTrue(included.running)
        try XCTAssertEqual(included.configuration["Env"] as? [String],["TOKEN=do-not-copy"])
        try XCTAssertThrowsError(try ContainerSnapshotPlan(fixture(user:["unexpected":true]),includeEnvironment:false))
        try XCTAssertThrowsError(try ContainerSnapshotPlan(fixture(state:"starting"),includeEnvironment:false))
        try XCTAssertEqual(SidebarOrder.normalized("images,images,unknown,overview"),["images","overview","containers","networks","volumes","registries","composeProjects","core","settings"])
    }
    @MainActor func testContainerSnapshotLive()async throws {
        let store=Store();await store.start();let cli=try XCTUnwrap(store.cli)
        let baseline=Dictionary(uniqueKeysWithValues:store.containers.map{($0.id,$0.state)})
        let baselineImages=Set(store.images.map(\.id))
        let suffix=UUID().uuidString.lowercased().prefix(8),source="cd-snapshot-"+suffix,clone="cd-clone-"+suffix
        let base="docker.io/library/busybox:1.37",snapshot="docker.io/containerdesk/snapshot-"+suffix+":test",withEnv="docker.io/containerdesk/snapshot-"+suffix+":env"
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(source)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        try Data("mounted-not-in-image".utf8).write(to:directory.appendingPathComponent("private-marker"))
        defer{try? FileManager.default.removeItem(at:directory)}
        func command(_ args:[String])async throws->CommandResult{try await ProcessRunner.checked(cli,args,timeout:180)}
        func wait()async throws {
            let deadline=Date().addingTimeInterval(180)
            while store.operationRunning{guard Date()<deadline else{store.cancelOperation();throw DeskError.message("Snapshot timed out")};try await Task.sleep(for:.milliseconds(100))}
            try XCTAssertEqual(store.operationResult,"operationComplete",store.operationResult ?? "nil")
            while store.refreshing{try await Task.sleep(for:.milliseconds(100))}
        }
        func cleanup()async throws {
            let items=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            for id in [clone,source] {
                if let c=items.first(where:{$0.id==id}){if c.running{_=try await command(["stop","--",id])};_=try await command(["delete","--",id])}
            }
            let images=try ResourceItem.parseImages((try await command(["image","list","--format","json"])).data)
            for ref in [snapshot,withEnv]+(baselineImages.contains(base) ? []:[base]) where images.contains(where:{$0.id==ref}) {
                _=try await command(["image","delete","--",ref])
            }
        }
        do {
            if !baselineImages.contains(base){_=try await command(["image","pull","--platform","linux/arm64","--",base])}
            _=try await command(["create","--name",source,"--cpus","1","--memory","256M","--env","SNAPSHOT_TEST_SECRET=fixture-only","--volume",directory.path+":/snapshot-mount","--entrypoint","/bin/sh","--",base,"-c","while :; do sleep 1; done"])
            _=try await command(["start","--",source])
            _=try await command(["exec","--",source,"/bin/sh","-c","printf snapshot-change > /snapshot-marker; rm /bin/true; sync"])
            await store.refresh()
            store.snapshotContainer(ContainerSnapshotRequest(container:source,image:snapshot,acknowledgeRunning:true));try await wait()
            let inspect=try await command(["image","inspect","--",snapshot])
            let variants=try ResourceSafety.rows(inspect.data).first?["variants"] as? [[String:Any]] ?? []
            let imageConfig=try XCTUnwrap(variants.first?["config"] as? [String:Any])
            let process=try XCTUnwrap(imageConfig["config"] as? [String:Any])
            try XCTAssertEqual(process["Entrypoint"] as? [String],["/bin/sh"])
            try XCTAssertEqual(process["Cmd"] as? [String],["-c","while :; do sleep 1; done"])
            try XCTAssertFalse((process["Env"] as? [String] ?? []).contains{$0.hasPrefix("SNAPSHOT_TEST_SECRET=")})
            _=try await command(["create","--name",clone,"--cpus","1","--memory","256M","--",snapshot])
            _=try await command(["start","--",clone])
            _=try await command(["exec","--",clone,"/bin/sh","-c","test \"$(cat /snapshot-marker)\" = snapshot-change && test ! -e /bin/true && test ! -e /snapshot-mount/private-marker && test -z \"$SNAPSHOT_TEST_SECRET\""])
            print("PASS: running snapshot restores modified/deleted files and startup command; bind mount and environment omitted")
            _=try await command(["stop","--",source]);await store.refresh()
            store.snapshotContainer(ContainerSnapshotRequest(container:source,image:withEnv,includeEnvironment:true));try await wait()
            let envInspect=try await command(["image","inspect","--",withEnv])
            try XCTAssertTrue(envInspect.text.contains("SNAPSHOT_TEST_SECRET=fixture-only"))
            store.snapshotContainer(ContainerSnapshotRequest(container:source,image:withEnv))
            while store.operationRunning{try await Task.sleep(for:.milliseconds(100))}
            try XCTAssertEqual(store.operationResult,"imageTagExists")
            print("PASS: stopped snapshot, explicit environment inclusion and existing-tag refusal")
            _=try await command(["stop","--",clone]);_=try await command(["delete","--",clone])
            try await RegistryLiveTests().testLoopbackPush(sourceOverride:snapshot,expectedLayers:1)
            try await cleanup()
            let after=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            let images=try ResourceItem.parseImages((try await command(["image","list","--format","json"])).data)
            try XCTAssertEqual(Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)}),baseline)
            try XCTAssertEqual(Set(images.map(\.id)),baselineImages)
            print("PASS: snapshot pushed to loopback registry, full fixture cleanup and original state preservation")
        } catch{try await cleanup();throw error}
    }
}
