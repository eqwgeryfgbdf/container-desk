import Foundation
import AppKit

struct InspectionTarget: Identifiable {
    let id = UUID()
    let kind: ResourceKind?
    let name: String
    var arguments: [String] { (kind.map{[$0.rawValue]} ?? []) + ["inspect","--",name] }
}

extension Store {
    func resourceOperation(_ request: ResourceRequest) {
        guard canMutate, let cli else { return }
        do {
            let arguments = try request.arguments()
            startOperation(request.operation.rawValue) {
                try await StreamingProcess.run(cli,arguments) { self.operationOutput=$0 }
            }
        } catch { self.error=t(error.localizedDescription) }
    }
    func deleteResource(_ kind:ResourceKind, id:String) {
        guard canMutate, let cli else { return }
        startOperation("delete") {
            let inventory = try await ProcessRunner.checked(cli,[kind.rawValue,"list","--format","json"])
            let containers = try await ProcessRunner.checked(cli,["list","--all","--format","json"])
            try Task.checkCancellation()
            try ResourceSafety.validateDeletion(kind:kind,id:id,inventory:inventory.data,containers:containers.data)
            return try await StreamingProcess.run(cli,[kind.rawValue,"delete","--",id]) {self.operationOutput=$0}
        }
    }
    func openTerminal(_ item:ContainerItem) async {
        guard canMutate, let cli else {return}
        do {
            let fresh=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
            guard fresh.first(where:{$0.id==item.id})?.running == true else {throw DeskError.message("terminalRequiresRunning")}
            guard let terminal=NSWorkspace.shared.urlForApplication(withBundleIdentifier:"com.apple.Terminal") else {throw DeskError.message("terminalUnavailable")}
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-terminal-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let file=dir.appendingPathComponent("Container.command")
            // Quote every argument. No AppleScript, automation permission, or interpolated shell command.
            let command=([cli,"exec","--tty","--interactive","--",item.id,"/bin/sh"]).map(shellQuote).joined(separator:" ")
            let script="#!/bin/sh\n/bin/rm -- \"$0\"\n/bin/rmdir -- "+shellQuote(dir.path)+"\nexec "+command+"\n"
            try script.write(to:file,atomically:true,encoding:.utf8)
            try FileManager.default.setAttributes([.posixPermissions:0o700],ofItemAtPath:file.path)
            do {
                _=try await NSWorkspace.shared.open([file],withApplicationAt:terminal,configuration:NSWorkspace.OpenConfiguration())
            } catch {try? FileManager.default.removeItem(at:dir);throw error}
        } catch {self.error=t(error.localizedDescription)}
    }
}
