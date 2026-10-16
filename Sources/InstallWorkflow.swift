import Foundation

struct EngineSnapshot {
    let running:Bool
    let activeContainers:Int
    static func parse(_ data:Data) throws -> EngineSnapshot {
        guard let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],let status=object["status"] as? String,
              ["running","stopped"].contains(status) else {throw DeskError.message("engineStatusUnknown")}
        if status=="stopped" {return .init(running:false,activeContainers:0)}
        guard let resources=object["resources"] as? [String:Any],let active=resources["containersRunning"] as? Int,active>=0 else {throw DeskError.message("engineStatusUnknown")}
        return .init(running:true,activeContainers:active)
    }
}

/// The same sequencing is used by the live installer and isolated failure tests.
@MainActor struct InstallSteps {
    var inspect:() async throws -> EngineSnapshot
    var prepare:() async throws -> Void
    var stop:() async throws -> Void
    var install:() async throws -> Void
    var start:() async throws -> Void
    var verify:() async throws -> Void
    var recover:(_ installationAttempted:Bool) async throws -> Void
    var phase:(String)->Void
}
@MainActor enum InstallWorkflow {
    static func run(_ steps:InstallSteps) async throws {
        let before=try await steps.inspect()
        guard before.activeContainers==0 else{throw DeskError.message("updateDeferred")}
        // All download/source verification completes before any service interruption.
        try await steps.prepare()
        let fresh=try await steps.inspect()
        guard fresh.activeContainers==0 else{throw DeskError.message("updateDeferred")}
        var stopAttempted=false
        var installationAttempted=false
        do {
            if fresh.running {
                steps.phase("stoppingService");stopAttempted=true
                try await steps.stop()
            }
            steps.phase("awaitingAuthorization");installationAttempted=true
            try await steps.install()
            steps.phase("startingService");try await steps.start()
            try await steps.verify()
        } catch {
            let original=error.localizedDescription
            if stopAttempted {
                do{try await steps.recover(installationAttempted)}
                catch{throw DeskError.message(original+"\nrestoreFailed\n"+error.localizedDescription)}
            }
            throw DeskError.message(original)
        }
    }
}
