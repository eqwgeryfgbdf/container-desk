import SwiftUI
import AppKit

struct ComposeProjectsView:View {
    @EnvironmentObject var s:Store
    @StateObject private var library=ComposeProjectLibrary()
    @State private var converting=false
    @State private var converted:URL?
    @State private var selected:String?
    @State private var plan:ComposePlan?
    @State private var failure:String?
    @State private var busy=false
    @State private var action=""
    @State private var targets:[String]=[]
    @State private var owned:[ContainerItem]=[]
    private var record:ComposeProjectRecord?{library.projects.first{$0.id==selected}}
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {Text(s.t("composeProjects")).font(.largeTitle).fontWeight(.semibold);Spacer();Button(s.t("dockerConvert")){converting=true}.disabled(busy);Button(s.t("composeImport"),action:choose).buttonStyle(.borderedProminent).disabled(busy)}
            Text(s.t("composeScopeNote")).foregroundStyle(.secondary)
            if let error=failure ?? library.error {Text(error.hasPrefix("compose") ? s.t(error):error).foregroundStyle(.red).textSelection(.enabled).lineLimit(6)}
            HStack {
                Picker(s.t("composeProject"),selection:$selected) {
                    Text(s.t("selectProject")).tag(String?.none)
                    ForEach(library.projects){Text($0.name).tag(Optional($0.id))}
                }.frame(maxWidth:420)
                Button(s.t("composeValidate")){Task{await validate()}}.disabled(selected==nil || busy || !s.canMutate)
                if busy{ProgressView().controlSize(.small)}
            }
            if let plan {
                Text(plan.source.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                Table(plan.services) {
                    TableColumn(s.t("composeService"),value:\.name).width(min:100,ideal:130)
                    TableColumn(s.t("name"),value:\.container)
                    TableColumn(s.t("image"),value:\.image)
                    TableColumn(s.t("status")){service in Text(s.t(owned.first(where:{$0.id==service.container})?.running==true ? "running":owned.contains(where:{$0.id==service.container}) ? "stopped":"notCreated"))}.width(100)
                }
                ScrollView {
                    VStack(alignment:.leading,spacing:8) {
                        Text(s.t("composeOrder")+": "+plan.services.map(\.name).joined(separator:" → "))
                        Text(s.t("networks")+": "+plan.networks.map{$0.name+($0.external ? " (external)":"")}.joined(separator:", "))
                        Text(s.t("volumes")+": "+plan.volumes.map{$0.name+($0.external ? " (external)":" (\(plan.volumeGiB) GiB)")}.joined(separator:", "))
                        ForEach(plan.services){service in Text(serviceSummary(service))}

                    }.font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                }.frame(maxHeight:145)
                Text(s.t("composeDiscoveryNote")).font(.caption).foregroundStyle(.secondary)
                Text(s.t("composePreviewNote")).font(.caption).foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(s.t("composeImport"),systemImage:"square.stack.3d.up")
                    .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.center)
            }
            if record != nil {
                HStack {
                    Button(s.t("composeUp")){action="up"}.buttonStyle(.borderedProminent).disabled(plan==nil || !s.canMutate || busy)
                    Button(s.t("composeStop")){prepareManage("stop")}.disabled(!s.canMutate || owned.isEmpty || busy)
                    Button(s.t("composeDown"),role:.destructive){prepareManage("down")}.disabled(!s.canMutate || owned.isEmpty || busy)
                }
            }

        }.padding(28).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
        .sheet(isPresented:$converting,onDismiss:{if let url=converted{converted=nil;importProject(url)}}) {
            DockerMigrationView{converted=$0}.environmentObject(s)
        }
        .onChange(of:selected){_,_ in Task{await validate()}}
        .onChange(of:s.operationRunning){_,running in if !running{Task{await refreshOwned()}}}
        .confirmationDialog(s.t(action=="up" ? "composeUp":action=="stop" ? "composeStop":"composeDown"),isPresented:Binding(get:{!action.isEmpty},set:{if !$0{action=""}}),titleVisibility:.visible) {
            Button(s.t("continue"),role:action=="up" ? nil:.destructive) {
                if action=="up",let plan{s.composeUp(plan)}
                else if let record{s.composeManage(record.id,ids:targets,remove:action=="down")}
                action=""
            }
            Button(s.t("cancel"),role:.cancel){action=""}
        } message:{Text((action=="up" ? plan?.services.map(\.container) ?? []:targets).joined(separator:"\n")+"\n"+s.t(action=="up" ? "composeStartNote":"composeRetainData"))}
    }
    private func diagnostic(_ error:Error)->String {
        if let issue=error as? ComposeIssue {return issue.path+": "+s.t(issue.reason)}
        return s.t(error.localizedDescription)
    }
    private func serviceSummary(_ service:ComposeService)->String {
        var lines:[String]=[]
        let mounts=service.mounts.map{$0.source+":"+$0.target+($0.readOnly ? ":ro":"")}
        let ports=service.ports.map{"127.0.0.1:"+$0.host+":"+$0.container+"/"+$0.transport}
        for (values,key) in [(mounts,"mounts"),(ports,"ports")] {
            if !values.isEmpty{lines.append("\(service.name) · \(s.t(key)): \(values.joined(separator:", "))")}
        }
        if !service.command.isEmpty {lines.append("\(service.name) · \(s.t("commandArguments")): \(service.command.map(shellQuote).joined(separator:" "))")}
        if let build=service.buildArguments {lines.append("\(service.name) · \(s.t("buildContext")): \(build.last ?? "")")}
        return lines.joined(separator:"\n")
    }
    private func choose() {
        let panel=NSOpenPanel();panel.canChooseDirectories=false;panel.allowsMultipleSelection=false
        panel.begin {response in
            guard response == .OK,let url=panel.url else{return}
            importProject(url)
        }
    }
    private func importProject(_ url:URL) {
        do {let record=try library.add(url);selected=record.id;Task{await validate()}}catch{failure=diagnostic(error);plan=nil}
    }
    private func validate()async {
        guard let record=library.projects.first(where:{$0.id==selected}) else{plan=nil;return}
        busy=true;defer{busy=false}
        do{plan=try ComposePlanner(file:URL(fileURLWithPath:record.path),projectID:record.id,volumeGiB:record.volumeGiB).plan();failure=nil}catch{plan=nil;failure=diagnostic(error)}
        await refreshOwned()
    }
    private func refreshOwned()async {
        guard let record else{owned=[];return}
        do {let rows=try await s.composeOwned(record.id);owned=try ContainerItem.parse(JSONSerialization.data(withJSONObject:rows))}catch{owned=[];failure=diagnostic(error)}
    }
    private func prepareManage(_ verb:String) {
        Task {
            busy=true;await refreshOwned();busy=false
            guard record != nil,!owned.isEmpty else{return}
            // Include older owned services visibly, but never unrelated containers.
            let ordered=plan?.services.reversed().map(\.container) ?? []
            targets=ordered.filter{id in owned.contains{$0.id==id}}+owned.map(\.id).filter{!ordered.contains($0)}.sorted()
            action=verb
        }
    }
}
