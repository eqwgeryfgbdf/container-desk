import Foundation
import Darwin

struct AIHTTPError:LocalizedError {let status:Int;var errorDescription:String?{status==401 || status==403 ? "aiMCPAuthentication":(300..<400).contains(status) ? "aiHTTPRedirect":"aiHTTPUnavailable"}}
struct MCPRemoteError:LocalizedError {
    let code:Int
    var errorDescription:String? {code == -32022 ? "aiMCPVersionUnsupported":code == -32602 ? "aiMCPArgumentsInvalid":"aiMCPRemoteError"}
}

/// No cookies, ambient credentials, redirects, or unbounded response bodies.
final class AIHTTP:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
    func send(url:URL,body:[String:Any]?,headers:[String:String]=[:],matchingID:Int?=nil,timeout:TimeInterval=120)async throws->([String:Any],HTTPURLResponse) {
        let cfg=URLSessionConfiguration.ephemeral;cfg.httpCookieStorage=nil;cfg.urlCredentialStorage=nil
        cfg.timeoutIntervalForRequest=timeout;cfg.timeoutIntervalForResource=timeout
        let session=URLSession(configuration:cfg,delegate:self,delegateQueue:nil);defer{session.invalidateAndCancel()}
        var r=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:timeout)
        r.httpShouldHandleCookies=false;r.setValue("application/json, text/event-stream",forHTTPHeaderField:"Accept")
        for (key,value) in headers {
            guard value.utf8.count<8192,!value.contains("\r"),!value.contains("\n") else{throw DeskError.message("aiMCPConfigInvalid")}
            r.setValue(value,forHTTPHeaderField:key)
        }
        if let body {
            r.httpMethod="POST";r.setValue("application/json",forHTTPHeaderField:"Content-Type")
            r.httpBody=try JSONSerialization.data(withJSONObject:body)
            guard r.httpBody!.count<=1_048_576 else{throw DeskError.message("aiRequestTooLarge")}
        }
        let (stream,response)=try await session.bytes(for:r)
        guard let http=response as? HTTPURLResponse else{throw DeskError.message("aiMCPInvalidReply")}
        guard (200..<300).contains(http.statusCode) else {
            var errorBody=Data()
            for try await byte in stream {guard errorBody.count<16384 else{break};errorBody.append(byte)}
            if matchingID != nil,let object=try? Self.object(errorBody),let error=object["error"] as? [String:Any],error["code"] as? Int == -32022 {throw MCPRemoteError(code:-32022)}
            throw AIHTTPError(status:http.statusCode)
        }
        if http.statusCode==202{return ([:],http)}
        guard response.expectedContentLength<=2_097_152 else{throw DeskError.message("responseTooLarge")}
        let isSSE=(http.value(forHTTPHeaderField:"Content-Type") ?? "").lowercased().contains("text/event-stream")
        var data=Data(),line=Data(),eventLines=[String](),total=0
        for try await byte in stream {
            try Task.checkCancellation();total+=1
            guard total<=2_097_152 else{throw DeskError.message("responseTooLarge")}
            if isSSE {
                if byte==10 {
                    let value=String(decoding:line,as:UTF8.self).trimmingCharacters(in:.newlines);line.removeAll(keepingCapacity:true)
                    if value.isEmpty {
                        if !eventLines.isEmpty,let result=try? Self.object(Data(eventLines.joined(separator:"\n").utf8)),result["id"] as? Int==matchingID {return (result,http)}
                        eventLines=[]
                    } else if value.hasPrefix("data:") {eventLines.append(String(value.dropFirst(5)).trimmingCharacters(in:.whitespaces))}
                } else {line.append(byte)}
            } else {data.append(byte)}
        }
        guard !isSSE else{throw DeskError.message("aiMCPInvalidReply")}
        return (try Self.object(data),http)
    }
    static func object(_ data:Data)throws->[String:Any] {
        guard let object=try JSONSerialization.jsonObject(with:data) as? [String:Any] else{throw DeskError.message("aiMCPInvalidReply")};return object
    }
}

