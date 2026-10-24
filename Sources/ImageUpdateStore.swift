import Foundation

struct ContainerUpdateHistory {
    static var file:URL {FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/ContainerDesk/container-updates.json")}
    static func read()throws->[ContainerUpdateReceipt] {
        guard FileManager.default.fileExists(atPath:file.path) else{return []}
        guard (try file.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<1_048_576 else{throw DeskError.message("imageUpdateHistoryFailed")}
        return try JSONDecoder().decode([ContainerUpdateReceipt].self,from:Data(contentsOf:file))
    }
    static func save(_ values:[ContainerUpdateReceipt])throws {
        let dir=file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        try JSONEncoder().encode(values).write(to:file,options:[.atomic,.completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
    }
}

extension Store {
    func imageUpdater(_ cli:String)->ImageUpdateWorkflow {
        ImageUpdateWorkflow(command:{ args in
            // Do not echo create arguments or inspect JSON: these can contain secrets.
            do{return try await ProcessRunner.checked(cli,args,timeout:args.prefix(2)==["image","pull"] ? 600:120).data}
            catch is CancellationError{throw CancellationError()}
            catch{throw DeskError.message("imageUpdateCommandFailed")}
        })
    }
    func refreshImageVersion(_ image:String) {
        guard canMutate,let cli else{return}
        imageUpdateStatus[image]="imageUpdateChecking"
        startOperation("imageUpdateDownload") {
            do {
                let result=try await self.imageUpdater(cli).refresh(image)
                let status=result.changed ? "imageUpdateDownloaded":"imageUpdateCurrent"
                self.imageUpdateStatus[image]=status
                self.operationOutput=self.t(status)+"\n\n"+result.before.digest+"\n→ "+result.after.digest+"\n\n"+self.t("imageUpdateBackup")+": "+result.backup
                return 0
            }catch{self.imageUpdateStatus[image]="operationFailed";throw error}
        }
    }
    func applyImageUpdate(_ plan:ContainerUpdatePlan) {
        guard canMutate,let cli else{return}
        startOperation("containerUpdateApply") {
            var receipts=try ContainerUpdateHistory.read()
            guard !receipts.contains(where:{$0.original==plan.clone.id}) else{throw DeskError.message("imageUpdateChanged")}
            // Establish that the history can be written before stopping anything.
            try ContainerUpdateHistory.save(receipts)
            self.operationOutput=self.t("imageUpdateVerifying")
            let receipt=try await self.imageUpdater(cli).apply(plan)
            receipts.append(receipt)
            self.containerUpdateReceipts=receipts
            do{try ContainerUpdateHistory.save(receipts)}catch{throw DeskError.message("imageUpdateHistoryFailed")}
            self.operationOutput=self.t(plan.wasRunning ? (plan.healthURL==nil ? "imageUpdateRunningVerified":"imageUpdateHTTPVerified"):"imageUpdateStoppedVerified")+"\n\n"+receipt.original+" → "+receipt.replacement+"\n"+self.t("imageUpdateRetained")
            self.selected=receipt.replacement
            return 0
        }
    }
    func rollbackImageUpdate(_ receipt:ContainerUpdateReceipt) {
        guard canMutate,let cli else{return}
        startOperation("imageUpdateRollback") {
            var receipts=try ContainerUpdateHistory.read()
            try await self.imageUpdater(cli).rollback(receipt,history:receipts)
            receipts.removeAll{$0.id==receipt.id}
            try ContainerUpdateHistory.save(receipts);self.containerUpdateReceipts=receipts
            self.operationOutput=self.t("imageUpdateRollbackDone");return 0
        }
    }
}
