import Foundation
import CryptoKit
import Yams
import CYaml

struct ComposeIssue:LocalizedError {
    let path:String
    let reason:String
    var errorDescription:String?{"\(path): \(reason)"}
}
struct ComposeResource:Identifiable {
    let key:String
    let name:String
    let external:Bool
    var id:String{name}
}
struct ComposeHealth {
    let command:[String]
    let interval:Double
    let timeout:Double
    let retries:Int
    let startPeriod:Double
}
struct ComposeService:Identifiable {
    let name:String
    let container:String
    let image:String
    let createArguments:[String]
    let buildArguments:[String]?
    let dependencies:[String:String]
    let health:ComposeHealth?
    let fingerprint:String
    let hostsFile:URL
    let networkAliases:[String:[String]]
    var id:String{name}
}
struct ComposePlan {
    let projectID:String
    let name:String
    let source:URL
    let services:[ComposeService] // topological order
    let networks:[ComposeResource]
    let volumes:[ComposeResource]
    let volumeGiB:Int
    static let ownerLabel="app.containerdesk.project"
    static let configLabel="app.containerdesk.configuration"
    static let serviceLabel="app.containerdesk.service"
}

/// YAML parsing is delegated to pinned Yams/libyaml. The adapter deliberately
/// rejects unsupported Compose semantics with a property path before mutation.
struct ComposePlanner {
    private let root:Node
    private let file:URL
    private let projectID:String
    private let scope:String
    private let resolved:Bool
    private let variables:[String:String]
    private let capacity:Int
    private func issue(_ path:String,_ reason:String)->ComposeIssue{ComposeIssue(path:path,reason:reason)}
    init(file:URL,projectID:String,volumeGiB:Int=8,sourceData:Data?=nil)throws {
        self.file=file;self.projectID=projectID;self.capacity=volumeGiB
        guard UUID(uuidString:projectID) != nil,(1...1024).contains(volumeGiB) else{throw ComposeIssue(path:"project",reason:"Invalid project identity or volume capacity")}
        root=try Self.parseDocument(sourceData ?? Data(contentsOf:file,options:.mappedIfSafe))
        resolved=root["x-container-desk-resolved"]?.bool==true
        let dotenv=file.deletingLastPathComponent().appendingPathComponent(".env")
        variables = !resolved && FileManager.default.fileExists(atPath:dotenv.path) ? try Self.envFile(dotenv):[:]
        scope="cd-"+projectID.lowercased().replacingOccurrences(of:"-",with:"").prefix(12)
    }
    static func parseDocument(_ data:Data)throws->Node {
        let root:Node
        guard data.count<=512*1024,let text=String(data:data,encoding:.utf8) else{throw ComposeIssue(path:"document",reason:"Expected UTF-8 YAML, at most 512 KiB")}
        try Self.validateYAML(data)
        do {guard let node=try Yams.compose(yaml:text) else{throw ComposeIssue(path:"document",reason:"Empty document")};root=node}
        catch {throw ComposeIssue(path:"document",reason:"Invalid YAML or multiple documents; check syntax")}
        var count=0
        func check(_ node:Node,_ depth:Int)throws {
            count+=1;guard depth<40,count<=15000 else{throw ComposeIssue(path:"document",reason:"Document nesting or size limit exceeded")}
            guard node.anchor==nil else{throw ComposeIssue(path:"document",reason:"YAML anchors and aliases are not supported")}
            switch node {
            case .alias:throw ComposeIssue(path:"document",reason:"YAML aliases are not supported")
            case .mapping(let m):
                var keys=Set<String>()
                for pair in m {
                    guard let key=pair.key.string,key != "<<",keys.insert(key).inserted else{throw ComposeIssue(path:"document",reason:"Duplicate or merge key")}
                    try check(pair.value,depth+1)
                }
            case .sequence(let a):for item in a{try check(item,depth+1)}
            case .scalar:break
            }
        }
        try check(root,0)
        return root
    }
    private static func validateYAML(_ data:Data)throws {
        var parser=yaml_parser_t()
        guard yaml_parser_initialize(&parser) != 0 else{throw ComposeIssue(path:"document",reason:"YAML parser initialization failed")}
        defer{yaml_parser_delete(&parser)}
        try data.withUnsafeBytes {buffer in
            yaml_parser_set_input_string(&parser,buffer.bindMemory(to:UInt8.self).baseAddress,buffer.count)
            var depth=0,events=0,documents=0
            while true {
                var event=yaml_event_t()
                guard yaml_parser_parse(&parser,&event) != 0 else{throw ComposeIssue(path:"document:\(parser.problem_mark.line+1)",reason:"Invalid YAML; check syntax at the reported line")}
                defer{yaml_event_delete(&event)}
                events+=1
                guard events<=30000 else{throw ComposeIssue(path:"document",reason:"Document size limit exceeded")}
                switch event.type {
                case YAML_ALIAS_EVENT:throw ComposeIssue(path:"document",reason:"YAML aliases are unsupported")
                case YAML_MAPPING_START_EVENT:
                    guard event.data.mapping_start.anchor==nil else{throw ComposeIssue(path:"document",reason:"YAML anchors are unsupported")};depth+=1
                case YAML_SEQUENCE_START_EVENT:
                    guard event.data.sequence_start.anchor==nil else{throw ComposeIssue(path:"document",reason:"YAML anchors are unsupported")};depth+=1
                case YAML_SCALAR_EVENT:
                    guard event.data.scalar.anchor==nil else{throw ComposeIssue(path:"document",reason:"YAML anchors are unsupported")}
                case YAML_MAPPING_END_EVENT,YAML_SEQUENCE_END_EVENT:depth-=1
                case YAML_DOCUMENT_START_EVENT:documents+=1;guard documents<=1 else{throw ComposeIssue(path:"document",reason:"Multiple YAML documents are unsupported")}
                case YAML_STREAM_END_EVENT:return
                default:break
                }
                guard depth<40 else{throw ComposeIssue(path:"document",reason:"Document nesting limit exceeded")}
            }
        }
    }
    private func map(_ node:Node?,_ path:String,empty:Bool=false)throws->[String:Node] {
        if node==nil || node?.null != nil {if empty{return [:]}}
        guard let mapping=node?.mapping else{throw issue(path,"Expected a mapping")}
        return Dictionary(uniqueKeysWithValues:try mapping.map {pair in guard let key=pair.key.string else{throw issue(path,"Expected string keys")};return(key,pair.value)})
    }
    private func keys(_ values:[String:Node],_ allowed:Set<String>,_ path:String)throws {
        if let unknown=values.keys.sorted().first(where:{!allowed.contains($0)}){throw issue(path+"."+unknown,"Unsupported setting; remove or configure separately")}
    }
    private func string(_ node:Node?,_ path:String)throws->String {
        guard let scalar=node?.scalar,node?.null==nil else{throw issue(path,"Expected a scalar value")}
        guard !scalar.string.contains("\0") else{throw issue(path,"NUL is not allowed")}
        return resolved ? scalar.string:try expand(scalar.string,path)
    }
    private func array(_ node:Node?,_ path:String)throws->[Node] {
        guard let seq=node?.sequence else{throw issue(path,"Expected a list")};return Array(seq)
    }
    private func bool(_ node:Node?,_ path:String,default fallback:Bool=false)throws->Bool {
        guard let node else{return fallback};guard let value=node.bool else{throw issue(path,"Expected true or false")};return value
    }
    private func expand(_ input:String,_ path:String)throws->String {
        var out="",index=input.startIndex
        while index<input.endIndex {
            if input[index] != "$" {out.append(input[index]);index=input.index(after:index);continue}
            index=input.index(after:index)
            guard index<input.endIndex else{throw issue(path,"Escape literal dollar signs as $$")}
            if input[index]=="$" {out.append("$");index=input.index(after:index);continue}
            var expression=""
            if input[index]=="{" {
                let start=input.index(after:index);guard let end=input[start...].firstIndex(of:"}") else{throw issue(path,"Unclosed variable")}
                expression=String(input[start..<end]);index=input.index(after:end)
            } else {
                let start=index
                while index<input.endIndex,(input[index].isASCII && (input[index].isLetter || input[index].isNumber || input[index]=="_")){index=input.index(after:index)}
                expression=String(input[start..<index])
            }
            let parts=expression.components(separatedBy:":-")
            let key=parts[0]
            guard parts.count<=2,key.range(of:"^[A-Za-z_][A-Za-z0-9_]*$",options:.regularExpression) != nil else{throw issue(path,"Supported substitutions: $VAR, ${VAR}, ${VAR:-default}, $$")}
            if let value=variables[key],!value.isEmpty {out+=value}
            else if parts.count==2 {guard !parts[1].contains("$") else{throw issue(path,"Nested substitutions are unsupported")};out+=parts[1]}
            else if let value=variables[key]{out+=value}
            else{throw issue(path+"."+key,"Missing variable in the adjacent .env file; host environment is not inherited")}
        }
        guard !out.contains("\0") else{throw issue(path,"NUL is not allowed")};return out
    }
    static func envFile(_ file:URL)throws->[String:String] {
        let data=try Data(contentsOf:file)
        guard data.count<=256*1024,let text=String(data:data,encoding:.utf8) else{throw ComposeIssue(path:file.lastPathComponent,reason:"Expected UTF-8 environment file, at most 256 KiB")}
        var result:[String:String]=[:]
        for (index,raw) in text.components(separatedBy:.newlines).enumerated() {
            let line=raw.trimmingCharacters(in:.whitespaces)
            if line.isEmpty || line.hasPrefix("#"){continue}
            let path=file.lastPathComponent+":\(index+1)"
            guard let eq=line.firstIndex(of:"=") else{throw ComposeIssue(path:path,reason:"Expected KEY=value; implicit host values are unsupported")}
            let key=String(line[..<eq]).trimmingCharacters(in:.whitespaces)
            guard key.range(of:"^[A-Za-z_][A-Za-z0-9_]*$",options:.regularExpression) != nil else{throw ComposeIssue(path:path,reason:"Invalid environment key")}
            var value=String(line[line.index(after:eq)...]).trimmingCharacters(in:.whitespaces)
            if value.hasPrefix("\"") || value.hasPrefix("'") {
                guard value.count>=2,value.last==value.first else{throw ComposeIssue(path:path,reason:"Multiline or unmatched quotes are unsupported")};value=String(value.dropFirst().dropLast())
                guard !value.contains("\\") else{throw ComposeIssue(path:path,reason:"Escaped env-file values are unsupported")}
            } else if let comment=value.range(of:" #"){value=String(value[..<comment.lowerBound]).trimmingCharacters(in:.whitespaces)}
            guard !value.contains("\0"),!value.contains("$") else{throw ComposeIssue(path:path,reason:"Use literal values in environment files; interpolation is supported in YAML")}
            result[key]=value
        }
        return result
    }
    private func local(_ value:String,_ path:String)throws->URL {
        guard !value.isEmpty,!value.contains("://"),!value.hasPrefix("~"),!value.contains("\0") else{throw issue(path,"Expected a local path, relative to the Compose file or absolute")}
        return URL(fileURLWithPath:value,relativeTo:file.deletingLastPathComponent()).standardizedFileURL
    }
    private func tokens(_ node:Node?,_ path:String)throws->[String] {
        if let sequence=node?.sequence {return try sequence.map{try string($0,path)}}
        let text=try string(node,path)
        // Shell-style splitting only; never evaluate substitutions or commands.
        var words:[String]=[],word="",quote:Character?,escaped=false,started=false
        for c in text {
            if escaped{word.append(c);escaped=false;started=true;continue}
            if c=="\\",quote != "'" {escaped=true;started=true;continue}
            if let q=quote {if c==q{quote=nil}else{word.append(c)};continue}
            if c=="'" || c=="\""{quote=c;started=true;continue}
            if c.isWhitespace {if started{words.append(word);word="";started=false}}else{word.append(c);started=true}
        }
        guard quote==nil,!escaped else{throw issue(path,"Unmatched command quoting")}
        if started{words.append(word)};return words
    }
    private func resources(_ node:Node?,_ kind:String)throws->[String:ComposeResource] {
        let definitions=try map(node,kind,empty:true)
        return try Dictionary(uniqueKeysWithValues:definitions.sorted{$0.key<$1.key}.map {key,node in
            guard ResourceRequest.validName(key),key.count<=24 else{throw issue(kind+"."+key,"Use a name of at most 24 characters")}
            let values=try map(node,kind+"."+key,empty:true)
            try keys(values,["external","name"],kind+"."+key)
            let external=try bool(values["external"],kind+"."+key+".external")
            let name=try values["name"].map{try string($0,kind+"."+key+".name")} ?? (external ? key:scope+"-"+key)
            guard ResourceRequest.validName(name),external || values["name"]==nil else{throw issue(kind+"."+key,"Custom resource names require external: true")}
            return(key,ComposeResource(key:key,name:name,external:external))
        })
    }
    private func duration(_ node:Node?,_ path:String,_ fallback:Double)throws->Double {
        guard let node else{return fallback};let value=try string(node,path)
        let units:[String:Double]=["ms":0.001,"s":1,"m":60]
        for suffix in ["ms","s","m"] where value.hasSuffix(suffix) {
            guard let amount=Double(value.dropLast(suffix.count)),amount>0,amount*units[suffix]!<=300 else{throw issue(path,"Duration must be greater than zero and at most 5 minutes")}
            return amount*units[suffix]!
        }
        throw issue(path,"Use a duration in ms, s or m")
    }
    func plan()throws->ComposePlan {
        let document=try map(root,"document")
        try keys(document,["name","version","services","volumes","networks","x-container-desk-resolved"],"document")
        if let marker=document["x-container-desk-resolved"],marker.bool != true {throw issue("x-container-desk-resolved","Expected true or false")}
        let name=try document["name"].map{try string($0,"name")} ?? file.deletingLastPathComponent().lastPathComponent
        let definitions=try map(document["services"],"services")
        guard !definitions.isEmpty,definitions.count<=32 else{throw issue("services","Expected 1 to 32 services")}
        var networks=try resources(document["networks"],"networks")
        if networks["default"]==nil {networks["default"]=ComposeResource(key:"default",name:scope+"-default",external:false)}
        let volumes=try resources(document["volumes"],"volumes")
        var services:[String:ComposeService]=[:]
        for service in definitions.keys.sorted() {
            let path="services."+service
            guard service.range(of:"^[a-z0-9][a-z0-9-]{0,23}$",options:.regularExpression) != nil else{throw issue(path,"Service names must be lowercase DNS labels, at most 24 characters")}
            let values=try map(definitions[service],path)
            try keys(values,["image","build","command","entrypoint","environment","env_file","ports","volumes","networks","depends_on","healthcheck","cpus","mem_limit","working_dir","user","read_only","platform","restart","init","labels"],path)
            if let restart=values["restart"],try string(restart,path+".restart") != "no" {throw issue(path+".restart","Automatic restart policies are not supported by this adapter")}
            var request=CreateRequest();request.name=service+"."+scope;request.cpus=1;request.memoryMB=512
            request.image=try values["image"].map{try string($0,path+".image")} ?? scope+"-"+service+":compose"
            var build:[String]?
            if let node=values["build"] {
                let opts=node.scalar != nil ? ["context":node]:try map(node,path+".build")
                try keys(opts,["context","dockerfile","args","target","no_cache","pull"],path+".build")
                let context=try local(try string(opts["context"],path+".build.context"),path+".build.context")
                let dockerfile=try opts["dockerfile"].map{try string($0,path+".build.dockerfile")} ?? "Dockerfile"
                var resource=ResourceRequest(operation:.build);resource.name=request.image;resource.path=context.path;resource.dockerfile=dockerfile
                var arguments=try resource.arguments();arguments.removeLast(2)
                if let node=opts["args"] {
                    let values=try map(node,path+".build.args")
                    for key in values.keys.sorted() {
                        guard key.range(of:"^[A-Za-z_][A-Za-z0-9_]*$",options:.regularExpression) != nil else{throw issue(path+".build.args","Invalid environment key")}
                        arguments += ["--build-arg",key+"="+(try string(values[key],path+".build.args."+key))]
                    }
                }
                if let target=opts["target"] {let value=try string(target,path+".build.target");guard ResourceRequest.validName(value) else{throw issue(path+".build.target","Invalid build target")};arguments += ["--target",value]}
                if try bool(opts["no_cache"],path+".build.no_cache"){arguments += ["--no-cache"]}
                if try bool(opts["pull"],path+".build.pull"){arguments += ["--pull"]}
                build=arguments+["--",context.path]
            } else if values["image"]==nil {throw issue(path+".image","Image or local build is required")}
            if let node=values["platform"] {
                let platform=try string(node,path+".platform");guard platform=="linux/arm64" else{throw issue(path+".platform","This Compose adapter currently supports linux/arm64")}
            }
            if let node=values["cpus"] {let v=try string(node,path+".cpus");guard let d=Double(v),d.isFinite,d.rounded()==d,(1...1024).contains(d) else{throw issue(path+".cpus","Use whole CPU cores")};request.cpus=Int(d)}
            if let node=values["mem_limit"] {
                let v=try string(node,path+".mem_limit").lowercased()
                let pattern=#"^([0-9]+)(b|k|kb|kib|m|mb|mib|g|gb|gib)?$"#
                guard let match=try NSRegularExpression(pattern:pattern).firstMatch(in:v,range:NSRange(v.startIndex...,in:v)),let numberRange=Range(match.range(at:1),in:v),let number=Double(v[numberRange]) else{throw issue(path+".mem_limit","Use an integer byte size such as 512M or 2G")}
                let suffix=Range(match.range(at:2),in:v).map{String(v[$0])} ?? "b"
                let factor:Double=suffix.hasPrefix("g") ? 1024:suffix.hasPrefix("m") ? 1:suffix.hasPrefix("k") ? 1/1024:1/1048576
                let mb=ceil(number*factor);guard mb>=200,mb<=1048576 else{throw issue(path+".mem_limit","Memory must be between 200 MiB and 1 TiB")};request.memoryMB=Int(mb)
            }
            var env:[String:String]=[:]
            if let node=values["env_file"] {
                let paths=node.scalar != nil ? [node]:try array(node,path+".env_file")
                for item in paths {env.merge(try Self.envFile(local(try string(item,path+".env_file"),path+".env_file"))){_,new in new}}
            }
            if let node=values["environment"] {
                if node.sequence != nil {
                    for item in try array(node,path+".environment") {
                        let entry=try string(item,path+".environment");guard let eq=entry.firstIndex(of:"=") else{throw issue(path+".environment","Use KEY=value, not implicit host values")}
                        env[String(entry[..<eq])]=String(entry[entry.index(after:eq)...])
                    }
                } else {for (key,value) in try map(node,path+".environment"){env[key]=try string(value,path+".environment."+key)}}
            }
            guard env.values.allSatisfy({!$0.contains(where:{$0.isNewline})}) else{throw issue(path+".environment","Multiline environment values are unsupported")}
            request.environment=env.keys.sorted().map{$0+"="+env[$0]!}.joined(separator:"\n")
            if let node=values["ports"] {
                for entry in try array(node,path+".ports") {
                    let text=try string(entry,path+".ports")
                    let proto=text.split(separator:"/",omittingEmptySubsequences:false);guard proto.count<=2 else{throw issue(path+".ports","Invalid port protocol")}
                    var parts=proto[0].split(separator:":",omittingEmptySubsequences:false).map(String.init)
                    if parts.count==3 {guard parts.removeFirst()=="127.0.0.1" else{throw issue(path+".ports","Only loopback port publication is supported")}}
                    guard parts.count==2 else{throw issue(path+".ports","Use host:container[/tcp|udp], without ranges")}
                    request.additionalPorts.append(PortMapping(host:parts[0],container:parts[1],transport:proto.count==2 ? String(proto[1]):"tcp"))
                }
            }
            if let node=values["volumes"] {
                for entry in try array(node,path+".volumes") {
                    var source:String,target:String,readOnly=false,type=""
                    if entry.scalar != nil {
                        let parts=try string(entry,path+".volumes").split(separator:":",omittingEmptySubsequences:false).map(String.init)
                        guard (2...3).contains(parts.count),parts.count==2 || ["ro","rw"].contains(parts[2]) else{throw issue(path+".volumes","Use source:target[:ro|rw]")}
                        source=parts[0];target=parts[1];readOnly=parts.count==3 && parts[2]=="ro"
                        type=source.hasPrefix(".") || source.hasPrefix("/") ? "bind":"volume"
                    } else {
                        let mount=try map(entry,path+".volumes");try keys(mount,["type","source","target","read_only"],path+".volumes")
                        source=try string(mount["source"],path+".volumes.source");target=try string(mount["target"],path+".volumes.target");type=try string(mount["type"],path+".volumes.type");readOnly=try bool(mount["read_only"],path+".volumes.read_only")
                    }
                    if type=="bind" {
                        request.additionalMounts.append(MountMapping(source:try local(source,path+".volumes").path,target:target,readOnly:readOnly))
                    } else if type=="volume",let volume=volumes[source] {request.additionalMounts.append(MountMapping(kind:.volume,source:volume.name,target:target,readOnly:readOnly))}
                    else{throw issue(path+".volumes","Declare named volumes at the document root; only bind and volume mounts are supported")}
                }
            }
            var networkKeys=["default"],aliases:[String:[String]]=[:]
            if let node=values["networks"] {
                if node.sequence != nil {networkKeys=try array(node,path+".networks").map{try string($0,path+".networks")}}
                else {
                    let options=try map(node,path+".networks");networkKeys=options.keys.sorted()
                    for key in networkKeys {
                        let settings=try map(options[key],path+".networks."+key,empty:true)
                        try keys(settings,["aliases"],path+".networks."+key)
                        if let list=settings["aliases"] {aliases[key]=try array(list,path+".networks."+key).map{try string($0,path+".networks."+key+".aliases")}}
                    }
                }
            }
            guard !networkKeys.isEmpty,networkKeys.count<=8,Set(networkKeys).count==networkKeys.count,networkKeys.allSatisfy({networks[$0] != nil}) else{throw issue(path+".networks","Use 1 to 8 distinct declared networks")}
            var networkAliases:[String:[String]]=[:]
            for key in networkKeys {
                let names=aliases[key] ?? []
                guard names.count<=32,names.allSatisfy({$0.range(of:"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$",options:.regularExpression) != nil && !["localhost","ip6-localhost"].contains($0.lowercased())}) else{throw issue(path+".networks."+key,"Invalid or reserved network alias")}
                networkAliases[networks[key]!.name]=names
            }
            request.network=networks[networkKeys[0]]!.name
            if let node=values["working_dir"]{request.workingDirectory=try string(node,path+".working_dir")}
            var args=try request.arguments();args.removeLast(2) // remove -- IMAGE, then append exact argument arrays below
            for key in networkKeys.dropFirst(){args += ["--network",networks[key]!.name]}
            if try bool(values["init"],path+".init"){args += ["--init"]}
            if let node=values["labels"] {
                for (key,value) in try map(node,path+".labels").sorted(by:{$0.key<$1.key}) {
                    guard !key.isEmpty,!key.hasPrefix("app.containerdesk."),!key.contains("="),!key.contains(where:{$0.isWhitespace || $0=="\0"}) else{throw issue(path+".labels","Invalid or reserved label")}
                    args += ["--label",key+"="+(try string(value,path+".labels."+key))]
                }
            }
            guard !request.allMounts.contains(where:{(try? FileOperations.path($0.target))=="/etc/hosts"}) else{throw issue(path+".volumes","/etc/hosts is reserved for project service discovery")}
            let hostsFile=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("ContainerDesk/compose-hosts/"+projectID+"/"+service+".hosts")
            args += ["--volume",hostsFile.path+":/etc/hosts:ro","--label",ComposePlan.ownerLabel+"="+projectID,"--label",ComposePlan.serviceLabel+"="+service]
            if try bool(values["read_only"],path+".read_only"){args += ["--read-only"]}
            if let node=values["user"] {args += ["--user",try string(node,path+".user")]}
            var command:[String]=[]
            if let node=values["entrypoint"] {
                let entry=try tokens(node,path+".entrypoint");guard let executable=entry.first,!executable.isEmpty else{throw issue(path+".entrypoint","Empty entrypoint override is unsupported")}
                args += ["--entrypoint",executable];command=Array(entry.dropFirst())
            }
            if let node=values["command"] {
                let cmd=try tokens(node,path+".command");guard !cmd.isEmpty else{throw issue(path+".command","Empty command override is unsupported")};command+=cmd
            }
            if values["entrypoint"] != nil && command.isEmpty {throw issue(path+".entrypoint","Specify command when overriding the entrypoint; clearing image defaults is unsupported")}
            var dependencies:[String:String]=[:]
            if let node=values["depends_on"] {
                if node.sequence != nil {for item in try array(node,path+".depends_on"){dependencies[try string(item,path+".depends_on")]="service_started"}}
                else {for (key,node) in try map(node,path+".depends_on") {
                    let opts=try map(node,path+".depends_on."+key);try keys(opts,["condition"],path+".depends_on."+key)
                    let condition=try string(opts["condition"],path+".depends_on."+key+".condition")
                    guard ["service_started","service_healthy"].contains(condition) else{throw issue(path+".depends_on."+key,"Only service_started and service_healthy are supported")};dependencies[key]=condition
                }}
            }
            var health:ComposeHealth?
            if let node=values["healthcheck"] {
                let h=try map(node,path+".healthcheck");try keys(h,["test","interval","timeout","retries","start_period"],path+".healthcheck")
                let test=try tokens(h["test"],path+".healthcheck.test")
                guard test.count>=2,["CMD","CMD-SHELL"].contains(test[0]),test[0] != "CMD-SHELL" || test.count==2 else{throw issue(path+".healthcheck.test","Use [CMD, executable, ...] or [CMD-SHELL, command]")}
                let retries=try h["retries"].map{try string($0,path+".healthcheck.retries")} ?? "5"
                guard let attempts=Int(retries),(1...20).contains(attempts) else{throw issue(path+".healthcheck.retries","Use 1 to 20 retries")}
                health=ComposeHealth(command:test[0]=="CMD" ? Array(test.dropFirst()):["/bin/sh","-c",test[1]],interval:try duration(h["interval"],path+".healthcheck.interval",2),timeout:try duration(h["timeout"],path+".healthcheck.timeout",5),retries:attempts,startPeriod:try duration(h["start_period"],path+".healthcheck.start_period",0))
            }
            let fingerprint=SHA256.hash(data:try JSONSerialization.data(withJSONObject:["args":args+["--",request.image]+command,"build":build ?? [],"dependencies":dependencies,"health":health.map{["command":$0.command,"interval":$0.interval,"timeout":$0.timeout,"retries":$0.retries,"startPeriod":$0.startPeriod] as [String:Any]} ?? [:],"aliases":networkAliases],options:.sortedKeys)).map{String(format:"%02x",$0)}.joined()
            args += ["--label",ComposePlan.configLabel+"="+fingerprint,"--",request.image]+command
            services[service]=ComposeService(name:service,container:request.name,image:request.image,createArguments:args,buildArguments:build,dependencies:dependencies,health:health,fingerprint:fingerprint,hostsFile:hostsFile,networkAliases:networkAliases)
        }
        var claimedAliases:[String:String]=[:]
        for service in services.values {
            for (network,aliases) in service.networkAliases {
                for name in [service.name,service.container]+aliases {
                    let key=network+"/"+name.lowercased()
                    if let other=claimedAliases[key],other != service.name {throw issue("services."+service.name+".networks","Network alias is used by another service")}
                    claimedAliases[key]=service.name
                }
            }
        }
        var order:[ComposeService]=[],active=Set<String>(),done=Set<String>()
        func visit(_ name:String)throws {
            if done.contains(name){return};guard let service=services[name] else{throw issue("depends_on."+name,"Unknown service")}
            guard active.insert(name).inserted else{throw issue("depends_on."+name,"Dependency cycle")}
            for dep in service.dependencies.keys.sorted() {
                if service.dependencies[dep]=="service_healthy",services[dep]?.health==nil{throw issue("services."+name+".depends_on."+dep,"Dependency needs an explicit healthcheck")}
                try visit(dep)
            }
            active.remove(name);done.insert(name);order.append(service)
        }
        for name in services.keys.sorted(){try visit(name)}
        // Check port collisions across services, before creating any resources.
        var ports=Set<String>()
        for service in order {
            for (i,arg) in service.createArguments.enumerated() where arg=="--publish" {
                let value=service.createArguments[i+1],parts=value.components(separatedBy:":")
                let key=parts[1]+"/"+(value.hasSuffix("/udp") ? "udp":"tcp")
                guard ports.insert(key).inserted else{throw issue("services."+service.name+".ports","Host port/protocol is used by another service")}
            }
        }
        return ComposePlan(projectID:projectID,name:name,source:file,services:order,networks:networks.values.sorted{$0.name<$1.name},volumes:volumes.values.sorted{$0.name<$1.name},volumeGiB:capacity)
    }
}
