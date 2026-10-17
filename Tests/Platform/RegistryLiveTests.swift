import Foundation
import Darwin

final class RegistryLiveTests:PlatformTestCase {
    @MainActor func testLocalAuthentication()async throws {
        let s=Store();await s.start();let cli=try XCTUnwrap(s.cli)
        let before=try RegistryAccount.parse((try await ProcessRunner.checked(cli,["registry","list","--format","json"])).data)
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent("cd-registry-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        defer{try? FileManager.default.removeItem(at:dir)}
        let token=UUID().uuidString,script=dir.appendingPathComponent("registry.py"),portFile=dir.appendingPathComponent("port")
        let expected=Data(("qa:"+token).utf8).base64EncodedString()
        let python="""
        import http.server, pathlib
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.headers.get('Authorization') != 'Basic \(expected)':
                    self.send_response(401); self.send_header('WWW-Authenticate', 'Basic realm="qa"'); self.end_headers(); return
                self.send_response(200); self.send_header('Docker-Distribution-Api-Version', 'registry/2.0'); self.send_header('Content-Length','2'); self.end_headers(); self.wfile.write(b'{}')
            def log_message(self,*args): pass
        server=http.server.HTTPServer(('127.0.0.1',0),Handler)
        pathlib.Path(__file__).with_name('port').write_text(str(server.server_port))
        server.serve_forever()
        """
        try python.write(to:script,atomically:true,encoding:.utf8);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:script.path)
        let server=Process();server.executableURL=URL(fileURLWithPath:"/usr/bin/python3");server.arguments=[script.path];server.standardOutput=FileHandle.nullDevice;server.standardError=FileHandle.nullDevice
        try server.run();defer{if server.isRunning{server.terminate()}}
        for _ in 0..<50 {if FileManager.default.fileExists(atPath:portFile.path){break};try await Task.sleep(for:.milliseconds(100))}
        let port=try String(contentsOf:portFile,encoding:.utf8),hostname="127.0.0.1:"+port
        try XCTAssertFalse(before.contains{$0.name==hostname},"Never overwrite an existing saved login")
        do {
            var failed=false
            do {try await CredentialProcess.login(cli,request:RegistryLogin(server:hostname,username:"qa",password:"wrong-generated-fixture"),timeout:5)}catch{failed=error.localizedDescription=="registryLoginFailed"}
            try XCTAssertTrue(failed,"An HTTPS connection to the HTTP fixture must fail without saving credentials")
            let after=try RegistryAccount.parse((try await ProcessRunner.checked(cli,["registry","list","--format","json"])).data)
            try XCTAssertEqual(after.map(\.name),before.map(\.name))
        } catch {
            _=try? await ProcessRunner.run(cli,["registry","logout","--",hostname]);throw error
        }
        print("PASS: secure login failure leaves official CLI saved logins unchanged (trusted private-registry success still requires an account)")
    }
}
