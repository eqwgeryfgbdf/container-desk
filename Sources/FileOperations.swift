import Foundation
import Darwin

struct ContainerFile:Identifiable {
    let name:String
    let kind:String
    var id:String{name}
    var directory:Bool{kind=="d"}
    static func parse(_ data:Data)throws->[ContainerFile] {
        guard let text=String(data:data,encoding:.utf8) else{throw DeskError.message("fileEncodingUnsupported")}
        var fields=text.components(separatedBy:"\0")
        guard fields.last=="" else{throw DeskError.message("invalidFileListing")};fields.removeLast()
        guard fields.count%2==0,fields.count<=20000 else{throw DeskError.message("invalidFileListing")}
        return try stride(from:0,to:fields.count,by:2).map {i in
            guard ["d","f","l","o"].contains(fields[i]),!fields[i+1].isEmpty,!fields[i+1].contains("/"),![".",".."].contains(fields[i+1]) else{throw DeskError.message("invalidFileListing")}
            return ContainerFile(name:fields[i+1],kind:fields[i])
        }.sorted{$0.directory != $1.directory ? $0.directory:$0.name.localizedStandardCompare($1.name) == .orderedAscending}
    }
}
enum FileOperations {
    static func path(_ value:String)throws->String {
        guard value.hasPrefix("/"),!value.contains("\0"),!value.contains(":"),value.utf8.count<=4096,
              !value.split(separator:"/").contains("..") else{throw DeskError.message("invalidFilePath")}
        return "/"+value.split(separator:"/").filter{$0 != "."}.joined(separator:"/")
    }
    static func child(_ directory:String,_ name:String)throws->String {
        guard !name.isEmpty,![".",".."].contains(name),!name.contains("/"),!name.contains(":"),!name.contains("\0") else{throw DeskError.message("invalidFilePath")}
        return try path(directory+"/"+name)
    }
    static func shell(_ id:String,_ script:String,_ paths:[String])throws->[String] {
        guard ResourceRequest.validName(id) else{throw DeskError.message("invalidName")}
        return ["exec","--",id,"/bin/sh","-c",script,"containerdesk"]+(try paths.map(path))
    }
    static func listing(_ id:String,_ directory:String)throws->[String] {
        try shell(id,#"cd "$1" || exit; [ -r . ] && [ -x . ] || exit 1; for p in .[!.]* ..?* *; do [ -e "$p" ] || [ -L "$p" ] || continue; if [ -L "$p" ]; then t=l; elif [ -d "$p" ]; then t=d; elif [ -f "$p" ]; then t=f; else t=o; fi; printf '%s\000%s\000' "$t" "$p"; done"#,[directory])
    }
    static func mkdir(_ id:String,_ destination:String)throws->[String] {try shell(id,#"mkdir -- "$1""#,[destination])}
    static func rename(_ id:String,_ source:String,_ destination:String)throws->[String] {
        guard try path(source) != "/",try path(destination) != "/" else{throw DeskError.message("invalidFilePath")}
        return try shell(id,#"[ -e "$1" ] || [ -L "$1" ] || exit 1; [ ! -e "$2" ] && [ ! -L "$2" ] || exit 1; mv -n -- "$1" "$2"; [ ! -e "$1" ] && [ ! -L "$1" ]"#,[source,destination])
    }
    static func remove(_ id:String,_ target:String)throws->[String] {
        guard try path(target) != "/" else{throw DeskError.message("invalidFilePath")}
        // No recursive delete: a directory must be empty. Symlinks are unlinked.
        return try shell(id,#"if [ -L "$1" ] || [ -f "$1" ]; then rm -- "$1"; elif [ -d "$1" ]; then rmdir -- "$1"; else exit 1; fi"#,[target])
    }
    static func copy(_ id:String,local:URL,remote:String,upload:Bool)throws->[String] {
        guard ResourceRequest.validName(id),local.isFileURL,!local.path.contains(":"),!local.path.contains("\0") else{throw DeskError.message("invalidFilePath")}
        let target=id+":"+(try path(remote))
        return ["copy","--"]+(upload ? [local.path,target]:[target,local.path])
    }
}

@MainActor extension Store {
    func fileCommand(_ container:String,title:String,arguments:[String]) {
        guard canMutate,let cli else{return}
        startOperation(title,present:false) {
            try await self.requireRunning(container)
            return try await StreamingProcess.run(cli,arguments){self.operationOutput=$0}
        }
    }
    func requireRunning(_ id:String) async throws {
        guard let cli else{throw DeskError.message("coreMissing")}
        let fresh=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
        guard fresh.first(where:{$0.id==id})?.running==true else{throw DeskError.message("terminalRequiresRunning")}
        try Task.checkCancellation()
    }
    func transferFile(_ id:String,local:URL,remote:String,upload:Bool) {
        guard canMutate,let cli else{return}
        startOperation(upload ? "uploadFile":"downloadFile",present:false) {
            try await self.requireRunning(id)
            let remote=try FileOperations.path(remote)
            guard remote != "/",local.isFileURL else{throw DeskError.message("invalidFilePath")}
            let scratch=FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-transfer-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:scratch,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
            defer{try? FileManager.default.removeItem(at:scratch)}
            let archive=scratch.appendingPathComponent("transfer.tar"),output=scratch.appendingPathComponent("output")
            @MainActor func execute(_ executable:String,_ arguments:[String],input:URL?=nil,output:URL)async throws {
                try await FileTransferProcess.run(executable,arguments,input:input,output:output){bytes in
                    self.operationOutput=self.t("fileTransferProgress")+" · "+ByteCountFormatter.string(fromByteCount:bytes,countStyle:.file)
                }
            }
            if upload {
                guard try local.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink != true else{throw DeskError.message("fileSymlinkUpload")}
                let absent=try await ProcessRunner.run(cli,FileOperations.shell(id,#"[ ! -e "$1" ] && [ ! -L "$1" ]"#,[remote]))
                guard absent.code==0 else{throw DeskError.message("fileDestinationExists")}
                // Archive regular paths, never follow symlinks. ./ also prevents
                // bsdtar's special @archive operand interpretation.
                try await execute("/usr/bin/tar",["-cf","-","--no-xattrs","--no-acls","--no-fflags","-C",local.deletingLastPathComponent().path,"--","./"+local.lastPathComponent],output:archive)
                let parent=URL(fileURLWithPath:remote).deletingLastPathComponent().path
                let stage=try FileOperations.child(parent,".containerdesk-transfer-"+UUID().uuidString.lowercased())
                _=try await ProcessRunner.checked(cli,FileOperations.shell(id,#"umask 077; mkdir -- "$1""#,[stage]))
                do {
                    let args=["exec","--interactive","--",id,"/bin/sh","-c",#"exec tar -xf - -C "$1" --no-same-owner"#,"containerdesk",stage]
                    try await execute(cli,args,input:archive,output:output)
                    let payload=try FileOperations.child(stage,local.lastPathComponent)
                    let moved=try await StreamingProcess.run(cli,try FileOperations.rename(id,payload,remote)){_ in}
                    guard moved==0 else{throw DeskError.message("fileDestinationExists")}
                    _=try await ProcessRunner.checked(cli,FileOperations.remove(id,stage))
                    self.operationOutput=remote
                } catch {
                    self.operationOutput=self.t("transferStagingNote")+"\n"+stage
                    throw error
                }
            } else {
                var destinationInfo=stat()
                guard lstat(local.path,&destinationInfo) != 0,errno==ENOENT else{throw DeskError.message("fileDestinationExists")}
                let remoteURL=URL(fileURLWithPath:remote)
                let args=["exec","--",id,"tar","-cf","-","-C",remoteURL.deletingLastPathComponent().path,"--","./"+remoteURL.lastPathComponent]
                try await execute(cli,args,output:archive)
                let stage=local.deletingLastPathComponent().appendingPathComponent(".containerdesk-transfer-"+UUID().uuidString)
                try FileManager.default.createDirectory(at:stage,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
                defer{try? FileManager.default.removeItem(at:stage)}
                // BSD tar rejects traversal and extraction through symlinks by
                // default. Do not add -P; safe-writes avoids hardlink overwrites.
                try await execute("/usr/bin/tar",FileTransferProcess.extractionArguments(archive:archive,directory:stage),output:output)
                let payload=stage.appendingPathComponent(remoteURL.lastPathComponent)
                guard try payload.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink != true else{throw DeskError.message("fileSymlinkUpload")}
                try Task.checkCancellation()
                try FileManager.default.moveItem(at:payload,to:local)
                self.operationOutput=local.path
            }
            return 0
        }
    }
}

/// Binary stdin/stdout with bounded disk use, timeout and cancellation. No TTY
/// or text decoding may touch the archive stream.
@MainActor enum FileTransferProcess {
    static let maximumBytes:Int64=4*1024*1024*1024
    static func extractionArguments(archive:URL,directory:URL)->[String] {
        ["-xf",archive.path,"-C",directory.path,"--no-same-owner","--no-same-permissions","--no-xattrs","--no-acls","--no-fflags","--safe-writes"]
    }
    static func run(_ executable:String,_ arguments:[String],input:URL?=nil,output:URL,timeout:TimeInterval=900,progress:(Int64)->Void)async throws {
        try Task.checkCancellation()
        let errorFile=output.deletingLastPathComponent().appendingPathComponent("stderr-"+UUID().uuidString)
        FileManager.default.createFile(atPath:output.path,contents:nil,attributes:[.posixPermissions:0o600])
        FileManager.default.createFile(atPath:errorFile.path,contents:nil,attributes:[.posixPermissions:0o600])
        let out=try FileHandle(forWritingTo:output),err=try FileHandle(forWritingTo:errorFile)
        let source=try input.map{try FileHandle(forReadingFrom:$0)}
        defer{try? source?.close();try? out.close();try? err.close();try? FileManager.default.removeItem(at:errorFile)}
        let process=Process();process.executableURL=URL(fileURLWithPath:executable);process.arguments=arguments
        var environment=ProcessInfo.processInfo.environment;environment["COPYFILE_DISABLE"]="1";environment["NO_COLOR"]="1"
        process.environment=environment;process.standardInput=source ?? FileHandle.nullDevice;process.standardOutput=out;process.standardError=err
        try process.run()
        let deadline=Date().addingTimeInterval(timeout)
        func checkSize()throws {
            let bytes=Int64((try output.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0)
            let errors=(try errorFile.resourceValues(forKeys:[.fileSizeKey]).fileSize) ?? 0
            guard bytes<=maximumBytes,errors<=1024*1024 else{throw DeskError.message("fileTransferLimit")}
            progress(source.map{Int64((try? $0.offset()) ?? 0)} ?? bytes)
        }
        do {
            while process.isRunning {
                try Task.checkCancellation();guard Date()<deadline else{throw DeskError.message("commandTimeout")}
                try checkSize();try await Task.sleep(for:.milliseconds(100))
            }
            try checkSize();try Task.checkCancellation()
            guard process.terminationStatus==0 else{
                let message=String(decoding:(try Data(contentsOf:errorFile)).prefix(8192),as:UTF8.self)
                throw DeskError.message(message.isEmpty ? "operationFailed":message)
            }
        } catch {
            if process.isRunning {
                process.terminate();await Task.detached{try? await Task.sleep(for:.milliseconds(500))}.value
                if process.isRunning{kill(process.processIdentifier,SIGKILL)}
                await Task.detached{process.waitUntilExit()}.value
            }
            throw error
        }
    }
}
