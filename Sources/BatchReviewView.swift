import SwiftUI

struct BatchReviewView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let request:BatchRequest
    let submit:(BatchRequest)->Void
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("batchOperations")+" · "+s.t(request.verb.rawValue)).font(.title2).fontWeight(.semibold)
            Text(s.t("batchReviewNote")).foregroundStyle(.secondary)
            if request.verb == .delete {Text(s.t("deleteImpact")).foregroundStyle(.red)}
            else if request.verb == .stop || request.verb == .restart {Text(s.t("stopImpact")).foregroundStyle(.orange)}
            List(request.items) {item in
                HStack {
                    Text(item.id).textSelection(.enabled)
                    Spacer()
                    StatusView(item:item)
                    if (try? request.verb.commands(for:item,current:item)) == nil {
                        Text(s.t("batchSkipped")).foregroundStyle(.secondary)
                    }
                }
            }
            Text(s.t("selectedCount")+": \(request.items.count)").font(.caption)
            HStack {
                Spacer()
                Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction)
                Button(s.t("continue")){submit(request);dismiss()}.buttonStyle(.borderedProminent).disabled(!s.canMutate)
            }
        }.padding(24).frame(width:650,height:430)
    }
}
