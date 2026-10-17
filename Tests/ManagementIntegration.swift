import Foundation

/// Opt-in real-engine test. Uses an existing arm64 image and unique disposable resources.
@main struct ManagementIntegration {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.contains("--run") else {print("Pass --run to create disposable test resources on the local engine.");return}
        let s=Store();await s.start()
        guard s.connected,let cli=s.cli else {throw DeskError.message("Engine unavailable")}
        let baseline=Dictionary(uniqueKeysWithValues:s.containers.map{($0.id,$0.state)})
        let id="cd-qa-"+UUID().uuidString.lowercased().prefix(8)
        let image=id+":test", net=id+"-net", vol=id+"-vol"
        guard let source=s.images.first(where:{$0.detail.contains("arm64") && $0.id.contains("python")})?.id else {throw DeskError.message("An existing arm64 Python image is required; no download is performed")}
        func command(_ args:[String]) async throws -> CommandResult {try await ProcessRunner.checked(cli,args,timeout:120)}
        func waitOperation(_ expected:String="operationComplete") async throws {
            let deadline=Date().addingTimeInterval(120)
            while s.operationRunning,Date()<deadline {try await Task.sleep(nanoseconds:200_000_000)}
            guard !s.operationRunning,s.operationResult==expected else {throw DeskError.message("Unexpected operation result: \(s.operationResult ?? "pending")\n\(s.operationOutput)")}
            // The operation reconciles resource lists after publishing its result.
            await s.refreshResources()
        }
        func settledRefresh() async throws {
            let deadline=Date().addingTimeInterval(60)
            while s.refreshing || s.busy {guard Date()<deadline else {throw DeskError.message("Refresh timeout")};try await Task.sleep(nanoseconds:100_000_000)}
            await s.refresh()
        }
        func cleanup() async throws {
            let rows=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            if let c=rows.first(where:{$0.id==id}) {
                if c.running {_=try await command(["stop","--",id])}
                _=try await command(["delete","--",id])
            }
            for (kind,name) in [("image",image),("network",net),("volume",vol)] {
                let result=try await ProcessRunner.run(cli,[kind,"delete","--",name],timeout:60)
                if result.code != 0 && !result.error.lowercased().contains("notfound") && !result.error.lowercased().contains("not found") {
                    print("Cleanup note for \(name): \(result.error)")
                }
            }
        }
        do {
            var request=ResourceRequest(operation:.createNetwork);request.name=net;s.resourceOperation(request);try await waitOperation()
            guard s.networks.contains(where:{$0.id==net}) else {throw DeskError.message("Network not read back")}
            request=ResourceRequest(operation:.createVolume);request.name=vol;s.resourceOperation(request);try await waitOperation()
            guard s.volumes.contains(where:{$0.id==vol}) else {throw DeskError.message("Volume not read back")}
            request=ResourceRequest(operation:.tag);request.source=source;request.name=image;s.resourceOperation(request);try await waitOperation()
            guard let tagged=s.images.first(where:{$0.id==image || $0.id.hasSuffix("/"+image)})?.id else {throw DeskError.message("Tagged image not read back")}
            var create=CreateRequest();create.name=id;create.image=tagged;create.cpus=1;create.memoryMB=256;create.network=net;create.namedVolume=vol;create.volumeTarget="/qa";create.entrypoint="/bin/sh";create.commandArguments="-c\nprintf ready; touch /qa/marker; while :; do sleep 1; done"
            guard await s.create(create) else {throw DeskError.message(s.error ?? "Create failed")}
            try await settledRefresh()
            guard let stopped=s.containers.first(where:{$0.id==id}),!stopped.running else {throw DeskError.message("Creation did not remain stopped")}
            for (kind,name) in [(ResourceKind.network,net),(.volume,vol),(.image,tagged)] {
                s.deleteResource(kind,id:name);try await waitOperation("operationFailed")
                guard s.operationOutput.contains("resourceInUse") else{throw DeskError.message("Missing in-use refusal")}
            }
            s.deleteResource(.network,id:"default");try await waitOperation("operationFailed")
            guard s.operationOutput.contains("protectedResource") else{throw DeskError.message("Missing built-in refusal")}
            await s.action("start",stopped);try await settledRefresh()
            guard let running=s.containers.first(where:{$0.id==id}),running.running else {throw DeskError.message(s.error ?? "Start failed")}
            let marker=try await command(["exec","--",id,"/bin/sh","-c","test -f /qa/marker && printf persistent"])
            guard marker.text=="persistent" else {throw DeskError.message("Named volume not mounted")}
            await s.action("restart",running);try await settledRefresh()
            guard s.containers.first(where:{$0.id==id})?.running == true else {throw DeskError.message(s.error ?? "Restart failed")}
            _=try await command(["exec","--",id,"/bin/sh","-c","test -f /qa/marker"])
            let inspected=try await command(InspectionTarget(kind:nil,name:id).arguments)
            guard (try JSONSerialization.jsonObject(with:inspected.data)) is [[String:Any]] else {throw DeskError.message("Inspect invalid")}
            await s.action("stop",running);try await settledRefresh()
            guard let final=s.containers.first(where:{$0.id==id}),!final.running else {throw DeskError.message("Stop failed")}
            await s.action("delete",final);try await settledRefresh()
            for (kind,name) in [(ResourceKind.image,tagged),(.network,net),(.volume,vol)] {
                s.deleteResource(kind,id:name);try await waitOperation()
            }
            let after=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            guard Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)})==baseline else {throw DeskError.message("Unrelated container states changed")}
            print("PASS: real network/volume create and readback; image tag; stopped creation; in-use and built-in deletion refusal; named-volume mount; start/exec/restart/data persistence/inspect/stop/delete; cleanup. \(baseline.count) unrelated container states unchanged.")
        } catch {
            try await cleanup()
            throw error
        }
    }
}
