import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AIWorkspaceView:View {
    @EnvironmentObject var s:Store
    @EnvironmentObject var ai:AIWorkspace
    @State private var manualURL="http://127.0.0.1:3000/mcp"
    @State private var bearer=""
    @State private var connectReview=false
    @State private var searchModels=false
    private var maxCPUs:Int{max(1,s.host.logicalCores ?? 1)}
    private var maxMemory:Int{max(512,Int(s.host.memory/1048576))}
    private var existing:ContainerItem?{s.containers.first{$0.id==ai.deployment?.name}}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:22) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:8){Text(s.t("aiWorkspace")).font(.largeTitle.bold());Text(s.t("aiSubtitle")).foregroundStyle(.secondary)}
                    Spacer();Label("llama.cpp",systemImage:"sparkles").font(.title3)
                }
                if let error=ai.error{Label(s.t(error),systemImage:"exclamationmark.triangle.fill").foregroundStyle(.red).textSelection(.enabled)}
                if let activity=ai.activity {
                    HStack{ProgressView().controlSize(.small);Text(s.t(activity));Spacer();Button(s.t("cancel")){ai.cancel()}}
                    if activity=="aiDownloading"{ProgressView(value:ai.progress);Text(ai.progress.formatted(.percent.precision(.fractionLength(0)))).font(.caption)}
                }
                modelSection
                mcpSection
                chatSection
            }.padding(28).frame(maxWidth:1100).frame(maxWidth:.infinity)
        }
        .alert(s.t("aiCompatibilityTitle"),isPresented:Binding(get:{ai.warning != nil},set:{if !$0{ai.warning=nil}})) {
            Button(s.t("close")){ai.warning=nil}
        } message:{Text(s.t(ai.warning ?? ""))}
        .sheet(isPresented:$searchModels){HuggingFaceModelSearchView(maxMemory:maxMemory){ai.selectDownload($0)}}
        .sheet(isPresented:$connectReview) {
            VStack(alignment:.leading,spacing:16) {
                Text(s.t("aiConnectReview")).font(.title2.bold())
                Text(ai.server?.name ?? "").font(.headline)
                ScrollView{Text(ai.server?.summary ?? "").font(.system(.body,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}
                Text(s.t(ai.server?.command == nil ? "aiHTTPConnectNote":"aiStdioConnectNote")).foregroundStyle(.secondary)
                HStack{Spacer();Button(s.t("cancel")){connectReview=false};Button(s.t("aiConnect")){connectReview=false;ai.connect()}.buttonStyle(.borderedProminent)}
            }.padding(24).frame(width:620,height:360)
        }
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)){_ in ai.cancel();Task{await ai.disconnect()}}
        .onChange(of:existing?.running){_,running in if running != true{ai.modelReady=false;ai.toolSupport="aiToolsUnknown"}}
        .task{ai.cpus=min(ai.cpus,maxCPUs);ai.memoryMiB=min(ai.memoryMiB,maxMemory)}
    }
    private func section<Content:View>(_ title:String,@ViewBuilder content:()->Content)->some View {
        GroupBox {VStack(alignment:.leading,spacing:14,content:content).frame(maxWidth:.infinity,alignment:.leading).padding(12)} label:{Text(s.t(title)).font(.headline)}
    }
    private var modelSection:some View {
        section("aiModelSection") {
            Button(s.t("aiHFSearch"),systemImage:"magnifyingglass"){searchModels=true}.disabled(ai.isBusy)
            Picker(s.t("aiRecommendedModel"),selection:$ai.selectedModel){ForEach(ai.modelChoices){Text($0.id).tag($0.id)}}
                .disabled(ai.isBusy)
            HStack {
                Text(bytes(ai.model.size)+" · "+s.t(ai.model.license)).foregroundStyle(.secondary)
                Link(s.t("aiModelCard"),destination:ai.model.modelCard)
                Spacer();Button(s.t("aiDownloadModel")){ai.download()}.disabled(ai.isBusy)
                Button(s.t("aiChooseGGUF")){chooseModel()}.disabled(ai.isBusy)
            }
            Text(ai.modelPath.isEmpty ? s.t("aiNoModel"):ai.modelPath).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
            Text(s.t("aiCPUOnly")).font(.callout).foregroundStyle(.secondary)
            HStack(spacing:20) {
                Picker(s.t("cpuAllocation"),selection:$ai.cpus){ForEach(1...maxCPUs,id:\.self){Text(String($0)).tag($0)}}.frame(maxWidth:180)
                TextField(s.t("memoryLimit")+" (MiB)",value:$ai.memoryMiB,format:.number).frame(maxWidth:200)
                Picker(s.t("aiContext"),selection:$ai.context){ForEach([1024,2048,4096,8192],id:\.self){Text(String($0)).tag($0)}}.frame(maxWidth:180)
                TextField(s.t("hostPort"),text:$ai.port).frame(maxWidth:120)
            }.textFieldStyle(.roundedBorder).disabled(ai.isBusy)
            HStack {
                Button(s.t("aiDeploy")){ai.deploy(s)}.buttonStyle(.borderedProminent)
                    .disabled(ai.isBusy || !s.canMutate || ai.modelPath.isEmpty || existing != nil || ai.memoryMiB<512 || ai.memoryMiB>maxMemory || Int(ai.port)==nil)
                Button(s.t("aiTestModel")){ai.checkModel()}.disabled(ai.isBusy || existing?.running != true)
                Spacer()
                Label(s.t(ai.modelReady ? "aiModelReady":"aiModelUnchecked"),systemImage:ai.modelReady ? "checkmark.circle.fill":"circle").foregroundStyle(ai.modelReady ? Color.green:Color.secondary)
            }
            if let deployment=ai.deployment {
                HStack{Text(deployment.name).textSelection(.enabled);Text(deployment.endpoint).textSelection(.enabled);Spacer();Button(s.t("aiManageContainer")){s.selected=deployment.name;s.section="containers"}}
                Text(s.t("aiExistingDeploymentNote")).font(.caption).foregroundStyle(.secondary)
            }
            Label(s.t(ai.toolSupport),systemImage:ai.toolSupport=="aiToolsPassed" ? "checkmark.shield":"questionmark.circle").foregroundStyle(.secondary)
            if !ai.output.isEmpty{DisclosureGroup(s.t("aiDeploymentLog")){Text(ai.output).font(.system(.caption,design:.monospaced)).textSelection(.enabled)}}
        }
    }
    private var mcpSection:some View {
        section("aiMCPSection") {
            Text(s.t("aiMCPIntro")).foregroundStyle(.secondary)
            HStack {
                Button(s.t("aiImportMCP")){importConfiguration()}
                Picker(s.t("aiMCPServer"),selection:$ai.selectedServer) {
                    Text(s.t("none")).tag(Optional<UUID>.none)
                    ForEach(ai.configurations){Text($0.name).tag(Optional($0.id))}
                }
                Button(s.t("aiConnect")){connectReview=true}.disabled(ai.server==nil)
            }.disabled(ai.isBusy || ai.mcpConnected)
            DisclosureGroup(s.t("aiAddHTTP")) {
                HStack{TextField("http://127.0.0.1:3000/mcp",text:$manualURL);SecureField(s.t("aiBearer"),text:$bearer);Button(s.t("add")){addHTTP()}}
                    .textFieldStyle(.roundedBorder).disabled(ai.isBusy || ai.mcpConnected)
                Text(s.t("aiCredentialNote")).font(.caption).foregroundStyle(.secondary)
            }
            if ai.mcpConnected {
                HStack{Label(s.t("connected")+" · \(ai.tools.count)",systemImage:"checkmark.circle.fill").foregroundStyle(.green);Spacer();Button(s.t("aiDisconnect")){Task{await ai.disconnect()}}.disabled(ai.isBusy)}
                Text(s.t("aiSelectTools")).foregroundStyle(.secondary)
                ForEach(ai.tools){tool in
                    Toggle(isOn:Binding(get:{ai.enabledTools.contains(tool.name)},set:{if $0{ai.enabledTools.insert(tool.name)}else{ai.enabledTools.remove(tool.name)};ai.resetChat()})) {
                        VStack(alignment:.leading){Text(tool.name).fontWeight(.medium);Text(tool.description).font(.caption).foregroundStyle(.secondary).lineLimit(3)}
                    }.disabled(ai.isBusy || !ai.pending.isEmpty)
                }
            }
        }
    }
    private var chatSection:some View {
        section("aiChatSection") {
            Text(s.t("aiChatNote")).foregroundStyle(.secondary)
            ForEach(ai.chat){line in
                VStack(alignment:.leading,spacing:6){Text(s.t(line.role)).font(.caption.bold()).foregroundStyle(.secondary);Text(s.t(line.text)).textSelection(.enabled)}
                    .frame(maxWidth:.infinity,alignment:.leading).padding(12).background(.quaternary.opacity(0.5),in:RoundedRectangle(cornerRadius:10))
            }
            if !ai.pending.isEmpty {
                Text(s.t("aiToolReviewNote")).font(.callout)
                HStack{Button(s.t("aiDeclineTools")){ai.declineTools()};Button(s.t("aiApproveTools")){ai.approveTools()}.buttonStyle(.borderedProminent)}.disabled(ai.isBusy)
            }
            HStack {
                TextField(s.t("aiPrompt"),text:$ai.prompt,axis:.vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                    .disabled(ai.isBusy || !ai.pending.isEmpty)
                Button(s.t("aiSend")){ai.ask()}.buttonStyle(.borderedProminent).disabled(ai.isBusy || !ai.modelReady || ai.prompt.isEmpty || ai.prompt.utf8.count>16000 || !ai.pending.isEmpty)
                Button(s.t("aiClearChat")){ai.resetChat()}.disabled(ai.isBusy)
            }
        }
    }
    private func chooseModel() {
        let p=NSOpenPanel();p.canChooseDirectories=false;p.allowsMultipleSelection=false;p.allowedContentTypes=[UTType(filenameExtension:"gguf") ?? .data]
        p.begin{response in if response == .OK,let url=p.url {do{try AIModelFile.validate(url);ai.modelPath=url.resolvingSymlinksInPath().path}catch{ai.error=error.localizedDescription}}}
    }
    private func importConfiguration() {
        let p=NSOpenPanel();p.canChooseDirectories=false;p.allowsMultipleSelection=false;p.allowedContentTypes=[.json]
        p.begin{response in if response == .OK,let url=p.url {
            do {
                let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()}
                ai.configurations=try MCPServerConfiguration.parse(handle.read(upToCount:1_048_577) ?? Data());ai.selectedServer=ai.configurations.first?.id
            }catch{ai.error=error.localizedDescription}
        }}
    }
    private func addHTTP() {
        do{_=try AIEndpoint.validate(manualURL);let value=MCPServerConfiguration(name:manualURL,endpoint:manualURL,bearer:bearer);ai.configurations.append(value);ai.selectedServer=value.id;bearer=""}catch{ai.error=error.localizedDescription}
    }
}
