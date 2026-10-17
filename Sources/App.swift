import SwiftUI
import AppKit

@main struct ContainerDeskApp: App {
    @StateObject private var store=Store()
    @StateObject private var core=CoreManager()
    @StateObject private var zoom=ContentZoom()
    var body: some Scene {
        WindowGroup("Container Desk") {
            MainView().environmentObject(store).environmentObject(core).environmentObject(zoom)
                .environment(\.locale,Locale(identifier:store.localeID))
                .preferredColorScheme(store.colorScheme)
                .frame(minWidth:1100,minHeight:640)
                .task {
                    await store.start()
                    while !Task.isCancelled {
                        await core.periodic(store)
                        try? await Task.sleep(nanoseconds:5_000_000_000)
                        await store.refresh()
                    }
                }
        }
        .defaultSize(width:1320,height:860)
        .commands {
            CommandGroup(after:.sidebar) {
                Divider()
                Button(store.t("zoomIn"),action:zoom.increase).keyboardShortcut("+",modifiers:.command).disabled(!zoom.canIncrease)
                Button(store.t("zoomOut"),action:zoom.decrease).keyboardShortcut("-",modifiers:.command).disabled(!zoom.canDecrease)
                Button(store.t("actualSize"),action:zoom.reset).keyboardShortcut("0",modifiers:.command).disabled(zoom.percent==100)
            }
            CommandGroup(after:.newItem) {
                Button(store.t("refresh")){Task{await store.refresh()}}.keyboardShortcut("r",modifiers:.command)
                Button(store.t("coreUpdates")){store.section="core"}.keyboardShortcut("u",modifiers:[.command,.shift])
            }
        }
        Settings {
            PreferencesView().environmentObject(store).environmentObject(core)
                .environment(\.locale,Locale(identifier:store.localeID))
                .preferredColorScheme(store.colorScheme)
        }
    }
}
struct MainView:View {
    @ReducedInterfaceMotion private var reduceMotion
    @EnvironmentObject var zoom:ContentZoom
    @EnvironmentObject var s:Store
    @EnvironmentObject var core:CoreManager
    @State private var selectedIDs=Set<String>()
    @State private var batchReview:BatchRequest?
    @State private var submittedBatch:BatchRequest?
    @State private var create=false
    @State private var pending:ContainerItem?
    @State private var verb=""
    @State private var expandedContainerID:String?
    @State private var columnVisibility:NavigationSplitViewVisibility = .all
    @State private var previousColumnVisibility:NavigationSplitViewVisibility = .all
    private let sections=[("overview","chart.bar.xaxis"),("containers","shippingbox"),("images","square.stack.3d.up"),("networks","network"),("volumes","externaldrive")]
    var body:some View {
        NavigationSplitView(columnVisibility:$columnVisibility) {
            VStack(alignment:.leading,spacing:0) {
                HStack(spacing:10){Image(systemName:"shippingbox").font(.title2);Text("Container Desk").font(.headline)}.padding(.horizontal,18).padding(.top,16).padding(.bottom,22)
                HStack(spacing:9){Image(systemName:s.host.icon).foregroundStyle(.secondary);VStack(alignment:.leading,spacing:3){Text(s.host.name).font(.subheadline).lineLimit(1);Label(s.t(s.connected ? "connected":"disconnected"),systemImage:s.connected ? "checkmark.circle.fill":"circle").font(.caption).foregroundStyle(s.connected ? Color.green:Color.secondary)}}.padding(.horizontal,18).padding(.bottom,18)
                List(selection:$s.section) {
                    Section(s.t("manage")) {
                        ForEach(sections,id:\.0){ section in Label(s.t(section.0),systemImage:section.1).tag(section.0).padding(.vertical,3) }
                    }
                    Section(s.t("system")) {
                        Label(s.t("core"),systemImage:"cpu").tag("core").padding(.vertical,3)
                        Label(s.t("settings"),systemImage:"gearshape").tag("settings").padding(.vertical,3)
                    }
                }.listStyle(.sidebar)
                Divider().padding(.horizontal,16)
                HStack{Image(systemName:"apple.terminal");Text("Apple Container").font(.caption);Spacer()}.foregroundStyle(.secondary).padding(18)
            }.navigationSplitViewColumnWidth(min:205,ideal:230,max:280)
        } detail: {
            VStack(spacing:0) {
                if let error=s.error {HStack(alignment:.top){Image(systemName:"exclamationmark.triangle");Text(s.t(error)).font(.callout).textSelection(.enabled).lineLimit(3);Spacer();Button{ s.error=nil }label:{Image(systemName:"xmark")}.buttonStyle(.plain)}.padding(12).background(Color.red.opacity(0.08))}
                ZoomableContent(minimumWidth: expandedContainerID == nil ? 860 : 720) {
                    Group {
                        switch s.section {
                        case "overview": OverviewView()
                        case "containers": containerContent
                        case "images": ResourceManagementView(kind:.image)
                        case "networks": ResourceManagementView(kind:.network)
                        case "volumes": ResourceManagementView(kind:.volume)
                        case "core": CoreView()
                        default: PreferencesView()
                        }
                    }.modifier(InterfaceFade(value:s.section))
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                Divider()
                HStack(spacing:8){
                    if s.busy || s.refreshing || s.operationRunning {ProgressView().controlSize(.small)}
                    Text(s.t(s.busy ? "working" : s.connected ? "liveData":"disconnected")).font(.caption)
                    if let notice=s.notice {Text("· "+notice).font(.caption).lineLimit(1)}
                    Spacer()
                    if !s.operationTitle.isEmpty {
                        Button(s.t(s.operationRunning ? "working":"lastOperation")){s.operationPresented=true}.buttonStyle(.link)
                    }
                    Menu {
                        Picker(s.t("contentZoom"),selection:Binding(get:{zoom.percent},set:zoom.set)) {
                            ForEach(ContentZoom.levels,id:\.self){ Text("\($0)%").tag($0) }
                        }
                        Divider()
                        Button(s.t("actualSize"),action:zoom.reset)
                    } label: {
                        Text("\(zoom.percent)%").monospacedDigit()
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel(s.t("contentZoom"))
                    .help(s.t("zoomHelp"))
                    if let d=s.lastRefresh {Text(s.t("updated")+" "+d.formatted(date:.omitted,time:.standard)).font(.caption).monospacedDigit()}
                }.foregroundStyle(.secondary).padding(.horizontal,20).padding(.vertical,10)
            }
            .navigationTitle(expandedContainerID ?? s.t(s.section))
            .toolbar {
                if expandedContainerID != nil {
                    ToolbarItem(placement:.navigation) {
                        Button(action:closeContainerDetails) {
                            Label(s.t("backToContainers"),systemImage:"arrow.left")
                        }
                        .keyboardShortcut(.escape,modifiers:[])
                        .help(s.t("backToContainers"))
                    }
                }
                ToolbarItemGroup(placement:.primaryAction) {
                    Button{Task{await s.refresh()}}label:{Label(s.t("refresh"),systemImage:"arrow.clockwise")}.disabled(s.busy || s.refreshing)
                    if s.section=="containers" || s.section=="overview" {
                        Button{create=true}label:{Label(s.t("createContainer"),systemImage:"plus")}.buttonStyle(.borderedProminent).disabled(!s.canMutate)
                    }
                }
            }
        }
        .transaction { transaction in
            if reduceMotion { transaction.animation=nil; transaction.disablesAnimations=true }
        }
        .onChange(of:s.section) { _,_ in closeContainerDetails() }
        .onChange(of:s.selected) { _,selection in
            if let expandedContainerID,selection != expandedContainerID {closeContainerDetails()}
        }
        .onChange(of:s.containers.map(\.id)) { _,ids in
            if let expandedContainerID,!ids.contains(expandedContainerID) {closeContainerDetails()}
        }
        .onChange(of:selectedIDs) {_,ids in s.selected=ids.count==1 ? ids.first:nil}
        .onChange(of:s.selected) {_,id in
            if selectedIDs.count<=1 {selectedIDs=Set(id.flatMap{value in s.filtered.contains(where:{$0.id==value}) ? [value]:nil} ?? [])}
        }
        .onChange(of:s.query) {_,_ in trimSelection()}
        .onChange(of:s.filter) {_,_ in trimSelection()}
        .onChange(of:s.containers.map(\.id)) {_,_ in trimSelection()}
        .sheet(item:$batchReview,onDismiss:{
            if let request=submittedBatch {submittedBatch=nil;s.batchOperation(request)}
        }) {request in BatchReviewView(request:request){submittedBatch=$0}.environmentObject(s)}
        .sheet(isPresented:$create){CreateView().environmentObject(s)}
        .sheet(isPresented:$s.operationPresented){OperationProgressView().environmentObject(s)}
        .sheet(item:$s.inspection){InspectionView(target:$0).environmentObject(s)}
        .confirmationDialog(s.t("restartConfirm"),isPresented:Binding(get:{s.restartCandidate != nil},set:{if !$0{s.restartCandidate=nil}}),titleVisibility:.visible) {
            Button(s.t("restart"),role:.destructive){if let item=s.restartCandidate{Task{await s.action("restart",item)}};s.restartCandidate=nil}
            Button(s.t("cancel"),role:.cancel){s.restartCandidate=nil}
        } message:{Text((s.restartCandidate?.id ?? "")+"\n"+s.t("restartImpact"))}
        .confirmationDialog(s.t(verb=="delete" ? "deleteConfirm":"stopConfirm"),isPresented:Binding(get:{pending != nil},set:{if !$0{pending=nil}}),titleVisibility:.visible) {
            if let c=pending {Button(s.t(verb),role:.destructive){Task{await s.action(verb,c)};pending=nil}}
            Button(s.t("cancel"),role:.cancel){pending=nil}
        } message:{Text((pending?.id ?? "")+"\n"+s.t(verb=="delete" ? "deleteImpact":"stopImpact"))}
    }
    func trimSelection() {selectedIDs.formIntersection(Set(s.filtered.map(\.id)))}
    func reviewBatch(_ verb:BatchVerb,_ ids:Set<String>) {
        batchReview=BatchRequest(verb:verb,items:s.containers.filter{ids.contains($0.id)})
    }
    func banner(_ title:String,symbol:String,color:Color)->some View {Label(title,systemImage:symbol).font(.callout).frame(maxWidth:.infinity,alignment:.leading).padding(12).background(color.opacity(0.08))}
    func openContainerDetails(_ ids:Set<String>) {
        guard ids.count==1,let id=ids.first,s.containers.contains(where:{$0.id==id}) else{return}
        selectedIDs=[id];s.selected=id
        previousColumnVisibility=columnVisibility
        withAnimation(InterfaceMotion.layout(reduceMotion:reduceMotion)) {
            expandedContainerID=id
            columnVisibility = .detailOnly
        }
    }
    func closeContainerDetails() {
        guard expandedContainerID != nil else{return}
        withAnimation(InterfaceMotion.layout(reduceMotion:reduceMotion)) {
            expandedContainerID=nil
            columnVisibility=previousColumnVisibility
        }
    }
    var containerContent:some View {
        containerBody.modifier(InterfaceFade(value:expandedContainerID))
    }
    @ViewBuilder private var containerBody:some View {
        if s.cli==nil {
            ContentUnavailableView{Label(s.t("coreMissing"),systemImage:"shippingbox")}description:{Text(s.t("dependency"))}actions:{Button(s.t("setupCore")){s.section="core"}.buttonStyle(.borderedProminent)}
        } else if let id=expandedContainerID,let c=s.containers.first(where:{$0.id==id}) {
            ContainerDetailView(item:c,onStop:{verb="stop";pending=c},onDelete:{verb="delete";pending=c})
                .id(c.id)
                .frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
        } else {
            HSplitView {
                VStack(spacing:0) {
                    HStack{Text("\(s.containers.count) "+s.t("total")).font(.callout);Text("·").foregroundStyle(.tertiary);Label("\(s.active) "+s.t("running"),systemImage:"circle.fill").foregroundStyle(.green).font(.callout);Spacer()}.padding(20)
                    HStack(spacing:18){TextField(s.t("searchContainers"),text:$s.query).textFieldStyle(.roundedBorder).frame(maxWidth:280)
                        Picker(s.t("filter"),selection:$s.filter){Text(s.t("all")).tag("all");Text(s.t("running")).tag("running");Text(s.t("stopped")).tag("stopped")}.pickerStyle(.segmented).labelsHidden().frame(maxWidth:260)
                    }.padding(.horizontal,20).padding(.bottom,16)
                    if !selectedIDs.isEmpty {
                        HStack {
                            Text(s.t("selectedCount")+": \(selectedIDs.count)").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Menu(s.t("batchOperations")) {
                                ForEach(BatchVerb.allCases,id:\.self){action in
                                    Button(s.t(action.rawValue)){reviewBatch(action,selectedIDs)}
                                }
                            }.disabled(!s.canMutate)
                        }.padding(.horizontal,20).padding(.bottom,8)
                    }
                    Table(s.filtered,selection:$selectedIDs) {
                        TableColumn(s.t("name")){c in Label(c.id,systemImage:"shippingbox").fontWeight(.medium).help(c.id) .frame(minHeight:38)}.width(min:170,ideal:235)
                        TableColumn(s.t("status")){c in StatusView(item:c)}.width(min:85,ideal:95)
                        TableColumn("CPU"){c in Text(s.usage[c.id]?.cpu.map{String(format:"%.1f%%",$0)} ?? "—").monospacedDigit()}.width(65)
                        TableColumn(s.t("memory")){c in Text(s.usage[c.id].map{bytes($0.memory)} ?? "—").monospacedDigit()}.width(min:75,ideal:90)
                    }
                    .tableStyle(.inset(alternatesRowBackgrounds:false))
                    .contextMenu(forSelectionType:String.self){ids in
                        if ids.count==1,let id=ids.first,let c=s.containers.first(where:{$0.id==id}){
                            Button(s.t("expandContainerDetails")){openContainerDetails(ids)}
                            ContainerUtilityActions(item:c)
                            Divider()
                            Button(s.t(c.running ? "stop":"start")){if c.running{verb="stop";pending=c}else{Task{await s.action("start",c)}}}.disabled(!s.canMutate)
                            Button(s.t("delete"),role:.destructive){verb="delete";pending=c}.disabled(c.running || !s.canMutate)
                        }
                        if ids.count>1 {
                            ForEach(BatchVerb.allCases,id:\.self){action in
                                Button(s.t(action.rawValue)){reviewBatch(action,ids)}.disabled(!s.canMutate)
                            }
                        }
                    } primaryAction: { ids in openContainerDetails(ids) }
                    .overlay{if s.filtered.isEmpty{ContentUnavailableView.search(text:s.query)}}
                }.frame(minWidth:560,maxWidth:.infinity,maxHeight:.infinity)
                if selectedIDs.count==1,let c=s.chosen {
                    InspectorView(item:c,onStop:{verb="stop";pending=c},onDelete:{verb="delete";pending=c})
                        .frame(minWidth:285,idealWidth:320,maxWidth:380,maxHeight:.infinity)
                }
            }
        }
    }
}
struct StatusView:View {
    @EnvironmentObject var s:Store
    let item:ContainerItem
    var body:some View {Label(s.t(item.running ? "running":item.state=="stopped" ? "stopped":"unknown"),systemImage:item.running ? "circle.fill":"circle").font(.callout).foregroundStyle(item.running ? Color.green:Color.secondary)}
}
struct InspectorView:View {
    @EnvironmentObject var s:Store
    let item:ContainerItem
    let onStop:()->Void
    let onDelete:()->Void
    @State private var tab="info"
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            VStack(alignment:.leading,spacing:8){Text(item.id).font(.title2).fontWeight(.semibold).textSelection(.enabled);StatusView(item:item)}
            Picker("",selection:$tab){Text(s.t("info")).tag("info");Text(s.t("logs")).tag("logs")}.pickerStyle(.segmented).labelsHidden()
            HStack{
                Button{if item.running{onStop()}else{Task{await s.action("start",item)}}}label:{Label(s.t(item.running ? "stop":"start"),systemImage:item.running ? "stop.fill":"play.fill")}.disabled(!s.canMutate)
                Spacer()
                Menu{ContainerUtilityActions(item:item);Divider();Button(s.t("copyName")){NSPasteboard.general.clearContents();NSPasteboard.general.setString(item.id,forType:.string)};Button(s.t("delete"),role:.destructive,action:onDelete).disabled(item.running || !s.canMutate)}label:{Image(systemName:"ellipsis")}.menuStyle(.borderlessButton).frame(width:24)
            }
            Divider()
            VStack(alignment:.leading,spacing:20) {
                if tab=="info" {
                    ScrollView {
                        VStack(alignment:.leading,spacing:20){
                            info("image",item.image)
                            PublishedPortsView(ports:item.ports)
                            info("network",item.networks.joined(separator:", "))
                            Divider()
                            info("cpuAllocation","\(item.cpus) "+s.t("cores"))
                            info("memoryLimit",bytes(item.memory))
                            if let usage=s.usage[item.id] {info("processes",String(usage.processes));info("networkIO",bytes(usage.rx)+" ↓   "+bytes(usage.tx)+" ↑")}
                            Divider();info("mounts",item.mounts.isEmpty ? s.t("none"):item.mounts.joined(separator:"\n\n"))
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }
                }else{
                    ContainerLogsView(containerID:item.id).id(item.id)
                }
            }.frame(maxHeight:.infinity,alignment:.top)
                .modifier(InterfaceFade(value:tab))
            Spacer(minLength:0)
        }.padding(22).frame(maxHeight:.infinity,alignment:.top).background(.background)
    }
    func info(_ title:String,_ value:String)->some View {VStack(alignment:.leading,spacing:6){Text(s.t(title)).font(.caption).foregroundStyle(.secondary);Text(value.isEmpty ? "—":value).font(.callout).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)}}
}
