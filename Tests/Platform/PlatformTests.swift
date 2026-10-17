import Foundation

final class PlatformTests:PlatformTestCase {
    private func fixture(_ text:String)throws->URL {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("cd-unit-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        addTeardownBlock{try? FileManager.default.removeItem(at:dir)}
        let file=dir.appendingPathComponent("compose.yaml");try text.write(to:file,atomically:true,encoding:.utf8);return file
    }
    private func plan(_ text:String)throws->ComposePlan {try ComposePlanner(file:fixture(text),projectID:"11111111-2222-3333-4444-555555555555",volumeGiB:1).plan()}
    func testComposeOrderAndLiteralArguments()throws {
        let p=try plan("""
        name: test
        services:
          web:
            image: python:3.13-slim
            command: [python3, -c, "print('literal')"]
            depends_on:
              db:
                condition: service_healthy
            ports: ["8080:8000", "8080:53/udp"]
            environment: {API_KEY: literal-secret}
            volumes: ["data:/data", "./folder with spaces:/config:ro"]
          db:
            image: busybox:1.37
            command: [sleep, '3600']
            healthcheck:
              test: [CMD-SHELL, 'test -d /tmp']
              interval: 250ms
              timeout: 1s
              retries: 3
        volumes: {data: {}}
        """)
        try XCTAssertEqual(p.services.map(\.name),["db","web"])
        let web=try XCTUnwrap(p.services.last)
        try XCTAssertTrue(web.container.hasPrefix("web.cd-"));try XCTAssertTrue(web.createArguments.contains(where:{$0.hasSuffix(":/etc/hosts:ro")}))
        try XCTAssertTrue(web.createArguments.contains("127.0.0.1:8080:53/udp"))
        try XCTAssertEqual(Array(web.createArguments.suffix(3)),["python3","-c","print('literal')"])
        try XCTAssertTrue(web.createArguments.contains("API_KEY=literal-secret"))
        try XCTAssertEqual(p.volumes.count,1);try XCTAssertEqual(p.volumeGiB,1)
        try XCTAssertEqual(p.services[0].health?.interval,0.25)
    }
    func testComposeRejectsUnsupportedAndAmbiguousConfiguration()throws {
        let invalid=[
            "services: {web: {image: alpine, privileged: true}}",
            "services: {web: {image: alpine, restart: always}}",
            "services: {web: {image: alpine, networks: [missing]}}",
            "services: {web: {image: alpine, environment: [HOST_SECRET]}}",
            "services: {web: {image: alpine, ports: ['0.0.0.0:8080:80']}}",
            "services: {web: {image: alpine, cpus: 0.5}}",
            "services: {web: {image: alpine, command: []}}",
            "services: {web: {image: alpine, entrypoint: /bin/sh}}",
            "services: {web: {image: alpine, depends_on: [web]}}",
            "services: {web: {image: alpine, depends_on: [missing]}}",
            "services: {web: {image: a, image: b}}",
            "services: {web: {image: '${MISSING}'}}",
            "services: {web: {image: alpine, depends_on: {db: {condition: service_completed_successfully}}}, db: {image: alpine}}",
            "services: {web: {image: alpine, depends_on: {db: {condition: service_healthy}}}, db: {image: alpine}}",
            "services: {web: {image: alpine, ports: ['8080:80']}, db: {image: alpine, ports: ['8080:80']}}",
            "services: {web: &web {image: alpine}, db: *web}",
            "services: {web: {image: alpine}}\n---\nservices: {}",
            "services: {web: {image: alpine, volumes: ['data:/a']}}",
        ]
        for document in invalid {try XCTAssertThrowsError(try plan(document),document)}
    }
    func testEnvFilesAndInterpolation()throws {
        let file=try fixture("""
        services:
          app:
            image: '${IMAGE}'
            env_file: config.env
            environment: {TOKEN: override, DEFAULT: '${OPTIONAL:-fallback}', DOLLAR: '$$HOME'}
            command: 'echo "hello world"'
        """)
        try "IMAGE=busybox:1.37\n".write(to:file.deletingLastPathComponent().appendingPathComponent(".env"),atomically:true,encoding:.utf8)
        try "TOKEN=from-file\nSECOND=two\n".write(to:file.deletingLastPathComponent().appendingPathComponent("config.env"),atomically:true,encoding:.utf8)
        let service=try XCTUnwrap(ComposePlanner(file:file,projectID:UUID().uuidString).plan().services.first)
        try XCTAssertTrue(service.createArguments.contains("TOKEN=override"));try XCTAssertTrue(service.createArguments.contains("SECOND=two"))
        try XCTAssertTrue(service.createArguments.contains("DEFAULT=fallback"));try XCTAssertTrue(service.createArguments.contains("DOLLAR=$HOME"))
        try XCTAssertEqual(Array(service.createArguments.suffix(2)),["echo","hello world"])
    }
    func testFileNamesAndNoOverwriteCommands()throws {
        try XCTAssertEqual(try FileOperations.path("//tmp/./a"),"/tmp/a")
        try XCTAssertThrowsError(try FileOperations.path("/tmp/../etc"));try XCTAssertThrowsError(try FileOperations.copy("qa",local:URL(fileURLWithPath:"/tmp/a:b"),remote:"/tmp/a",upload:true))
        try XCTAssertThrowsError(try FileOperations.remove("qa","/"))
        let name="weird ' $(touch nope)\nfile"
        let list=try ContainerFile.parse(Data(("f\0"+name+"\0d\0folder\0").utf8))
        try XCTAssertEqual(list.map(\.name),["folder",name])
        let args=try FileOperations.rename("qa","/tmp/"+name,"/tmp/new")
        try XCTAssertEqual(args.suffix(2),["/tmp/"+name,"/tmp/new"])
        try XCTAssertTrue(args[5].contains("mv -n"))
        try XCTAssertThrowsError(try ContainerFile.parse(Data("f\0unterminated".utf8)))
    }
    func testManagedHostsIsolation()throws {
        let file=try fixture("""
        services:
          one: {image: alpine}
          two: {image: alpine, networks: [isolated]}
        networks: {isolated: {}}
        """)
        let plan=try ComposePlanner(file:file,projectID:UUID().uuidString.lowercased()).plan()
        let one=plan.services[0],two=plan.services[1]
        addTeardownBlock{try? FileManager.default.removeItem(at:one.hostsFile.deletingLastPathComponent())}
        let a=one.createArguments,b=two.createArguments
        let networkA=a[a.firstIndex(of:"--network")!+1],networkB=b[b.firstIndex(of:"--network")!+1]
        func row(_ service:ComposeService,_ network:String,_ ip:String,_ owner:String)->[String:Any] {
            ["id":service.container,"configuration":["labels":[ComposePlan.ownerLabel:owner]],"status":["state":"running","networks":[["network":network,"ipv4Address":ip]]]]
        }
        try ComposeHosts.update(plan,rows:[row(one,networkA,"192.168.1.2/24",plan.projectID),row(two,networkB,"192.168.2.2/24",plan.projectID)])
        let text=try String(contentsOf:one.hostsFile,encoding:.utf8)
        try XCTAssertTrue(text.contains("192.168.1.2 one"));try XCTAssertFalse(text.contains("192.168.2.2"))
        let inode=try FileManager.default.attributesOfItem(atPath:one.hostsFile.path)[.systemFileNumber] as? NSNumber
        try ComposeHosts.update(plan,rows:[row(one,networkA,"192.168.1.3/24",plan.projectID),row(two,networkA,"192.168.1.4/24","foreign")])
        try XCTAssertEqual(try FileManager.default.attributesOfItem(atPath:one.hostsFile.path)[.systemFileNumber] as? NSNumber,inode)
        try XCTAssertFalse(try String(contentsOf:one.hostsFile,encoding:.utf8).contains("192.168.1.4"))
        try XCTAssertThrowsError(try ComposeHosts.update(plan,rows:[row(one,networkA,"",plan.projectID)]))
        let sentinel=file.deletingLastPathComponent().appendingPathComponent("sentinel")
        try "keep".write(to:sentinel,atomically:true,encoding:.utf8)
        try FileManager.default.removeItem(at:one.hostsFile)
        try FileManager.default.createSymbolicLink(at:one.hostsFile,withDestinationURL:sentinel)
        try XCTAssertThrowsError(try ComposeHosts.update(plan,rows:[]))
        try XCTAssertEqual(try String(contentsOf:sentinel,encoding:.utf8),"keep")
    }
    @MainActor func testCorruptProjectLibraryIsPreserved()throws {
        let file=try fixture("not-json")
        let library=ComposeProjectLibrary(file:file)
        let source=try fixture("services: {web: {image: alpine}}")
        try XCTAssertThrowsError(try library.add(source))
        try XCTAssertEqual(try String(contentsOf:file,encoding:.utf8),"not-json")
    }
    func testRegistryValidationAndMetadata()throws {
        for host in ["ghcr.io","registry.example.com:5443","localhost:5000","[::1]:5000"]{try XCTAssertNoThrow(try RegistryLogin.validateServer(host))}
        for host in ["https://ghcr.io","user:secret@host","host/path","--flag","localhost:70000"]{try XCTAssertThrowsError(try RegistryLogin.validateServer(host))}
        try XCTAssertThrowsError(try RegistryLogin.validateServer("example.com",http:true))
        try XCTAssertNoThrow(try RegistryLogin.validateServer("127.0.0.1:5000",http:true))
        let request=RegistryLogin(server:"ghcr.io",username:"qa",password:"top-secret")
        try XCTAssertFalse(try request.arguments().contains("top-secret"));try XCTAssertTrue(try request.arguments().contains("--password-stdin"))
        let list=try RegistryAccount.parse(Data(#"[{"name":"ghcr.io","username":"qa"}]"#.utf8));try XCTAssertEqual(list.first?.name,"ghcr.io")
    }
    @MainActor func testCredentialPipeAndSuppressedOutput()async throws {
        let file=try fixture("")
        let dir=file.deletingLastPathComponent()
        let script=dir.appendingPathComponent("mock-cli")
        let content="#!/bin/sh\nprintf '%s\\n' \"$@\" > "+shellQuote(dir.appendingPathComponent("arguments").path)+"\ncat > "+shellQuote(dir.appendingPathComponent("input").path)+"\necho secret-reflection\n"
        try content.write(to:script,atomically:true,encoding:.utf8);try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:script.path)
        try await CredentialProcess.login(script.path,request:RegistryLogin(server:"localhost:5000",username:"qa",password:"generated-fixture-token"))
        try XCTAssertEqual(try String(contentsOf:dir.appendingPathComponent("input"),encoding:.utf8),"generated-fixture-token")
        try XCTAssertFalse(try String(contentsOf:dir.appendingPathComponent("arguments"),encoding:.utf8).contains("generated-fixture-token"))
    }
}
