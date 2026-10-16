import Foundation

@main struct CoreTests {
    static func main() async throws {
        var count=0
        func expect(_ value:Bool,_ message:String) throws {guard value else{throw DeskError.message(message)};count+=1}
        func rejects(_ work:()throws->Void)->Bool {do{try work();return false}catch{return true}}
        let rows=Data("""
        [{"id":"web","configuration":{"image":{"reference":"nginx:alpine"},"resources":{"cpus":2,"memoryInBytes":1073741824},"publishedPorts":[{"hostAddress":"127.0.0.1","hostPort":8080,"containerPort":80,"proto":"tcp"}],"networks":[{"network":"default"}]},"status":{"state":"running"}},{"id":"old","configuration":{},"status":{"state":"stopped"}}]
        """.utf8)
        let parsed=try ContainerItem.parse(rows)
        try expect(parsed.count==2 && parsed.first(where:{$0.id=="web"})?.running==true,"Container state parsing failed")
        try expect(parsed.first(where:{$0.id=="web"})?.memory==1073741824,"Memory limit changed")
        try expect(parsed.first(where:{$0.id=="old"})?.image=="—","Missing field must remain unknown")
        try expect(parsed.first(where:{$0.id=="web"})?.ports.first?.webURL?.absoluteString=="http://127.0.0.1:8080","Port link must use the published host port")
        func port(_ host:String="127.0.0.1",_ published:Int=8765,_ target:Int=8080,_ transport:String="tcp")->PublishedPort {
            PublishedPort(["hostAddress":host,"hostPort":published,"containerPort":target,"proto":transport])
        }
        try expect(port().webURL?.absoluteString=="http://127.0.0.1:8765","Screenshot mapping must open the host address and port")
        try expect(port("0.0.0.0").webURL?.absoluteString=="http://127.0.0.1:8765","IPv4 wildcard must open loopback")
        try expect(port("::").webURL?.absoluteString=="http://[::1]:8765","IPv6 wildcard must open loopback")
        try expect(port("0:0:0:0:0:0:0:0").webURL?.absoluteString=="http://[::1]:8765","Expanded IPv6 wildcard must open loopback")
        try expect(port("::1").webURL?.absoluteString=="http://[::1]:8765","IPv6 URLs must have brackets")
        try expect(port("192.168.1.10",9443,443).webURL?.absoluteString=="https://192.168.1.10:9443","TLS container port must use HTTPS and mapped host port")
        try expect(port("127.0.0.1",443,8080).webURL?.scheme=="http","Published port must not override container protocol hint")
        try expect(port("localhost").webURL?.absoluteString=="http://localhost:8765","Localhost mapping must open")
        try expect(port("127.0.0.1",53,53,"udp").webURL==nil,"UDP must not create a browser link")
        try expect(port("127.0.0.1",0).webURL==nil && port("127.0.0.1",65536).webURL==nil,"Invalid published ports must not create links")
        try expect(port("127.0.0.1",8080,0).webURL==nil,"Invalid container port must not create a link")
        try expect(port("127.0.0.1/path").webURL==nil && port("user@example.com").webURL==nil,"Malformed hosts must not create links")
        try expect(PublishedPort([:]).webURL==nil,"Missing metadata must not fabricate a browser endpoint")
        var req=CreateRequest();req.name="test";req.image="local:test";req.environment="VALUE=$(touch /tmp/should-not-exist)";req.hostPort="8080";req.containerPort="80"
        let args=try req.arguments()
        try expect(args.contains("127.0.0.1:8080:80"),"Ports must default to loopback")
        try expect(args.contains(req.environment),"Environment value must remain one literal argument")
        req.name="--force";try expect(rejects{_=try req.arguments()},"Option-like names must fail")
        req.name="test";req.hostPort="65536";try expect(rejects{_=try req.arguments()},"Out of range ports must fail")
        req.hostPort="8080";req.environment="BAD-KEY=x";try expect(rejects{_=try req.arguments()},"Invalid environment keys must fail")
        req.environment="";req.memoryMB=128
        try expect(rejects{_=try req.arguments()},"Engine memory minimum must be enforced")
        req.memoryMB=200;req.cpus=1
        try req.validateAllocation(maxCPUs:10,maxMemoryMiB:16384)
        req.memoryMB=16385;try expect(rejects{try req.validateAllocation(maxCPUs:10,maxMemoryMiB:16384)},"Memory above host capacity accepted")
        req.memoryMB=512;req.cpus=11;try expect(rejects{try req.validateAllocation(maxCPUs:10,maxMemoryMiB:16384)},"CPU above host capacity accepted")
        let imageRows=Data("""
        [{"configuration":{"name":"local:test"},"variants":[{"platform":{"architecture":"arm64"},"size":123}]},{"configuration":{"name":"local:test"},"variants":[{}]},{"configuration":{"name":"incomplete:test"},"variants":[]},{"id":"unnamed","variants":[{}]}]
        """.utf8)
        let localImages=try ResourceItem.parseImages(imageRows)
        try expect(localImages.count==1 && localImages[0].id=="local:test","Invalid or duplicate image candidates included")
        try expect(try ResourceItem.parseImages(Data("[]".utf8)).isEmpty,"Empty image inventory handling failed")
        let digest="sha256:"+String(repeating:"a",count:64)
        func release(_ url:String,_ name:String="container-1.5.0-installer-signed.pkg",_ prerelease:Bool=false,_ hash:String?=nil)->CoreRelease {
            CoreRelease(tag_name:"1.5.0",html_url:"https://github.com/apple/container/releases/tag/1.5.0",body:nil,prerelease:prerelease,draft:false,assets:[.init(name:name,browser_download_url:url,digest:hash ?? digest,size:100)])
        }
        let official="https://github.com/apple/container/releases/download/1.5.0/container-1.5.0-installer-signed.pkg"
        try expect(try release(official).validatedAsset().size==100,"Official release was rejected")
        for url in [official.replacingOccurrences(of:"github.com",with:"github.com.evil.test"),official.replacingOccurrences(of:"https:",with:"http:"),official+"?redirect=evil",official.replacingOccurrences(of:"/apple/",with:"/attacker/")] {
            try expect(rejects{_=try release(url).validatedAsset()},"Untrusted release accepted")
        }
        try expect(rejects{_=try release(official,"container-installer-unsigned.pkg").validatedAsset()},"Unsigned fallback accepted")
        try expect(rejects{_=try release(official,"container-1.5.0-installer-signed.pkg",true).validatedAsset()},"Prerelease accepted")
        try expect(rejects{_=try release(official,"container-1.5.0-installer-signed.pkg",false,"sha256:bad").validatedAsset()},"Invalid digest accepted")
        try expect(release(official).isNewer(than:"1.4.9"),"Newer version not detected")
        try expect(!release(official).isNewer(than:"1.10.0"),"Must not downgrade newer installs")
        do { _=try await ProcessRunner.checked("/bin/sleep",["5"],timeout:0.1); throw DeskError.message("Timeout not enforced") }
        catch { try expect(error.localizedDescription=="commandTimeout","Timeout error changed") }
        var host=HostInfo();host.refreshDisk();await host.loadModelName()
        try expect(host.memory>0 && host.physicalCores != nil && host.chip != nil && host.modelName != nil,"Actual hardware detection failed")
        try expect((host.diskTotal ?? 0)>0 && host.diskFree != nil,"Actual volume detection failed")
        print("Host: \(host.modelName ?? "?") · \(host.modelIdentifier ?? "?") · \(host.chip ?? "?") · \(host.memory) bytes · \(host.physicalCores ?? 0) physical / \(host.logicalCores ?? 0) logical cores · \(host.osVersion)")
        let tricky="name ' ; $(echo bad) \" \\"
        let result=try await ProcessRunner.checked("/bin/sh",["-c","printf %s "+shellQuote(tricky)])
        try expect(result.text==tricky,"Shell escaping changed literal content")
        let echo=try await ProcessRunner.checked("/bin/echo",["literal $(touch /tmp/nope)"])
        try expect(echo.text.contains("$(touch /tmp/nope)"),"Arguments evaluated unexpectedly")
        let large=try await ProcessRunner.checked("/usr/bin/awk",["BEGIN { for(i=0;i<10000;i++) print \"a long line for pipe buffer checking\" }"])
        try expect(large.data.count>65536,"Large output handling failed")
        print("PASS: \(count) policy, parser, quoting and process checks")
    }
}
