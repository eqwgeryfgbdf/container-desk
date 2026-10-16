import Foundation
import Darwin

@main struct ManagementTests {
    @MainActor static func main() async throws {
        var count=0
        func expect(_ condition:Bool,_ message:String) throws {if !condition{throw DeskError.message(message)};count+=1}
        func rejects(_ work:()throws->Void)->Bool {do{try work();return false}catch{return true}}
        var request=ResourceRequest(operation:.pull)
        request.name="registry.example:5000/team/image:v1";request.architecture="amd64"
        try expect(try request.arguments()==["image","pull","--progress","plain","--arch","amd64","--",request.name],"Pull must preserve registry port and explicit architecture")
        request.name="--all";try expect(rejects{_=try request.arguments()},"Reject flags as image names")
        request.name="x\n--all";try expect(rejects{_=try request.arguments()},"Reject multiline references")
        request=ResourceRequest(operation:.tag);request.source="local:v1";request.name="local:v2"
        try expect(try request.arguments()==["image","tag","--","local:v1","local:v2"],"Tag must keep source and target separate")
        request=ResourceRequest(operation:.build);request.name="local:qa";request.path="/tmp/context with ' quotes";request.dockerfile="Custom file";request.noCache=true
        let build=try request.arguments()
        try expect(build.contains("/tmp/context with ' quotes/Custom file") && build.suffix(2)==["--",request.path] && build.contains("--no-cache"),"Build paths must stay literal")
        request=ResourceRequest(operation:.createNetwork);request.name="cd-qa-net";request.subnet="192.168.70.0/24";request.internalNetwork=true
        try expect(try request.arguments()==["network","create","--internal","--subnet","192.168.70.0/24","--","cd-qa-net"],"Network options")
        for subnet in ["999.2.3.0/24","1.2.3.4/33","1.2.3/24","1.2.3.4/24 --all"] {request.subnet=subnet;try expect(rejects{_=try request.arguments()},"Reject invalid subnet")}
        request=ResourceRequest(operation:.createVolume);request.name="cd-qa-vol";request.volumeGiB="2"
        try expect(try request.arguments()==["volume","create","-s","2G","--","cd-qa-vol"],"Volume explicit capacity")
        for size in ["0","1.5","1025","--all"] {request.volumeGiB=size;try expect(rejects{_=try request.arguments()},"Reject invalid capacity")}
        request=ResourceRequest(operation:.load);request.path="/tmp/local file.tar"
        try expect(try request.arguments()==["image","load","--input",request.path],"Archive path literal")
        request=ResourceRequest(operation:.save);request.source="local:qa";request.path="/tmp/out.tar"
        try expect(try request.arguments()==["image","save","--output",request.path,"--",request.source],"Export one exact image")
        let empty=Data("[]".utf8)
        let inventory=Data("""
        [{"configuration":{"name":"default","labels":{"com.apple.container.resource.role":"builtin"}}},{"configuration":{"name":"internal-system","labels":{"com.apple.container.resource.role":"builtin"}}},{"configuration":{"name":"qa","descriptor":{"digest":"sha256:123"}}}]
        """.utf8)
        for name in ["default","internal-system"] {try expect(rejects{try ResourceSafety.validateDeletion(kind:.network,id:name,inventory:inventory,containers:empty)},"Protect built-in labels and names")}
        try ResourceSafety.validateDeletion(kind:.network,id:"qa",inventory:inventory,containers:empty)
        try expect(rejects{try ResourceSafety.validateDeletion(kind:.volume,id:"missing",inventory:inventory,containers:empty)},"Do not delete vanished resource")
        let used=Data("""
        [{"configuration":{"image":{"reference":"alias:v1","descriptor":{"digest":"sha256:123"}},"networks":[{"network":"qa"}],"mounts":[{"source":"qa","destination":"/data"}]},"status":{"state":"stopped"}}]
        """.utf8)
        for kind in ResourceKind.allCases {try expect(rejects{try ResourceSafety.validateDeletion(kind:kind,id:"qa",inventory:inventory,containers:used)},"Protect stopped containers' references, including image aliases")}
        let typedVolume=Data("""
        [{"configuration":{"mounts":[{"source":"/private/data/volume.img","type":{"volume":{"name":"qa"}}}]}}]
        """.utf8)
        try expect(rejects{try ResourceSafety.validateDeletion(kind:.volume,id:"qa",inventory:inventory,containers:typedVolume)},"Protect engine's typed volume mount with disk image source")
        try expect(rejects{try ResourceSafety.validateDeletion(kind:.image,id:"qa",inventory:inventory,containers:Data("[{}]".utf8))},"Fail closed on incomplete container metadata")
        try expect(rejects{try ResourceSafety.validateDeletion(kind:.network,id:"qa",inventory:inventory,containers:Data("{}".utf8))},"Fail closed on invalid inventory")
        let volume=try ResourceItem.parseResources(Data("[{\"name\":\"qa\",\"sizeInBytes\":1073741824}]".utf8))
        try expect(volume.first?.id=="qa" && volume.first?.extra==bytes(1073741824),"Support direct volume schema")
        var create=CreateRequest();create.name="cd-qa";create.image="local:v1";create.network="qa";create.namedVolume="qa";create.volumeTarget="/data";create.volumeReadOnly=true;create.architecture="amd64";create.rosetta=true;create.entrypoint="/bin/sh";create.commandArguments="-c\nprintf '%s' 'literal $HOME'";create.workingDirectory="/app"
        let args=try create.arguments()
        try expect(args.contains("qa:/data:ro") && args.contains("--rosetta") && args.suffix(4)==["--","local:v1","-c","printf '%s' 'literal $HOME'"],"Create must preserve literal command and named volume")
        create.mountSource="/tmp/qa";create.mountTarget="/data"
        try expect(rejects{_=try create.arguments()},"Reject two mounts on same destination")
        create.mountTarget="/tmp\n/data";try expect(rejects{_=try create.arguments()},"Reject multiline mount paths")
        var output=""
        let code=try await StreamingProcess.run("/bin/sh",["-c","printf 'first\\n'; /bin/sleep 0.3; printf 'last\\n'; exit 7"],output:{output=$0})
        try expect(code==7 && output.contains("first") && output.contains("last"),"Stream and retain nonzero exit status")
        var snapshots:[String]=[]
        _=try await StreamingProcess.run("/bin/sh",["-c","printf 'early\\n'; /bin/sleep 0.5; printf 'late\\n'"],output:{snapshots.append($0)})
        try expect(snapshots.contains{ $0.contains("early") && !$0.contains("late") },"Output must arrive before process exit")
        _=try await StreamingProcess.run("/bin/sh",["-c","/usr/bin/head -c 80000 /dev/zero | /usr/bin/tr '\\000' A"],output:{output=$0})
        try expect(output.utf8.count==65536,"Bound displayed output to 64 KiB")
        var processID:Int32=0
        let task=Task {try await StreamingProcess.run("/bin/sh",["-c","echo $$; exec /bin/sleep 10"],output:{processID=Int32($0.trimmingCharacters(in:.whitespacesAndNewlines)) ?? 0})}
        try await Task.sleep(nanoseconds:300_000_000)
        task.cancel()
        var cancelled=false
        do{_=try await task.value}catch is CancellationError{cancelled=true}
        try expect(cancelled && processID>0 && kill(processID,0) != 0,"Cancel must terminate and reap the CLI process")
        var timedOut=false
        do{_=try await StreamingProcess.run("/bin/sleep",["10"],timeout:0.1,output:{_ in})}catch{timedOut=error.localizedDescription=="commandTimeout"}
        try expect(timedOut,"Bound runtime and return timeout error")
        print("PASS: \(count) management checks (arguments, reference protection, live output, cancellation, timeout)")
    }
}
