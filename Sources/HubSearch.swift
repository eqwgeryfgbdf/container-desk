import Foundation

struct HubRepository:Decodable,Identifiable {
    let repo_name:String
    let short_description:String?
    let star_count:Int?
    let pull_count:Int64?
    let is_official:Bool?
    var id:String{repo_name}
    var reference:String {"docker.io/"+(repo_name.contains("/") ? repo_name : "library/"+repo_name)}
}
struct HubTag:Decodable,Identifiable {
    struct Variant:Decodable {let architecture:String?;let os:String?;let variant:String?}
    let name:String
    let images:[Variant]?
    var id:String{name}
    var supportsARM:Bool{images?.contains{$0.architecture=="arm64" && $0.os=="linux"} == true}
    var platforms:[String] {
        Array(Set((images ?? []).compactMap { item -> String? in
            guard let os=item.os,let arch=item.architecture,os != "unknown",arch != "unknown" else{return nil}
            return os+"/"+arch+(item.variant.flatMap{$0.isEmpty ? nil:"/"+$0} ?? "")
        })).sorted()
    }
    var deployableArchitectures:[String] {
        ["arm64","amd64"].filter { arch in images?.contains{$0.os=="linux" && $0.architecture==arch} == true }
    }
}
struct HubPage<Item:Decodable>:Decodable {
    let results:[Item]
    let next:String?
    var hasNext:Bool{next?.isEmpty==false}
}

/// Public discovery only. No registry credentials are sent, and server-supplied
/// pagination URLs are never followed. Downloads still use the Apple CLI.
struct HubSearchClient {
    private static let publicSession:URLSession = {
        let configuration=URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage=nil;configuration.urlCredentialStorage=nil
        configuration.timeoutIntervalForResource=30
        return URLSession(configuration:configuration)
    }()
    let session:URLSession
    init(session:URLSession? = nil){self.session=session ?? Self.publicSession}
    static func searchURL(_ query:String,page:Int=1)throws->URL {
        let term=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !term.isEmpty,term.count<=200,!term.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains),page>0 else{throw DeskError.message("hubSearchInvalid")}
        return url(path:"/v2/search/repositories/",items:[URLQueryItem(name:"query",value:term)],page:page)
    }
    static func tagsURL(_ repository:HubRepository,page:Int=1)throws->URL {
        let name=repository.repo_name.contains("/") ? repository.repo_name : "library/"+repository.repo_name
        let parts=name.split(separator:"/",omittingEmptySubsequences:false)
        guard parts.count==2,parts.allSatisfy({$0.range(of:"^[a-z0-9][a-z0-9_.-]*$",options:.regularExpression) != nil}),page>0 else{throw DeskError.message("hubSearchResponse")}
        return url(path:"/v2/namespaces/"+name.replacingOccurrences(of:"/",with:"/repositories/")+"/tags",items:[],page:page)
    }
    private static func url(path:String,items:[URLQueryItem],page:Int)->URL {
        var c=URLComponents();c.scheme="https";c.host="hub.docker.com";c.path=path
        c.queryItems=items+[URLQueryItem(name:"page_size",value:"25"),URLQueryItem(name:"page",value:String(page))]
        return c.url!
    }
    func search(_ query:String,page:Int=1)async throws->HubPage<HubRepository>{try await fetch(Self.searchURL(query,page:page))}
    func tags(_ repository:HubRepository,page:Int=1)async throws->HubPage<HubTag>{try await fetch(Self.tagsURL(repository,page:page))}
    private func fetch<T:Decodable>(_ url:URL)async throws->T {
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:20)
        request.setValue("application/json",forHTTPHeaderField:"Accept")
        request.httpShouldHandleCookies=false
        let (bytes,response)=try await session.bytes(for:request)
        guard let http=response as? HTTPURLResponse else{throw DeskError.message("hubSearchResponse")}
        if http.statusCode==429{throw DeskError.message("hubSearchRateLimit")}
        guard http.statusCode==200 else{throw DeskError.message("hubSearchUnavailable")}
        guard response.expectedContentLength<=2_097_152 else{throw DeskError.message("hubSearchResponse")}
        var data=Data()
        for try await byte in bytes {
            if data.count>=2_097_152{throw DeskError.message("hubSearchResponse")}
            data.append(byte)
        }
        try Task.checkCancellation()
        do{return try JSONDecoder().decode(T.self,from:data)}catch{throw DeskError.message("hubSearchResponse")}
    }
}
