import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ResourceManagementView: View {
    @EnvironmentObject var s:Store
    let kind:ResourceKind
    @State private var query=""
    @State private var selection=Set<String>()
    @State private var editor:ResourceRequest?
    @State private var submitted:ResourceRequest?
    @State private var deleting:ResourceBatchDeletion?
    @State private var submittedDeletion:ResourceBatchDeletion?
    @State private var quickDeploy=false
    @State private var createImage:String?
    @State private var pushSource:String?
    @State private var pushSubmission:(String,String,Bool)?
    private var items:[ResourceItem] {kind == .image ? s.images : kind == .network ? s.networks : s.volumes}
    private var filtered:[ResourceItem] {items.filter{query.isEmpty || $0.id.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query)}}
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                VStack(alignment:.leading,spacing:6) {
                    Text(s.t(kind.title)).font(.largeTitle).fontWeight(.semibold)
                    Text(s.t("resourceManagementSubtitle")).foregroundStyle(.secondary)
                }
                Spacer()
                if kind == .image {
                    Button(s.t("deployUnified")){quickDeploy=true}.buttonStyle(.borderedProminent).disabled(!s.canMutate)
                    Button(s.t("build")){editor=ResourceRequest(operation:.build)}.disabled(!s.canMutate)
                    Button(s.t("load")){chooseImport()}.disabled(!s.canMutate)
                } else {
                    Button(s.t("create")){editor=ResourceRequest(operation:kind == .network ? .createNetwork : .createVolume)}.buttonStyle(.borderedProminent).disabled(!s.canMutate)
                }
            }
            HStack {
                TextField(s.t("searchResources"),text:$query).textFieldStyle(.roundedBorder).frame(maxWidth:320)
                Text("\(filtered.count)").monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Button(s.t("refresh")){Task{await s.refreshResources()}}.disabled(s.imagesLoading || s.busy)
            }
            HStack {
                SelectionControls(selection:$selection,visibleIDs:filtered.map(\.id))
                Spacer()
                Button(s.t("deleteSelected"),role:.destructive){deleting=ResourceBatchDeletion(kind:kind,ids:selection.sorted())}
                    .disabled(selection.isEmpty || !s.canMutate)
            }
            Table(filtered,selection:$selection) {
                TableColumn(s.t("select")){item in SelectionCheckbox(id:item.id,label:s.t("select")+" "+item.id,selection:$selection)}.width(36)
                TableColumn(s.t("name")){item in Label(item.id,systemImage:kind.icon).help(item.id)}.width(min:220,ideal:380)
                TableColumn(s.t("details"),value:\.detail)
                TableColumn(s.t(kind == .network ? "type":"size"),value:\.extra)
            }
            .contextMenu(forSelectionType:String.self) { ids in
                if let id=ids.first,ids.count==1 {actions(id)}
                if ids.count>1 {
                    Button(s.t("copyNames")){Clipboard.copy(ids.sorted().joined(separator:"\n"))}
                    Button(s.t("deleteSelected"),role:.destructive){deleting=ResourceBatchDeletion(kind:kind,ids:ids.sorted())}.disabled(!s.canMutate)
                }
            } primaryAction: {ids in if let id=ids.first,ids.count==1{s.inspection=InspectionTarget(kind:kind,name:id)}}
            .overlay {if filtered.isEmpty {ContentUnavailableView.search(text:query)}}
            if selection.count==1,let id=selection.first,items.contains(where:{$0.id==id}) {
                HStack(spacing:12) {actions(id)}
            }
        }.padding(28)
        .onChange(of:filtered.map(\.id)){_,ids in selection.formIntersection(Set(ids))}
        .onChange(of:kind){_,_ in selection=[];query=""}
        .task {await s.refreshResources()}
        .sheet(isPresented:$quickDeploy) {
            QuickDeployView().environmentObject(s)
        }
        .sheet(item:$editor,onDismiss:{if let request=submitted{submitted=nil;s.resourceOperation(request)}}) {request in
            ResourceEditor(request:request) {submitted=$0;editor=nil}.environmentObject(s)
        }
        .sheet(isPresented:Binding(get:{pushSource != nil},set:{if !$0{pushSource=nil}}),onDismiss:{if let (source,target,http)=pushSubmission{pushSubmission=nil;s.pushImage(source:source,target:target,localHTTP:http)}}) {
            ImagePushView(source:pushSource ?? ""){target,http in pushSubmission=(pushSource ?? "",target,http)}.environmentObject(s)
        }
        .sheet(isPresented:Binding(get:{createImage != nil},set:{if !$0{createImage=nil}})) {
            CreateView(initialImage:createImage ?? "").environmentObject(s)
        }
        .sheet(item:$deleting,onDismiss:{
            if let request=submittedDeletion{submittedDeletion=nil;s.deleteResources(request)}
        }) {request in
            ResourceDeletionReview(request:request){submittedDeletion=$0;deleting=nil}.environmentObject(s)
        }
    }
    @ViewBuilder private func actions(_ id:String)->some View {
        Button(s.t("inspect")){s.inspection=InspectionTarget(kind:kind,name:id)}
        Button(s.t("copyName")){Clipboard.copy(id)}
        if kind == .image {
            Button(s.t("createContainer")){createImage=id}.disabled(!s.canMutate)
            Button(s.t("tag")){var request=ResourceRequest(operation:.tag);request.source=id;editor=request}.disabled(!s.canMutate)
            Button(s.t("pushImage")){pushSource=id}.disabled(!s.canMutate)
            Button(s.t("save")){chooseExport(id)}.disabled(!s.canMutate)
        }
        Button(s.t("delete"),role:.destructive){deleting=ResourceBatchDeletion(kind:kind,ids:[id])}.disabled(!s.canMutate || (kind == .network && ["default","none"].contains(id)))
    }
    private func chooseImport() {
        let panel=NSOpenPanel();panel.canChooseDirectories=false;panel.allowsMultipleSelection=false
        panel.begin {response in if response == .OK,let url=panel.url {var request=ResourceRequest(operation:.load);request.path=url.path;s.resourceOperation(request)}}
    }
    private func chooseExport(_ id:String) {
        let panel=NSSavePanel();panel.nameFieldStringValue="image.tar";panel.allowedContentTypes=[.tarArchive]
        panel.begin {response in if response == .OK,let url=panel.url {var request=ResourceRequest(operation:.save);request.source=id;request.path=url.path;s.resourceOperation(request)}}
    }
}

