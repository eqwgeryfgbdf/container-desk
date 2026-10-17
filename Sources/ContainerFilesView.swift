import SwiftUI
import AppKit

struct ContainerFilesView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let containerID:String
    @State private var directory="/"
    @State private var pathText="/"
    @State private var files:[ContainerFile]=[]
    @State private var selection:String?
    @State private var loading=false
    @State private var failure:String?
    @State private var query=""
    @State private var editMode=""
    @State private var editName=""
    @State private var deleting:String?
    @State private var token=UUID()
    private var selected:ContainerFile?{files.first{$0.id==selection}}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Text(s.t("files")+" · "+containerID).font(.title2).fontWeight(.semibold);Spacer();Button(s.t("close")){dismiss()}.keyboardShortcut(.cancelAction)}
            Text(s.t("filesNote")).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button {navigate(URL(fileURLWithPath:directory).deletingLastPathComponent().path)} label:{Image(systemName:"arrow.up")}.help(s.t("parentFolder")).accessibilityLabel(s.t("parentFolder")).disabled(directory=="/")
                TextField(s.t("containerPath"),text:$pathText).textFieldStyle(.roundedBorder).onSubmit{navigate(pathText)}
                Button(s.t("go")){navigate(pathText)}
                Button(s.t("refresh")){token=UUID()}.disabled(loading)
            }
            HStack {
                TextField(s.t("searchFiles"),text:$query).textFieldStyle(.roundedBorder).frame(maxWidth:300)
                Spacer()
                Button(s.t("newFolder")){editName="";editMode="mkdir"}.disabled(!s.canMutate || loading)
                Button(s.t("uploadFile"),action:upload).disabled(!s.canMutate || loading)
            }
            if let failure {Text(s.t(failure)).font(.callout).foregroundStyle(.red).textSelection(.enabled).lineLimit(3)}
            Table(files.filter{query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)},selection:$selection) {
                TableColumn(s.t("name")){file in Label(file.name,systemImage:file.directory ? "folder":file.kind=="l" ? "link":"doc").help(file.name)}
                TableColumn(s.t("type")){file in Text(s.t(file.directory ? "folder":file.kind=="l" ? "symbolicLink":file.kind=="f" ? "file":"otherFile"))}.width(130)
            }.contextMenu(forSelectionType:String.self) {ids in
                if let name=ids.first,ids.count==1 {
                    Button(s.t("copyPath")){if let path=try? FileOperations.child(directory,name){Clipboard.copy(path)}}
                }
            } primaryAction:{ids in if let name=ids.first,ids.count==1,files.first(where:{$0.name==name})?.directory==true {if let next=try? FileOperations.child(directory,name){navigate(next)}}}
            if let selected {
                HStack {
                    Button(s.t("downloadFile")){download(selected)}.disabled(!s.canMutate || !["f","d"].contains(selected.kind))
                    Button(s.t("renameFile")){editName=selected.name;editMode="rename"}.disabled(!s.canMutate)
                    Button(s.t("delete"),role:.destructive){deleting=selected.name}.disabled(!s.canMutate)
                }
            }
            if s.operationRunning || !s.operationTitle.isEmpty {
                Divider()
                HStack {Text(s.t(s.operationTitle));Spacer();if s.operationRunning {ProgressView().controlSize(.small);Button(s.t("cancel")){s.cancelOperation()}}else if let result=s.operationResult{Text(s.t(result)).foregroundStyle(.secondary)}}
                ScrollView{Text(s.operationOutput).font(.system(.caption,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(height:65)
            }
        }.padding(24).frame(width:850,height:650)
        .task(id:token){await refresh()}
        .onChange(of:s.operationRunning){_,running in if !running{token=UUID()}}
        .alert(s.t(editMode=="mkdir" ? "newFolder":"renameFile"),isPresented:Binding(get:{!editMode.isEmpty},set:{if !$0{editMode=""}})) {
            TextField(s.t("name"),text:$editName)
            Button(s.t("cancel"),role:.cancel){editMode=""}
            Button(s.t("continue")){edit();editMode=""}
        } message:{Text(s.t("fileNoOverwrite"))}
        .confirmationDialog(s.t("deleteFileConfirm"),isPresented:Binding(get:{deleting != nil},set:{if !$0{deleting=nil}}),titleVisibility:.visible) {
            Button(s.t("delete"),role:.destructive){if let name=deleting {run("delete"){try FileOperations.remove(containerID,FileOperations.child(directory,name))}};deleting=nil}
            Button(s.t("cancel"),role:.cancel){deleting=nil}
        } message:{Text((deleting ?? "")+"\n"+s.t("deleteFileNote"))}
    }
    private func navigate(_ path:String) {
        do {directory=try FileOperations.path(path);pathText=directory;files=[];selection=nil;token=UUID()}catch{failure=error.localizedDescription}
    }
    private func refresh() async {
        guard let cli=s.cli else{return};loading=true;defer{loading=false}
        do {
            let result=try await ProcessRunner.checked(cli,FileOperations.listing(containerID,directory))
            try Task.checkCancellation();files=try ContainerFile.parse(result.data);failure=nil
            if !files.contains(where:{$0.id==selection}){selection=nil}
        }catch{if !Task.isCancelled{files=[];failure=error.localizedDescription}}
    }
    private func run(_ title:String,_ args:()throws->[String]) {
        do{let arguments=try args();failure=nil;s.fileCommand(containerID,title:title,arguments:arguments)}catch{failure=error.localizedDescription}
    }
    private func edit() {
        run(editMode=="mkdir" ? "newFolder":"renameFile") {
            let destination=try FileOperations.child(directory,editName)
            if editMode=="mkdir" {return try FileOperations.mkdir(containerID,destination)}
            guard let selection else{throw DeskError.message("invalidFilePath")}
            return try FileOperations.rename(containerID,FileOperations.child(directory,selection),destination)
        }
    }
    private func upload() {
        let parent=directory
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=true;panel.allowsMultipleSelection=false
        panel.begin {response in
            guard response == .OK,let url=panel.url else{return}
            do {
                guard try url.resourceValues(forKeys:[.isSymbolicLinkKey]).isSymbolicLink != true else{throw DeskError.message("fileSymlinkUpload")}
                s.transferFile(containerID,local:url,remote:try FileOperations.child(parent,url.lastPathComponent),upload:true)
            }catch{failure=error.localizedDescription}
        }
    }
    private func download(_ file:ContainerFile) {
        let source=try? FileOperations.child(directory,file.name)
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.prompt=s.t("downloadFile")
        panel.begin {response in
            guard response == .OK,let parent=panel.url,let source else{return}
            s.transferFile(containerID,local:parent.appendingPathComponent(file.name),remote:source,upload:false)
        }
    }
}
