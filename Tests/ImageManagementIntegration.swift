import Foundation

/// Opt-in: a tiny FROM scratch build, archive round trip and BusyBox pull.
/// Starts the builder only when explicitly run and restores its original stopped state.
@main struct ImageManagementIntegration {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.contains("--run") else {print("Pass --run to exercise build/archive/pull with disposable images.");return}
        let s=Store();await s.start()
        guard s.connected,let cli=s.cli else {throw DeskError.message("Engine unavailable")}
        let baseline=Dictionary(uniqueKeysWithValues:s.containers.map{($0.id,$0.state)})
        guard baseline["buildkit"]=="stopped" else {throw DeskError.message("Requires the existing builder to be stopped; will not interfere with an active builder")}
        let name="cd-qa-image-"+UUID().uuidString.lowercased().prefix(8)+":test"
        let pullName="docker.io/library/busybox:1.37.0"
        let hadBusybox=s.images.contains{$0.id==pullName}
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-image-test-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        defer{try? FileManager.default.removeItem(at:directory)}
        try "FROM scratch\nCOPY marker /marker\n".write(to:directory.appendingPathComponent("Dockerfile"),atomically:true,encoding:.utf8)
        try "Container Desk archive check\n".write(to:directory.appendingPathComponent("marker"),atomically:true,encoding:.utf8)
        let archive=directory.appendingPathComponent("roundtrip.tar").path
        func wait() async throws {
            let deadline=Date().addingTimeInterval(180)
            while s.operationRunning,Date()<deadline {try await Task.sleep(nanoseconds:200_000_000)}
            guard !s.operationRunning,s.operationResult=="operationComplete" else {s.cancelOperation();throw DeskError.message("\(s.operationResult ?? "timeout")\n\(s.operationOutput)")}
            await s.refreshResources()
        }
        func cleanup() async {
            _=try? await ProcessRunner.run(cli,["image","delete","--",name],timeout:60)
            if !hadBusybox {_=try? await ProcessRunner.run(cli,["image","delete","--",pullName],timeout:60)}
            _=try? await ProcessRunner.checked(cli,["builder","stop"],timeout:120)
        }
        do {
            var request=ResourceRequest(operation:.build);request.name=name;request.path=directory.path
            s.resourceOperation(request);try await wait()
            guard let reference=s.images.first(where:{$0.id==name || $0.id.hasSuffix("/"+name)})?.id else {throw DeskError.message("Build image missing")}
            request=ResourceRequest(operation:.save);request.source=reference;request.path=archive
            s.resourceOperation(request);try await wait()
            guard (try URL(fileURLWithPath:archive).resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)>0 else {throw DeskError.message("Archive empty")}
            s.deleteResource(.image,id:reference);try await wait()
            request=ResourceRequest(operation:.load);request.path=archive
            s.resourceOperation(request);try await wait()
            guard s.images.contains(where:{$0.id==reference}) else {throw DeskError.message("Archive import missing")}
            s.deleteResource(.image,id:reference);try await wait()
            request=ResourceRequest(operation:.pull);request.name=pullName
            s.resourceOperation(request);try await wait()
            guard s.images.contains(where:{$0.id==pullName && $0.detail.contains("arm64")}) else {throw DeskError.message("Pull missing arm64 image")}
            await cleanup()
            let after=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
            guard Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)})==baseline else {throw DeskError.message("Container states not restored")}
            print("PASS: real scratch image build, export/delete/import archive round trip, arm64 BusyBox pull, image cleanup; builder restored to stopped; \(baseline.count) original container states unchanged.")
        }catch{await cleanup();throw error}
    }
}
