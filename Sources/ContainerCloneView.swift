import SwiftUI

struct ContainerCloneView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let source:String
    @State private var plan:ContainerClonePlan?
    @State private var failure:String?
    @State private var environment=false
    @State private var mounts=false
    @State private var writable=false
    @State private var configure=false
    @State private var created=false
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text(s.t("cloneContainer")).font(.title2).fontWeight(.semibold)
            Text(source).textSelection(.enabled)
            Text(s.t("cloneScope")).foregroundStyle(.secondary)
            if let plan {
                Grid(alignment:.leading,horizontalSpacing:24,verticalSpacing:12) {
                    GridRow{Text(s.t("image"));Text(plan.base.image).textSelection(.enabled)}
                    GridRow{Text(s.t("cpuAllocation"));Text(String(plan.base.cpus))}
                    GridRow{Text(s.t("memoryLimit"));Text("\(plan.base.memoryMB) MiB")}
                    GridRow{Text(s.t("commandArguments"));Text(([plan.base.entrypoint]+plan.arguments).joined(separator:" ")).lineLimit(3)}
                    GridRow{Text(s.t("ports"));Text(s.t("clonePortsCleared"))}
                }
                Toggle(s.t("cloneEnvironment"),isOn:$environment)
                Toggle(s.t("cloneMounts")+" (\(plan.mounts.count))",isOn:$mounts).disabled(plan.mounts.isEmpty)
                if mounts {Toggle(s.t("cloneWritable"),isOn:$writable);Text(s.t("cloneMountWarning")).font(.caption).foregroundStyle(.secondary)}
            } else if failure==nil {ProgressView()}
            if let failure{Text(s.t(failure)).foregroundStyle(.red)}
            Spacer()
            HStack{Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction);Spacer();Button(s.t("cloneConfigure")){configure=true}.buttonStyle(.borderedProminent).disabled(plan==nil || !s.canMutate)}
        }.padding(24).frame(width:640,height:520)
        .task {
            guard let cli=s.cli else{return}
            do {plan=try ContainerClonePlan((try await ProcessRunner.checked(cli,["inspect","--",source])).data)}catch{failure=error.localizedDescription}
        }
        .sheet(isPresented:$configure,onDismiss:{if created{dismiss()}}){
            if let plan {CreateView(initialRequest:plan.request(environment:environment,mounts:mounts,writable:writable),origin:plan.origin(requireStopped:mounts && writable),onCreated:{created=true}).environmentObject(s)}
        }
    }
}

struct ClonePresentation:ViewModifier {
    @EnvironmentObject var s:Store
    func body(content:Content)->some View {
        content.sheet(isPresented:Binding(get:{s.cloneSource != nil},set:{if !$0{s.cloneSource=nil}})) {
            ContainerCloneView(source:s.cloneSource ?? "").environmentObject(s)
        }
    }
}
