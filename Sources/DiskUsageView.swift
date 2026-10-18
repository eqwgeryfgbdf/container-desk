import SwiftUI

struct DiskUsageView: View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State private var report:[String:DiskUsageEntry]=[:]
    @State private var kind:ResourceKind = .image
    @State private var candidates:[ResourceItem]=[]
    @State private var selection=Set<String>()
    @State private var loading=false
    @State private var failure:String?
    @State private var review:ResourceBatchDeletion?
    @State private var submitted:ResourceBatchDeletion?
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack{Label(s.t("diskUsageCleanup"),systemImage:"externaldrive").font(.title2);Spacer();Button(s.t("refresh")){Task{await refresh()}}.disabled(loading || !s.canMutate)}
            HStack {
                ForEach(["images","containers","volumes"],id:\.self){key in
                    GroupBox {
                        VStack(alignment:.leading,spacing:6){Text(s.t(key)).font(.headline);Text(report[key].map{bytes($0.sizeInBytes)} ?? "—").font(.title2);Text(s.t("reclaimable")+": "+(report[key].map{bytes($0.reclaimable)} ?? "—")).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(8)
                    }
                }
            }
            Text(s.t("cleanupScope")).font(.callout).foregroundStyle(.secondary)
            Picker(s.t("type"),selection:$kind){ForEach(ResourceKind.allCases,id:\.self){Text(s.t($0.title)).tag($0)}}.pickerStyle(.segmented).disabled(loading)
            if loading{ProgressView()}
            if let failure{Text(s.t(failure)).foregroundStyle(.red)}
            HStack{SelectionControls(selection:$selection,visibleIDs:candidates.map(\.id));Spacer();Text("\(candidates.count)").monospacedDigit()}
            Table(candidates,selection:$selection) {
                TableColumn(s.t("select")){item in SelectionCheckbox(id:item.id,label:s.t("select")+" "+item.id,selection:$selection)}.width(36)
                TableColumn(s.t("name"),value:\.id)
                TableColumn(s.t("details"),value:\.extra)
            }.overlay{if candidates.isEmpty && !loading{ContentUnavailableView(s.t("noCleanupCandidates"),systemImage:"checkmark.shield")}}
            HStack{Spacer();Button(s.t("close")){dismiss()}.keyboardShortcut(.cancelAction);Button(s.t("reviewCleanup"),role:.destructive){review=ResourceBatchDeletion(kind:kind,ids:selection.sorted())}.disabled(selection.isEmpty || loading || !s.canMutate)}
        }.padding(24).frame(width:820,height:580)
        .task{await refresh()}
        .onChange(of:kind){_,_ in selection=[];Task{await refresh()}}
        .onChange(of:s.operationRunning){_,running in if !running{Task{await refresh()}}}
        .sheet(item:$review,onDismiss:{if let request=submitted{submitted=nil;dismiss();s.deleteResources(request)}}){request in ResourceDeletionReview(request:request){submitted=$0;review=nil}.environmentObject(s)}
    }
    private func refresh()async {
        guard let cli,!loading else{return}
        loading=true;failure=nil;candidates=[];selection=[];defer{loading=false}
        let requestedKind=kind
        do {
            report=try JSONDecoder().decode([String:DiskUsageEntry].self,from:(try await ProcessRunner.checked(cli,["system","df","--format","json"])).data)
            let data=try await ProcessRunner.checked(cli,[requestedKind.rawValue,"list","--format","json"])
            let containers=try await ProcessRunner.checked(cli,["list","--all","--format","json"])
            let items=try requestedKind == .image ? ResourceItem.parseImages(data.data):ResourceItem.parseResources(data.data)
            guard kind==requestedKind else{return}
            candidates=items.filter{(try? ResourceSafety.validateDeletion(kind:requestedKind,id:$0.id,inventory:data.data,containers:containers.data)) != nil}
        } catch {failure=error.localizedDescription}
    }
    private var cli:String?{s.cli}
}
