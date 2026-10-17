import Foundation
import Yams
import Darwin

struct DockerMigrationNotice:Identifiable {
    let id=UUID()
    let path:String
    let message:String
    let blocking:Bool
}
struct DockerMigrationResult {
    let source:URL
    let original:Data
    let yaml:String
    let notices:[DockerMigrationNotice]
    let services:Int
    var resolution:DockerComposeResolution?=nil
    var canImport:Bool{!notices.contains(where:{$0.blocking})}

    /// Write only beside the original so .env, env_file, build and bind paths
    /// retain their meaning. Exclusive creation never replaces an existing file.
    func save()throws->URL {
        guard resolution==nil else{throw DeskError.message("dockerSourceChanged")}
        return try write()
    }
    @MainActor func saveVerified()async throws->URL {
        if let resolution{try await resolution.verify()}
        return try write()
    }
    private func write()throws->URL {
        guard canImport else{throw DeskError.message("dockerConversionBlocked")}
        guard try Data(contentsOf:source)==original else{throw DeskError.message("dockerSourceChanged")}
        let destination=source.deletingLastPathComponent().appendingPathComponent("compose.container-desk-"+UUID().uuidString.lowercased().prefix(8)+".yaml")
        let data=Data(yaml.utf8)
        _=try ComposePlanner(file:destination,projectID:UUID().uuidString,sourceData:data).plan()
        let fd=open(destination.path,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0o600)
        guard fd>=0 else{throw DeskError.message("dockerSaveFailed")}
        let handle=FileHandle(fileDescriptor:fd,closeOnDealloc:true)
        do{try handle.write(contentsOf:data);try handle.synchronize();try handle.close()}
        catch{try? handle.close();try? FileManager.default.removeItem(at:destination);throw error}
        return destination
    }
}

