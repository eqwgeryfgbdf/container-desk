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

extension PlatformTests {
    func testArchiveBudgets()async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("cd-archive-budget-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        defer{try? FileManager.default.removeItem(at:directory)}
        let script="""
        import io,sys,tarfile,pathlib
        root=pathlib.Path(sys.argv[1])
        for mode,name,count,size,kind in [('w','ordinary.tar',1,4096,'file'),('w:gz','compressed.tar',1,65536,'file'),('w','entries.tar',20,0,'dir'),('w','sparse.tar',1,0,'sparse'),('w','pax.tar',1,1,'pax'),('w','long.tar',1,4,'long')]:
            with tarfile.open(root/name,mode,format=tarfile.PAX_FORMAT) as tar:
                for i in range(count):
                    entry=tarfile.TarInfo(('long/'+'a'*180 if kind=='long' else 'item'+str(i)))
                    entry.size=size
                    if kind=='dir': entry.type=tarfile.DIRTYPE
                    if kind=='sparse': entry.type=tarfile.GNUTYPE_SPARSE
                    if kind=='pax': entry.pax_headers={'size':'999999999'}
                    tar.addfile(entry,io.BytesIO(b'x'*size))
        """
        _=try await ProcessRunner.checked("/usr/bin/python3",["-c",script,directory.path])
        for name in ["ordinary.tar","long.tar"] {try SafeTar.validate(directory.appendingPathComponent(name),maximumBytes:1024*1024)}
        for name in ["compressed.tar","entries.tar","sparse.tar","pax.tar"] {
            try XCTAssertThrowsError(try SafeTar.validate(directory.appendingPathComponent(name),maximumBytes:1024*1024,maximumEntries:10),name)
        }
        let corrupt=directory.appendingPathComponent("corrupt.tar")
        try Data(repeating:65,count:1024).write(to:corrupt)
        try XCTAssertThrowsError(try SafeTar.validate(corrupt,maximumBytes:1024*1024))
        print("PASS: plain tar / long PAX paths accepted; compression, excessive entries, sparse metadata, size overrides and invalid headers rejected before extraction")
    }
}