actor MCPStdio {
    private let process=Process()
    private let input=Pipe(),output=Pipe()
    private var buffer=Data()
    private var closed=false
    init(config:MCPServerConfiguration)throws {
        process.executableURL=URL(fileURLWithPath:try config.executable());process.arguments=config.arguments
        var env=["PATH":"/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin","HOME":FileManager.default.homeDirectoryForCurrentUser.path,"LANG":"en_US.UTF-8"]
        for (key,value) in config.environment{env[key]=value};process.environment=env
        process.standardInput=input;process.standardOutput=output;process.standardError=FileHandle.nullDevice
        try process.run()
        try input.fileHandleForReading.close();try output.fileHandleForWriting.close()
        _=fcntl(output.fileHandleForReading.fileDescriptor,F_SETFL,O_NONBLOCK)
        _=fcntl(input.fileHandleForWriting.fileDescriptor,F_SETFL,O_NONBLOCK)
        _=fcntl(input.fileHandleForWriting.fileDescriptor,F_SETNOSIGPIPE,1)
    }
    deinit {
        try? input.fileHandleForWriting.close();try? output.fileHandleForReading.close()
        if process.isRunning {process.terminate()}
    }
    func close()async {
        guard !closed else{return};closed=true
        try? input.fileHandleForWriting.close();try? output.fileHandleForReading.close()
        if process.isRunning {
            process.terminate()
            await Task.detached{try? await Task.sleep(for:.milliseconds(250))}.value
            if process.isRunning{kill(process.processIdentifier,SIGKILL)}
            // Foundation waitUntilExit can wait forever on a cooperative executor
            // after the child has already exited. Process owns reaping; bound the
            // asynchronous termination observation instead of blocking a thread.
            let child=process
            await Task.detached {
                let deadline=Date().addingTimeInterval(2)
                while child.isRunning,Date()<deadline {try? await Task.sleep(for:.milliseconds(20))}
            }.value
        }
    }
    func exchange(_ body:[String:Any],id:Int?,timeout:TimeInterval)async throws->[String:Any] {
        guard !closed,process.isRunning else{throw DeskError.message("aiMCPDisconnected")}
        var wire=try JSONSerialization.data(withJSONObject:body);wire.append(10)
        guard wire.count<=262144 else{throw DeskError.message("aiRequestTooLarge")}
        let deadline=Date().addingTimeInterval(timeout);var offset=0,total=0
        while offset<wire.count {
            try Task.checkCancellation();guard Date()<deadline else{throw DeskError.message("commandTimeout")}
            let n=wire.withUnsafeBytes{Darwin.write(input.fileHandleForWriting.fileDescriptor,$0.baseAddress!.advanced(by:offset),wire.count-offset)}
            if n>0{offset+=n}else if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR{throw DeskError.message("aiMCPDisconnected")}
            if offset<wire.count{try await Task.sleep(for:.milliseconds(10))}
        }
        guard let id else{return [:]}
        while Date()<deadline {
            try Task.checkCancellation()
            while let newline=buffer.firstIndex(of:10) {
                let line=Data(buffer[..<newline]);buffer.removeSubrange(...newline)
                guard !line.isEmpty else{continue}
                let reply=try AIHTTP.object(line)
                if reply["id"] as? Int==id,reply["method"]==nil{return reply}
                if reply["method"] != nil,let requestID=reply["id"] {
                    // Legacy servers may ask for unsupported sampling/roots/elicitation.
                    _=try await exchange(["jsonrpc":"2.0","id":requestID,"error":["code":-32601,"message":"Client capability not supported"]],id:nil,timeout:2)
                }
            }
            var bytes=[UInt8](repeating:0,count:32768)
            let n=Darwin.read(output.fileHandleForReading.fileDescriptor,&bytes,bytes.count)
            if n>0 {
                total+=n;guard total<=2_097_152,buffer.count+n<=2_097_152 else{throw DeskError.message("responseTooLarge")}
                buffer.append(contentsOf:bytes.prefix(n));continue
            }
            if n==0 || (!process.isRunning) {throw DeskError.message("aiMCPDisconnected")}
            if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR{throw DeskError.message("aiMCPDisconnected")}
            try await Task.sleep(for:.milliseconds(10))
        }
        throw DeskError.message("commandTimeout")
    }
}

