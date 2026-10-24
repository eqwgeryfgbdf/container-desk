import SwiftUI

struct HuggingFaceModelSearchView:View {
    @EnvironmentObject var s:Store
    @Environment(\.dismiss) private var dismiss
    let maxMemory:Int
    let choose:(AIModelChoice)->Void
    @State private var query=""
    @State private var searchID=UUID()
    @State private var repositories=[HFRepository]()
    @State private var repository:HFRepository?
    @State private var files:HFModelFiles?
    @State private var selected:String?
    @State private var fileQuery=""
    @State private var searching=true
    @State private var loading=false
    @State private var searchError:String?
    @State private var fileError:String?
    private var choice:AIModelChoice?{files?.choices.first{$0.id==selected}}
    private var visibleFiles:[AIModelChoice]{files?.choices.filter{fileQuery.isEmpty || $0.filename.localizedCaseInsensitiveContains(fileQuery)} ?? []}

    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            HStack{Text(s.t("aiHFSearch")).font(.title2.bold());Spacer();Button(s.t("close")){dismiss()}.keyboardShortcut(.cancelAction)}
            Text(s.t("aiHFIntro")).foregroundStyle(.secondary)
            HStack {
                TextField(s.t("aiHFQuery"),text:$query).textFieldStyle(.roundedBorder).onSubmit{search()}
                Button(s.t("aiHFRunSearch")){search()}.buttonStyle(.borderedProminent)
            }
            HStack(spacing:8) {
                Text(s.t("aiHFQuickSearch")).font(.caption).foregroundStyle(.secondary)
                ForEach(["SmolLM2-135M-Instruct","Qwen2.5-0.5B-Instruct"],id:\.self){term in Button(term){query=term;search()}.controlSize(.small)}
            }
            HStack(alignment:.top,spacing:16) {
                VStack(alignment:.leading,spacing:10) {
                    Text(s.t("aiHFRepositories")).font(.headline)
                    if searching{ProgressView().controlSize(.small)}
                    if let searchError{Text(s.t(searchError)).foregroundStyle(.red)}
                    if !searching && searchError==nil && repositories.isEmpty{Text(s.t("aiHFNoResults")).foregroundStyle(.secondary)}
                    ScrollView {
                        LazyVStack(alignment:.leading,spacing:6) {
                            ForEach(repositories){item in
                                Button {
                                    guard repository?.id != item.id else{return}
                                    repository=item;files=nil;selected=nil;fileQuery="";fileError=nil;loading=true
                                } label:{
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(item.id).font(.callout.weight(.medium)).fixedSize(horizontal:false,vertical:true)
                                        Text("↓ "+item.downloads.formatted()+" · "+s.t(item.license)).font(.caption).foregroundStyle(.secondary)
                                    }.frame(maxWidth:.infinity,alignment:.leading).padding(10)
                                        .background(repository?.id==item.id ? Color.accentColor.opacity(0.12):Color.clear,in:RoundedRectangle(cornerRadius:8))
                                }.buttonStyle(.plain).accessibilityLabel(item.id)
                            }
                        }
                    }
                }.frame(width:270)
                Divider()
                VStack(alignment:.leading,spacing:10) {
                    if let repository {
                        HStack{Text(s.t("aiHFFiles")).font(.headline);Spacer();Link(s.t("aiModelCard"),destination:repository.modelCard)}
                        Text(repository.id).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        if loading{ProgressView().controlSize(.small)}
                        if let fileError{Text(s.t(fileError)).foregroundStyle(.red)}
                        if let files {
                            if files.gated{Text(s.t("aiHFGated")).foregroundStyle(.secondary)}
                            else if files.choices.isEmpty{Text(s.t("aiHFNoFiles")).foregroundStyle(.secondary)}
                            if files.omitted>0{Text(s.t("aiHFOmitted")).font(.caption).foregroundStyle(.secondary)}
                            if !files.choices.isEmpty {
                                TextField(s.t("aiHFFileFilter"),text:Binding(get:{fileQuery},set:{fileQuery=$0;selected=nil})).textFieldStyle(.roundedBorder)
                                if visibleFiles.isEmpty{Text(s.t("aiHFNoMatchingFile")).foregroundStyle(.secondary)}
                            }
                            ScrollView {
                                LazyVStack(alignment:.leading,spacing:6) {
                                    ForEach(visibleFiles){item in
                                        Button {selected=item.id} label:{
                                            HStack(alignment:.top) {
                                                Image(systemName:selected==item.id ? "checkmark.circle.fill":"circle").foregroundStyle(Color.accentColor)
                                                VStack(alignment:.leading,spacing:4){Text(item.filename).fixedSize(horizontal:false,vertical:true);Text(bytes(item.size)).font(.caption).foregroundStyle(.secondary)}
                                                Spacer(minLength:0)
                                            }.padding(10).frame(maxWidth:.infinity,alignment:.leading)
                                                .background(selected==item.id ? Color.accentColor.opacity(0.12):Color.secondary.opacity(0.05),in:RoundedRectangle(cornerRadius:8))
                                        }.buttonStyle(.plain).accessibilityLabel(item.filename)
                                    }
                                }
                            }
                        }
                    } else {ContentUnavailableView(s.t("aiHFChooseRepository"),systemImage:"magnifyingglass")}
                }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
            }.frame(maxHeight:.infinity)
            Divider()
            if let choice {
                HStack {
                    Text(bytes(choice.size)+" · "+s.t(choice.license)).textSelection(.enabled)
                    Spacer();Text(s.t("aiHFMemoryEstimate")+": "+bytes(Int64(choice.memoryMiB)*1048576))
                }.font(.callout)
                if choice.memoryMiB>maxMemory{Label(s.t("aiHFMemoryWarning"),systemImage:"exclamationmark.triangle").foregroundStyle(.orange).font(.caption)}
            }
            Text(s.t("aiHFCompatibilityNote")).font(.caption).foregroundStyle(.secondary)
            HStack{Spacer();Button(s.t("aiHFSelectDownload")){if let choice{choose(choice);dismiss()}}.buttonStyle(.borderedProminent).disabled(choice==nil || searching || loading)}
        }.padding(24).frame(width:900,height:620)
        .task(id:searchID) {
            let id=searchID,text=query
            do {
                let result=try await HuggingFaceModels().search(text)
                guard !Task.isCancelled,id==searchID else{return}
                repositories=result;searching=false
            }catch{guard !Task.isCancelled,id==searchID else{return};searchError=error.localizedDescription;searching=false}
        }
        .task(id:repository?.id) {
            guard let id=repository?.id else{return}
            do {
                let result=try await HuggingFaceModels().files(id)
                guard !Task.isCancelled,repository?.id==id else{return}
                files=result;loading=false
            }catch{guard !Task.isCancelled,repository?.id==id else{return};fileError=error.localizedDescription;loading=false}
        }
    }
    private func search(){repositories=[];repository=nil;files=nil;selected=nil;fileQuery="";searchError=nil;fileError=nil;loading=false;searching=true;searchID=UUID()}
}
