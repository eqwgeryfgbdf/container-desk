import Foundation
import Darwin

struct CommandResult {
    let data: Data
    let error: String
    let code: Int32
    var text: String { String(data:data,encoding:.utf8) ?? "" }
}
enum ProcessRunner {
    // Temporary files avoid pipe-buffer deadlocks with large inspect/log output.
    static func run(_ executable:String, _ arguments:[String], timeout:TimeInterval?=30) async throws -> CommandResult {
        try await Task.detached(priority:.utility) {
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            defer { try? FileManager.default.removeItem(at:dir) }
            let out=dir.appendingPathComponent("stdout"), err=dir.appendingPathComponent("stderr")
            FileManager.default.createFile(atPath:out.path,contents:nil,attributes:[.posixPermissions:0o600])
            FileManager.default.createFile(atPath:err.path,contents:nil,attributes:[.posixPermissions:0o600])
            let oh=try FileHandle(forWritingTo:out), eh=try FileHandle(forWritingTo:err)
            defer { try? oh.close();try? eh.close() }
            let p=Process();p.executableURL=URL(fileURLWithPath:executable);p.arguments=arguments
            var env=ProcessInfo.processInfo.environment
            env["PATH"]="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:"+FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
            env["LC_ALL"]="en_US.UTF-8";p.environment=env;p.standardOutput=oh;p.standardError=eh;p.standardInput=FileHandle.nullDevice
            try p.run()
            let deadline=timeout.map { Date().addingTimeInterval($0) }
            while p.isRunning && (deadline==nil || Date()<deadline!) { try await Task.sleep(nanoseconds:50_000_000) }
            if p.isRunning {
                p.terminate()
                let grace=Date().addingTimeInterval(2)
                while p.isRunning && Date()<grace { try await Task.sleep(nanoseconds:50_000_000) }
                if p.isRunning { kill(p.processIdentifier,SIGKILL) }
                throw DeskError.message("commandTimeout")
            }
            let maxBytes=4*1024*1024
            let size=(try? out.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0
            guard size<maxBytes else { throw DeskError.message("responseTooLarge") }
            return CommandResult(data:try Data(contentsOf:out),error:String(data:(try? Data(contentsOf:err)) ?? Data(),encoding:.utf8) ?? "",code:p.terminationStatus)
        }.value
    }
    static func checked(_ path:String,_ args:[String],timeout:TimeInterval?=30) async throws -> CommandResult {
        let r=try await run(path,args,timeout:timeout)
        guard r.code==0 else { throw DeskError.message(r.error.isEmpty ? r.text : r.error) }
        return r
    }
}
