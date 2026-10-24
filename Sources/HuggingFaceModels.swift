import Foundation

struct HFRepository:Identifiable,Equatable {
    let id:String
    let downloads:Int
    let license:String
    var modelCard:URL{URL(string:"https://huggingface.co")!.appendingPathComponent(id)}
}

struct HFModelFiles {
    let choices:[AIModelChoice]
    let omitted:Int
    let gated:Bool
}

/// Only public metadata is queried. Repository content is never executed.
final class HuggingFaceModels:NSObject,URLSessionTaskDelegate {
    static let responseLimit=8*1024*1024
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}

    func request(path:String,query:[URLQueryItem]=[])async throws->Data {
        var url=URLComponents();url.scheme="https";url.host="huggingface.co";url.path=path;url.queryItems=query.isEmpty ? nil:query
        guard let endpoint=url.url else{throw DeskError.message("aiHFInvalidMetadata")}
        let cfg=URLSessionConfiguration.ephemeral
        cfg.httpCookieStorage=nil;cfg.urlCredentialStorage=nil;cfg.timeoutIntervalForRequest=25;cfg.timeoutIntervalForResource=45
        let session=URLSession(configuration:cfg,delegate:self,delegateQueue:nil);defer{session.invalidateAndCancel()}
        let (stream,response)=try await session.bytes(from:endpoint)
        guard let http=response as? HTTPURLResponse else{throw DeskError.message("aiHFUnavailable")}
        if http.statusCode==429{throw DeskError.message("aiHFRateLimit")}
        if [401,403].contains(http.statusCode){throw DeskError.message("aiHFGated")}
        guard http.statusCode==200 else{throw DeskError.message("aiHFUnavailable")}
        guard response.expectedContentLength<=Self.responseLimit else{throw DeskError.message("responseTooLarge")}
        var data=Data()
        for try await byte in stream {
            try Task.checkCancellation()
            guard data.count<Self.responseLimit else{throw DeskError.message("responseTooLarge")}
            data.append(byte)
        }
        return data
    }
    func search(_ query:String)async throws->[HFRepository] {
        let text=String(query.trimmingCharacters(in:.whitespacesAndNewlines).prefix(200))
        return try Self.parseSearch(await request(path:"/api/models",query:[
            URLQueryItem(name:"filter",value:"gguf"),URLQueryItem(name:"search",value:text),
            URLQueryItem(name:"sort",value:"downloads"),URLQueryItem(name:"direction",value:"-1"),URLQueryItem(name:"limit",value:"40")]))
    }
    func files(_ repository:String)async throws->HFModelFiles {
        guard AIModelChoice.safePath(repository),repository.split(separator:"/").count==2 else{throw DeskError.message("aiHFInvalidMetadata")}
        return try Self.parseFiles(await request(path:"/api/models/\(repository)/revision/main",query:[URLQueryItem(name:"blobs",value:"true")]),repository:repository)
    }
    static func textModel(_ row:[String:Any])->Bool {
        guard let pipeline=row["pipeline_tag"] as? String,!pipeline.isEmpty else{return true}
        return ["text-generation","conversational"].contains(pipeline)
    }
    static func parseSearch(_ data:Data)throws->[HFRepository] {
        guard data.count<=responseLimit,let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]] else{throw DeskError.message("aiHFInvalidMetadata")}
        var seen=Set<String>()
        return rows.prefix(100).compactMap {row in
            guard let id=row["id"] as? String,AIModelChoice.safePath(id),id.split(separator:"/").count==2,
                  row["private"] as? Bool != true,textModel(row),seen.insert(id).inserted else{return nil}
            let license=(row["tags"] as? [String])?.first{$0.hasPrefix("license:")}.map{String($0.dropFirst(8))} ?? "aiHFLicenseUnknown"
            return HFRepository(id:id,downloads:max(0,row["downloads"] as? Int ?? 0),license:license)
        }
    }
    static func parseFiles(_ data:Data,repository:String)throws->HFModelFiles {
        guard data.count<=responseLimit,let row=try JSONSerialization.jsonObject(with:data) as? [String:Any],
              row["id"] as? String==repository,let revision=row["sha"] as? String,textModel(row) else{throw DeskError.message("aiHFInvalidMetadata")}
        let gated=(row["gated"] as? Bool==true) || (row["gated"] as? String).map{!["false",""] .contains($0)}==true || row["private"] as? Bool==true
        if gated{return HFModelFiles(choices:[],omitted:0,gated:true)}
        guard let siblings=row["siblings"] as? [[String:Any]],siblings.count<=20000 else{throw DeskError.message("aiHFInvalidMetadata")}
        let license=(row["cardData"] as? [String:Any])?["license"] as? String ?? "aiHFLicenseUnknown"
        var choices=[AIModelChoice](),omitted=0,seen=Set<String>()
        for file in siblings {
            guard let filename=file["rfilename"] as? String,filename.lowercased().hasSuffix(".gguf") else{continue}
            let lower=filename.lowercased()
            guard !lower.contains("mmproj"),!lower.contains("lora"),!lower.contains("-of-"),
                  let lfs=file["lfs"] as? [String:Any],let size=lfs["size"] as? Int64,let digest=lfs["sha256"] as? String,
                  size==file["size"] as? Int64,seen.insert(filename).inserted else{omitted+=1;continue}
            let estimate=Int((Double(size)/1048576*1.3+1024).rounded(.up))
            let choice=AIModelChoice(id:repository+" · "+filename,repository:repository,revision:revision,filename:filename,size:size,sha256:digest,memoryMiB:max(1024,estimate),license:license)
            guard (try? choice.validateMetadata()) != nil else{omitted+=1;continue}
            choices.append(choice)
        }
        return HFModelFiles(choices:choices.sorted{$0.size==$1.size ? $0.filename<$1.filename:$0.size<$1.size},omitted:omitted,gated:false)
    }
}
