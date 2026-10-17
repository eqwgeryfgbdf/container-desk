import SwiftUI
import AppKit

struct CreateView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State private var request:CreateRequest
    @State private var submitting=false
    @State private var validation:String?
    @State private var memoryText="512"
    init(initialImage:String="") {
        var draft=CreateRequest();draft.image=initialImage
        _request=State(initialValue:draft)
    }
    private var maxCPUs:Int {max(1,s.host.logicalCores ?? ProcessInfo.processInfo.activeProcessorCount)}
    private var maxMemory:Int {max(200,Int(s.host.memory/1048576))}
    private var validMemory:Bool {Int(memoryText).map{(200...maxMemory).contains($0)} ?? false}
    private var memorySlider:Binding<Double> {
        Binding(get:{Double(min(maxMemory,max(200,request.memoryMB)))},set:{request.memoryMB=Int($0.rounded());memoryText=String(request.memoryMB)})
    }
    var body:some View {
        VStack(alignment:.leading,spacing:0) {
            VStack(alignment:.leading,spacing:8) {
                Text(s.t("createContainer")).font(.title2).fontWeight(.semibold)
                Text(s.t("createSubtitle")).font(.callout).foregroundStyle(.secondary)
            }.padding(24)
            Divider()
            // Keep the actions visible while scrolling long configurations.
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    general
                    resources
                    connections
                    storage
                    advanced
                }.padding(24)
            }.disabled(submitting)
            Divider()
            if let validation {Text(s.t(validation)).foregroundStyle(.red).font(.callout).padding([.horizontal,.top],20).lineLimit(3)}
            HStack {
                if submitting {ProgressView().controlSize(.small);Text(s.t("working"))}
                Spacer()
                Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction).disabled(submitting)
                Button(s.t("create"),action:submit).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(submitting || !s.canMutate || !validMemory || s.imagesLoading || request.name.isEmpty || !s.images.contains(where:{$0.id==request.image}))
            }.padding(20)
        }.frame(width:620,height:640)
        .task {request.cpus=min(request.cpus,maxCPUs);await s.refreshResources()}
        .onChange(of:s.images.map(\.id)) {_,ids in if !ids.contains(request.image){request.image=""}}
    }
    private func group<Content:View>(_ key:String,@ViewBuilder content:()->Content)->some View {
        GroupBox {
            VStack(alignment:.leading,spacing:14,content:content).frame(maxWidth:.infinity,alignment:.leading).padding(10)
        } label:{Text(s.t(key)).font(.headline)}
    }
    private var general:some View {
        group("general") {
            LabeledContent(s.t("name")){TextField("my-service",text:$request.name).textFieldStyle(.roundedBorder).accessibilityLabel(s.t("name"))}
            Picker(s.t("image"),selection:$request.image) {
                Text(s.t("selectImage")).tag("")
                ForEach(s.images){Text($0.id).tag($0.id)}
            }.pickerStyle(.menu).disabled(s.imagesLoading || s.images.isEmpty)
            HStack {
                Text(s.t("localImagesOnly")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if s.imagesLoading{ProgressView().controlSize(.small)}
                Button(s.t("refresh")){Task{await s.refreshResources()}}.disabled(s.imagesLoading)
            }
            if let error=s.imageError {Text(error).font(.caption).foregroundStyle(.red)}
            else if !s.imagesLoading && s.images.isEmpty {Text(s.t("noLocalImages")).font(.caption).foregroundStyle(.secondary)}
        }
    }
    private var resources:some View {
        group("resources") {
            Picker(s.t("cpuAllocation"),selection:$request.cpus){ForEach(1...maxCPUs,id:\.self){Text(String($0)).tag($0)}}.pickerStyle(.menu)
            HStack {
                Text(s.t("memoryLimit"));Spacer()
                TextField(s.t("memoryLimit"),text:$memoryText).multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width:100)
                    .accessibilityLabel(s.t("memoryLimit")+" (MiB)")
                    .onChange(of:memoryText){_,text in if let value=Int(text){request.memoryMB=value}}
                Text("MiB").foregroundStyle(.secondary)
            }
            // macOS 26 draws a mark for every discrete step. A 1 MiB step on a
            // large memory range stalls SliderMarkLabels layout. The binding
            // rounds to whole MiB without creating thousands of native marks.
            Slider(value:memorySlider,in:200...Double(maxMemory)){Text(s.t("memoryLimit"))}.labelsHidden()
            HStack {Text("200 MiB");Spacer();Text(bytes(Int64(maxMemory)*1048576))}.font(.caption).foregroundStyle(.secondary)
            if !validMemory {Text(s.t("allocationOutOfRange")).font(.caption).foregroundStyle(.red)}
        }
    }
    private var connections:some View {
        group("connections") {
            Picker(s.t("network"),selection:$request.network) {
                Text(s.t("defaultNetwork")).tag("")
                ForEach(s.networks){Text($0.id).tag($0.id)}
            }.pickerStyle(.menu)
            LabeledContent(s.t("hostPort")){TextField("8080",text:$request.hostPort).textFieldStyle(.roundedBorder).accessibilityLabel(s.t("hostPort"))}
            LabeledContent(s.t("containerPort")){TextField("80",text:$request.containerPort).textFieldStyle(.roundedBorder).accessibilityLabel(s.t("containerPort"))}
            Picker(s.t("transport"),selection:$request.portTransport){Text("TCP").tag("tcp");Text("UDP").tag("udp")}.pickerStyle(.menu)
            ForEach($request.additionalPorts) { $port in
                HStack {
                    TextField(s.t("hostPort"),text:$port.host).textFieldStyle(.roundedBorder)
                    Image(systemName:"arrow.right").foregroundStyle(.secondary)
                    TextField(s.t("containerPort"),text:$port.container).textFieldStyle(.roundedBorder)
                    Picker(s.t("transport"),selection:$port.transport){Text("TCP").tag("tcp");Text("UDP").tag("udp")}.labelsHidden().frame(width:90)
                    Button {request.additionalPorts.removeAll{$0.id==port.id}} label:{Image(systemName:"minus.circle")}.help(s.t("removeMapping")).accessibilityLabel(s.t("removeMapping"))
                }
            }
            Button(s.t("addPort")){request.additionalPorts.append(PortMapping())}
            Text(s.t("loopbackPort")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var storage:some View {
        group("mounts") {
            Picker(s.t("namedVolume"),selection:$request.namedVolume) {
                Text(s.t("none")).tag("")
                ForEach(s.volumes){Text($0.id).tag($0.id)}
            }.pickerStyle(.menu)
            if !request.namedVolume.isEmpty {
                LabeledContent(s.t("containerPath")){TextField("/data",text:$request.volumeTarget).textFieldStyle(.roundedBorder)}
                Toggle(s.t("readOnly"),isOn:$request.volumeReadOnly)
            }
            Divider()
            HStack {
                Text(request.mountSource.isEmpty ? s.t("noFolder"):request.mountSource).lineLimit(2).truncationMode(.middle)
                Spacer()
                Button(s.t("chooseFolder"),action:chooseFolder)
                if !request.mountSource.isEmpty {Button(s.t("clear")){request.mountSource=""}}
            }
            if !request.mountSource.isEmpty {
                LabeledContent(s.t("containerPath")){TextField("/data",text:$request.mountTarget).textFieldStyle(.roundedBorder)}
                Toggle(s.t("readOnly"),isOn:$request.readOnly)
            }
            ForEach($request.additionalMounts) { $mount in
                Divider()
                VStack(alignment:.leading,spacing:10) {
                    HStack {
                        Picker(s.t("mountType"),selection:$mount.kind) {
                            Text(s.t("hostFolder")).tag(MountMapping.Kind.folder)
                            Text(s.t("namedVolume")).tag(MountMapping.Kind.volume)
                        }.onChange(of:mount.kind){_,_ in mount.source=""}
                        Button {request.additionalMounts.removeAll{$0.id==mount.id}} label:{Image(systemName:"minus.circle")}.help(s.t("removeMapping")).accessibilityLabel(s.t("removeMapping"))
                    }
                    if mount.kind == .folder {
                        HStack {
                            Text(mount.source.isEmpty ? s.t("noFolder"):mount.source).lineLimit(2).truncationMode(.middle)
                            Spacer()
                            Button(s.t("chooseFolder")){chooseAdditionalFolder(mount.id)}
                        }
                    } else {
                        Picker(s.t("namedVolume"),selection:$mount.source) {
                            Text(s.t("none")).tag("")
                            ForEach(s.volumes){Text($0.id).tag($0.id)}
                        }
                    }
                    TextField(s.t("containerPath"),text:$mount.target).textFieldStyle(.roundedBorder)
                    Toggle(s.t("readOnly"),isOn:$mount.readOnly)
                }
            }
            Button(s.t("addMount")){request.additionalMounts.append(MountMapping())}
        }
    }
    private func chooseAdditionalFolder(_ id:UUID) {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
        panel.begin {response in
            if response == .OK,let index=request.additionalMounts.firstIndex(where:{$0.id==id}),request.additionalMounts[index].kind == .folder {
                request.additionalMounts[index].source=panel.url?.path ?? ""
            }
        }
    }
    private var advanced:some View {
        group("advanced") {
            Picker(s.t("architecture"),selection:$request.architecture){Text("arm64").tag("arm64");Text("amd64").tag("amd64")}.pickerStyle(.menu)
            if request.architecture == "amd64" {Toggle(s.t("enableRosetta"),isOn:$request.rosetta)}
            TextField(s.t("entrypointOptional"),text:$request.entrypoint).textFieldStyle(.roundedBorder)
            TextField(s.t("workingDirectoryOptional"),text:$request.workingDirectory).textFieldStyle(.roundedBorder)
            Text(s.t("environment"))
            TextEditor(text:$request.environment).font(.system(.caption,design:.monospaced)).frame(height:70).accessibilityLabel(s.t("environment"))
            Text("KEY=value").font(.caption).foregroundStyle(.secondary)
            Text(s.t("commandArguments"))
            TextEditor(text:$request.commandArguments).font(.system(.caption,design:.monospaced)).frame(height:60).accessibilityLabel(s.t("commandArguments"))
            Text(s.t("argumentsNote")).font(.caption).foregroundStyle(.secondary)
            if let arguments=try? request.arguments() {
                DisclosureGroup(s.t("commandPreview")){Text(([s.cli ?? "container"]+arguments).map(shellQuote).joined(separator:" ")).font(.system(.caption,design:.monospaced)).textSelection(.enabled)}
            }
        }
    }
    private func chooseFolder() {
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false
        panel.begin {response in if response == .OK {request.mountSource=panel.url?.path ?? ""}}
    }
    private func submit() {
        do {
            guard let memory=Int(memoryText),validMemory else {throw DeskError.message("allocationOutOfRange")}
            request.memoryMB=memory;_=try request.arguments();validation=nil;submitting=true
            Task {if await s.create(request){dismiss()}else{validation=s.error};submitting=false}
        }catch{validation=error.localizedDescription}
    }
}
