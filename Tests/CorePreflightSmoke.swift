import Foundation
@main @MainActor struct CorePreflightSmoke {
    static func main() async throws {
        let store=Store();await store.start()
        let manager=CoreManager();await manager.check()
        guard let release=manager.release,store.connected,store.active>0,manager.canMigrate(store) else{throw DeskError.message("Preconditions changed; no installation attempted")}
        let before=store.containers
        await manager.install(store,migrate:true)
        guard manager.failure=="updateDeferred",!manager.installing,manager.phase=="failed" else{throw DeskError.message("Active-workload guard did not reject migration")}
        guard let cli=store.cli else{throw DeskError.message("CLI lost")}
        let after=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
        guard before.allSatisfy({old in after.contains(where:{$0.id==old.id && $0.state==old.state})}) else{throw DeskError.message("Workload state changed")}
        print("PASS: official release \(release.tag_name) metadata verified; custom same-version migration recognized and blocked before download/stop/install while \(store.active) workload runs. Existing \(before.count) states preserved.")
    }
}
