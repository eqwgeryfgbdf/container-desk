import Foundation

/// A separate ephemeral browsing session. Credentials are never read from the
/// CLI Keychain or persisted here, and no redirects are followed with a secret.
final class RegistryCatalogClient:NSObject,URLSessionTaskDelegate {
    struct Page:Decodable {let repositories:[String]?;let tags:[String]?}
    static func endpoint(server:String,repository:String?,last:String?)throws->URL {
        try RegistryLogin.validateServer(server)
        var url=URLComponents(string:"https://"+server)!
        if let repository {
            guard repository.count<=255,repository.split(separator:"/",omittingEmptySubsequences:false).allSatisfy({$0.range(of:"^[a-z0-9][a-z0-9._-]*$",options:.regularExpression) != nil}) else{throw DeskError.message("catalogInvalidRepository")}
            url.path="/v2/"+repository+"/tags/list"
        } else {url.path="/v2/_catalog"}
        url.queryItems=[URLQueryItem(name:"n",value:"100")]
        if let last {guard !last.isEmpty,last.count<=255,!last.unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else{throw DeskError.message("catalogInvalidRepository")};url.queryItems!.append(URLQueryItem(name:"last",value:last))}
        guard let result=url.url else{throw DeskError.message("invalidRegistry")};return result
    }
    static func imageReference(server:String,repository:String,tag:String)throws->String {
        _=try endpoint(server:server,repository:repository,last:nil)
        guard tag.range(of:"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$",options:.regularExpression) != nil else{throw DeskError.message("invalidImage")}
        // Docker reference grammar treats a bare host as a Hub namespace.
        // Explicit HTTPS port preserves the catalog's origin through deployment.
        let authority = !server.contains(".") && !server.contains(":") && server != "localhost" ? server+":443":server
        let reference=authority+"/"+repository+":"+tag
        guard try DeploymentSource.image(reference)==reference else{throw DeskError.message("invalidRegistry")}
        return reference
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void){completionHandler(nil)}
    func fetch(server:String,repository:String?,last:String?,username:String,password:String)async throws->[String] {
        let url=try Self.endpoint(server:server,repository:repository,last:last)
        let config=URLSessionConfiguration.ephemeral;config.httpCookieStorage=nil;config.urlCredentialStorage=nil;config.timeoutIntervalForResource=30
        let session=URLSession(configuration:config,delegate:self,delegateQueue:nil);defer{session.invalidateAndCancel()}
        let request=try Self.request(url:url,username:username,password:password)
        let (stream,response)=try await session.bytes(for:request)
        guard let http=response as? HTTPURLResponse else{throw DeskError.message("catalogUnavailable")}
        guard http.statusCode==200 else {throw DeskError.message(http.statusCode==401 || http.statusCode==403 ? "catalogAuthentication":"catalogUnavailable")}
        guard response.expectedContentLength<=2_097_152 else{throw DeskError.message("catalogUnavailable")}
        var data=Data()
        for try await byte in stream {try Task.checkCancellation();guard data.count<2_097_152 else{throw DeskError.message("catalogUnavailable")};data.append(byte)}
        return try Self.decode(data,server:server,repository:repository)
    }
    static func request(url:URL,username:String,password:String)throws->URLRequest {
        var request=URLRequest(url:url,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:20)
        request.setValue("application/json",forHTTPHeaderField:"Accept");request.httpShouldHandleCookies=false
        if !username.isEmpty || !password.isEmpty {
            guard !username.isEmpty,!username.contains(":"),username.utf8.count<=256,!password.isEmpty,password.utf8.count<=4096,
                  !(username+password).unicodeScalars.contains(where:CharacterSet.controlCharacters.contains) else{throw DeskError.message("registryCredentialsRequired")}
            request.setValue("Basic "+Data((username+":"+password).utf8).base64EncodedString(),forHTTPHeaderField:"Authorization")
        }
        return request
    }
    static func decode(_ data:Data,server:String,repository:String?)throws->[String] {
        guard data.count<=2_097_152 else{throw DeskError.message("catalogUnavailable")}
        let result=try JSONDecoder().decode(Page.self,from:data)
        let values=repository==nil ? result.repositories:result.tags
        guard let values,values.count<=100,Set(values).count==values.count,values.allSatisfy({ value in
            if repository != nil {return value.range(of:"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$",options:.regularExpression) != nil}
            return (try? Self.endpoint(server:server,repository:value,last:nil)) != nil
        }) else{throw DeskError.message("catalogUnavailable")}
        return values
    }
}
