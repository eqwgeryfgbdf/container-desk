import Foundation
import Darwin

struct CommandResult {
    let data: Data
    let error: String
    let code: Int32
    var text: String { String(data:data,encoding:.utf8) ?? "" }
}
enum ProcessRunner {
    /// Drain both pipes without disk spooling. Each stream has a strict in-memory
    /// budget; a noisy guest cannot fill the host's temporary volume.
    static func run(_ executable:String, _ arguments:[String], timeout:TimeInterval?=30) async throws -> CommandResult {
        let task=Task.detached(priority:.utility) { () throws -> CommandResult in
            try Task.checkCancellation()
            let out=Pipe(),err=Pipe(),p=Process()
            let handles=[out.fileHandleForReading,err.fileHandleForReading,out.fileHandleForWriting,err.fileHandleForWriting]
            defer {for h in handles {try? h.close()}}
            for h in [out.fileHandleForReading,err.fileHandleForReading] {
                guard fcntl(h.fileDescriptor,F_SETFL,O_NONBLOCK)==0 else{throw DeskError.message("operationFailed")}
            }
            p.executableURL=URL(fileURLWithPath:executable);p.arguments=arguments
            var env=ProcessInfo.processInfo.environment
            env["PATH"]="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:"+FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
            env["LC_ALL"]="en_US.UTF-8";p.environment=env
            p.standardOutput=out;p.standardError=err;p.standardInput=FileHandle.nullDevice
            try p.run()
            try out.fileHandleForWriting.close();try err.fileHandleForWriting.close()
            var stdout=Data(),stderr=Data()
            let limit=4*1024*1024,deadline=timeout.map{Date().addingTimeInterval($0)}
            func drain(_ handle:FileHandle,_ data:inout Data)throws {
                var buffer=[UInt8](repeating:0,count:32768)
                // A finite batch keeps the other stream, deadline and cancellation responsive.
                for _ in 0..<32 {
                    let count=Darwin.read(handle.fileDescriptor,&buffer,buffer.count)
                    if count>0 {
                        guard data.count+count<=limit else{throw DeskError.message("responseTooLarge")}
                        data.append(contentsOf:buffer.prefix(count))
                    } else if count==0 || errno==EAGAIN || errno==EWOULDBLOCK {return}
                    else if errno != EINTR {throw DeskError.message("operationFailed")}
                }
            }
            do {
                repeat {
                    try Task.checkCancellation()
                    try drain(out.fileHandleForReading,&stdout);try drain(err.fileHandleForReading,&stderr)
                    if !p.isRunning {break}
                    if let deadline,Date()>=deadline {throw DeskError.message("commandTimeout")}
                    try await Task.sleep(for:.milliseconds(10))
                } while true
                // A closed child may leave up to a pipe buffer of unread output.
                try drain(out.fileHandleForReading,&stdout);try drain(err.fileHandleForReading,&stderr)
                try Task.checkCancellation()
                return CommandResult(data:stdout,error:String(decoding:stderr,as:UTF8.self),code:p.terminationStatus)
            } catch {
                if p.isRunning {
                    p.terminate()
                    await Task.detached {try? await Task.sleep(for:.milliseconds(250))}.value
                    if p.isRunning {kill(p.processIdentifier,SIGKILL)}
                    await Task.detached {p.waitUntilExit()}.value
                }
                throw error
            }
        }
        return try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{if timeout != nil {task.cancel()}})
    }
    static func checked(_ path:String,_ args:[String],timeout:TimeInterval?=30) async throws -> CommandResult {
        let r=try await run(path,args,timeout:timeout)
        guard r.code==0 else { throw DeskError.message(r.error.isEmpty ? r.text : r.error) }
        return r
    }
}
