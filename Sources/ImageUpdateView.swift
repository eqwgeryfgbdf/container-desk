import SwiftUI

struct ImageUpdateView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let image:String
    let submit:(ContainerUpdatePlan)->Void
    @State private var candidates:[ContainerItem]=[]
    @State private var selected=""
    @State private var source:Data?
    @State private var metadata:Data?
    @State private var health=""
    @State private var acknowledge=false
    @State private var failure:String?
    @State private var loading=true
    @State private var replacement=""
    private var plan:ContainerUpdatePlan? {
        guard let source,let metadata else{return nil}
        return try? ContainerUpdatePlan(container:source,image:image,metadata:metadata,replacement:replacement,health:health)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text(s.t("containerUpdateApply")).font(.title2).fontWeight(.semibold)
            Text(image).textSelection(.enabled).foregroundStyle(.secondary)
            if loading {ProgressView()}
            if candidates.isEmpty && !loading {Text(s.t("imageUpdateNoContainers"))}
            else {
                Picker(s.t("containers"),selection:$selected){ForEach(candidates){Text($0.id).tag($0.id)}}
                LabeledContent(s.t("imageUpdateReplacement"),value:replacement)
                Text(s.t("imageUpdateImpact")).font(.callout).fixedSize(horizontal:false,vertical:true)
                TextField(s.t("imageUpdateHealthLabel"),text:$health,prompt:Text("http://127.0.0.1:8080/health")).textFieldStyle(.roundedBorder)
                    .disabled(candidates.first{$0.id==selected}?.running != true)
                Text(s.t("imageUpdateHealthNote")).font(.caption).foregroundStyle(.secondary)
                Toggle(s.t("imageUpdateAcknowledge"),isOn:$acknowledge)
            }
            if let failure {Text(s.t(failure)).foregroundStyle(.red).fixedSize(horizontal:false,vertical:true)}
            if !loading,source != nil,plan==nil,failure==nil {Text(s.t("imageUpdatePlanInvalid")).foregroundStyle(.orange)}
            Spacer()
            HStack {Spacer();Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction)
                Button(s.t("containerUpdateApply")){if let plan{submit(plan);dismiss()}}
                    .buttonStyle(.borderedProminent).disabled(loading || !acknowledge || plan==nil || !s.canMutate)
            }
        }.padding(24).frame(width:660,height:540)
        .task {
            guard let cli=s.cli else{loading=false;failure="coreMissing";return}
            do {
                metadata=try await ProcessRunner.checked(cli,["image","inspect","--",image]).data
                let version=try LocalImageVersion(metadata!)
                let data=try await ProcessRunner.checked(cli,["list","--all","--format","json"]).data
                candidates=try ContainerItem.parse(data).filter{$0.image==image}
                let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]] ?? []
                let outdated=Set(rows.compactMap { row -> String? in
                    guard let c=row["configuration"] as? [String:Any],let i=c["image"] as? [String:Any],(i["descriptor"] as? [String:Any])?["digest"] as? String != version.digest else{return nil}
                    return c["id"] as? String
                })
                let retained=Set(s.containerUpdateReceipts.map(\.original))
                candidates=candidates.filter{outdated.contains($0.id) && !retained.contains($0.id)}
                selected=candidates.first?.id ?? ""
            }catch{failure=error.localizedDescription}
            loading=false
        }
        .task(id:selected) {
            source=nil;health="";acknowledge=false
            guard !selected.isEmpty,let cli=s.cli else{return}
            let id=selected
            replacement=String(id.prefix(42))+"-upd-"+UUID().uuidString.lowercased().prefix(8)
            do {
                let data=try await ProcessRunner.checked(cli,["inspect","--",id]).data
                guard !Task.isCancelled,selected==id else{return}
                source=data;failure=nil
                if let metadata {_=try ContainerUpdatePlan(container:data,image:image,metadata:metadata,replacement:replacement)}
            }catch{if !Task.isCancelled{failure=error.localizedDescription}}
        }
    }
}
