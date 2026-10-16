import Foundation
@main @MainActor struct StoreSmoke {
    static func main() async throws {
        let store=Store();await store.start()
        guard store.connected,let cli=store.cli,let image=store.images.first(where:{$0.id.contains("python@")}) else{throw DeskError.message("Need a connected engine and existing Python image")}
        let before=store.containers
        let name="containerdesk-form-"+UUID().uuidString.prefix(8).lowercased()
        var req=CreateRequest();req.name=name;req.image=image.id;req.cpus=2;req.memoryMB=768
        do {
            guard await store.create(req) else{throw DeskError.message(store.error ?? "Creation failed")}
            let data=try await ProcessRunner.checked(cli,["list","--all","--format","json"])
            guard let created=try ContainerItem.parse(data.data).first(where:{$0.id==name}),!created.running,created.cpus==2,created.memory==768*1048576,created.image==image.id else{throw DeskError.message("Form allocation/image did not reach engine")}
            _=try await ProcessRunner.checked(cli,["delete","--",name])
            let after=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
            guard before.allSatisfy({old in after.contains(where:{$0.id==old.id && $0.state==old.state})}),!after.contains(where:{$0.id==name}) else{throw DeskError.message("Existing state changed or cleanup failed")}
            print("PASS: real Store.create from downloaded image, CPU 2, memory 768 MiB, stopped state, cleanup; existing \(before.count) workloads preserved.")
        }catch{_=try? await ProcessRunner.checked(cli,["delete","--",name]);throw error}
    }
}
