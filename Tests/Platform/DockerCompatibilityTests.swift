import Foundation

extension PlatformTests {
    func testDockerCompatibility()throws {
        try XCTAssertEqual(try DeploymentSource.image("https://hub.docker.com/_/nginx",tag:"1.28"),"docker.io/library/nginx:1.28")
        try XCTAssertEqual(try DeploymentSource.image("https://hub.docker.com/r/example/app/tags",tag:"stable"),"docker.io/example/app:stable")
        try XCTAssertEqual(try DeploymentSource.image("redis:7"),"docker.io/library/redis:7")
        try XCTAssertEqual(try DeploymentSource.image("docker.io/nginx",tag:"stable"),"docker.io/library/nginx:stable")
        try XCTAssertEqual(try DeploymentSource.image("ghcr.io/example/app:stable"),"ghcr.io/example/app:stable")
        let digest=String(repeating:"a",count:64)
        try XCTAssertEqual(try DeploymentSource.image("alpine@sha256:"+digest),"docker.io/library/alpine@sha256:"+digest)
        for source in ["https://hub.docker.com.evil/_/alpine","https://user:password@hub.docker.com/_/alpine","http://hub.docker.com/_/alpine","https://hub.docker.com/search?q=alpine","https://example.com/app.sh","alpine;touch /tmp/no","-x","a/../b","alpine@sha256:bad"] {try XCTAssertThrowsError(try DeploymentSource.image(source),source)}
        let file=try fixture("services: {app: {image: alpine, build: {context: '.', args: {MODE: production}, target: release, no_cache: true}, init: true, labels: {purpose: test}, networks: {front: {aliases: [api]}, back: {}}}, db: {image: alpine, networks: {back: {aliases: [database]}}}}\nnetworks: {front: {}, back: {}}")
        let plan=try ComposePlanner(file:file,projectID:UUID().uuidString).plan()
        let app=try XCTUnwrap(plan.services.first{$0.name=="app"})
        try XCTAssertEqual(app.createArguments.filter{$0=="--network"}.count,2)
        try XCTAssertTrue(app.createArguments.contains("--init"))
        try XCTAssertTrue(app.createArguments.contains("purpose=test"))
        try XCTAssertTrue(app.buildArguments?.contains("MODE=production")==true)
        try XCTAssertTrue(app.buildArguments?.contains("release")==true)
        try XCTAssertTrue(app.networkAliases.values.contains(["api"]))
        for text in [
            "services: {a: {image: alpine, networks: {default: {aliases: [database]}}}, b: {image: alpine, networks: {default: {aliases: [database]}}}}",
            "services: {a: {image: alpine, networks: {default: {aliases: [localhost]}}}}",
            "services: {a: {image: alpine, labels: {app.containerdesk.project: foreign}}}",
            "services: {a: {image: alpine, build: {context: '.', args: {KEY: null}}}}"
        ] {let f=try fixture(text);try XCTAssertThrowsError(try ComposePlanner(file:f,projectID:UUID().uuidString).plan())}
    }
    @MainActor func testOfficialComposeResolution()async throws {
        guard let cli=DockerComposeResolver.executable() else{throw DeskError.message("dockerComposeMissing")}
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("cd-resolve-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:false)
        defer{try? FileManager.default.removeItem(at:dir)}
        let file=dir.appendingPathComponent("compose.yaml"),dotenv=dir.appendingPathComponent(".env")
        try """
        x-common: &common
          image: alpine:3.21
          init: true
        services:
          app:
            <<: *common
            environment: {TOKEN: '${TOKEN}', DOUBLE: '${DOUBLE}', MESSAGE: '${MESSAGE:-default}'}
            env_file: settings.env
            ports: ['${PORT:-18088}:80']
            build: {context: '.', args: {MODE: '${MODE}'}, target: release}
            networks: {front: {aliases: [api]}, back: {}}
          db:
            <<: *common
            networks: {back: {aliases: [database]}}
            volumes: [data:/data]
        networks: {front: {}, back: {}}
        volumes: {data: {}}
        """.write(to:file,atomically:true,encoding:.utf8)
        let environment="TOKEN='literal$VALUE'\nDOUBLE='two$$dollars'\nMODE=production\nMESSAGE=hello\n"
        try environment.write(to:dotenv,atomically:true,encoding:.utf8)
        try "OTHER=\"${MODE}-value\"\n".write(to:dir.appendingPathComponent("settings.env"),atomically:true,encoding:.utf8)
        try "services: {app: {environment: {MESSAGE: overridden}}}".write(to:dir.appendingPathComponent("compose.override.yaml"),atomically:true,encoding:.utf8)
        let resolution=try await DockerComposeResolver.resolve([file],executable:cli)
        try XCTAssertEqual(resolution.files.count,2)
        let result=try DockerProjectConverter.analyze(file,resolution:resolution)
        try XCTAssertTrue(result.canImport,result.notices.filter(\.blocking).map{$0.path+": "+$0.message}.joined(separator:"\n"))
        try XCTAssertThrowsError(try result.save()) // official results must be re-resolved
        let saved=try await result.saveVerified()
        let plan=try ComposePlanner(file:saved,projectID:UUID().uuidString).plan()
        let app=try XCTUnwrap(plan.services.first{$0.name=="app"})
        try XCTAssertTrue(app.createArguments.contains("TOKEN=literal$VALUE"))
        try XCTAssertTrue(app.createArguments.contains("DOUBLE=two$$dollars"))
        try XCTAssertTrue(app.createArguments.contains("MESSAGE=overridden"))
        try XCTAssertTrue(app.createArguments.contains("OTHER=production-value"))
        try XCTAssertTrue(app.createArguments.contains("127.0.0.1:18088:80"))
        try XCTAssertTrue(app.buildArguments?.contains("MODE=production")==true)
        try (environment+"PORT=18090\n").write(to:dotenv,atomically:true,encoding:.utf8)
        do{_=try await result.saveVerified();throw DeskError.message("Changed dotenv accepted")}catch{try XCTAssertEqual(error.localizedDescription,"dockerSourceChanged")}
        // Saved snapshots do not re-read .env or interpolate literal $ values.
        try XCTAssertTrue(try ComposePlanner(file:saved,projectID:UUID().uuidString).plan().services.first{$0.name=="app"}!.createArguments.contains("127.0.0.1:18088:80"))
        setenv("CONTAINERDESK_RESOLVE_TEST_HOST","must-not-inherit",1)
        defer{unsetenv("CONTAINERDESK_RESOLVE_TEST_HOST")}
        try "services: {app: {image: alpine, environment: {VALUE: '${CONTAINERDESK_RESOLVE_TEST_HOST}'}}}".write(to:file,atomically:true,encoding:.utf8)
        do{_=try await DockerComposeResolver.resolve([file],executable:cli,discoverOverride:false);throw DeskError.message("Host environment inherited")}
        catch{try XCTAssertEqual(error.localizedDescription,"dockerComposeVariableMissing")}
        print("PASS: official Compose merge/anchor/env-file resolution, literal dollar snapshot, changed-input refusal and host-env isolation")
    }
}
