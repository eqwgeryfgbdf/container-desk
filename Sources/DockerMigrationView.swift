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
    let imported:(URL)->Void
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("dockerConvert")).font(.title2).fontWeight(.semibold)
            Text(s.t("dockerConvertIntro")).foregroundStyle(.secondary)
            HStack {
                Button(s.t("dockerChoose"),action:choose)
                if let source{Text(source.path).font(.caption).lineLimit(2).textSelection(.enabled)}
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
                Button(s.t("dockerSaveImport"),action:save).buttonStyle(.borderedProminent).disabled(result?.canImport != true || !reviewed)
            }
        }.padding(24).frame(width:760,height:680)
    }
    private func diagnostic(_ error:Error)->String {
        if let issue=error as? ComposeIssue{return issue.path+": "+s.t(issue.reason)}
        return s.t(error.localizedDescription)
    }
    private func choose() {
        let panel=NSOpenPanel();panel.canChooseFiles=true;panel.canChooseDirectories=true;panel.allowsMultipleSelection=false
        panel.begin {response in
            guard response == .OK,let url=panel.url else{return}
            source=url;analyze()
        }
    }
    private func analyze() {
        reviewed=false;result=nil;error=nil
        guard let source else{return}
        do{result=try DockerProjectConverter.analyze(source,allowManualRestart:manualRestart)}catch{self.error=diagnostic(error)}
    }
    private func save() {
        guard reviewed,let result,result.canImport else{return}
        do{let url=try result.save();imported(url);dismiss()}catch{self.error=diagnostic(error)}
    }
}
