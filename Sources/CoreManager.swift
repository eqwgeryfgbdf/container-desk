import SwiftUI
import CryptoKit

final class OfficialDownloads: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) {
        let hosts=["github.com","release-assets.githubusercontent.com","objects.githubusercontent.com"]
        guard let u=request.url,u.scheme=="https",let h=u.host,hosts.contains(h),u.user==nil,u.password==nil else { completionHandler(nil);return }
        completionHandler(request)
    }
}
@MainActor final class CoreManager: ObservableObject {
    @Published var release:CoreRelease?
    @Published var phase="idle"
    @Published var failure:String?
    @Published var checking=false
    @Published var installing=false
    @Published var lastChecked:Date?
    @Published var autoCheck=UserDefaults.standard.object(forKey:"autoCheck") as? Bool ?? true {
        didSet{UserDefaults.standard.set(autoCheck,forKey:"autoCheck")}
    }
    @Published var autoInstall=UserDefaults.standard.bool(forKey:"autoInstall") {
        didSet{UserDefaults.standard.set(autoInstall,forKey:"autoInstall")}
    }
    var isExternal:Bool=false
    private let downloader=OfficialDownloads()
    private var lastAttempt:Date?
    func installedVersion(_ store:Store)->String? {
        store.version.components(separatedBy:" ").first { $0.range(of:"^[0-9]+\\.[0-9]+\\.[0-9]+$",options:.regularExpression) != nil }
    }
    func updateAvailable(_ store:Store)->Bool { guard let r=release,let v=installedVersion(store) else{return false};return r.isNewer(than:v) }
    func managed(_ store:Store)->Bool {
        guard let cli=store.cli else{return true}
        guard cli=="/usr/local/bin/container",(try? FileManager.default.destinationOfSymbolicLink(atPath:cli))==nil else{return false}
        let home=FileManager.default.homeDirectoryForCurrentUser.path
        return UserDefaults.standard.bool(forKey:"officialMigrationCompleted") || ![home+"/.local/bin/container","/opt/homebrew/bin/container"].contains{FileManager.default.isExecutableFile(atPath:$0)}
    }
    func check() async {
        guard !checking,!installing else{return};checking=true;failure=nil;defer{checking=false}
        lastAttempt=Date()
        do {
            var req=URLRequest(url:URL(string:"https://api.github.com/repos/apple/container/releases/latest")!);req.timeoutInterval=20;req.setValue("application/vnd.github+json",forHTTPHeaderField:"Accept");req.setValue("ContainerDesk/0.1",forHTTPHeaderField:"User-Agent")
            let (data,res)=try await URLSession.shared.data(for:req)
            guard let h=res as? HTTPURLResponse,h.statusCode==200 else{throw DeskError.message("releaseUnavailable")}
            let r=try JSONDecoder().decode(CoreRelease.self,from:data);_=try r.validatedAsset()
            release=r;lastChecked=Date();phase="checked"
        }catch{failure=error.localizedDescription}
    }
    func periodic(_ store:Store) async {
        guard autoCheck,!store.busy,!installing else{return}
        if let lastAttempt,Date().timeIntervalSince(lastAttempt)<86400{return}
        await check()
        if autoInstall,let r=release,r.tested,managed(store),store.connected,store.active==0,updateAvailable(store) {await install(store,automatic:true)}
    }
    private func migrationSource(_ store:Store)->String? {
        let home=FileManager.default.homeDirectoryForCurrentUser.path
        guard store.cli==home+"/.local/bin/container",let version=installedVersion(store),
              let wrapper=try? String(contentsOfFile:home+"/.local/bin/container",encoding:.utf8) else{return nil}
        let binary=home+"/.local/share/apple-container/"+version+"/bin/container"
        let forms=["#!/bin/sh\nexec "+binary+" \"$@\"","#!/bin/sh\nexec \""+binary+"\" \"$@\""]
        guard forms.contains(wrapper.trimmingCharacters(in:.whitespacesAndNewlines)),FileManager.default.isExecutableFile(atPath:binary) else{return nil}
        return binary
    }
    func canMigrate(_ store:Store)->Bool {
        guard store.cli != nil,!managed(store),let r=release,r.tested,let current=installedVersion(store) else{return false}
        // Keep migration within the same product version; upgrades follow after migration.
        return current==r.tag_name && migrationSource(store) != nil && !FileManager.default.fileExists(atPath:"/usr/local/bin/container")
    }
    private func snapshot(_ cli:String?) async throws -> EngineSnapshot {
        guard let cli else{return .init(running:false,activeContainers:0)}
        let state=try EngineSnapshot.parse((try await ProcessRunner.checked(cli,["system","status","--format","json"])).data)
        if state.running {
            let rows=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
            return .init(running:true,activeContainers:rows.filter(\.running).count)
        }
        return state
    }
    func install(_ store:Store,automatic:Bool=false,migrate:Bool=false) async {
        guard !installing,!store.busy,!store.refreshing else{return}
        guard managed(store) || (migrate && !automatic && canMigrate(store)) else{failure="externalInstall";return}
        guard let r=release,r.tested else{failure="compatibilityPending";return}
        if let current=installedVersion(store),r.tag_name.compare(current,options:.numeric) == .orderedAscending{failure="downgradeBlocked";return}
        installing=true;store.busy=true;failure=nil
        let oldCLI=store.cli, freshInstall=store.cli==nil
        var dir:URL?,package:URL?
        defer{installing=false;store.busy=false;if let dir{try? FileManager.default.removeItem(at:dir)};Task{await store.refresh()}}
        do {
            let asset=try r.validatedAsset()
            let expected=String(asset.digest!.dropFirst(7))
            try await InstallWorkflow.run(InstallSteps(
                inspect:{
                    if migrate,let oldCLI {
                        let status=try await ProcessRunner.checked(oldCLI,["system","status","--format","json"])
                        let json=try JSONSerialization.jsonObject(with:status.data) as? [String:Any]
                        let root=(json?["paths"] as? [String:Any])?["appRoot"] as? String
                        let expectedRoot=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/com.apple.container").standardizedFileURL.path
                        guard let root,URL(fileURLWithPath:root).standardizedFileURL.path==expectedRoot else{throw DeskError.message("migrationUnsupported")}
                    }
                    return try await self.snapshot(oldCLI)
                },
                prepare:{
                    if migrate {
                        guard let binary=self.migrationSource(store) else{throw DeskError.message("migrationUnsupported")}
                        _=try await ProcessRunner.checked("/usr/bin/codesign",["--verify","--strict","-R=anchor apple generic and identifier \"com.apple.container.cli\" and certificate leaf[subject.OU] = \"UPBK2H6LZM\"",binary])
                    }
                    self.phase="downloading"
                    let session=URLSession(configuration:.ephemeral,delegate:self.downloader,delegateQueue:nil)
                    defer{session.invalidateAndCancel()}
                    var request=URLRequest(url:URL(string:asset.browser_download_url)!);request.timeoutInterval=600
                    let (temp,response)=try await session.download(for:request)
                    guard (response as? HTTPURLResponse)?.statusCode==200 else{throw DeskError.message("downloadFailed")}
                    let stage=FileManager.default.temporaryDirectory.appendingPathComponent("containerdesk-install-"+UUID().uuidString)
                    try FileManager.default.createDirectory(at:stage,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700]);dir=stage
                    let file=stage.appendingPathComponent("container.pkg");try FileManager.default.moveItem(at:temp,to:file);package=file
                    guard try file.resourceValues(forKeys:[.fileSizeKey]).fileSize==Int(asset.size) else{throw DeskError.message("downloadFailed")}
                    self.phase="verifying"
                    let hash=try await ProcessRunner.checked("/usr/bin/shasum",["-a","256",file.path],timeout:60)
                    guard hash.text.split(separator:" ").first.map(String.init)==expected else{throw DeskError.message("signatureFailed")}
                    let sig=try await ProcessRunner.checked("/usr/sbin/pkgutil",["--check-signature",file.path])
                    guard sig.text.contains("Developer ID Installer: Apple Inc. - Containerization (UPBK2H6LZM)") else{throw DeskError.message("signatureFailed")}
                    _=try await ProcessRunner.checked("/usr/sbin/spctl",["--assess","--type","install",file.path],timeout:60)
                    // An installation appearing during the download must not be overwritten by a migration.
                    if migrate && FileManager.default.fileExists(atPath:"/usr/local/bin/container"){throw DeskError.message("externalInstall")}
                },
                stop:{if let oldCLI{_=try await ProcessRunner.checked(oldCLI,["system","stop"],timeout:90)}},
                install:{
                    guard let package else{throw DeskError.message("downloadFailed")}
                    let path=shellQuote(package.path)
                    let script="/usr/bin/shasum -a 256 "+path+" | /usr/bin/awk '{print $1}' | /usr/bin/grep -qx "+shellQuote(expected)+" && /usr/sbin/installer -pkg "+path+" -target /"
                    do {
                        // Do not kill an authorized installer while it is writing system files.
                        _=try await ProcessRunner.checked("/usr/bin/osascript",["-e","do shell script "+appleScriptQuote(script)+" with administrator privileges"],timeout:nil)
                    }catch{
                        if error.localizedDescription.contains("(-128)"){throw DeskError.message("authorizationCancelled")}
                        throw error
                    }
                },
                start:{
                    store.detect()
                    guard store.cli=="/usr/local/bin/container" else{throw DeskError.message("coreMissing")}
                    _=try await ProcessRunner.checked("/usr/local/bin/container",["system","start",freshInstall ? "--enable-kernel-install":"--disable-kernel-install"],timeout:600)
                },
                verify:{
                    let v=try await ProcessRunner.checked("/usr/local/bin/container",["--version"])
                    guard v.text.split(whereSeparator:{$0.isWhitespace}).contains(Substring(r.tag_name)) else{throw DeskError.message("versionMismatch")}
                    _=try await ProcessRunner.checked("/usr/local/bin/container",["list","--all","--format","json"])
                    store.version=v.text.trimmingCharacters(in:.whitespacesAndNewlines)
                },
                recover:{attempted in
                    // Recover service availability; never downgrade data or promise binary rollback.
                    let path=attempted && FileManager.default.isExecutableFile(atPath:"/usr/local/bin/container") ? "/usr/local/bin/container":oldCLI
                    if let path{_=try await ProcessRunner.checked(path,["system","start","--disable-kernel-install"],timeout:90)}
                },
                phase:{self.phase=$0}
            ))
            if migrate {UserDefaults.standard.set(true,forKey:"officialMigrationCompleted")}
            phase="installed";store.notice=store.t("installComplete")
        } catch {failure=error.localizedDescription;phase="failed"}
    }
}
