import Foundation
import Darwin

class PlatformTestCase {
    var teardown:[()throws->Void]=[]
    func addTeardownBlock(_ body:@escaping ()throws->Void){teardown.append(body)}
    func clean(){for body in teardown{try? body()}}
}
func XCTAssertTrue(_ value:@autoclosure ()throws->Bool,_ message:String="",file:StaticString=#filePath,line:UInt=#line)throws {if try !value(){throw DeskError.message("\(file):\(line): \(message)")}}
func XCTAssertFalse(_ value:@autoclosure ()throws->Bool,_ message:String="",file:StaticString=#filePath,line:UInt=#line)throws {try XCTAssertTrue(!value(),message,file:file,line:line)}
func XCTAssertEqual<T:Equatable>(_ a:@autoclosure ()throws->T,_ b:@autoclosure ()throws->T,_ message:String="",file:StaticString=#filePath,line:UInt=#line)throws {try XCTAssertTrue(a()==b(),message,file:file,line:line)}
func XCTAssertThrowsError<T>(_ body:@autoclosure ()throws->T,_ message:String="",file:StaticString=#filePath,line:UInt=#line)throws {
    do {_=try body()}catch{return};throw DeskError.message("\(file):\(line): Expected rejection: \(message)")
}
func XCTAssertNoThrow<T>(_ body:@autoclosure ()throws->T)throws{_=try body()}
func XCTUnwrap<T>(_ value:T?)throws->T{guard let value else{throw DeskError.message("Required test value missing")};return value}

@main struct PlatformTestRunner {
    @MainActor static func main() async {
        setbuf(stdout,nil)
        do {
        let unit=PlatformTests();defer{unit.clean()}
        try await unit.testAIWorkspaceState()
        try unit.testDockerMigration()
        try unit.testDockerCompatibility()
        try await unit.testHubSearch()
        try unit.testSnapshotPlan()
        try unit.testComposeOrderAndLiteralArguments()
        try unit.testComposeArgumentIsolationAndExpansionLimits()
        try unit.testComposeRejectsUnsupportedAndAmbiguousConfiguration()
        try unit.testEnvFilesAndInterpolation()
        try unit.testFileNamesAndNoOverwriteCommands()
        try unit.testManagedHostsIsolation()
        try unit.testCorruptProjectLibraryIsPreserved()
        try unit.testRegistryValidationAndMetadata()
        try unit.testRegistryCatalog()
        try await unit.testCredentialPipeAndSuppressedOutput()
        try await unit.testArchiveTraversalAndCancellation()
        try await unit.testArchiveBudgets()
        print("PASS: 17 platform suites (Hub search, Compose semantics and rejection cases, env interpolation, file safety, registry validation, credential pipe)")
        if CommandLine.arguments.contains("--clone"){try await unit.testCloneLive()}
        if CommandLine.arguments.contains("--resource-batch"){try await unit.testResourceBatchLive()}
        if CommandLine.arguments.contains("--snapshot"){try await unit.testContainerSnapshotLive()}
        if CommandLine.arguments.contains("--hub-search"){try await unit.testHubSearchLive()}
        if CommandLine.arguments.contains("--hub-download"){try await unit.testHubSearchDownload()}
        if CommandLine.arguments.contains("--architecture-deploy"){try await unit.testArchitectureDeployment()}
        if CommandLine.arguments.contains("--resolve") || CommandLine.arguments.contains("--resolved-run") {try await unit.testOfficialComposeResolution()}
        if CommandLine.arguments.contains("--registry") {
            try await RegistryLiveTests().testLocalAuthentication()
        }
        if CommandLine.arguments.contains("--push") {
            try await RegistryLiveTests().testLoopbackPush()
        }
        if CommandLine.arguments.contains("--run") || CommandLine.arguments.contains("--convert-run") || CommandLine.arguments.contains("--resolved-run") {
            setenv("CONTAINERDESK_LIVE_PLATFORM_TESTS","1",1)
            let live=PlatformLiveTests();defer{live.clean()}
            try await live.testLiveComposeAndFiles(converted:CommandLine.arguments.contains("--convert-run") || CommandLine.arguments.contains("--resolved-run"),resolved:CommandLine.arguments.contains("--resolved-run"))
            print("PASS: real Compose dependency/health startup, service DNS, file transfer round trip, no-overwrite, rename/mkdir/remove, project stop/restart/removal, retained volume, changed-config refusal and original-state preservation")
        }
        } catch {fputs("FAIL: \(error.localizedDescription)\n",stderr);exit(1)}
    }
}
