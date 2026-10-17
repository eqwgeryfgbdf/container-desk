import SwiftUI

struct ContainerSnapshotView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let containerID:String
    let push:(String,String,Bool)->Void
    @State private var name=""
    @State private var environment=false
    @State private var acknowledged=false
    @State private var runningAcknowledged=false
    @State private var busy=false
    @State private var result:String?
    @State private var requested:String?
    @State private var error:String?
    @State private var destination=""
    @State private var localHTTP=false
    private var running:Bool{s.containers.first{$0.id==containerID}?.running==true}
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(s.t("snapshotTitle")).font(.title2).fontWeight(.semibold)
            Text(containerID).font(.headline).textSelection(.enabled)
            Text(s.t("snapshotScope")).foregroundStyle(.secondary)
            if let result {
                Label(s.t("snapshotReady"),systemImage:"checkmark.circle").foregroundStyle(.green)
                Text(result).font(.system(.callout,design:.monospaced)).textSelection(.enabled)
                TextField("ghcr.io/account/image:tag",text:$destination).textFieldStyle(.roundedBorder).accessibilityLabel(s.t("pushDestination"))
                Toggle(s.t("registryLocalHTTP"),isOn:$localHTTP)
                Text(s.t("snapshotPushNote")).font(.callout).foregroundStyle(.secondary)
            } else {
                TextField(s.t("snapshotImageName"),text:$name).textFieldStyle(.roundedBorder).disabled(busy)
                Toggle(s.t("snapshotIncludeEnvironment"),isOn:$environment).disabled(busy)
                Text(s.t("snapshotEnvironmentNote")).font(.caption).foregroundStyle(.secondary)
                Toggle(s.t("snapshotFilesAcknowledgement"),isOn:$acknowledged).disabled(busy)
                if running {Toggle(s.t("snapshotRunningAcknowledgement"),isOn:$runningAcknowledged).disabled(busy)}
                if busy{ProgressView(s.t("snapshotWorking"))}
            }
            if let error{Text(s.t(error)).font(.callout).foregroundStyle(.red).lineLimit(5)}
            Spacer()
            HStack {
                Button(s.t(result == nil ? "cancel":"done")){if busy{s.cancelOperation()};dismiss()}.keyboardShortcut(.cancelAction)
                Spacer()
                if let result {
                    Button(s.t("pushImage")){push(result,destination,localHTTP)}.buttonStyle(.borderedProminent).disabled(destination.isEmpty || !s.canMutate)
                } else {
                    Button(s.t("snapshotSave"),action:save).buttonStyle(.borderedProminent).disabled(busy || !s.canMutate || name.isEmpty || !acknowledged || (running && !runningAcknowledged))
                }
            }
        }.padding(24).frame(width:680,height:540)
        .interactiveDismissDisabled(busy)
        .onAppear {if name.isEmpty{name="containerdesk/"+containerID.lowercased()+":"+String(Int(Date().timeIntervalSince1970))}}
        .onChange(of:s.operationRunning){_,active in
            guard busy,!active else{return};busy=false
            if s.operationResult=="operationComplete"{result=requested}else{error=s.operationResult ?? "operationFailed"}
        }
    }
    private func save() {
        do {
            let reference=try DeploymentSource.image(name)
            guard s.canMutate else{return}
            requested=reference;error=nil;busy=true
            s.snapshotContainer(ContainerSnapshotRequest(container:containerID,image:reference,includeEnvironment:environment,acknowledgeRunning:runningAcknowledged))
        } catch{self.error=error.localizedDescription}
    }
}
