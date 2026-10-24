import Foundation

extension PlatformTests {
    @MainActor func testAIWorkspaceState()async throws {
        let fixture=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("AI/mcp-fixture.py")
        let python=try await ProcessRunner.checked("/usr/bin/which",["python3"])
        let process=Process(),pipe=Pipe();process.executableURL=URL(fileURLWithPath:python.text.trimmingCharacters(in:.whitespacesAndNewlines));process.arguments=[fixture.path,"http-state-legacy"];process.standardOutput=pipe;process.standardError=FileHandle.nullDevice
        try process.run();defer{process.terminate();process.waitUntilExit();try? pipe.fileHandleForReading.close();try? pipe.fileHandleForWriting.close()}
        let port=Int(String(decoding:try pipe.fileHandleForReading.read(upToCount:32)!,as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines))!
        let url="http://127.0.0.1:\(port)",state=AIWorkspace()
        let server=MCPServerConfiguration(name:"test",endpoint:url+"/mcp")
        state.configurations=[server];state.selectedServer=server.id
        state.deployment=AIDeployment(name:"fixture",port:port,modelPath:"");state.modelReady=true
        func wait()async throws {
            let deadline=Date().addingTimeInterval(10)
            while state.isBusy {guard Date()<deadline else{state.cancel();throw DeskError.message("AI state timeout")};try await Task.sleep(for:.milliseconds(10))}
            try XCTAssertTrue(state.error==nil,state.error ?? "")
        }
        func calls()async throws->Int {
            let (value,_)=try await AIHTTP().send(url:URL(string:url+"/counts")!,body:nil)
            return value["calls"] as? Int ?? -1
        }
        func expectCalls(_ expected:Int,_ note:String="")async throws {let value=try await calls();try XCTAssertEqual(value,expected,note)}
        state.connect();try await wait()
        try XCTAssertTrue(state.mcpConnected && state.tools.count==1 && state.enabledTools.isEmpty)
        try await expectCalls(0,"Discovery must not invoke tools")
        state.enabledTools=["echo"];state.prompt="Echo something";state.ask();try await wait()
        try XCTAssertEqual(state.warning,"aiToolsFailedDetail","Untested model must be gated")
        try XCTAssertTrue(state.pending.isEmpty)
        state.toolSupport="aiToolsPassed";state.ask();try await wait()
        try XCTAssertEqual(state.pending.count,1)
        try await expectCalls(0,"Model proposal must await user review")
        state.approveTools();try await wait()
        try await expectCalls(1)
        try XCTAssertTrue(state.pending.isEmpty && state.chat.last?.text=="state-echo")
        state.prompt="Echo again";state.ask();try await wait();state.declineTools()
        try await expectCalls(1,"Decline must not invoke the tool")
        state.prompt="New request";state.ask();try await wait()
        await state.disconnect()
        try XCTAssertTrue(state.pending.isEmpty && state.tools.isEmpty && !state.mcpConnected)
        state.approveTools();try await expectCalls(1,"Disconnected approvals must do nothing")
        print("PASS: AI workspace connection, capability gate, proposal/review/execute/result, decline and disconnect")
    }
}
