import SwiftUI

struct SelectionControls:View {
    @EnvironmentObject var s:Store
    @Binding var selection:Set<String>
    let visibleIDs:[String]
    var body:some View {
        HStack(spacing:12) {
            Button(s.t("selectVisible")){selection=Set(visibleIDs)}
                .disabled(visibleIDs.isEmpty || selection==Set(visibleIDs))
            Button(s.t("clearSelection")){selection=[]}.disabled(selection.isEmpty)
            Text(s.t("selectedCount")+": \(selection.count)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }.help(s.t("selectionHelp"))
    }
}

struct SelectionCheckbox:View {
    let id:String
    let label:String
    @Binding var selection:Set<String>
    var body:some View {
        Toggle(label,isOn:Binding(get:{selection.contains(id)},set:{value in
            if value{selection.insert(id)}else{selection.remove(id)}
        })).toggleStyle(.checkbox).labelsHidden().accessibilityLabel(label)
    }
}

struct ResourceDeletionReview:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let request:ResourceBatchDeletion
    let submit:(ResourceBatchDeletion)->Void
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("deleteSelected")).font(.title2).fontWeight(.semibold)
            Text(s.t("resourceBatchReview")).foregroundStyle(.secondary)
            Text(s.t(request.kind == .volume ? "deleteVolumeImpact":"deleteResourceImpact")).foregroundStyle(.red)
            List(request.ids,id:\.self){id in Text(id).textSelection(.enabled)}
            Text(s.t("selectedCount")+": \(request.ids.count)").font(.caption)
            HStack {
                Spacer()
                Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction)
                Button(s.t("delete"),role:.destructive){submit(request)}.disabled(request.ids.isEmpty || !s.canMutate)
            }
        }.padding(24).frame(width:650,height:430)
    }
}