actor MCPClient {
    private let configuration:MCPServerConfiguration
    private var stdio:MCPStdio?
    private var sessionID:String?
    private var protocolVersion="2026-07-28"
    private var sequence=0
    private var connected=false
    init(_ configuration:MCPServerConfiguration){self.configuration=configuration}
    func close()async {connected=false;await stdio?.close();stdio=nil;sessionID=nil}
    func connect()async throws->[MCPTool] {
        do {
            if configuration.command != nil{stdio=try MCPStdio(config:configuration)}
            // Probe before legacy initialize. Never probe a tool with side effects.
            do {
                let discovery=try await rpc("server/discover",[:],timeout:8)
                guard let supported=discovery["supportedVersions"] as? [String],supported.contains(protocolVersion) else{throw MCPRemoteError(code:-32022)}
            } catch let error as MCPRemoteError where error.code == -32022 {throw error}
              catch {
                try Task.checkCancellation()
                let legacyError = error is MCPRemoteError || (error as? AIHTTPError).map{[400,404,405,406].contains($0.status)} == true || (stdio != nil && error.localizedDescription=="commandTimeout")
                guard legacyError else{throw error}
                protocolVersion="2025-11-25"
                let initialized=try await rpc("initialize",["protocolVersion":protocolVersion,"capabilities":[:],"clientInfo":["name":"Container Desk","version":"0.3.0-dev"]])
                guard let version=initialized["protocolVersion"] as? String,["2025-11-25","2025-06-18","2025-03-26","2024-11-05"].contains(version) else{throw DeskError.message("aiMCPVersionUnsupported")}
                protocolVersion=version
                _=try await rpc("notifications/initialized",[:],notification:true)
            }
            connected=true
            return try await listTools()
        } catch {await close();throw error}
    }
    func listTools()async throws->[MCPTool] {
        guard connected else{throw DeskError.message("aiMCPDisconnected")}
        var tools=[MCPTool](),cursor:String?,seen=Set<String>()
        repeat {
            let result=try await rpc("tools/list",cursor.map{["cursor":$0]} ?? [:])
            guard let rows=result["tools"] as? [[String:Any]] else{throw DeskError.message("aiMCPInvalidReply")}
            tools += try MCPTool.parse(rows,offset:tools.count)
            guard tools.count<=128,Set(tools.map(\.name)).count==tools.count else{throw DeskError.message("aiMCPTooManyTools")}
            cursor=result["nextCursor"] as? String
            if let cursor {guard !cursor.isEmpty,cursor.utf8.count<4096,seen.count<16,seen.insert(cursor).inserted else{throw DeskError.message("aiMCPInvalidReply")}}
        } while cursor != nil
        return tools
    }
    func call(_ tool:MCPTool,arguments:[String:Any])async throws->[String:Any] {
        guard connected else{throw DeskError.message("aiMCPDisconnected")}
        // Header projection extensions and multi-round-trip requests are not silently ignored.
        let schemaData=try JSONSerialization.data(withJSONObject:tool.schema)
        guard !String(decoding:schemaData,as:UTF8.self).contains("\"x-mcp-header\"") else{throw DeskError.message("aiMCPCapabilityUnsupported")}
        let result=try await rpc("tools/call",["name":tool.name,"arguments":arguments],timeout:90)
        guard result["inputRequests"]==nil,result["task"]==nil else{throw DeskError.message("aiMCPCapabilityUnsupported")}
        guard result["content"] is [[String:Any]] || result["structuredContent"] != nil else{throw DeskError.message("aiMCPInvalidReply")}
        return result
    }
    static func headerValue(_ value:String)->String {
        let sentinel=value.hasPrefix("=?base64?") && value.hasSuffix("?=")
        if !sentinel,value==value.trimmingCharacters(in:.whitespacesAndNewlines),value.unicodeScalars.allSatisfy({($0.value>=32 && $0.value<127) || $0.value==9}) {return value}
        return "=?base64?"+Data(value.utf8).base64EncodedString()+"?="
    }
    private func rpc(_ method:String,_ parameters:[String:Any],notification:Bool=false,timeout:TimeInterval=30)async throws->[String:Any] {
        sequence+=1;let id=sequence
        var params=parameters
        let modern=protocolVersion=="2026-07-28"
        if modern {params["_meta"]=["io.modelcontextprotocol/protocolVersion":protocolVersion,"io.modelcontextprotocol/clientInfo":["name":"Container Desk","version":"0.3.0-dev"],"io.modelcontextprotocol/clientCapabilities":[:]] as [String:Any]}
        var body:[String:Any]=["jsonrpc":"2.0","method":method,"params":params];if !notification{body["id"]=id}
        let reply:[String:Any]
        if let stdio {reply=try await stdio.exchange(body,id:notification ? nil:id,timeout:timeout)} else {
            let url=try AIEndpoint.validate(configuration.endpoint ?? "")
            var headers=["MCP-Protocol-Version":protocolVersion]
            if let sessionID{headers["Mcp-Session-Id"]=sessionID}
            if modern{headers["Mcp-Method"]=method;if let name=params["name"] as? String{headers["Mcp-Name"]=Self.headerValue(name)}}
            if !configuration.bearer.isEmpty{headers["Authorization"]="Bearer "+configuration.bearer}
            let (value,response)=try await AIHTTP().send(url:url,body:body,headers:headers,matchingID:notification ? nil:id,timeout:timeout)
            if method=="initialize",let session=response.value(forHTTPHeaderField:"Mcp-Session-Id") {
                guard !session.isEmpty,session.utf8.count<=512,session.unicodeScalars.allSatisfy({$0.value>=33 && $0.value<=126}) else{throw DeskError.message("aiMCPInvalidReply")};sessionID=session
            }
            reply=value
        }
        if notification{return [:]}
        guard reply["jsonrpc"] as? String=="2.0",reply["id"] as? Int==id else{throw DeskError.message("aiMCPInvalidReply")}
        if let error=reply["error"] as? [String:Any]{throw MCPRemoteError(code:error["code"] as? Int ?? -1)}
        guard let result=reply["result"] as? [String:Any] else{throw DeskError.message("aiMCPInvalidReply")};return result
    }
}

