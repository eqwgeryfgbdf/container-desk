import SwiftUI

struct QuickDeployView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State private var input=""
    @State private var tag="latest"
    @State private var architecture="arm64"
    @State private var resolved:DeploymentSelection?
    @State private var configuring:DeploymentSelection?
    @State private var busy=false
    @State private var failure:String?
    @State private var requested:DeploymentSelection?
    @State private var mode="search"
    @State private var continueToConfiguration=false
    init(initialSource:String="") {
        _input=State(initialValue:initialSource);_mode=State(initialValue:initialSource.isEmpty ? "search":"direct")
    }
    private var canConfigure:Bool{architecture != "amd64" || DeploymentRuntime.rosettaReady}
    var body:some View {
        Group {
            if let configuring {
                // Keep configuration in the same sheet rather than dismissing one
                // sheet and presenting another during its dismissal animation.
                CreateView(initialImage:configuring.image,initialArchitecture:configuring.architecture).environmentObject(s)
            } else {downloadView}
        }
    }
    private var downloadView:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("deployUnified")).font(.title2).fontWeight(.semibold)
            Text(s.t("deployUnifiedIntro")).foregroundStyle(.secondary)
            Picker(s.t("hubSource"),selection:$mode) {
                Text(s.t("hubSearchAction")).tag("search")
                Text(s.t("hubSearchDirect")).tag("direct")
            }.pickerStyle(.segmented).disabled(busy || resolved != nil)
            if mode=="search" {
                HubSearchView { selection in
                    input=selection.image;architecture=selection.architecture
                    tag="latest";requested=nil;failure=nil;mode="direct"
                }
            } else {
                TextField("https://hub.docker.com/_/nginx",text:$input).textFieldStyle(.roundedBorder).accessibilityLabel(s.t("hubSource")).disabled(busy || resolved != nil)
                LabeledContent(s.t("hubDefaultTag")){TextField("latest",text:$tag).textFieldStyle(.roundedBorder).frame(width:160)}.disabled(busy || resolved != nil)
                Picker(s.t("architecture"),selection:$architecture) {
                    Text(s.t("deployARMNative")).tag("arm64")
                    Text(s.t("deployAMDTranslated")).tag("amd64")
                }.pickerStyle(.menu).disabled(busy || resolved != nil)
                Text(s.t("deployArchitectureNote")).font(.caption).foregroundStyle(.secondary)
                if architecture=="amd64" {
                    Label(s.t(DeploymentRuntime.rosettaStatus),systemImage:DeploymentRuntime.rosettaReady ? "checkmark.circle":"exclamationmark.triangle").font(.callout)
                    Text(s.t("deployRosettaNote")).font(.caption).foregroundStyle(.secondary)
                }
                if let requested{Text(requested.image+" · linux/"+requested.architecture).font(.system(.caption,design:.monospaced)).textSelection(.enabled)}
                if busy {ProgressView();ScrollView{Text(s.operationOutput).font(.system(.caption,design:.monospaced)).textSelection(.enabled)}.frame(maxHeight:140)}
                if let failure{Text(s.t(failure)).foregroundStyle(.red).lineLimit(4)}
                if resolved != nil{Label(s.t("deployDownloaded"),systemImage:"checkmark.circle").foregroundStyle(.green)}
                Text(s.t("hubConfigurationNote")).font(.callout).foregroundStyle(.secondary)
                Spacer(minLength:0)
            }
            HStack {
                Button(s.t(resolved == nil ? "cancel":"done")){if busy{s.cancelOperation()};dismiss()}.keyboardShortcut(.cancelAction)
                Spacer()
                if let resolved {
                    Button(s.t("hubConfigure")){configuring=resolved}.buttonStyle(.borderedProminent).disabled(!canConfigure)
                } else if mode=="direct" {
                    Button(s.t("deployDownloadOnly")){download(configure:false)}.disabled(busy || !s.canMutate || input.isEmpty)
                    Button(s.t("deployDownloadConfigure")){download(configure:true)}.buttonStyle(.borderedProminent).disabled(busy || !s.canMutate || input.isEmpty || !canConfigure)
                }
            }
        }.padding(24).frame(width:680,height:660)
        .interactiveDismissDisabled(busy)
        .onChange(of:s.operationRunning){_,running in
            guard busy,!running else{return};busy=false
            if s.operationResult=="operationComplete" {
                resolved=requested
                if continueToConfiguration,canConfigure{configuring=requested}
            } else{failure=s.operationResult ?? "operationFailed"}
        }
    }
    private func download(configure:Bool) {
        do {
            let image=try DeploymentSource.image(input,tag:tag)
            guard s.canMutate else{return}
            requested=DeploymentSelection(image:image,architecture:architecture)
            continueToConfiguration=configure;failure=nil;busy=true
            s.prepareDeployment(image,architecture:architecture)
        } catch{busy=false;failure=error.localizedDescription}
    }
}
