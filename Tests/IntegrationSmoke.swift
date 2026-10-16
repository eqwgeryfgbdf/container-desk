import Foundation
@main struct IntegrationSmoke {
    static func main() async throws {
        let cli=CommandLine.arguments[1],image=CommandLine.arguments[2]
        let name="containerdesk-smoke-"+String(UUID().uuidString.prefix(8)).lowercased()
        func command(_ a:[String]) async throws -> CommandResult {try await ProcessRunner.checked(cli,a,timeout:120)}
        func state() async throws -> [ContainerItem] {try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)}
        let before=try await state()
        do {
            _=try await command(["create","--name",name,"--cpus","1","--memory","256M",image,"/bin/sh","-c","echo containerdesk-smoke-ok; sleep 120"])
            guard (try await state()).first(where:{$0.id==name})?.running==false else{throw DeskError.message("Create did not produce stopped container")}
            _=try await command(["start","--",name])
            guard (try await state()).first(where:{$0.id==name})?.running==true else{throw DeskError.message("Start failed")}
            let logs=try await command(["logs","-n","150","--",name])
            guard logs.text.contains("containerdesk-smoke-ok") else{throw DeskError.message("Logs missing")}
            _=try await command(["stats","--no-stream","--format","json",name])
            _=try await command(["stop","--",name])
            _=try await command(["delete","--",name])
            let after=try await state()
            guard !after.contains(where:{$0.id==name}) else{throw DeskError.message("Delete failed")}
            for old in before {guard after.first(where:{$0.id==old.id})?.state==old.state else{throw DeskError.message("Existing workload state changed")}}
            print("PASS: create → start → logs → stats → stop → delete. Existing \(before.count) container states unchanged.")
        }catch{
            _=try? await command(["stop","--",name]);_=try? await command(["delete","--",name]);throw error
        }
    }
}
