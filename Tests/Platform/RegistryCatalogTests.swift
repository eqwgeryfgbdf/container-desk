import Foundation

extension PlatformTests {
    func testRegistryCatalog()throws {
        for (host,authority) in [("registry","registry:443"),("Registry","Registry:443"),("LOCALHOST","LOCALHOST:443"),("localhost","localhost"),("registry.example.com","registry.example.com"),("registry:5443","registry:5443"),("[::1]","[::1]")] {
            let reference=try RegistryCatalogClient.imageReference(server:host,repository:"team/app",tag:"v1")
            try XCTAssertEqual(reference,authority+"/team/app:v1")
            try XCTAssertEqual(try DeploymentSource.image(reference),reference)
        }
        try XCTAssertEqual(try DeploymentSource.image("registry/app:v1"),"docker.io/registry/app:v1")
        try XCTAssertThrowsError(try RegistryCatalogClient.imageReference(server:"registry",repository:"../app",tag:"v1"))
        try XCTAssertThrowsError(try RegistryCatalogClient.imageReference(server:"registry",repository:"app",tag:"bad/tag"))
        let url=try RegistryCatalogClient.endpoint(server:"registry.example.com:5443",repository:"team/app",last:"v1+two")
        let parts=URLComponents(url:url,resolvingAgainstBaseURL:false)!
        try XCTAssertEqual(parts.scheme,"https");try XCTAssertEqual(parts.path,"/v2/team/app/tags/list")
        try XCTAssertEqual(parts.queryItems?.last?.value,"v1+two")
        for path in ["../x","team//app","/app","app?token=x","app#x","UPPER"] {
            try XCTAssertThrowsError(try RegistryCatalogClient.endpoint(server:"example.com",repository:path,last:nil))
        }
        try XCTAssertThrowsError(try RegistryCatalogClient.endpoint(server:"user:pass@example.com",repository:nil,last:nil))
        let request=try RegistryCatalogClient.request(url:url,username:"qa",password:"generated-test-value")
        try XCTAssertEqual(request.value(forHTTPHeaderField:"Authorization"),"Basic "+Data("qa:generated-test-value".utf8).base64EncodedString())
        try XCTAssertThrowsError(try RegistryCatalogClient.request(url:url,username:"qa:other",password:"x"))
        try XCTAssertThrowsError(try RegistryCatalogClient.request(url:url,username:"qa",password:"x\r\nHeader: value"))
        let anonymous=try RegistryCatalogClient.request(url:url,username:"",password:"")
        try XCTAssertTrue(anonymous.value(forHTTPHeaderField:"Authorization")==nil)
        let decoded=try RegistryCatalogClient.decode(Data(#"{"repositories":["team/app","other"]}"#.utf8),server:"example.com",repository:nil)
        try XCTAssertEqual(decoded,["team/app","other"])
        try XCTAssertEqual(try RegistryCatalogClient.decode(Data(#"{"tags":["latest","v1.2"]}"#.utf8),server:"example.com",repository:"app"),["latest","v1.2"])
        for json in [#"{"tags":["bad/tag"]}"#,#"{"tags":["same","same"]}"#,#"{"repositories":["../bad"]}"#] {
            try XCTAssertThrowsError(try RegistryCatalogClient.decode(Data(json.utf8),server:"example.com",repository:json.contains("tags") ? "app":nil))
        }
        try XCTAssertThrowsError(try RegistryCatalogClient.decode(Data(repeating:32,count:2_097_153),server:"example.com",repository:nil))
        let client=RegistryCatalogClient(),session=URLSession(configuration:.ephemeral)
        defer{session.invalidateAndCancel()}
        var redirected=true
        client.urlSession(session,task:session.dataTask(with:url),willPerformHTTPRedirection:HTTPURLResponse(url:url,statusCode:302,httpVersion:nil,headerFields:["Location":"https://other.example"])!,newRequest:URLRequest(url:URL(string:"https://other.example")!)){redirected = $0 != nil}
        try XCTAssertFalse(redirected,"Credential-bearing redirects must be refused")
    }
}
