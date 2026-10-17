import SwiftUI

struct HubSearchView:View {
    @EnvironmentObject var s:Store
    @State private var query=""
    @State private var searched=""
    @State private var results:[HubRepository]=[]
    @State private var selected:HubRepository?
    @State private var tags:[HubTag]=[]
    @State private var tag=""
    @State private var page=1
    @State private var tagPage=1
    @State private var more=false
    @State private var moreTags=false
    @State private var busy=false
    @State private var failure:String?
    @State private var task:Task<Void,Never>?
    @State private var generation=UUID()
    let choose:(String)->Void

    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                TextField(s.t("hubSearchPlaceholder"),text:$query).textFieldStyle(.roundedBorder).onSubmit{search()}
                Button(s.t("hubSearchAction")){search()}.disabled(query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }
            Text(s.t("hubSearchScope")).font(.caption).foregroundStyle(.secondary)
            if let selected {
                HStack {
                    Button{resetSelection()}label:{Label(s.t("hubSearchBack"),systemImage:"chevron.left")}
                    Text(selected.repo_name).font(.headline).textSelection(.enabled)
                    Spacer()
                }
                Text(selected.short_description ?? "").font(.callout).foregroundStyle(.secondary).lineLimit(3)
                if !tags.isEmpty {
                    Picker(s.t("hubSearchVersions"),selection:$tag) {
                        Text(s.t("hubSearchChooseVersion")).tag("")
                        if !tag.isEmpty,!tags.contains(where:{$0.name==tag}){Text(tag).tag(tag)}
                        ForEach(tags){item in Text(item.name+(item.supportsARM ? " · Linux ARM64" : " · "+s.t("hubSearchARMUnknown"))).tag(item.name)}
                    }
                }
                HStack {
                    TextField(s.t("hubSearchCustomTag"),text:$tag).textFieldStyle(.roundedBorder)
                    if moreTags{Button(s.t("hubSearchMoreVersions")){loadTags(selected,next:true)}.disabled(busy)}
                }
                Text(s.t("hubSearchVerifyNote")).font(.caption).foregroundStyle(.secondary)
                if let item=tags.first(where:{$0.name==tag}),!item.supportsARM {
                    Label(s.t("hubSearchARMWarning"),systemImage:"exclamationmark.triangle").foregroundStyle(.orange).font(.callout)
                }
                Button(s.t("hubSearchUse")) {
                    do{choose(try DeploymentSource.image(selected.reference,tag:tag))}catch{failure=error.localizedDescription}
                }.buttonStyle(.borderedProminent).disabled(tag.isEmpty || busy || tags.contains(where:{$0.name==tag && !$0.supportsARM}))
                Spacer(minLength:0)
            } else {
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:0) {
                        ForEach(results){repo in
                            Button{selected=repo;tags=[];tag="";loadTags(repo)}label:{
                                VStack(alignment:.leading,spacing:5) {
                                    HStack {
                                        Text(repo.repo_name).font(.headline)
                                        if repo.is_official==true{Label(s.t("hubSearchOfficial"),systemImage:"checkmark.seal.fill").font(.caption).foregroundStyle(.blue)}
                                        Spacer();Image(systemName:"chevron.right").foregroundStyle(.secondary)
                                    }
                                    Text(repo.short_description ?? "").font(.callout).foregroundStyle(.secondary).lineLimit(2)
                                    HStack(spacing:16) {
                                        if let pulls=repo.pull_count{Label(pulls.formatted(),systemImage:"arrow.down.circle").help(s.t("hubSearchPulls"))}
                                        if let stars=repo.star_count{Label(stars.formatted(),systemImage:"star").help(s.t("hubSearchStars"))}
                                    }.font(.caption).foregroundStyle(.secondary)
                                }.padding(10).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Divider()
                        }
                        if more{Button(s.t("hubSearchMore")){search(next:true)}.disabled(busy).padding(10)}
                    }
                }
                if !busy,results.isEmpty{Text(s.t(searched.isEmpty ? "hubSearchHint":"hubSearchEmpty")).foregroundStyle(.secondary)}
            }
            if busy{ProgressView().controlSize(.small)}
            if let failure {
                Text(s.t(failure)).foregroundStyle(.red).font(.callout)
                if let selected{Button(s.t("hubSearchRetry")){loadTags(selected)}}
            }
        }
        .onChange(of:query){_,_ in cancel();selected=nil;results=[];searched="";more=false;failure=nil}
        .onDisappear{cancel()}
    }
    private func cancel(){task?.cancel();generation=UUID();busy=false}
    private func resetSelection(){cancel();selected=nil;tags=[];tag="";failure=nil}
    private func search(next:Bool=false) {
        cancel();let id=generation
        let term=query.trimmingCharacters(in:.whitespacesAndNewlines),p=next ? page+1:1
        if !next{results=[];more=false;selected=nil}
        searched=term;failure=nil;busy=true
        task=Task { @MainActor in
            do {
                let response=try await HubSearchClient().search(term,page:p)
                guard !Task.isCancelled,generation==id else{return}
                var seen=Set(results.map(\.id));results+=response.results.filter{seen.insert($0.id).inserted}
                page=p;more=response.hasNext;busy=false
            } catch{guard !Task.isCancelled,generation==id else{return};busy=false;failure=message(error)}
        }
    }
    private func loadTags(_ repo:HubRepository,next:Bool=false) {
        cancel();let id=generation,p=next ? tagPage+1:1
        if !next{moreTags=false};failure=nil;busy=true
        task=Task { @MainActor in
            do {
                let response=try await HubSearchClient().tags(repo,page:p)
                guard !Task.isCancelled,generation==id else{return}
                var seen=Set(tags.map(\.id));tags+=response.results.filter{seen.insert($0.id).inserted}
                tagPage=p;moreTags=response.hasNext;busy=false
                if tag.isEmpty{tag=tags.first(where:{$0.name=="latest" && $0.supportsARM})?.name ?? tags.first(where:{$0.supportsARM})?.name ?? ""}
            } catch{guard !Task.isCancelled,generation==id else{return};busy=false;failure=message(error)}
        }
    }
    private func message(_ error:Error)->String{error is URLError ? "hubSearchUnavailable":error.localizedDescription}
}
