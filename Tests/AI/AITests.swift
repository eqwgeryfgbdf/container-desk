import Foundation
import Darwin

@main struct AITests {
    static var count=0
    static var metrics=[String:Any]()
    static var fixture:String {ProcessInfo.processInfo.environment["AI_FIXTURE"]!}
    static var python:String {ProcessInfo.processInfo.environment["AI_PYTHON"]!}
    static func check(_ value:Bool,_ label:String)throws {
        guard value else{throw DeskError.message("FAIL: "+label)};count+=1;print("PASS: "+label)
    }
    static func reject(_ label:String,_ body:()throws->Void)throws {
        do{try body()}catch{try check(true,label);return};throw DeskError.message("FAIL: accepted "+label)
    }
    static func fixtureConfig(_ mode:String)->MCPServerConfiguration {MCPServerConfiguration(name:"fixture",command:python,arguments:[fixture,mode])}
    static func protocolTests()async throws {
        for mode in ["stdio-legacy","stdio-modern"] {
            let client=MCPClient(fixtureConfig(mode))
            let tools=try await client.connect();try check(tools.count==1,"\(mode) discovery")
            let result=try await client.call(tools[0],arguments:["text":"fixture-response"])
            try check((result["content"] as? [[String:Any]])?.first?["text"] as? String=="fixture-response","\(mode) round trip")
            await client.close()
            do{_=try await client.call(tools[0],arguments:[:]);throw DeskError.message("unexpected call")}
            catch{try check(error.localizedDescription=="aiMCPDisconnected","closed session rejects tools")}
        }
        for mode in ["http-legacy","http-modern","http-sse-modern"] {
            let process=Process(),pipe=Pipe();process.executableURL=URL(fileURLWithPath:python);process.arguments=[fixture,mode];process.standardOutput=pipe;process.standardError=FileHandle.nullDevice
            try process.run();defer{process.terminate();process.waitUntilExit()}
            let data=try pipe.fileHandleForReading.read(upToCount:32)!
            let port=String(decoding:data,as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines)
            let url="http://127.0.0.1:\(port)"
            let client=MCPClient(MCPServerConfiguration(name:mode,endpoint:url+"/mcp"))
            let tools=try await client.connect()
            let result=try await client.call(tools[0],arguments:["text":"HTTP echo"])
            try check((result["content"] as? [[String:Any]])?.first?["text"] as? String=="HTTP echo","\(mode) discovery/session/headers and call")
            await client.close()
            try check(try await LlamaClient(endpoint:url).probe()==false,"non-tool model produces failed compatibility result")
            try check(try await LlamaClient(endpoint:url+"/bad-tool").probe()==false,"invented tool produces failed compatibility result")
            for path in ["redirect","auth"] {
                do{_=try await MCPClient(MCPServerConfiguration(name:path,endpoint:url+"/"+path)).connect();throw DeskError.message("unexpected connection")}
                catch{try check(error is AIHTTPError,"reject \(path) without forwarding/retrying tools")}
            }
            try? pipe.fileHandleForReading.close();try? pipe.fileHandleForWriting.close()
        }
        let tooBig=MCPClient(fixtureConfig("stdio-oversize"))
        do{_=try await tooBig.connect();throw DeskError.message("unexpected response")}
        catch{try check(error.localizedDescription=="responseTooLarge","bounded MCP stdout")}
        await tooBig.close()
        let stalled=MCPClient(fixtureConfig("stdio-silent"))
        let task=Task{try await stalled.connect()}
        try await Task.sleep(for:.milliseconds(150));task.cancel()
        do{_=try await task.value;throw DeskError.message("uncancelled")}
        catch{try check(error is CancellationError,"cancellation closes stalled MCP process")}
    }
    static func unit()async throws {
        try check(try AIEndpoint.validate("http://127.0.0.1:3000/mcp").host=="127.0.0.1","loopback endpoint")
        for url in ["http://example.com/mcp","https://user:pass@example.com/mcp","https://example.com/mcp?token=secret","file:///etc/passwd"]{try reject("unsafe endpoint \(url)"){_=try AIEndpoint.validate(url)}}
        try reject("remote inference endpoint"){_=try AIEndpoint.validate("https://example.com",localOnly:true)}
        let config=try MCPServerConfiguration.parse(Data(#"{"mcpServers":{"local":{"command":"python3","args":["server.py"],"env":{"TEST":"value"}}}}"#.utf8))
        try check(config.count==1 && config[0].environment["TEST"]=="value","import existing MCP configuration without launching")
        try reject("unsupported imported headers"){_=try MCPServerConfiguration.parse(Data(#"{"mcpServers":{"remote":{"url":"https://example.com","headers":{"Cookie":"secret"}}}}"#.utf8))}
        try reject("malformed tool schema"){_=try MCPTool.parse([["name":"bad","inputSchema":["type":"array"]]])}
        let object:[String:Any]=["choices":[["message":["role":"assistant","tool_calls":[["id":"1","type":"function","function":["name":"not_allowed","arguments":"{}"]]]]]]]
        try reject("hallucinated tool cannot execute"){_=try AIChatReply.parse(object,allowed:["echo"])}
        let textOnly=try AIChatReply.parse(["choices":[["message":["content":"{tool: delete_all}" ]]]],allowed:["echo"])
        try check(textOnly.calls.isEmpty,"plain text never becomes a tool call")
        try check(MCPClient.headerValue("工具")=="=?base64?5bel5YW3?=","modern header encoding")
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("model.gguf");try (Data("GGUF".utf8)+Data(repeating:0,count:64)).write(to:file)
        let plan=AIDeployment(name:"cd-ai-test",port:18090,modelPath:file.path)
        let args=try plan.request(cpus:2,memory:2048,context:2048).arguments()
        try check(args.contains("127.0.0.1:18090:8080") && args.contains(file.path+":/models/model.gguf:ro"),"loopback publish and single read-only model mount")
        try check(args.contains("--jinja") && args.contains("--n-gpu-layers") && args.contains(AIDeployment.image),"pinned image, Jinja and explicit CPU inference")
        try reject("invalid GGUF contents"){let f=folder.appendingPathComponent("bad.gguf");try Data(repeating:0,count:32).write(to:f);try AIModelFile.validate(f)}
        try reject("privileged or invalid host port"){_=try AIDeployment(name:"test",port:0,modelPath:file.path).request(cpus:2,memory:2048,context:2048)}
        do {try await AIModelDownload.verify(file,model:AIModelChoice.catalog[0]);throw DeskError.message("unexpected digest")}
        catch{try check(error.localizedDescription=="aiModelChecksum","reject corrupt model without replacement")}
        try await protocolTests()
    }
    static func live()async throws {
        guard let cli=ProcessInfo.processInfo.environment["AI_CONTAINER"] else{throw DeskError.message("AI_CONTAINER missing")}
        let manager=FileManager.default,dir=manager.temporaryDirectory.appendingPathComponent("containerdesk-ai-test-"+UUID().uuidString)
        try manager.createDirectory(at:dir,withIntermediateDirectories:true)
        let original=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
        let initialImages=try ResourceItem.parseImages((try await ProcessRunner.checked(cli,["image","list","--format","json"])).data)
        let existed=initialImages.contains{$0.id==AIDeployment.image}
        let name="cd-ai-test-"+String(UUID().uuidString.prefix(8)).lowercased()
        // Unique resources only; never remove the user's existing model library or services.
        var created=false,operationError:Error?
        let started=Date()
        do {
            let model=AIModelChoice.catalog[0];metrics["model"]=model.filename;metrics["modelBytes"]=model.size;metrics["memoryLimitMiB"]=2048;metrics["cpus"]=2
            let downloadStart=Date()
            let file=try await AIModelDownload(model){_ in}.run(directory:dir)
            metrics["downloadSeconds"]=Date().timeIntervalSince(downloadStart);try check(true,"real smallest catalog model download and SHA-256")
            _=try await ProcessRunner.checked(cli,["image","pull","--arch","arm64",AIDeployment.image],timeout:600)
            let plan=AIDeployment(name:name,port:19891,modelPath:file.path)
            _=try await ProcessRunner.checked(cli,try plan.request(cpus:2,memory:2048,context:2048).arguments(),timeout:120);created=true
            _=try await ProcessRunner.checked(cli,["start","--",name],timeout:120)
            let client=LlamaClient(endpoint:plan.endpoint),readyStart=Date();var ready=false
            while Date().timeIntervalSince(readyStart)<173 {if (try? await client.health()) != nil{ready=true;break};try await Task.sleep(for:.seconds(2))}
            try check(ready,"real llama.cpp health within 180 seconds");metrics["startupSeconds"]=Date().timeIntervalSince(readyStart)
            let responseStart=Date()
            let answer=try await client.chat([["role":"user","content":"Reply with exactly: hello"]])
            try check(!answer.text.isEmpty,"real model text completion");metrics["completionSeconds"]=Date().timeIntervalSince(responseStart)
            let passed=try await client.probe();try check(passed,"real synthetic structured tool-call probe (no MCP execution)")
            let mcp=MCPClient(fixtureConfig("stdio-legacy"))
            do {
                let tools=try await mcp.connect()
                let conversation:[[String:Any]]=[["role":"user","content":"Call \(tools[0].alias) with text container-desk-ai-ok. Do not answer without calling it."]]
                let proposal=try await client.chat(conversation,tools:tools.map(\.function),required:true)
                try check(proposal.calls.count==1 && proposal.calls[0].arguments["text"] as? String=="container-desk-ai-ok","real model proposes exact MCP tool and arguments")
                let result=try await mcp.call(tools[0],arguments:proposal.calls[0].arguments)
                let text=String(decoding:try JSONSerialization.data(withJSONObject:result),as:UTF8.self)
                let final=try await client.chat(conversation+[proposal.message,["role":"tool","tool_call_id":proposal.calls[0].id,"content":text]])
                try check(final.text.contains("container-desk-ai-ok"),"model → MCP echo → model final answer")
                await mcp.close()
            }catch{await mcp.close();throw error}
            let stats=try await ProcessRunner.checked(cli,["stats","--no-stream","--format","json",name])
            metrics["containerStats"]=try JSONSerialization.jsonObject(with:stats.data)
        }catch{operationError=error}
        if created {
            _=try? await ProcessRunner.checked(cli,["stop","--",name],timeout:60)
            _=try await ProcessRunner.checked(cli,["delete","--",name],timeout:60)
        }
        let after=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
        try check(!after.contains{$0.id==name} && Set(after.map(\.id)).isSuperset(of:Set(original.map(\.id))),"test container removed; existing containers preserved")
        let remainingImages=try ResourceItem.parseImages((try await ProcessRunner.checked(cli,["image","list","--format","json"])).data)
        if !existed,remainingImages.contains(where:{$0.id==AIDeployment.image}),!after.contains(where:{$0.image==AIDeployment.image}) {_=try await ProcessRunner.checked(cli,["image","delete","--",AIDeployment.image],timeout:60)}
        try manager.removeItem(at:dir);try check(!manager.fileExists(atPath:dir.path),"temporary GGUF and test files removed")
        metrics["totalSeconds"]=Date().timeIntervalSince(started);metrics["cleanupCompleted"]=true
        if let operationError{throw operationError}
    }
    static func main()async {
        setbuf(stdout,nil)
        do {
            try await unit();if CommandLine.arguments.contains("--live"){try await live()}
            metrics["result"]="PASS";metrics["checks"]=count
        }catch{metrics["result"]="FAIL";metrics["error"]=error.localizedDescription;print("FAIL: \(error.localizedDescription)")}
        if let path=ProcessInfo.processInfo.environment["AI_REPORT"],let data=try? JSONSerialization.data(withJSONObject:metrics,options:[.prettyPrinted,.sortedKeys]){try? data.write(to:URL(fileURLWithPath:path))}
        print("AI checks passed: \(count)");exit(metrics["result"] as? String=="PASS" ? 0:1)
    }
}