extension ResourceRequest:Identifiable { var id:String {operation.rawValue+source} }

struct ResourceEditor:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State var request:ResourceRequest
    let submit:(ResourceRequest)->Void
    @State private var validation:String?
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            Text(s.t(request.operation.rawValue)).font(.title2).fontWeight(.semibold)
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    if !request.source.isEmpty {LabeledContent(s.t("source"),value:request.source).textSelection(.enabled)}
                    TextField(s.t(request.operation == .pull || request.operation == .build || request.operation == .tag ? "image":"name"),text:$request.name).textFieldStyle(.roundedBorder)
                    if request.operation == .pull || request.operation == .build {
                        Picker(s.t("architecture"),selection:$request.architecture){Text("Apple Silicon (arm64)").tag("arm64");Text("Intel / AMD (amd64)").tag("amd64")}.pickerStyle(.menu)
                        Text(s.t("architectureNote")).font(.caption).foregroundStyle(.secondary)
                    }
                    if request.operation == .build {
                        HStack {Text(request.path.isEmpty ? s.t("buildContext"):request.path).lineLimit(2).textSelection(.enabled);Spacer();Button(s.t("chooseFolder")){chooseContext()}}
                        TextField(s.t("dockerfile"),text:$request.dockerfile).textFieldStyle(.roundedBorder)
                        Toggle(s.t("noCache"),isOn:$request.noCache)
                        Text(s.t("buildImpact")).font(.caption).foregroundStyle(.secondary)
                    }
                    if request.operation == .createNetwork {
                        TextField(s.t("subnetOptional"),text:$request.subnet,prompt:Text("192.168.70.0/24")).textFieldStyle(.roundedBorder)
                        Toggle(s.t("internalNetwork"),isOn:$request.internalNetwork)
                    }
                    if request.operation == .createVolume {
                        TextField(s.t("volumeSizeGiB"),text:$request.volumeGiB).textFieldStyle(.roundedBorder)
                        Text(s.t("volumeSizeNote")).font(.caption).foregroundStyle(.secondary)
                    }
                    if let arguments=try? request.arguments() {
                        DisclosureGroup(s.t("commandPreview")) {Text(([s.cli ?? "container"]+arguments).map(shellQuote).joined(separator:" ")).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}
                    }
                }.padding(2)
            }
            if let validation {Text(s.t(validation)).foregroundStyle(.red)}
            HStack {Spacer();Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction);Button(s.t("continue")){
                do{_=try request.arguments();submit(request)}catch{validation=error.localizedDescription}
            }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(!s.canMutate)}
        }.padding(24).frame(width:580,height:460)
    }
    private func chooseContext() {
        let panel=NSOpenPanel();panel.canChooseFiles=false;panel.canChooseDirectories=true
        panel.begin {response in if response == .OK,let url=panel.url {request.path=url.path}}
    }
}

