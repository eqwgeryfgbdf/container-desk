import Foundation
@main @MainActor struct InstallWorkflowTests {
    static func main() async throws {
        var count=0
        func check(_ value:Bool,_ message:String)throws{guard value else{throw DeskError.message(message)};count+=1}
        func run(_ failure:String?=nil,_ active:Int=0,_ race:Bool=false,_ running:Bool=true,_ recoveryFails:Bool=false) async -> ([String],String?) {
            var calls=[String](),inspections=0
            func step(_ name:String)throws{calls.append(name);if failure==name{throw DeskError.message(name)}}
            let steps=InstallSteps(inspect:{
                inspections+=1;try step("inspect")
                return .init(running:running,activeContainers:race && inspections==2 ? 1:active)
            },prepare:{try step("prepare")},stop:{try step("stop")},install:{try step("install")},start:{try step("start")},verify:{try step("verify")},recover:{attempted in
                calls.append(attempted ? "recover-current":"recover-old")
                if recoveryFails{throw DeskError.message("recoveryFailure")}
            },phase:{_ in})
            do{try await InstallWorkflow.run(steps);return(calls,nil)}catch{return(calls,error.localizedDescription)}
        }
        var r=await run();try check(r.1==nil && r.0==["inspect","prepare","inspect","stop","install","start","verify"],"Normal update sequence failed")
        r=await run(nil,0,false,false);try check(r.1==nil && !r.0.contains("stop"),"Fresh/stopped engine should not stop a service")
        r=await run(nil,1);try check(r.1=="updateDeferred" && r.0==["inspect"],"Running workload must block before downloading")
        r=await run(nil,0,true);try check(r.1=="updateDeferred" && !r.0.contains("stop"),"Workload appearing during download must block")
        r=await run("prepare");try check(r.1=="prepare" && !r.0.contains("stop"),"Download/signature failure must not interrupt engine")
        r=await run("install");try check(r.1=="install" && r.0.last=="recover-current" && !r.0.contains("verify"),"Authorization/installer failure must recover service and remain failed")
        r=await run("stop");try check(r.1=="stop" && r.0.last=="recover-old" && !r.0.contains("install"),"Failed stop must not proceed to installer")
        r=await run("start");try check(r.1=="start" && r.0.last=="recover-current","Start failure recovery missing")
        r=await run("verify");try check(r.1=="verify" && r.0.last=="recover-current","Verification failure must not report success")
        r=await run("install",0,false,true,true);try check(r.1?.contains("restoreFailed")==true && r.1?.contains("recoveryFailure")==true,"Must preserve original and recovery errors")
        r=await run("install",0,false,false);try check(!r.0.contains("recover-current"),"Fresh install failure must not pretend an old service exists")
        let stopped=try EngineSnapshot.parse(Data("{\"status\":\"stopped\"}".utf8));try check(!stopped.running,"Stopped engine status rejected")
        do{_=try EngineSnapshot.parse(Data("{\"status\":\"running\"}".utf8));throw DeskError.message("Missing metrics accepted")}catch{try check(error.localizedDescription=="engineStatusUnknown","Unknown state must fail closed")}
        print("PASS: \(count) installer sequencing and recovery checks (isolated simulated operations, not a real install)")
    }
}
