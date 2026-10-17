import Foundation

private final class HubStubProtocol:URLProtocol {
    static var response:(Int,Data)=(200,Data())
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func startLoading() {
        let (status,data)=Self.response
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading(){}
}
extension PlatformTests {
    func testHubSearch()async throws {
        let url=try HubSearchClient.searchURL("nginx & redis",page:2)
        let components=try XCTUnwrap(URLComponents(url:url,resolvingAgainstBaseURL:false))
        try XCTAssertEqual(components.host,"hub.docker.com")
        try XCTAssertEqual(components.queryItems?.first{$0.name=="query"}?.value,"nginx & redis")
        try XCTAssertEqual(components.queryItems?.first{$0.name=="page"}?.value,"2")
        for query in ["  ",String(repeating:"x",count:201),"bad\nterm"]{try XCTAssertThrowsError(try HubSearchClient.searchURL(query))}
        let official=HubRepository(repo_name:"nginx",short_description:nil,star_count:nil,pull_count:nil,is_official:true)
        try XCTAssertEqual(try HubSearchClient.tagsURL(official).path,"/v2/namespaces/library/repositories/nginx/tags")
        try XCTAssertEqual(try DeploymentSource.image(official.reference,tag:"stable"),"docker.io/library/nginx:stable")
        for name in ["../nginx","evil/a/b","https://evil.test/a","a/%2e"] {
            let repo=HubRepository(repo_name:name,short_description:nil,star_count:nil,pull_count:nil,is_official:false)
            try XCTAssertThrowsError(try HubSearchClient.tagsURL(repo))
        }
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[HubStubProtocol.self]
        let session=URLSession(configuration:config);defer{session.invalidateAndCancel()}
        let client=HubSearchClient(session:session)
        HubStubProtocol.response=(200,Data(#"{"next":"https://untrusted.test/next","results":[{"repo_name":"nginx","pull_count":13473685989,"is_official":true}]}"#.utf8))
        let page=try await client.search("nginx")
        try XCTAssertEqual(page.results.first?.pull_count,13473685989)
        try XCTAssertTrue(page.hasNext)
        // Missing variant metadata must not be presented as ARM64 compatibility.
        HubStubProtocol.response=(200,Data(#"{"results":[{"name":"arm","images":[{"os":"linux","architecture":"arm64"}]},{"name":"intel","images":[{"os":"linux","architecture":"amd64"}]},{"name":"unknown"}],"next":null}"#.utf8))
        let tags=try await client.tags(official)
        try XCTAssertEqual(tags.results.map(\.supportsARM),[true,false,false]);try XCTAssertFalse(tags.hasNext)
        HubStubProtocol.response=(200,Data(#"{"results":[],"next":""}"#.utf8))
        let empty=try await client.search("missing");try XCTAssertTrue(empty.results.isEmpty)
        for (status,data,key) in [(429,Data(),"hubSearchRateLimit"),(503,Data(),"hubSearchUnavailable"),(200,Data("not-json".utf8),"hubSearchResponse"),(200,Data(repeating:32,count:2_097_153),"hubSearchResponse")] {
            HubStubProtocol.response=(status,data)
            var failure:String?
            do{_=try await client.search("nginx")}catch{failure=error.localizedDescription}
            try XCTAssertEqual(failure,key)
        }
        HubStubProtocol.response=(200,Data(#"{"results":[],"next":null}"#.utf8))
        let cancelled=Task{try await client.search("nginx")};cancelled.cancel()
        do{_=try await cancelled.value;throw DeskError.message("Cancelled search unexpectedly succeeded")}
        catch is CancellationError{}catch let error as URLError where error.code == .cancelled{}
    }
    func testHubSearchLive()async throws {
        let client=HubSearchClient()
        let page=try await client.search("nginx")
        let nginx=try XCTUnwrap(page.results.first{$0.repo_name=="nginx" && $0.is_official==true})
        try XCTAssertTrue(page.hasNext)
        let second=try await client.search("nginx",page:2)
        try XCTAssertFalse(second.results.isEmpty)
        let tags=try await client.tags(nginx)
        let compatible=try XCTUnwrap(tags.results.first{$0.supportsARM})
        try XCTAssertTrue(try DeploymentSource.image(nginx.reference,tag:compatible.name).hasPrefix("docker.io/library/nginx:"))
        let nextTags=try await client.tags(nginx,page:2);try XCTAssertFalse(nextTags.results.isEmpty)
        print("PASS: live Docker Hub keyword search, official image, repository/tag pagination and Linux ARM64 tag selection")
    }
    @MainActor func testHubSearchDownload()async throws {
        let store=Store();await store.start()
        let cli=try XCTUnwrap(store.cli);try XCTAssertTrue(store.canMutate)
        let baseline=Dictionary(uniqueKeysWithValues:store.containers.map{($0.id,$0.state)})
        let originalImages=Set(store.images.map(\.id))
        let page=try await HubSearchClient().search("busybox")
        let repository=try XCTUnwrap(page.results.first{$0.repo_name=="busybox" && $0.is_official==true})
        let tags=try await HubSearchClient().tags(repository)
        let tag=try XCTUnwrap(tags.results.first{$0.supportsARM})
        let image=try DeploymentSource.image(repository.reference,tag:tag.name)
        store.prepareDeployment(image)
        let deadline=Date().addingTimeInterval(120)
        while store.operationRunning {
            if Date()>deadline{store.cancelOperation();throw DeskError.message("Hub download timeout")}
            try await Task.sleep(for:.milliseconds(100))
        }
        let outcome=store.operationResult
        // Remove only this test's newly downloaded reference; never prune shared images.
        if !originalImages.contains(image) {
            let inspected=try await ProcessRunner.run(cli,["image","inspect","--",image])
            if inspected.code==0{_=try await ProcessRunner.checked(cli,["image","delete","--",image])}
        }
        try XCTAssertEqual(outcome,"operationComplete")
        while store.refreshing{try await Task.sleep(for:.milliseconds(100))}
        await store.refresh();await store.refreshImages()
        try XCTAssertEqual(Dictionary(uniqueKeysWithValues:store.containers.map{($0.id,$0.state)}),baseline)
        try XCTAssertEqual(Set(store.images.map(\.id)),originalImages)
        print("PASS: search → ARM64 tag → actual image download/verification, test image cleanup and original container states preserved")
    }
}
