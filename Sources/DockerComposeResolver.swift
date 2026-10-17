import Foundation
import Darwin

/// Read-only use of the installed official Compose CLI. It resolves YAML merges,
/// interpolation and env files without contacting or changing a running project.
struct DockerComposeResolution {
    let executable:String
    let files:[URL]
    let data:Data
    @MainActor func verify()async throws {
        let current=try await DockerComposeResolver.resolve(files,executable:executable,discoverOverride:false)
        guard current.data==data else{throw DeskError.message("dockerSourceChanged")}
    }
}
@MainActor enum DockerComposeResolver {
    static func executable()->String? {
        let home=FileManager.default.homeDirectoryForCurrentUser.path
        return [home+"/.docker/bin/docker","/usr/local/bin/docker","/opt/homebrew/bin/docker","/Applications/Docker.app/Contents/Resources/bin/docker"].first{FileManager.default.isExecutableFile(atPath:$0)}
    }
    static func inputFiles(_ selected:[URL],discoverOverride:Bool)throws->[URL] {
        guard let first=selected.first,selected.count<=12 else{throw DeskError.message("dockerChooseSource")}
        var files=[try DockerProjectConverter.source(in:first)]+selected.dropFirst().map(\.standardizedFileURL)
        if discoverOverride,files.count==1,DockerProjectConverter.composeNames.contains(files[0].lastPathComponent) {
            let folder=files[0].deletingLastPathComponent()
            let candidates=DockerProjectConverter.overrides.map{folder.appendingPathComponent($0)}.filter{FileManager.default.fileExists(atPath:$0.path)}
            guard candidates.count<=1 else{throw DeskError.message("dockerAmbiguousOverride")}
            files+=candidates
        }
        guard Set(files.map(\.path)).count==files.count,files.allSatisfy({$0.isFileURL && FileManager.default.fileExists(atPath:$0.path)}) else{throw DeskError.message("dockerChooseSource")}
        return files
    }
    static func resolve(_ selected:[URL],executable:String?=nil,discoverOverride:Bool=true)async throws->DockerComposeResolution {
        guard let cli=executable ?? self.executable() else{throw DeskError.message("dockerComposeMissing")}
        let files=try inputFiles(selected,discoverOverride:discoverOverride)
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-compose-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
        defer{try? FileManager.default.removeItem(at:directory)}
        let output=directory.appendingPathComponent("config"),error=directory.appendingPathComponent("error")
        for file in [output,error]{FileManager.default.createFile(atPath:file.path,contents:nil,attributes:[.posixPermissions:0o600])}
        let out=try FileHandle(forWritingTo:output),err=try FileHandle(forWritingTo:error)
        defer{try? out.close();try? err.close()}
        let process=Process();process.executableURL=URL(fileURLWithPath:cli)
        process.arguments=["compose","--ansi","never","--project-directory",files[0].deletingLastPathComponent().path]+files.flatMap{["-f",$0.path]}+["config","--format","json"]
        // Shell/session COMPOSE_* and arbitrary host values must not silently
        // alter the selected files. Compose still reads the project's .env.
        process.environment=["HOME":FileManager.default.homeDirectoryForCurrentUser.path,"PATH":"/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin","LC_ALL":"C","NO_COLOR":"1"]
        process.currentDirectoryURL=files[0].deletingLastPathComponent()
        process.standardInput=FileHandle.nullDevice;process.standardOutput=out;process.standardError=err
        try Task.checkCancellation();try process.run()
        func bounded()throws {
            for file in [output,error] {guard (try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<=512*1024 else{throw DeskError.message("dockerSourceSize")}}
        }
        do {
            let deadline=Date().addingTimeInterval(30)
            while process.isRunning {
                try Task.checkCancellation();try bounded()
                guard Date()<deadline else{throw DeskError.message("commandTimeout")}
                try await Task.sleep(for:.milliseconds(50))
            }
            try bounded();try Task.checkCancellation()
            // Never reflect CLI stderr: a diagnostic can contain an env value.
            guard process.terminationStatus==0 else{throw DeskError.message("dockerComposeResolveFailed")}
            let warnings=try String(contentsOf:error,encoding:.utf8)
            guard !warnings.contains("is not set"),!warnings.contains("Defaulting to a blank string") else{throw DeskError.message("dockerComposeVariableMissing")}
            // Compose config escapes every dollar in its serialized output for
            // a future Compose interpolation pass (including JSON). Undo that
            // one layer before storing our non-interpolating snapshot.
            let serialized=try String(contentsOf:output,encoding:.utf8).replacingOccurrences(of:"$$",with:"$")
            let object=try JSONSerialization.jsonObject(with:Data(serialized.utf8))
            guard let document=object as? [String:Any],document["services"] is [String:Any] else{throw DeskError.message("dockerComposeResolveFailed")}
            return DockerComposeResolution(executable:cli,files:files,data:try JSONSerialization.data(withJSONObject:document,options:[.sortedKeys]))
        } catch {
            if process.isRunning {
                process.terminate();await Task.detached{try? await Task.sleep(for:.milliseconds(500))}.value
                if process.isRunning{kill(process.processIdentifier,SIGKILL)}
                await Task.detached{process.waitUntilExit()}.value
            }
            if error is CancellationError{throw error}
            if error is DeskError{throw error}
            throw DeskError.message("dockerComposeResolveFailed")
        }
    }
}
