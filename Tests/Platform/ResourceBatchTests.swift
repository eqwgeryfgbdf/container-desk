import Foundation

extension PlatformTests {
    @MainActor func testResourceBatchLive()async throws {
        let store=Store();await store.start();let cli=try XCTUnwrap(store.cli)
        func command(_ args:[String])async throws->CommandResult{try await ProcessRunner.checked(cli,args)}
        func networks()async throws->Set<String>{Set(try ResourceItem.parseResources((try await command(["network","list","--format","json"])).data).map(\.id))}
        let baseline=try await networks()
        let containers=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
        let suffix=UUID().uuidString.lowercased().prefix(8)
        let names=["cd-batch-a-"+suffix,"cd-batch-b-"+suffix]
        func cleanup()async throws {
            let current=try await networks()
            for name in names where current.contains(name){_=try await command(["network","delete","--",name])}
        }
        do {
            for name in names{_=try await command(["network","create","--internal","--",name])}
            let request=ResourceBatchDeletion(kind:.network,ids:[names[0],names[0],"default","cd-batch-missing-"+suffix,names[1]])
            store.deleteResources(request)
            let deadline=Date().addingTimeInterval(60)
            while store.operationRunning {
                guard Date()<deadline else{store.cancelOperation();throw DeskError.message("Batch timed out")}
                try await Task.sleep(for:.milliseconds(100))
            }
            try XCTAssertEqual(store.operationResult,"operationFailed")
            try XCTAssertTrue(store.operationOutput.contains("2/4"),store.operationOutput)
            try XCTAssertTrue(store.operationOutput.contains(store.t("protectedResource")))
            try XCTAssertTrue(store.operationOutput.contains(store.t("resourceDisappeared")))
            let remaining=try await networks()
            try XCTAssertEqual(remaining,baseline)
            let after=try ContainerItem.parse((try await command(["list","--all","--format","json"])).data)
            try XCTAssertEqual(Dictionary(uniqueKeysWithValues:after.map{($0.id,$0.state)}),Dictionary(uniqueKeysWithValues:containers.map{($0.id,$0.state)}))
            print("PASS: resource batch deduplicates targets, deletes both disposable networks, skips protected/missing resources, continues after failures, verifies absence and preserves baseline")
        } catch{try await cleanup();throw error}
    }
}