enum DockerProjectConverter {
    static let composeNames=["compose.yaml","compose.yml","docker-compose.yaml","docker-compose.yml"]
    static let overrides=["compose.override.yaml","compose.override.yml","docker-compose.override.yaml","docker-compose.override.yml"]
    static func source(in selection:URL)throws->URL {
        let url=selection.standardizedFileURL
        guard url.isFileURL else{throw DeskError.message("dockerChooseSource")}
        var directory:ObjCBool=false
        guard FileManager.default.fileExists(atPath:url.path,isDirectory:&directory) else{throw DeskError.message("dockerChooseSource")}
        if !directory.boolValue{return url}
        let matches=composeNames.map{url.appendingPathComponent($0)}.filter{FileManager.default.fileExists(atPath:$0.path)}
        guard matches.count<=1 else{throw DeskError.message("dockerAmbiguousSource")}
        if let match=matches.first{return match}
        let dockerfile=url.appendingPathComponent("Dockerfile")
        guard FileManager.default.fileExists(atPath:dockerfile.path) else{throw DeskError.message("dockerChooseSource")}
        return dockerfile
    }
    private static func string(_ value:String)->Node{Node(value,Tag(.str),.doubleQuoted)}
    private static func remove(_ key:String,from node:inout Node) {
        // Node's setter ignores nil; Mapping's setter actually removes a key.
        guard var mapping=node.mapping else{return}
        mapping[key]=nil;node = .mapping(mapping)
    }
    static func analyze(_ selection:URL,allowManualRestart:Bool=false,resolution:DockerComposeResolution?=nil)throws->DockerMigrationResult {
        let source=try source(in:selection)
        let original=try Data(contentsOf:source,options:.mappedIfSafe)
        guard original.count<=512*1024,let content=String(data:original,encoding:.utf8) else{throw DeskError.message("dockerSourceSize")}
        var notices:[DockerMigrationNotice]=[]
        func note(_ path:String,_ message:String,_ blocking:Bool=false){notices.append(DockerMigrationNotice(path:path,message:message,blocking:blocking))}
        var document:Node
        let dockerfile=source.lastPathComponent=="Dockerfile" || source.lastPathComponent.hasPrefix("Dockerfile.")
        if dockerfile {
            let build=Node([(string("context"),string(".")),(string("dockerfile"),string(source.lastPathComponent))])
            document=Node([(string("services"),Node([(string("app"),Node([(string("build"),build)]))]))])
            note("Dockerfile","dockerBuildWrapper")
            if content.range(of:#"(?im)^\s*FROM\s+--platform\s*=\s*linux/(amd64|386)"#,options:.regularExpression) != nil {
                note("Dockerfile.FROM","dockerArchitectureBlocked",true)
            }
        } else {
            document=try ComposePlanner.parseDocument(resolution?.data ?? original)
            for name in overrides where resolution==nil && composeNames.contains(source.lastPathComponent) && FileManager.default.fileExists(atPath:source.deletingLastPathComponent().appendingPathComponent(name).path) && source.lastPathComponent != name {
                note(name,"dockerOverridesBlocked",true)
            }
            if document["version"] != nil {remove("version",from:&document);note("version","dockerVersionRemoved")}
        }
        if resolution != nil {
            document["x-container-desk-resolved"]=Node("true",Tag(.bool))
            // Compose has already applied these extension templates.
            for pair in document.mapping ?? [:] {
                if let key=pair.key.string,key.hasPrefix("x-"),key != "x-container-desk-resolved"{remove(key,from:&document)}
            }
            note("project","dockerComposeResolved")
        }
        // Scan all unsupported property names so users get a useful report,
        // while the normal planner remains the final validator of values.
        let rootKeys:Set<String>=["name","services","volumes","networks","x-container-desk-resolved"]
        for pair in document.mapping ?? [:] {
            if let key=pair.key.string,!rootKeys.contains(key){note(key,"dockerUnsupported",true)}
        }
        var services=document["services"]
        let serviceKeys:Set<String>=["image","build","command","entrypoint","environment","env_file","ports","volumes","networks","depends_on","healthcheck","cpus","mem_limit","working_dir","user","read_only","platform","restart","container_name","expose","init","labels"]
        for pair in services?.mapping ?? [:] {
            guard let name=pair.key.string else{continue}
            let path="services."+name
            var service=pair.value
            for field in service.mapping ?? [:] {
                if let key=field.key.string,!serviceKeys.contains(key){note(path+"."+key,"dockerUnsupported",true)}
            }
            if service["container_name"] != nil {remove("container_name",from:&service);note(path+".container_name","dockerNamesChanged")}
            if let restart=service["restart"],restart.scalar?.string != "no" {
                let value=restart.scalar?.string ?? ""
                let supported=["always","unless-stopped","on-failure"].contains(value) || value.range(of:#"^on-failure:[1-9][0-9]*$"#,options:.regularExpression) != nil
                if allowManualRestart && supported {service["restart"]=string("no");note(path+".restart","dockerRestartManual")}
                else{note(path+".restart","dockerRestartBlocked",true)}
            }
            if let platform=service["platform"]?.scalar?.string,platform != "linux/arm64" {note(path+".platform","dockerArchitectureBlocked",true)}
            if var build=service["build"],build.mapping != nil,build["context"]==nil {build["context"]=string(".");service["build"]=build;note(path+".build.context","dockerBuildContext")}
            if let expose=service["expose"] {
                let valid=expose.sequence?.allSatisfy { node in
                    guard let value=node.scalar?.string else{return false}
                    guard value.range(of:#"^[0-9]+(?:-[0-9]+)?(?:/(?:tcp|udp))?$"#,options:.regularExpression) != nil else{return false}
                    let bounds=value.split(separator:"/")[0].split(separator:"-").compactMap{Int($0)}
                    return bounds.allSatisfy{(1...65535).contains($0)} && (bounds.count==1 || bounds.count==2 && bounds[0]<=bounds[1])
                } ?? false
                if valid {remove("expose",from:&service);note(path+".expose","dockerExposeRemoved")}
            }
            if let networks=service["networks"]?.mapping,networks.allSatisfy({$0.value.null != nil || $0.value.mapping?.isEmpty==true}) {
                service["networks"]=Node(networks.map{$0.key});note(path+".networks","dockerNetworkList")
            }
            if let env=service["env_file"]?.sequence {
                service["env_file"]=Node(env.map {node in
                    guard let map=node.mapping,map.allSatisfy({["path","required"].contains($0.key.string ?? "")}),node["required"]==nil || node["required"]?.bool==true,let pathNode=node["path"],pathNode.scalar != nil else{return node}
                    note(path+".env_file","dockerEnvFileShort");return pathNode
                })
            }
            if resolution != nil {
                for key in ["command","entrypoint"] where service[key]?.null != nil{remove(key,from:&service)}
                if var dependencies=service["depends_on"] {
                    for item in dependencies.mapping ?? [:] {
                        guard let key=item.key.string else{continue};var options=item.value
                        if options["required"]?.bool==true{remove("required",from:&options)}
                        if options["restart"]?.bool==false{remove("restart",from:&options)}
                        dependencies[key]=options
                    }
                    service["depends_on"]=dependencies
                }
                if let mounts=service["volumes"]?.sequence {
                    service["volumes"]=Node(mounts.map {item in
                        var item=item
                        if item["volume"]?.mapping?.isEmpty==true{remove("volume",from:&item)}
                        if let bind=item["bind"],bind.mapping?.count==1,bind["create_host_path"]?.bool==true,
                           let source=item["source"]?.scalar?.string,FileManager.default.fileExists(atPath:source) {
                            remove("bind",from:&item)
                        }
                        return item
                    })
                }
            }
            if let ports=service["ports"]?.sequence {
                if !ports.isEmpty {note(path+".ports","dockerLoopback")}
                service["ports"]=Node(ports.enumerated().map {index,node in
                    let portPath=path+".ports[\(index)]"
                    var node=node
                    if resolution != nil,node["mode"]?.scalar?.string=="ingress"{remove("mode",from:&node)}
                    var text=node.scalar?.string
                    if let fields=node.mapping {
                        let allowed:Set<String>=["target","published","protocol","host_ip"]
                        if fields.allSatisfy({allowed.contains($0.key.string ?? "") && $0.value.scalar != nil}),let target=node["target"]?.scalar?.string,let published=node["published"]?.scalar?.string {
                            let host=node["host_ip"]?.scalar?.string ?? "0.0.0.0"
                            let transport=node["protocol"]?.scalar?.string ?? "tcp"
                            text=host+":"+published+":"+target+"/"+transport
                            note(portPath,"dockerPortsShort")
                        }
                    }
                    guard let text else{return node}
                    // Interpolated mappings need the normal validator; never
                    // guess a missing host port or silently discard a binding.
                    let parts=text.components(separatedBy:":")
                    if parts.count==2 {return string("127.0.0.1:"+text)}
                    if parts.count==3 && ["0.0.0.0",""].contains(parts[0]) {return string("127.0.0.1:"+parts.dropFirst().joined(separator:":"))}
                    return node.mapping != nil ? string(text):node
                })
            }
            for mount in service["volumes"]?.sequence ?? [] {
                if mount.scalar?.string.contains("docker.sock")==true || mount["source"]?.scalar?.string.contains("docker.sock")==true || mount["target"]?.scalar?.string.contains("docker.sock")==true {
                    note(path+".volumes","dockerSocketBlocked",true)
                }
            }
            services?[name]=service
        }
        document["services"]=services
        for kind in ["networks","volumes"] {
            guard var resources=document[kind],let definitions=resources.mapping else{continue}
            for pair in definitions {
                guard let name=pair.key.string else{continue};var options=pair.value
                if resolution != nil,options["external"]?.bool != true,options["name"] != nil {
                    remove("name",from:&options);note(kind+"."+name,"dockerResourceNames")
                }
                if resolution != nil,kind=="networks",options["ipam"]?.mapping?.isEmpty==true{remove("ipam",from:&options)}
                let expected=kind=="networks" ? "bridge":"local"
                if options["driver"]?.scalar?.string==expected,options["driver_opts"]==nil,options["external"]?.bool != true {
                    remove("driver",from:&options);note(kind+"."+name+".driver","dockerDefaultDriver")
                }
                resources[name]=options
            }
            document[kind]=resources
            if kind=="volumes",!definitions.isEmpty{note("volumes","dockerVolumeData")}
        }
        let yaml=try Yams.serialize(node:document)
        do {_=try ComposePlanner(file:source,projectID:UUID().uuidString,sourceData:Data(yaml.utf8)).plan()}
        catch let issue as ComposeIssue {note(issue.path,issue.reason,true)}
        catch {note("document",error.localizedDescription,true)}
        if (services?.mapping?.contains(where:{$0.value["image"] != nil}) ?? false){note("images","dockerImageStore")}
        note("project",resolution==nil ? "dockerRuntimeCheck":"dockerResolvedRuntimeCheck")
        return DockerMigrationResult(source:source,original:original,yaml:yaml,notices:notices,services:services?.mapping?.count ?? 0,resolution:resolution)
    }
}
