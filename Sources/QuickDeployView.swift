import SwiftUI

struct QuickDeployView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State private var input=""
    @State private var tag="latest"
    @State private var resolved:String?
    @State private var busy=false
    @State private var failure:String?
    @State private var requested:String?
    @State private var mode="search"
    let configure:(String)->Void
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("quickDeploy")).font(.title2).fontWeight(.semibold)
            Text(s.t("quickDeployIntro")).foregroundStyle(.secondary)
            Picker(s.t("hubSource"),selection:$mode) {
                Text(s.t("hubSearchAction")).tag("search")
                Text(s.t("hubSearchDirect")).tag("direct")
            }.pickerStyle(.segmented).disabled(busy || resolved != nil)
            if mode=="search" {
                HubSearchView { image in input=image;tag="latest";failure=nil;mode="direct" }
            } else {
                TextField("https://hub.docker.com/_/nginx",text:$input).textFieldStyle(.roundedBorder).accessibilityLabel(s.t("hubSource")).disabled(busy || resolved != nil)
                LabeledContent(s.t("hubDefaultTag")){TextField("latest",text:$tag).textFieldStyle(.roundedBorder).frame(width:160)}.disabled(busy || resolved != nil)
                if let requested{Text(requested).font(.system(.caption,design:.monospaced)).textSelection(.enabled)}
                if busy {ProgressView();ScrollView{Text(s.operationOutput).font(.system(.caption,design:.monospaced)).textSelection(.enabled)}.frame(maxHeight:180)}
                if let failure{Text(s.t(failure)).foregroundStyle(.red)}
                if resolved != nil{Label(s.t("hubImageReady"),systemImage:"checkmark.circle").foregroundStyle(.green)}
                Text(s.t("hubConfigurationNote")).font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            HStack {
                Button(s.t("cancel")){if busy{s.cancelOperation()};dismiss()}.keyboardShortcut(.cancelAction)
                Spacer()
                if let resolved {
                    Button(s.t("hubConfigure")){configure(resolved);dismiss()}.buttonStyle(.borderedProminent)
                } else if mode=="direct" {
                    Button(s.t("hubDownload"),action:download).buttonStyle(.borderedProminent).disabled(busy || !s.canMutate || input.isEmpty)
                }
            }
        }.padding(24).frame(width:680,height:620)
        .onChange(of:s.operationRunning){_,running in
            guard busy,!running else{return};busy=false
            if s.operationResult=="operationComplete"{resolved=requested}else{failure=s.operationResult ?? "operationFailed"}
        }
    }
    private func download() {
        do {
            let image=try DeploymentSource.image(input,tag:tag)
            guard s.canMutate else{return}
            requested=image;failure=nil;busy=true
            s.prepareDeployment(image)
        } catch{busy=false;failure=error.localizedDescription}
    }
}
