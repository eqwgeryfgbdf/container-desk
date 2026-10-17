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

extension Store {
    func batchOperation(_ request:BatchRequest) {
        guard canMutate,let cli,!request.items.isEmpty else{return}
        // Deduplicate the fixed confirmation snapshot; selection/filter changes
        // while the task is running cannot add more targets.
        var seen=Set<String>()
        let items=request.items.filter{seen.insert($0.id).inserted}
        startOperation("batchOperations") {
            var report="",failed=0
            for (index,item) in items.enumerated() {
                let heading="[\(index+1)/\(items.count)] \(self.t(request.verb.rawValue)) · \(item.id)\n"
                do {
                    try Task.checkCancellation()
                    let fresh=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
                    let commands=try request.verb.commands(for:item,current:fresh.first{$0.id==item.id})
                    self.operationOutput=report+heading
                    for command in commands {
                        try Task.checkCancellation()
                        let code=try await StreamingProcess.run(cli,command,timeout:120) { self.operationOutput=report+heading+$0 }
                        guard code==0 else {throw DeskError.message(String(self.operationOutput.suffix(4000)))}
                    }
                    let after=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
                    guard request.verb.completed(after.first{$0.id==item.id}) else {throw DeskError.message("batchUnconfirmed")}
                    report+=heading+self.t("operationComplete")+"\n\n"
                } catch is CancellationError {
                    let remaining=items[index...].map(\.id).joined(separator:", ")
                    self.operationOutput=report+heading+self.t("batchCancelledNote")+"\n"+remaining
                    throw CancellationError()
                } catch {
                    failed+=1
                    report+=heading+self.t("operationFailed")+": "+self.t(error.localizedDescription)+"\n\n"
                }
                // Bound UI history without ever altering which targets execute.
                report=String(report.suffix(60000));self.operationOutput=report
            }
            self.operationOutput=report+self.t("batchSummary")+": \(items.count-failed)/\(items.count)\n"
            return failed==0 ? 0:1
        }
    }
}
