import Foundation
import Darwin

/// Bounded live output without pipe back-pressure. Cancellation stops the CLI client;
/// engine-side work may still finish, so callers must reconcile the inventory afterwards.
@MainActor enum StreamingProcess {
    static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 1800,
                    output: (String) -> Void) async throws -> Int32 {
        try Task.checkCancellation()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-task-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        defer { try? FileManager.default.removeItem(at:directory) }
        let file = directory.appendingPathComponent("output")
        FileManager.default.createFile(atPath:file.path,contents:nil,attributes:[.posixPermissions:0o600])
        let writer = try FileHandle(forWritingTo:file), reader = try FileHandle(forReadingFrom:file)
        defer { try? writer.close(); try? reader.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath:executable); process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path
        environment["LC_ALL"] = "en_US.UTF-8"; environment["NO_COLOR"] = "1"
        process.environment = environment
        process.standardOutput = writer; process.standardError = writer; process.standardInput = FileHandle.nullDevice
        try process.run()
        var tail = Data(), total = 0
        func drain() throws {
            while let data = try reader.read(upToCount:32768), !data.isEmpty {
                total += data.count; tail.append(data)
                if tail.count > 65536 { tail = Data(tail.suffix(65536)) }
                guard total <= 32*1024*1024 else { throw DeskError.message("operationOutputLimit") }
            }
            let text = String(decoding:tail,as:UTF8.self)
                .replacingOccurrences(of:"\u{001B}\\[[0-?]*[ -/]*[@-~]",with:"",options:.regularExpression)
                .replacingOccurrences(of:"\r",with:"\n")
            output(text)
        }
        let deadline = Date().addingTimeInterval(timeout)
        do {
            while process.isRunning {
                try Task.checkCancellation()
                guard Date() < deadline else { throw DeskError.message("commandTimeout") }
                try drain()
                try await Task.sleep(nanoseconds:200_000_000)
            }
            try drain()
            try Task.checkCancellation()
            return process.terminationStatus
        } catch {
            if process.isRunning {
                process.terminate()
                // Detached grace period also works when the caller's task has been cancelled.
                await Task.detached { try? await Task.sleep(nanoseconds:500_000_000) }.value
                if process.isRunning { kill(process.processIdentifier,SIGKILL) }
                // Reap before removing the output files.
                await Task.detached { process.waitUntilExit() }.value
            }
            throw error
        }
    }
}
