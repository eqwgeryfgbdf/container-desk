import Foundation

/// Local inference only. These endpoints never come from model-generated text.
enum AIEndpoint {
    static func validate(_ text:String, localOnly:Bool=false)throws->URL {
        guard let c=URLComponents(string:text),let url=c.url,let host=c.host,
              c.user==nil,c.password==nil,c.fragment==nil,c.query==nil,
              !text.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains),
              c.port.map({(1...65535).contains($0)}) ?? true else{throw DeskError.message("aiInvalidEndpoint")}
        let loopback=["127.0.0.1","localhost","[::1]","::1"].contains(host.lowercased())
        guard (c.scheme=="https" || (c.scheme=="http" && loopback)),!localOnly || loopback else{throw DeskError.message("aiInvalidEndpoint")}
        return url
    }
}

struct AIModelChoice:Identifiable,Codable {
    let id:String
    let repository:String
    let revision:String
    let filename:String
    let size:Int64
    let sha256:String
    let memoryMiB:Int
    var license:String="apache-2.0"
    var url:URL {URL(string:"https://huggingface.co")!.appendingPathComponent(repository).appendingPathComponent("resolve").appendingPathComponent(revision).appendingPathComponent(filename)}
    var modelCard:URL {URL(string:"https://huggingface.co")!.appendingPathComponent(repository)}
    static func safePath(_ text:String)->Bool {
        !text.isEmpty && text.utf8.count<=512 && text.split(separator:"/",omittingEmptySubsequences:false).allSatisfy {
            !$0.isEmpty && $0 != "." && $0 != ".." && $0.unicodeScalars.allSatisfy {CharacterSet(charactersIn:"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.").contains($0)}
        }
    }
    func validateMetadata()throws {
        guard Self.safePath(repository),repository.split(separator:"/").count==2,
              Self.safePath(filename),filename.lowercased().hasSuffix(".gguf"),!filename.lowercased().contains("-of-"),
              revision.range(of:"^[a-f0-9]{40}$",options:.regularExpression) != nil,
              sha256.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,
              size>24,size<=256*1024*1024*1024 else{throw DeskError.message("aiHFInvalidMetadata")}
    }
    // Content-addressed folders prevent equal filenames in different repositories/revisions colliding.
    func destination(in directory:URL)throws->URL {
        try validateMetadata()
        return directory.appendingPathComponent(sha256,isDirectory:true).appendingPathComponent(URL(fileURLWithPath:filename).lastPathComponent)
    }
    static let catalog=[
        AIModelChoice(id:"Qwen2.5 0.5B Instruct · Q4_K_M",repository:"Qwen/Qwen2.5-0.5B-Instruct-GGUF",revision:"9217f5db79a29953eb74d5343926648285ec7e67",filename:"qwen2.5-0.5b-instruct-q4_k_m.gguf",size:491400032,sha256:"74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db",memoryMiB:2048),
        AIModelChoice(id:"Qwen2.5 1.5B Instruct · Q4_K_M",repository:"Qwen/Qwen2.5-1.5B-Instruct-GGUF",revision:"91cad51170dc346986eccefdc2dd33a9da36ead9",filename:"qwen2.5-1.5b-instruct-q4_k_m.gguf",size:1117320736,sha256:"6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e",memoryMiB:3072)
    ]
}

struct AIDeployment:Codable {
    // Official server image, pinned to the inspected multi-platform index.
    static let image="ghcr.io/ggml-org/llama.cpp@sha256:143926008cbbbab8fae8fd87809875af3e42d3d676c30c11c55c0f3f683a5a07"
    let name:String
    let port:Int
    let modelPath:String
    var endpoint:String {"http://127.0.0.1:\(port)"}
    func request(cpus:Int,memory:Int,context:Int)throws->CreateRequest {
        guard (1024...65535).contains(port),(512...32768).contains(context) else{throw DeskError.message("aiInvalidResources")}
        let url=URL(fileURLWithPath:modelPath).resolvingSymlinksInPath()
        try AIModelFile.validate(url)
        var r=CreateRequest();r.name=name;r.image=Self.image;r.cpus=cpus;r.memoryMB=memory
        r.hostPort=String(port);r.containerPort="8080"
        r.mountSource=url.path;r.mountTarget="/models/model.gguf";r.readOnly=true
        r.commandArguments=["--model","/models/model.gguf","--host","0.0.0.0","--port","8080","--jinja","--ctx-size",String(context),"--threads",String(cpus),"--parallel","1","--n-gpu-layers","0","--alias","container-desk-local"].joined(separator:"\n")
        return r
    }
}

enum AIModelFile {
    static func validate(_ url:URL,requireExtension:Bool=true)throws {
        let values=try url.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey])
        guard (!requireExtension || url.pathExtension.lowercased()=="gguf"),values.isRegularFile==true,(values.fileSize ?? 0)>24,
              !url.lastPathComponent.contains("-of-") else{throw DeskError.message("aiInvalidModel")}
        let f=try FileHandle(forReadingFrom:url);defer{try? f.close()}
        guard try f.read(upToCount:4)==Data("GGUF".utf8) else{throw DeskError.message("aiInvalidModel")}
    }
}