enum Clipboard {
    @MainActor static func copy(_ text:String) {NSPasteboard.general.clearContents();NSPasteboard.general.setString(text,forType:.string)}
}

struct OperationProgressView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack {Text(s.t(s.operationTitle)).font(.title2).fontWeight(.semibold);Spacer();if s.operationRunning{ProgressView().controlSize(.small)}}
            Text(s.t(s.operationResult ?? "working")).foregroundStyle(s.operationResult == "operationComplete" ? Color.green:Color.primary).textSelection(.enabled)
            ScrollView([.horizontal,.vertical]) {Text(s.operationOutput.isEmpty ? s.t("waitingForOutput"):s.operationOutput).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.topLeading).padding(12)}
                .background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:8))
            Text(s.t("operationOutputNote")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(s.t("copyOutput")){Clipboard.copy(s.operationOutput)}.disabled(s.operationOutput.isEmpty)
                Spacer()
                if s.operationRunning {Button(s.t("cancel")){s.cancelOperation()}}
                Button(s.t(s.operationRunning ? "runInBackground":"close")){dismiss()}.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width:740,height:500)
    }
}

struct InspectionView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let target:InspectionTarget
    @State private var text=""
    @State private var failure:String?
    @State private var loading=true
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("inspect")+" · "+target.name).font(.title2).lineLimit(2)
            Text(s.t("inspectPrivacy")).font(.caption).foregroundStyle(.secondary)
            if loading {ProgressView()}
            if let failure {Text(s.t(failure)).foregroundStyle(.red)}
            ScrollView([.horizontal,.vertical]) {Text(text).font(.system(.caption,design:.monospaced)).textSelection(.enabled).padding(12).frame(maxWidth:.infinity,alignment:.leading)}.background(Color(nsColor:.textBackgroundColor))
            HStack {Button(s.t("copyOutput")){Clipboard.copy(text)}.disabled(text.isEmpty);Button(s.t("exportJSON")){export()}.disabled(text.isEmpty);Spacer();Button(s.t("close")){dismiss()}.keyboardShortcut(.cancelAction)}
        }.padding(24).frame(width:800,height:580)
        .task {
            defer{loading=false}
            guard let cli=s.cli else {failure="coreMissing";return}
            do {
                let result=try await ProcessRunner.checked(cli,target.arguments)
                let object=try JSONSerialization.jsonObject(with:result.data)
                text=String(decoding:try JSONSerialization.data(withJSONObject:object,options:[.prettyPrinted,.sortedKeys,.fragmentsAllowed]),as:UTF8.self)
            }catch{failure=error.localizedDescription}
        }
    }
    private func export() {
        let panel=NSSavePanel();panel.nameFieldStringValue="inspect.json";panel.allowedContentTypes=[.json]
        panel.begin {response in if response == .OK,let url=panel.url {do{try text.write(to:url,atomically:true,encoding:.utf8)}catch{failure=error.localizedDescription}}}
    }
}

struct ContainerUtilityActions:View {
    @EnvironmentObject var s:Store
    let item:ContainerItem
    var body:some View {
        Button(s.t("inspect")){s.inspection=InspectionTarget(kind:nil,name:item.id)}
        Button(s.t("snapshotTitle")){s.snapshotSource=item.id}.disabled(!s.canMutate)
        Button(s.t("files")){s.fileContainer=item.id}.disabled(!item.running || !s.canMutate)
        Button(s.t("openTerminal")){Task{await s.openTerminal(item)}}.disabled(!item.running || !s.canMutate)
        Button(s.t("restart")){s.restartCandidate=item}.disabled(!item.running || !s.canMutate)
    }
}
