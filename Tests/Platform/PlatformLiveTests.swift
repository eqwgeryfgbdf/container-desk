import Foundation
import Darwin

final class PlatformLiveTests:PlatformTestCase {
    @MainActor private func wait(_ s:Store,expected:String="operationComplete",seconds:Double=180)async throws {
        let deadline=Date().addingTimeInterval(seconds)
        while s.operationRunning {guard Date()<deadline else{s.cancelOperation();throw DeskError.message("Test timeout")};try await Task.sleep(for:.milliseconds(100))}
        try XCTAssertEqual(s.operationResult,expected,"\(s.operationTitle): expected \(expected), got \(s.operationResult ?? "nil")\n"+s.operationOutput)
        print("LIVE: \(s.operationTitle) → \(s.operationResult ?? "nil")")
        while s.refreshing {try await Task.sleep(for:.milliseconds(100))}
        await s.refresh()
    }
    @MainActor func testLiveComposeAndFiles(converted:Bool=false)async throws {
        guard ProcessInfo.processInfo.environment["CONTAINERDESK_LIVE_PLATFORM_TESTS"]=="1" else{print("SKIP: live engine tests require --run");return}
        let s=Store();await s.start();let cli=try XCTUnwrap(s.cli);try XCTAssertTrue(s.connected)
        let baseline=Dictionary(uniqueKeysWithValues:s.containers.map{($0.id,$0.state)})
        let image=try XCTUnwrap(s.images.first{$0.id.contains("python") && $0.detail.contains("arm64")})
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("cd-live-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:dir)}
        var file=dir.appendingPathComponent("compose.yaml")
        let project=UUID().uuidString.lowercased()
        try """
        name: qa-compose
        services:
          web:
            image: \(image.id)
            command: [/bin/sh, -c, 'while :; do sleep 1; done']
            depends_on:
              db: {condition: service_healthy}
            mem_limit: 256M
            environment: {QA_TOKEN: private-fixture-value}
          db:
            image: \(image.id)
            command: [/bin/sh, -c, 'touch /data/persistent; exec python3 -m http.server 8000 --bind 0.0.0.0']
            mem_limit: 256M
            volumes: [data:/data]
            healthcheck:
              test: [CMD, python3, -c, 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:8000")']
              timeout: 2s
              interval: 500ms
              retries: 10
        volumes: {data: {}}
        """.write(to:file,atomically:true,encoding:.utf8)
        if converted {
            let original="version: '3.8'\n"+(try String(contentsOf:file,encoding:.utf8))
                .replacingOccurrences(of:"  web:\n",with:"  web:\n    container_name: docker-original-name\n    restart: unless-stopped\n")
                .replacingOccurrences(of:"volumes: {data: {}}",with:"volumes: {data: {driver: local}}\nnetworks: {default: {driver: bridge}}")
            try original.write(to:file,atomically:true,encoding:.utf8)
            try XCTAssertFalse(try DockerProjectConverter.analyze(file).canImport)
            let conversion=try DockerProjectConverter.analyze(file,allowManualRestart:true)
            try XCTAssertTrue(conversion.canImport)
            let migrated=try conversion.save()
            try XCTAssertEqual(try String(contentsOf:file,encoding:.utf8),original)
            file=migrated
            print("LIVE: Docker configuration converted to separate validated Compose file; original preserved")
        }
        let plan=try ComposePlanner(file:file,projectID:project,volumeGiB:1).plan()
        func command(_ args:[String])async throws->CommandResult {try await ProcessRunner.checked(cli,args,timeout:120)}
        func cleanup()async throws {
            let rows=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            for c in rows where plan.services.contains(where:{$0.container==c.id}) {
                if c.running{_=try await command(["stop","--",c.id])};_=try await command(["delete","--",c.id])
            }
            try? FileManager.default.removeItem(at:plan.services[0].hostsFile.deletingLastPathComponent())
            for (kind,resources) in [("network",plan.networks),("volume",plan.volumes)] {
                let existing=try ResourceItem.parseResources((try await command([kind,"list","--format","json"])).data)
                for resource in resources where !resource.external && existing.contains(where:{$0.id==resource.name}){_=try await command([kind,"delete","--",resource.name])}
            }
        }
        do {
            s.composeUp(plan);try await wait(s)
            try XCTAssertFalse(s.operationOutput.contains("private-fixture-value"))
            let web=try XCTUnwrap(plan.services.first{$0.name=="web"}),db=try XCTUnwrap(plan.services.first{$0.name=="db"})
            let dns=try await command(["exec","--",web.container,"python3","-c","import urllib.request; print(urllib.request.urlopen('http://db:8000').status)"])
            try XCTAssertEqual(dns.text.trimmingCharacters(in:.whitespacesAndNewlines),"200","Service DNS/search-domain compatibility")
            let local=dir.appendingPathComponent("quote ' file.txt")
            try Data([0,1,2,3,255,10]).write(to:local)
            s.transferFile(db.container,local:local,remote:"/data/quote ' file.txt",upload:true);try await wait(s)
            let listing=try ContainerFile.parse((try await command(FileOperations.listing(db.container,"/data"))).data)
            try XCTAssertTrue(listing.contains{$0.name==local.lastPathComponent})
            s.transferFile(db.container,local:local,remote:"/data/quote ' file.txt",upload:true);try await wait(s,expected:"fileDestinationExists")
            let destination=dir.appendingPathComponent("downloaded.bin")
            s.transferFile(db.container,local:destination,remote:"/data/quote ' file.txt",upload:false);try await wait(s)
            try XCTAssertEqual(try Data(contentsOf:local),try Data(contentsOf:destination))
            let folder=dir.appendingPathComponent("folder with spaces")
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false)
            try Data([4,5,6]).write(to:folder.appendingPathComponent("nested.bin"))
            try FileManager.default.createDirectory(at:folder.appendingPathComponent("empty"),withIntermediateDirectories:false)
            s.transferFile(db.container,local:folder,remote:"/data/folder",upload:true);try await wait(s)
            let downloadedFolder=dir.appendingPathComponent("downloaded-folder")
            s.transferFile(db.container,local:downloadedFolder,remote:"/data/folder",upload:false);try await wait(s)
            try XCTAssertEqual(try Data(contentsOf:downloadedFolder.appendingPathComponent("nested.bin")),Data([4,5,6]))
            var isDirectory:ObjCBool=false
            try XCTAssertTrue(FileManager.default.fileExists(atPath:downloadedFolder.appendingPathComponent("empty").path,isDirectory:&isDirectory) && isDirectory.boolValue)
            s.fileCommand(db.container,title:"renameFile",arguments:try FileOperations.rename(db.container,"/data/quote ' file.txt","/data/renamed"));try await wait(s)
            s.fileCommand(db.container,title:"newFolder",arguments:try FileOperations.mkdir(db.container,"/data/empty"));try await wait(s)
            s.fileCommand(db.container,title:"delete",arguments:try FileOperations.remove(db.container,"/data/empty"));try await wait(s)
            s.fileCommand(db.container,title:"delete",arguments:try FileOperations.remove(db.container,"/data/renamed"));try await wait(s)
            let ids=plan.services.reversed().map(\.container)
            s.composeManage(project,ids:ids,remove:false);try await wait(s)
            s.composeUp(plan);try await wait(s)
            _=try await command(["exec","--",db.container,"test","-f","/data/persistent"])
            s.composeManage(project,ids:ids,remove:true);try await wait(s)
            let retained=try ResourceItem.parseResources((try await command(["volume","list","--format","json"])).data)
            try XCTAssertTrue(retained.contains{$0.id==plan.volumes[0].name})
            s.composeUp(plan);try await wait(s)
            _=try await command(["exec","--",db.container,"test","-f","/data/persistent"])
            let modified=try String(contentsOf:file,encoding:.utf8).replacingOccurrences(of:"256M",with:"300M")
            try modified.write(to:file,atomically:true,encoding:.utf8)
            s.composeUp(try ComposePlanner(file:file,projectID:project,volumeGiB:1).plan());try await wait(s,expected:"composeConfigurationChanged")
            try await cleanup()
            let after=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            try XCTAssertEqual(Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)}),baseline)
        } catch {try await cleanup();throw error}
    }
}
