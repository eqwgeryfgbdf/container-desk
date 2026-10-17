import Foundation
import Yams

extension PlatformTests {
    func testDockerMigration()throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("cd-migrate-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:false)
        defer{try? FileManager.default.removeItem(at:dir)}
        let source=dir.appendingPathComponent("compose.yaml")
        let original="""
        version: '3.8'
        services:
          web:
            image: '${IMAGE}'
            container_name: fixed-web
            restart: unless-stopped
            ports: [{target: 80, published: '8080', protocol: tcp}]
            expose: ['80']
            environment: {TOKEN: 'literal-value'}
            env_file: [{path: settings.env, required: true}]
            volumes: [data:/data, './app:/app:ro']
            networks: {default: {}}
        volumes: {data: {driver: local}}
        networks: {default: {driver: bridge}}
        """
        try original.write(to:source,atomically:true,encoding:.utf8)
        try "IMAGE=python:3.13-alpine\n".write(to:dir.appendingPathComponent(".env"),atomically:true,encoding:.utf8)
        try "CONFIG=preserved\n".write(to:dir.appendingPathComponent("settings.env"),atomically:true,encoding:.utf8)
        let blocked=try DockerProjectConverter.analyze(dir)
        try XCTAssertFalse(blocked.canImport)
        try XCTAssertThrowsError(try blocked.save())
        let result=try DockerProjectConverter.analyze(dir,allowManualRestart:true)
        try XCTAssertTrue(result.canImport,result.notices.map{$0.path+": "+$0.message}.joined(separator:"\n"))
        try XCTAssertTrue(result.notices.contains{$0.message=="dockerVolumeData"})
        try XCTAssertTrue(result.notices.contains{$0.message=="dockerLoopback"})
        try XCTAssertFalse(result.notices.contains{$0.message.contains("literal-value")})
        let transformed=try ComposePlanner.parseDocument(Data(result.yaml.utf8))
        try XCTAssertTrue(transformed["version"]==nil)
        try XCTAssertTrue(transformed["services"]?["web"]?["container_name"]==nil)
        try XCTAssertTrue(transformed["networks"]?["default"]?["driver"]==nil)
        try XCTAssertTrue(transformed["volumes"]?["data"]?["driver"]==nil)
        let saved=try result.save(),again=try result.save()
        try XCTAssertTrue(saved != again)
        try XCTAssertEqual(try String(contentsOf:source,encoding:.utf8),original)
        let permissions=try FileManager.default.attributesOfItem(atPath:saved.path)[.posixPermissions] as? NSNumber
        try XCTAssertEqual(permissions?.intValue,0o600)
        let plan=try ComposePlanner(file:saved,projectID:UUID().uuidString).plan(),service=try XCTUnwrap(plan.services.first)
        try XCTAssertEqual(service.image,"python:3.13-alpine")
        try XCTAssertTrue(service.createArguments.contains("127.0.0.1:8080:80"))
        try XCTAssertTrue(service.createArguments.contains(dir.appendingPathComponent("app").path+":/app:ro"))
        try XCTAssertTrue(service.createArguments.contains("CONFIG=preserved"))
        try XCTAssertTrue(service.createArguments.contains("TOKEN=literal-value"))
        try (original+"\n# changed\n").write(to:source,atomically:true,encoding:.utf8)
        try XCTAssertThrowsError(try result.save())
        for text in [
            "services: {app: {image: alpine, expose: ['65536']}}",
            "services: {app: {image: alpine, expose: ['90-80']}}",
            "services: {app: {image: alpine, privileged: true}}",
            "services: {app: {image: alpine, platform: linux/amd64}}",
            "services: {app: {image: alpine, volumes: ['/var/run/docker.sock:/var/run/docker.sock']}}",
            "services: {app: {image: alpine, ports: ['80']}}",
            "services: {app: {image: alpine, ports: [{target: 80, published: 8080, protocol: {invalid: true}}]}}",
            "services: {app: {image: alpine, ports: ['192.168.0.1:80:80']}}",
            "services: {app: {image: alpine, networks: {default: {aliases: [other]}}}}",
            "services: {app: {image: alpine, env_file: [{path: optional.env, required: false}]}}"
        ] {
            try text.write(to:source,atomically:true,encoding:.utf8)
            try XCTAssertFalse(try DockerProjectConverter.analyze(source,allowManualRestart:true).canImport,text)
        }
        try "services: {app: {image: alpine}}".write(to:source,atomically:true,encoding:.utf8)
        let override=dir.appendingPathComponent("compose.override.yml")
        try "services: {}".write(to:override,atomically:true,encoding:.utf8)
        try XCTAssertFalse(try DockerProjectConverter.analyze(source).canImport)
        let merged=dir.appendingPathComponent("compose.merged.yaml")
        try Data(contentsOf:source).write(to:merged)
        try XCTAssertTrue(try DockerProjectConverter.analyze(merged).canImport)
        try FileManager.default.removeItem(at:override)
        let alternate=dir.appendingPathComponent("docker-compose.yml")
        try Data(contentsOf:source).write(to:alternate)
        try XCTAssertThrowsError(try DockerProjectConverter.analyze(dir))
        let dockerfile=dir.appendingPathComponent("Dockerfile")
        try "FROM scratch\nEXPOSE 8080\n".write(to:dockerfile,atomically:true,encoding:.utf8)
        let wrapper=try DockerProjectConverter.analyze(dockerfile)
        try XCTAssertTrue(wrapper.canImport)
        let wrapperPlan=try ComposePlanner(file:try wrapper.save(),projectID:UUID().uuidString).plan()
        try XCTAssertEqual(wrapperPlan.services[0].buildArguments?.last,dir.path)
        try XCTAssertFalse(wrapperPlan.services[0].createArguments.contains("--publish"))
        try "FROM --platform=linux/amd64 alpine\n".write(to:dockerfile,atomically:true,encoding:.utf8)
        try XCTAssertFalse(try DockerProjectConverter.analyze(dockerfile).canImport)
        try "services: {app: &app {image: alpine}, second: *app}".write(to:source,atomically:true,encoding:.utf8)
        try XCTAssertThrowsError(try DockerProjectConverter.analyze(source))
    }
}
