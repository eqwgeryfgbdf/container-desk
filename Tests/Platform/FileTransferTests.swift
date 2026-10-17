import Foundation

extension PlatformTests {
    @MainActor func testArchiveTraversalAndCancellation()async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("cd-archive-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        defer{try? FileManager.default.removeItem(at:directory)}
        let stage=directory.appendingPathComponent("stage"),outside=directory.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at:stage,withIntermediateDirectories:false)
        try FileManager.default.createDirectory(at:outside,withIntermediateDirectories:false)
        let sentinel=outside.appendingPathComponent("keep")
        try "unchanged".write(to:sentinel,atomically:true,encoding:.utf8)
        let archive=directory.appendingPathComponent("unsafe.tar"),out=directory.appendingPathComponent("output")
        let script="""
        import io,sys,tarfile
        with tarfile.open(sys.argv[1],'w') as tar:
            link=tarfile.TarInfo('link');link.type=tarfile.SYMTYPE;link.linkname=sys.argv[2];tar.addfile(link)
            for name in ['link/keep','../outside/keep']:
                entry=tarfile.TarInfo(name);entry.size=7;tar.addfile(entry,io.BytesIO(b'changed'))
        """
        _=try await ProcessRunner.checked("/usr/bin/python3",["-c",script,archive.path,outside.path])
        var refused=false
        do {try await FileTransferProcess.run("/usr/bin/tar",FileTransferProcess.extractionArguments(archive:archive,directory:stage),output:out){_ in}}
        catch {refused=true}
        try XCTAssertTrue(refused,"Reject path traversal / extraction through symlinks")
        try XCTAssertEqual(try String(contentsOf:sentinel,encoding:.utf8),"unchanged")
        let task=Task{try await FileTransferProcess.run("/bin/sleep",["30"],output:out){_ in}}
        try await Task.sleep(for:.milliseconds(100));task.cancel()
        do {try await task.value;throw DeskError.message("Cancellation unexpectedly succeeded")}
        catch is CancellationError {} // subprocess is reaped before the call returns
    }
}
