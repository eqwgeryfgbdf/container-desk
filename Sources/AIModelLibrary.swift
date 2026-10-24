import Foundation
import CryptoKit

final class AIModelDownload:NSObject,URLSessionDownloadDelegate {
    let model:AIModelChoice
    let progress:@Sendable (Double)->Void
    init(_ model:AIModelChoice,progress:@escaping @Sendable (Double)->Void){self.model=model;self.progress=progress}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL){}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64) {
        if totalBytesWritten>model.size || totalBytesExpectedToWrite>model.size{downloadTask.cancel()}
        progress(min(1,Double(totalBytesWritten)/Double(model.size)))
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) {
        let host=request.url?.host ?? ""
        completionHandler(request.url?.scheme=="https" && (host=="huggingface.co" || host.hasSuffix(".hf.co") || host.hasSuffix(".huggingface.co")) ? request:nil)
    }
    static var directory:URL {FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Container Desk/Models",isDirectory:true)}
    static func verify(_ url:URL,model:AIModelChoice)async throws {
        let task=Task.detached {
            try AIModelFile.validate(url,requireExtension:false)
            let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize
            guard size==Int(model.size) else{throw DeskError.message("aiModelChecksum")}
            let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()};var hash=SHA256()
            while let data=try handle.read(upToCount:1024*1024),!data.isEmpty {try Task.checkCancellation();hash.update(data:data)}
            guard hash.finalize().map({String(format:"%02x",$0)}).joined()==model.sha256 else{throw DeskError.message("aiModelChecksum")}
        }
        try await withTaskCancellationHandler(operation:{try await task.value},onCancel:{task.cancel()})
    }
    func run(directory:URL=AIModelDownload.directory)async throws->URL {
        let manager=FileManager.default
        let destination=try model.destination(in:directory)
        try manager.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        // Reuse pre-search catalog downloads only after verifying their content.
        let legacy=directory.appendingPathComponent(URL(fileURLWithPath:model.filename).lastPathComponent)
        if manager.fileExists(atPath:legacy.path) {
            do{try await Self.verify(legacy,model:model);return legacy}
            catch is CancellationError{throw CancellationError()}
            catch{} // A same-named file from a different repository is preserved.
        }
        try manager.createDirectory(at:destination.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        if manager.fileExists(atPath:destination.path){try await Self.verify(destination,model:model);return destination}
        if let free=try? directory.resourceValues(forKeys:[.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
           free<model.size+128*1024*1024{throw DeskError.message("aiModelDiskSpace")}
        let cfg=URLSessionConfiguration.ephemeral;cfg.httpCookieStorage=nil;cfg.urlCredentialStorage=nil;cfg.timeoutIntervalForRequest=60;cfg.timeoutIntervalForResource=1800
        let session=URLSession(configuration:cfg,delegate:self,delegateQueue:nil);defer{session.invalidateAndCancel()}
        let (file,response)=try await session.download(from:model.url);defer{try? manager.removeItem(at:file)}
        guard (response as? HTTPURLResponse)?.statusCode==200 else{throw DeskError.message("aiModelDownloadFailed")}
        try await Self.verify(file,model:model)
        try Task.checkCancellation()
        try manager.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        try manager.moveItem(at:file,to:destination)
        return destination
    }
}