struct MCPServerConfiguration:Identifiable {
    let id=UUID()
    let name:String
    var command:String?=nil
    var arguments:[String]=[]
    var environment:[String:String]=[:]
    var endpoint:String?=nil
    var bearer:String=""
    var summary:String {endpoint ?? ([command ?? ""]+arguments).map(shellQuote).joined(separator:" ")}
    static func parse(_ data:Data)throws->[Self] {
        guard data.count<=1_048_576,let root=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let servers=root["mcpServers"] as? [String:[String:Any]],!servers.isEmpty,servers.count<=30 else{throw DeskError.message("aiMCPConfigInvalid")}
        return try servers.keys.sorted().map {name in
            let row=servers[name]!
            guard !name.isEmpty,name.count<=128,row["disabled"] as? Bool != true else{throw DeskError.message("aiMCPConfigInvalid")}
            if let url=row["url"] as? String {
                _=try AIEndpoint.validate(url)
                guard row["command"]==nil,row["headers"]==nil || row["headers"] is [String:String],row["type"] as? String != "sse" else{throw DeskError.message("aiMCPConfigInvalid")}
                let headers=row["headers"] as? [String:String] ?? [:]
                guard headers.keys.allSatisfy({$0.lowercased()=="authorization"}) else{throw DeskError.message("aiMCPConfigInvalid")}
                let auth=headers.first?.value ?? ""
                guard auth.isEmpty || auth.hasPrefix("Bearer ") else{throw DeskError.message("aiMCPConfigInvalid")}
                return Self(name:name,endpoint:url,bearer:auth.isEmpty ? "":String(auth.dropFirst(7)))
            }
            guard let command=row["command"] as? String,!command.isEmpty,command.count<4096,
                  row["args"]==nil || row["args"] is [String],row["env"]==nil || row["env"] is [String:String] else{throw DeskError.message("aiMCPConfigInvalid")}
            let args=row["args"] as? [String] ?? [],env=row["env"] as? [String:String] ?? [:]
            guard args.count<=100,env.count<=100,([command]+args+Array(env.values)).allSatisfy({!$0.contains("\0") && $0.utf8.count<16384}),env.keys.allSatisfy({$0.range(of:"^[A-Za-z_][A-Za-z0-9_]*$",options:.regularExpression) != nil}) else{throw DeskError.message("aiMCPConfigInvalid")}
            return Self(name:name,command:command,arguments:args,environment:env)
        }
    }
    func executable()throws->String {
        guard let command else{throw DeskError.message("aiMCPConfigInvalid")}
        if command.hasPrefix("/"),FileManager.default.isExecutableFile(atPath:command){return command}
        guard !command.contains("/") else{throw DeskError.message("aiMCPExecutableMissing")}
        let paths=["/opt/homebrew/bin","/usr/local/bin",FileManager.default.homeDirectoryForCurrentUser.path+"/.local/bin","/usr/bin","/bin"]
        guard let path=paths.map({$0+"/"+command}).first(where:{FileManager.default.isExecutableFile(atPath:$0)}) else{throw DeskError.message("aiMCPExecutableMissing")}
        return path
    }
}

struct MCPTool:Identifiable {
    let name:String
    let description:String
    let schema:[String:Any]
    var id:String{name}
    // Alias avoids exposing unsupported MCP names to OpenAI function-name validators.
    let alias:String
    var function:[String:Any] {["type":"function","function":["name":alias,"description":String(description.prefix(3000)),"parameters":schema]]}
    static func parse(_ rows:[[String:Any]],offset:Int=0)throws->[Self] {
        guard rows.count<=128 else{throw DeskError.message("aiMCPTooManyTools")}
        return try rows.enumerated().map {index,row in
            guard let name=row["name"] as? String,!name.isEmpty,name.utf8.count<=256,
                  let schema=row["inputSchema"] as? [String:Any],schema["type"] as? String=="object" else{throw DeskError.message("aiMCPInvalidReply")}
            return Self(name:name,description:row["description"] as? String ?? name,schema:schema,alias:"mcp_tool_\(index+offset)")
        }
    }
}

struct AIToolCall:Identifiable {
    let id:String
    let name:String
    let arguments:[String:Any]
    var formatted:String {String(data:(try? JSONSerialization.data(withJSONObject:arguments,options:[.prettyPrinted,.sortedKeys])) ?? Data(),encoding:.utf8) ?? "{}"}
}
struct AIChatReply {
    let text:String
    let calls:[AIToolCall]
    let message:[String:Any]
    static func parse(_ object:[String:Any],allowed:Set<String>)throws->Self {
        guard let choices=object["choices"] as? [[String:Any]],let first=choices.first,
              let message=first["message"] as? [String:Any] else{throw DeskError.message("aiModelInvalidReply")}
        let raw=message["tool_calls"] as? [[String:Any]] ?? []
        guard message["tool_calls"]==nil || message["tool_calls"] is [[String:Any]],raw.count<=8 else{throw DeskError.message("aiModelInvalidReply")}
        var ids=Set<String>()
        let calls=try raw.map {row->AIToolCall in
            guard row["type"] as? String=="function",let id=row["id"] as? String,!id.isEmpty,id.count<256,ids.insert(id).inserted,
                  let f=row["function"] as? [String:Any],let name=f["name"] as? String,allowed.contains(name),
                  let text=f["arguments"] as? String,text.utf8.count<=65536,
                  let args=(try? JSONSerialization.jsonObject(with:Data(text.utf8))) as? [String:Any] else{throw DeskError.message("aiToolCallRejected")}
            return AIToolCall(id:id,name:name,arguments:args)
        }
        let text=message["content"] as? String ?? ""
        var normalized:[String:Any]=["role":"assistant","content":text]
        if !raw.isEmpty{normalized["tool_calls"]=raw}
        return Self(text:text,calls:calls,message:normalized)
    }
}
