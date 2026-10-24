import Foundation
import CryptoKit

@main struct HuggingFaceTests {
    static var checks=0
    static func check(_ yes:Bool,_ label:String)throws{guard yes else{throw DeskError.message("FAIL: "+label)};checks+=1;print("PASS: "+label)}
    static func json(_ value:Any)throws->Data{try JSONSerialization.data(withJSONObject:value)}
    static func rejects(_ label:String,_ body:()throws->Void)throws{do{try body()}catch{try check(true,label);return};throw DeskError.message("FAIL: "+label)}
    static let repo="publisher/tiny-GGUF",revision=String(repeating:"a",count:40)
    static func entry(_ name:String="tiny.Q4_K_M.gguf",size:Int64=64,hash:String=String(repeating:"b",count:64))->[String:Any]{["rfilename":name,"size":size,"lfs":["size":size,"sha256":hash]]}
    static func metadata(_ files:[[String:Any]],extra:[String:Any]=[:])->[String:Any]{["id":repo,"sha":revision,"siblings":files,"cardData":["license":"mit"]].merging(extra){_,b in b}}
    static func unit()async throws {
        let search=try HuggingFaceModels.parseSearch(json([
            ["id":repo,"downloads":25,"tags":["license:mit"]],
            ["id":repo], ["id":"../evil"], ["id":"private/model","private":true],
            ["id":"embeddings/model","pipeline_tag":"feature-extraction"],
            ["id":"speech/model","pipeline_tag":"text-to-speech"],
            ["id":"publisher/chat","pipeline_tag":"text-generation"]
        ]))
        try check(search.map(\.id)==[repo,"publisher/chat"],"Search excludes private, non-language, unsafe and duplicate repositories")
        try check(search[0].license=="mit" && search[1].license=="aiHFLicenseUnknown","Licenses come from each repository; unknown stays explicit")
        let valid=try HuggingFaceModels.parseFiles(json(metadata([entry(size:128),entry("quant/tiny.Q2_K.gguf")])),repository:repo)
        try check(valid.choices.count==2 && valid.choices[0].size==64,"Nested single-file GGUFs sorted by download size")
        let choice=valid.choices[0]
        try check(choice.revision==revision && choice.license=="mit" && choice.url.path.contains("/resolve/"+revision+"/quant/"),"Downloads pin the returned commit with the correct license")
        let rejected=try HuggingFaceModels.parseFiles(json(metadata([
            entry("../escape.gguf"),entry("/absolute.gguf"),entry("path/%2e%2e/escape.gguf"),entry("bad\\file.gguf"),
            entry("mmproj-f16.gguf"),entry("adapter-lora.gguf"),entry("tiny-00001-of-00002.gguf"),
            entry("zero.gguf",size:0),entry("huge.gguf",size:Int64.max),entry("hash.gguf",hash:"invalid"),
            ["rfilename":"nohash.gguf","size":64],entry()
        ])),repository:repo)
        try check(rejected.choices.count==1 && rejected.omitted==11,"Split/projector/adapter, traversal, missing hashes and invalid sizes cannot download")
        for gated:Any in [true,"auto","manual"] {
            let result=try HuggingFaceModels.parseFiles(json(metadata([entry()],extra:["gated":gated])),repository:repo)
            try check(result.gated && result.choices.isEmpty,"Gated model requires manual access: \(gated)")
        }
        try rejects("Wrong repository response rejected"){_=try HuggingFaceModels.parseFiles(json(metadata([entry()],extra:["id":"other/model"])),repository:repo)}
        try rejects("Non-text model details rejected"){_=try HuggingFaceModels.parseFiles(json(metadata([entry()],extra:["pipeline_tag":"image-text-to-text"])),repository:repo)}
        let badRevision=try HuggingFaceModels.parseFiles(json(metadata([entry()],extra:["sha":"main"])),repository:repo)
        try check(badRevision.choices.isEmpty,"Mutable revision without commit identity cannot download")
        try rejects("Oversized metadata rejected"){_=try HuggingFaceModels.parseSearch(Data(repeating:32,count:HuggingFaceModels.responseLimit+1))}
        let fm=FileManager.default,dir=fm.temporaryDirectory.appendingPathComponent("cd-hf-test-"+UUID().uuidString)
        try fm.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? fm.removeItem(at:dir)}
        let data=Data("GGUF".utf8)+Data(repeating:0,count:60)
        let hash=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
        let model=AIModelChoice(id:"fixture",repository:repo,revision:revision,filename:"nested/tiny.gguf",size:64,sha256:hash,memoryMiB:1024,license:"mit")
        let target=try model.destination(in:dir)
        try fm.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:target)
        let legacy=dir.appendingPathComponent("tiny.gguf");try Data(repeating:7,count:64).write(to:legacy)
        let cached=try await AIModelDownload(model){_ in}.run(directory:dir)
        try check(cached==target && (try Data(contentsOf:legacy))==Data(repeating:7,count:64),"Content-addressed cache reused; same-named legacy model preserved")
        let other=AIModelChoice(id:"other",repository:"other/repo",revision:revision,filename:"tiny.gguf",size:64,sha256:String(repeating:"c",count:64),memoryMiB:1024)
        try check(try other.destination(in:dir) != target,"Different model content cannot collide on the same filename")
        try data.write(to:legacy)
        try check(try await AIModelDownload(model){_ in}.run(directory:dir)==legacy,"Valid old model cache reused without another download")
        do{try await AIModelDownload.verify(target,model:other);throw DeskError.message("unexpected success")}
        catch{try check(error.localizedDescription=="aiModelChecksum","Checksum mismatch rejected before model selection")}
    }
    static func live(download:Bool,inference:Bool)async throws {
        let client=HuggingFaceModels(),rows=try await client.search("SmolLM2-135M-Instruct")
        let repository="bartowski/SmolLM2-135M-Instruct-GGUF"
        try check(rows.contains{$0.id==repository},"Live public Hugging Face search finds a lightweight instruct model")
        let files=try await client.files(repository)
        guard let choice=files.choices.first(where:{$0.filename.contains("Q4_K_M") && $0.size<128*1024*1024}) else{throw DeskError.message("No Q4 model below 128 MiB; download refused")}
        print("MODEL: \(choice.repository) / \(choice.filename) | \(choice.size) bytes | \(choice.revision)")
        try choice.validateMetadata();try check(!files.gated,"Live metadata has pinned revision, single GGUF, size and SHA-256")
        guard download else{return}
        let fm=FileManager.default,dir=fm.temporaryDirectory.appendingPathComponent("cd-hf-live-"+UUID().uuidString)
        defer{try? fm.removeItem(at:dir)}
        let file=try await AIModelDownload(choice){_ in}.run(directory:dir)
        try check(fm.fileExists(atPath:file.path),"Live model download passes GGUF header, exact size and SHA-256 verification")
        guard inference else{return}
        let cli=ProcessInfo.processInfo.environment["AI_CONTAINER"] ?? "/Users/server/.local/bin/container"
        let original=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
        let imageList=try ResourceItem.parseImages((try await ProcessRunner.checked(cli,["image","list","--format","json"])).data)
        let hadImage=imageList.contains(where:{$0.id==AIDeployment.image})
        if !hadImage {
            guard CommandLine.arguments.contains("--allow-image-pull") else{throw DeskError.message("llama.cpp server image absent; use --allow-image-pull to download the pinned server image")}
            _=try await ProcessRunner.checked(cli,["image","pull","--arch","arm64",AIDeployment.image],timeout:600)
        }
        let name="cd-hf-test-"+String(UUID().uuidString.prefix(8)).lowercased()
        let plan=AIDeployment(name:name,port:19893,modelPath:file.path)
        var error:Error?,attempted=false
        do {
            attempted=true
            _=try await ProcessRunner.checked(cli,try plan.request(cpus:2,memory:1024,context:1024).arguments(),timeout:120)
            _=try await ProcessRunner.checked(cli,["start","--",name],timeout:120)
            let llama=LlamaClient(endpoint:plan.endpoint),deadline=Date().addingTimeInterval(120)
            var ready=false
            while Date()<deadline{if (try? await llama.health()) != nil{ready=true;break};try await Task.sleep(for:.seconds(2))}
            try check(ready,"Searched model starts on pinned llama.cpp with 2 CPUs / 1 GiB")
            let answer=try await llama.chat([["role":"user","content":"Say hello in one short sentence."]])
            try check(!answer.text.isEmpty,"Searched model completes real local inference")
            // Capability is measured, not presumed from GGUF or the repository name.
            do{print("TOOL CAPABILITY: \(try await llama.probe() ? "passed":"unsupported")")}
            catch{print("TOOL CAPABILITY: unsupported/unconfirmed (\(error.localizedDescription))")}
        }catch let failure{error=failure}
        if attempted{_=try? await ProcessRunner.checked(cli,["stop","--",name],timeout:60);_=try? await ProcessRunner.checked(cli,["delete","--",name],timeout:60)}
        let after=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
        try check(!after.contains{$0.id==name} && original.allSatisfy{before in after.contains{$0.id==before.id && $0.running==before.running}},"Temporary inference container removed; pre-existing containers and states preserved")
        if !hadImage,!after.contains(where:{$0.image==AIDeployment.image}) {
            _=try await ProcessRunner.checked(cli,["image","delete","--",AIDeployment.image],timeout:60)
            try check(true,"Server image downloaded for the test removed")
        }
        if let error{throw error}
    }
    static func main()async {
        setbuf(stdout,nil)
        do{try await unit();if CommandLine.arguments.contains("--live"){try await live(download:CommandLine.arguments.contains("--download"),inference:CommandLine.arguments.contains("--inference"))};print("PASS: \(checks) Hugging Face checks")}
        catch{print(error.localizedDescription);exit(1)}
    }
}
