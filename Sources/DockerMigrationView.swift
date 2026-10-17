import SwiftUI
import AppKit

struct DockerMigrationView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State private var source:URL?
    @State private var result:DockerMigrationResult?
    @State private var error:String?
    @State private var manualRestart=false
    @State private var reviewed=false
    @State private var useOfficial=true
    @State private var overrides:[URL]=[]
    @State private var busy=false
    @State private var analysisTask:Task<Void,Never>?
    @State private var generation=UUID()
    let imported:(URL)->Void
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("dockerConvert")).font(.title2).fontWeight(.semibold)
            Text(s.t("dockerConvertIntro")).foregroundStyle(.secondary)
            HStack {
                Button(s.t("dockerChoose"),action:choose).disabled(busy)
                if let source{Text(source.path).font(.caption).lineLimit(2).textSelection(.enabled)}
            }
            Toggle(s.t("dockerUseCompose"),isOn:$useOfficial).onChange(of:useOfficial){_,_ in analyze()}
            if useOfficial,source != nil {
                HStack {
                    Button(s.t("dockerAddOverride"),action:chooseOverride).disabled(busy)
                    if !overrides.isEmpty {Button(s.t("dockerClearOverrides")){overrides=[];analyze()}.disabled(busy)}
                    if busy{ProgressView().controlSize(.small)}
                }
                if !overrides.isEmpty{Text(overrides.map(\.lastPathComponent).joined(separator:" → ")).font(.caption).textSelection(.enabled)}
            }
            Toggle(s.t("dockerAllowManualRestart"),isOn:$manualRestart).onChange(of:manualRestart){_,_ in analyze()}
            if let error{Text(error).foregroundStyle(.red).textSelection(.enabled)}
            if let result {
                Label(s.t(result.canImport ? "dockerConvertible":"dockerConversionBlocked"),systemImage:result.canImport ? "checkmark.circle":"exclamationmark.triangle").foregroundStyle(result.canImport ? .green:.orange)
                ScrollView {
                    VStack(alignment:.leading,spacing:12) {
                        ForEach(result.notices){notice in
                            VStack(alignment:.leading,spacing:3){
                                Label(notice.path,systemImage:notice.blocking ? "xmark.circle":"info.circle").font(.headline)
                                Text(s.t(notice.message)).foregroundStyle(notice.blocking ? .red:.secondary).textSelection(.enabled)
                            }.frame(maxWidth:.infinity,alignment:.leading)
                        }
                        DisclosureGroup(s.t("dockerYAMLPreview")) {
                            Text(result.yaml).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                        }
                    }.padding(.trailing,8)
                }
                Toggle(s.t("dockerReviewed"),isOn:$reviewed)
            } else {Spacer()}
            Text(s.t("dockerSaveNote")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction)
                Button(s.t("dockerSaveImport"),action:save).buttonStyle(.borderedProminent).disabled(result?.canImport != true || !reviewed || busy)
            }
        }.padding(24).frame(width:760,height:740).onDisappear{analysisTask?.cancel()}
    }
    private func diagnostic(_ error:Error)->String {
        if let issue=error as? ComposeIssue{return issue.path+": "+s.t(issue.reason)}
        return s.t(error.localizedDescription)
    }
    private func choose() {
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=true;panel.allowsMultipleSelection=false
        panel.begin {response in
            guard response == .OK,let url=panel.url else{return}
            source=url;overrides=[];analyze()
        }
    }
    private func chooseOverride() {
        let panel=NSOpenPanel();panel.canChooseDirectories=false;panel.allowsMultipleSelection=false
        panel.begin {response in
            guard response == .OK,let url=panel.url else{return}
            overrides.append(url);analyze()
        }
    }
    private func analyze() {
        analysisTask?.cancel();generation=UUID();let current=generation
        reviewed=false;result=nil;error=nil;busy=false
        guard let source else{return}
        let manual=manualRestart,official=useOfficial,extra=overrides
        busy=true
        analysisTask=Task { @MainActor in
            defer{if generation==current{busy=false}}
            do {
                let file=try DockerProjectConverter.source(in:source)
                let dockerfile=file.lastPathComponent=="Dockerfile" || file.lastPathComponent.hasPrefix("Dockerfile.")
                let resolution:DockerComposeResolution?
                if official && !dockerfile {
                    resolution=try await DockerComposeResolver.resolve([file]+extra,discoverOverride:extra.isEmpty)
                } else{resolution=nil}
                try Task.checkCancellation()
                let value=try DockerProjectConverter.analyze(file,allowManualRestart:manual,resolution:resolution)
                if generation==current{result=value}
            } catch is CancellationError {} catch {if generation==current{self.error=diagnostic(error)}}
        }
    }
    private func save() {
        guard reviewed,let result,result.canImport,!busy else{return}
        busy=true
        analysisTask=Task { @MainActor in
            defer{busy=false}
            do{let url=try await result.saveVerified();imported(url);dismiss()}
            catch is CancellationError {} catch{self.error=diagnostic(error);reviewed=false}
        }
    }
}
