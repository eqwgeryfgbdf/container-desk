import SwiftUI
struct RegistryCatalogView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State var server:String
    @State private var repository=""
    @State private var username=""
    @State private var password=""
    @State private var values:[String]=[]
    @State private var loadedRepository:String?
    @State private var loadedServer=""
    @State private var loading=false
    @State private var error:String?
    @State private var pageTask:Task<Void,Never>?
    @State private var deploy=false
    @State private var reference=""
    @State private var hub=false
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack{Text(s.t("catalogTitle")).font(.title2);Spacer();Button("Docker Hub"){hub=true}}
            Text(s.t("catalogScope")).font(.callout).foregroundStyle(.secondary)
            TextField(s.t("registryServer"),text:$server).textFieldStyle(.roundedBorder)
            TextField(s.t("catalogRepository"),text:$repository).textFieldStyle(.roundedBorder)
            DisclosureGroup(s.t("catalogSessionAuth")) {
                TextField(s.t("username"),text:$username).textFieldStyle(.roundedBorder)
                SecureField(s.t("registryToken"),text:$password).textFieldStyle(.roundedBorder)
                Text(s.t("catalogAuthScope")).font(.caption).foregroundStyle(.secondary)
            }
            HStack{Button(s.t("refresh")){load(next:false)}.disabled(loading);if loading{ProgressView().controlSize(.small)};Spacer();Button(s.t("catalogNext")){load(next:true)}.disabled(loading || values.count<100 || loadedServer != server || loadedRepository != currentRepository)}
            if let error{Text(s.t(error)).foregroundStyle(.red)}
            if !loadedServer.isEmpty {Text(loadedServer+" / "+(loadedRepository ?? "_catalog")).font(.caption).foregroundStyle(.secondary)}
            List(values,id:\.self) { value in
                HStack{Text(value).textSelection(.enabled);Spacer();if let repo=loadedRepository{Button(s.t("deployUnified")){do{reference=try RegistryCatalogClient.imageReference(server:loadedServer,repository:repo,tag:value);deploy=true}catch{self.error=error.localizedDescription}}.disabled(!s.canMutate)}else{Button(s.t("catalogTags")){repository=value;load(next:false)}}}
            }
            HStack{Spacer();Button(s.t("close")){dismiss()}.keyboardShortcut(.cancelAction)}
        }.padding(24).frame(width:720,height:650)
        .onDisappear{pageTask?.cancel();password=""}
        .sheet(isPresented:$hub){QuickDeployView().environmentObject(s)}
        .sheet(isPresented:$deploy){QuickDeployView(initialSource:reference).environmentObject(s)}
    }
    private var currentRepository:String?{repository.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? nil:repository.trimmingCharacters(in:.whitespacesAndNewlines)}
    private func load(next:Bool) {
        let host=server.trimmingCharacters(in:.whitespacesAndNewlines),repo=currentRepository,last=next ? values.last:nil
        server=host;loading=true;error=nil
        let user=username,secret=password
        pageTask?.cancel()
        pageTask=Task {
            defer{loading=false}
            do{let result=try await RegistryCatalogClient().fetch(server:host,repository:repo,last:last,username:user,password:secret);try Task.checkCancellation();values=result;loadedRepository=repo;loadedServer=host}
            catch is CancellationError{}catch{values=[];self.error=error.localizedDescription}
        }
    }
}