struct LlamaClient {
    let endpoint:String
    func health()async throws {
        let base=try AIEndpoint.validate(endpoint,localOnly:true)
        let (reply,_)=try await AIHTTP().send(url:base.appendingPathComponent("health"),body:nil,timeout:5)
        guard reply["status"] as? String=="ok" else{throw DeskError.message("aiModelNotReady")}
    }
    func chat(_ messages:[[String:Any]],tools:[[String:Any]]=[],required:Bool=false)async throws->AIChatReply {
        let base=try AIEndpoint.validate(endpoint,localOnly:true)
        var body:[String:Any]=["model":"container-desk-local","messages":messages,"stream":false,"temperature":0,"max_tokens":512]
        if !tools.isEmpty{body["tools"]=tools;body["tool_choice"]=required ? "required":"auto";body["parallel_tool_calls"]=false}
        let (reply,_)=try await AIHTTP().send(url:base.appendingPathComponent("v1/chat/completions"),body:body,timeout:180)
        let names=Set(tools.compactMap{($0["function"] as? [String:Any])?["name"] as? String})
        return try AIChatReply.parse(reply,allowed:names)
    }
    /// Synthetic echo: verifies structured selection and arguments, executes no external tool.
    func probe()async throws->Bool {
        let token=UUID().uuidString.lowercased()
        let tool:[String:Any]=["type":"function","function":["name":"container_desk_echo","description":"Echo the exact provided token.","parameters":["type":"object","properties":["token":["type":"string"]],"required":["token"],"additionalProperties":false]]]
        do {
            let reply=try await chat([["role":"user","content":"Call container_desk_echo exactly once with token \(token). Do not answer in text."]],tools:[tool],required:true)
            return reply.calls.count==1 && reply.calls[0].name=="container_desk_echo" && reply.calls[0].arguments["token"] as? String==token && reply.calls[0].arguments.count==1
        } catch where ["aiToolCallRejected","aiModelInvalidReply"].contains(error.localizedDescription) {
            // A model producing malformed or invented calls failed the capability probe.
            // Transport and authentication failures still propagate as connection errors.
            return false
        }
    }
}
