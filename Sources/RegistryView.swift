import SwiftUI

struct RegistryView:View {
    @EnvironmentObject var s:Store
    @State private var accounts:[RegistryAccount]=[]
    @State private var loading=false
    @State private var failure:String?
    @State private var login=false
    @State private var browse=false
    @State private var browseServer=""
    @State private var submitted:RegistryLogin?
    @State private var logout:String?
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {Text(s.t("registries")).font(.largeTitle).fontWeight(.semibold);Spacer();Button(s.t("catalogTitle")){browseServer="";browse=true};Button(s.t("refresh")){Task{await refresh()}}.disabled(loading);Button(s.t("registryLogin")){login=true}.buttonStyle(.borderedProminent).disabled(!s.canMutate)}
            Text(s.t("registryCredentialNote")).foregroundStyle(.secondary)
            if let failure{Text(s.t(failure)).foregroundStyle(.red)}
            if loading{ProgressView()}
            List(accounts){account in
                HStack {
                    Label(account.name,systemImage:"server.rack").font(.headline)
                    Text(account.username).foregroundStyle(.secondary);Spacer()
                    Button(s.t("catalogTitle")){browseServer=account.name;browse=true}
                    Button(s.t("registryLogout"),role:.destructive){logout=account.name}.disabled(!s.canMutate)
                }.padding(.vertical,8)
            }.overlay{if accounts.isEmpty && !loading && failure==nil{ContentUnavailableView(s.t("noRegistries"),systemImage:"server.rack")}}
        }.padding(28)
        .sheet(isPresented:$browse){RegistryCatalogView(server:browseServer).environmentObject(s)}
        .task{await refresh()}
        .onChange(of:s.operationRunning){_,running in if !running{Task{await refresh()}}}
        .sheet(isPresented:$login,onDismiss:{if let request=submitted{submitted=nil;s.loginRegistry(request)}}){RegistryLoginView{submitted=$0;login=false}.environmentObject(s)}
        .confirmationDialog(s.t("registryLogout"),isPresented:Binding(get:{logout != nil},set:{if !$0{logout=nil}}),titleVisibility:.visible){
            Button(s.t("registryLogout"),role:.destructive){if let server=logout{s.logoutRegistry(server)};logout=nil}
            Button(s.t("cancel"),role:.cancel){logout=nil}
        }message:{Text((logout ?? "")+"\n"+s.t("registryLogoutNote"))}
    }
    private func refresh()async {
        guard let cli=s.cli,!loading else{return};loading=true;defer{loading=false}
        do{accounts=try RegistryAccount.parse((try await ProcessRunner.checked(cli,["registry","list","--format","json"])).data);failure=nil}catch{accounts=[];failure=error.localizedDescription}
    }
}
struct RegistryLoginView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    @State private var request=RegistryLogin()
    @State private var error:String?
    let submit:(RegistryLogin)->Void
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text(s.t("registryLogin")).font(.title2).fontWeight(.semibold)
            TextField(s.t("registryServer"),text:$request.server).textFieldStyle(.roundedBorder)
            TextField(s.t("username"),text:$request.username).textFieldStyle(.roundedBorder)
            SecureField(s.t("registryToken"),text:$request.password).textFieldStyle(.roundedBorder)
            Text(s.t("registryCredentialNote")).font(.callout).foregroundStyle(.secondary)
            if let error{Text(s.t(error)).foregroundStyle(.red)}
            HStack{Spacer();Button(s.t("cancel")){request.password="";dismiss()}.keyboardShortcut(.cancelAction);Button(s.t("registryLogin")){do{_=try request.arguments();let credentials=request;request.password="";submit(credentials)}catch{self.error=error.localizedDescription}}.buttonStyle(.borderedProminent).disabled(!s.canMutate)}
        }.padding(24).frame(width:520)
        .onDisappear{request.password=""}
    }
}
struct ImagePushView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let source:String
    let submit:(String,Bool)->Void
    @State private var target=""
    @State private var localHTTP=false
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text(s.t("pushImage")).font(.title2).fontWeight(.semibold)
            Text(source).textSelection(.enabled)
            TextField("ghcr.io/account/image:tag",text:$target).textFieldStyle(.roundedBorder).accessibilityLabel(s.t("pushDestination"))
            Toggle(s.t("registryLocalHTTP"),isOn:$localHTTP)
            Text(s.t("pushImageNote")).foregroundStyle(.secondary)
            HStack{Spacer();Button(s.t("cancel")){dismiss()}.keyboardShortcut(.cancelAction);Button(s.t("pushImage")){submit(target,localHTTP);dismiss()}.buttonStyle(.borderedProminent).disabled(target.isEmpty || !s.canMutate)}
        }.padding(24).frame(width:580)
    }
}
