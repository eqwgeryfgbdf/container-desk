import SwiftUI
import AppKit

@MainActor final class Store: ObservableObject {
    @Published var host=HostInfo()
    @Published var containers:[ContainerItem]=[]
    @Published var usage:[String:Usage]=[:]
    @Published var images:[ResourceItem]=[]
    @Published var networks:[ResourceItem]=[]
    @Published var volumes:[ResourceItem]=[]
    @Published var history:[Sample]=[]
    @Published var containerHistory=ContainerMetricHistory()
    @Published var selected:String?
    @Published var section="containers"
    @Published var query=""
    @Published var filter="all"
    @Published var busy=false
    @Published var refreshing=false
    @Published var connected=false
    @Published var error:String?
    @Published var notice:String?
    @Published var logs=""
    @Published var logError:String?
    @Published var logsLoading=false
    @Published var version="—"
    @Published var lastRefresh:Date?
    @Published var cli:String?
    @Published var imagesLoading=false
    @Published var imageError:String?
    @Published var operationRunning=false
    @Published var operationPresented=false
    @Published var operationTitle=""
    @Published var operationOutput=""
    @Published var operationResult:String?
    @Published var inspection:InspectionTarget?
    @Published var restartCandidate:ContainerItem?
    private var operationTask:Task<Void,Never>?
    @Published var language:String=UserDefaults.standard.string(forKey:"language") ?? "system" {
        didSet { UserDefaults.standard.set(language,forKey:"language") }
    }
    @Published var appearance:String=UserDefaults.standard.string(forKey:"appearance") ?? "system" {
        didSet { UserDefaults.standard.set(appearance,forKey:"appearance") }
    }
    private var previous:[String:(Double,Date)]=[:]
    private var refreshCount=0
    var canMutate:Bool { connected && !busy && !operationRunning }
    var active:Int { containers.filter(\.running).count }
    var chosen:ContainerItem? { containers.first{$0.id==selected} }
    var totalMemory:Int64 { usage.values.reduce(0){$0+$1.memory} }
    var colorScheme:ColorScheme? { appearance == "dark" ? .dark : appearance == "light" ? .light : nil }
    var localeID:String {
        if language != "system" { return language }
        for l in Locale.preferredLanguages {
            if l.hasPrefix("zh-Hant") || l.hasPrefix("zh-TW") || l.hasPrefix("zh-HK") { return "zh-Hant" }
            if l.hasPrefix("zh") { return "zh-Hans" }
            if l.hasPrefix("en") { return "en" }
        }
        return "en"
    }
    func t(_ key:String)->String {
        guard let p=Bundle.main.path(forResource:localeID,ofType:"lproj"),let b=Bundle(path:p) else { return key }
        return b.localizedString(forKey:key,value:key,table:"Localizable")
    }
    var filtered:[ContainerItem] {
        containers.filter { (query.isEmpty || $0.id.localizedCaseInsensitiveContains(query) || $0.image.localizedCaseInsensitiveContains(query)) && (filter == "all" || (filter == "running" ? $0.running : !$0.running)) }
    }
    func detect() {
        let home=FileManager.default.homeDirectoryForCurrentUser.path
        let detected=["/usr/local/bin/container",home+"/.local/bin/container","/opt/homebrew/bin/container"].first { FileManager.default.isExecutableFile(atPath:$0) }
        if cli != detected {version="—"};cli=detected
    }
    func start() async {
        host.refreshDisk()
        var detectedHost=host
        await detectedHost.loadModelName()
        host=detectedHost
        detect()
        await refresh()
    }
    func refresh() async {
        host.refreshDisk()
        guard !refreshing,!busy else { return }
        detect();guard let cli else { connected=false;usage=[:];previous=[:];return }
        refreshing=true;defer{refreshing=false}
        do {
            if version=="—" {let v=try await ProcessRunner.checked(cli,["--version"]);version=v.text.trimmingCharacters(in:.whitespacesAndNewlines)}
            let r=try await ProcessRunner.checked(cli,["list","--all","--format","json"])
            containers=try ContainerItem.parse(r.data);connected=true;error=nil;lastRefresh=Date()
            let existingIDs=Set(containers.map(\.id))
            containerHistory.record([:],at:Date(),existingIDs:existingIDs)
            previous=previous.filter { id,_ in containers.contains(where:{$0.id==id && $0.running}) }
            if chosen==nil { selected=containers.first?.id }
            if version=="—" { let v=try await ProcessRunner.checked(cli,["--version"]);version=v.text.trimmingCharacters(in:.whitespacesAndNewlines) }
            if active>0 {
                do {
                    let stats=try await ProcessRunner.checked(cli,["stats","--no-stream","--format","json"])
                    let rows=try JSONSerialization.jsonObject(with:stats.data) as? [[String:Any]] ?? []
                    let now=Date();var next:[String:Usage]=[:]
                    for row in rows {
                        guard let id=row["id"] as? String,
                              let memory=(row["memoryUsageBytes"] as? NSNumber)?.int64Value,
                              let processes=row["numProcesses"] as? Int,
                              let rx=(row["networkRxBytes"] as? NSNumber)?.int64Value,
                              let tx=(row["networkTxBytes"] as? NSNumber)?.int64Value,
                              memory>=0,processes>=0,rx>=0,tx>=0 else { continue }
                        var cpu:Double?
                        if let use=(row["cpuUsageUsec"] as? NSNumber)?.doubleValue,use.isFinite,use>=0 {
                            if let old=previous[id],now.timeIntervalSince(old.1)>0,use>=old.0 {
                                let percent=(use-old.0)/(now.timeIntervalSince(old.1)*1_000_000)*100
                                if percent.isFinite {cpu=percent}
                            }
                            previous[id]=(use,now)
                        } else {previous[id]=nil}
                        next[id]=Usage(id:id,cpu:cpu,memory:memory,processes:processes,rx:rx,tx:tx)
                    }
                    usage=next
                    previous=previous.filter {next[$0.key] != nil}
                    containerHistory.record(next,at:now,existingIDs:existingIDs)
                    if next.values.contains(where:{$0.cpu != nil}) { history.append(Sample(date:now,cpu:next.values.compactMap(\.cpu).reduce(0,+)));history=Array(history.suffix(120)) }
                } catch { usage=[:];previous=[:];notice=t("statsUnavailable") }
            } else { usage=[:];previous=[:] }
            if refreshCount % 6 == 0 { await refreshResources() };refreshCount+=1
        } catch { connected=false;self.error=error.localizedDescription;usage=[:];previous=[:] }
    }
    func refreshResources() async {
        guard let cli else{return}
        await refreshImages()
        for kind in ["network","volume"] {
            do {
                let r=try await ProcessRunner.checked(cli,[kind,"list","--format","json"])
                let items=try ResourceItem.parseResources(r.data)
                if kind=="network"{networks=items}else{volumes=items}
            } catch { notice=t("resourcesUnavailable") }
        }
    }
    func refreshImages() async {
        guard let cli,!imagesLoading else{return}
        imagesLoading=true;imageError=nil;defer{imagesLoading=false}
        do {
            images=try ResourceItem.parseImages((try await ProcessRunner.checked(cli,["image","list","--format","json"])).data)
        }catch{images=[];imageError=t("imagesUnavailable")}
    }
    func action(_ verb:String,_ item:ContainerItem) async {
        guard canMutate,let cli,["start","stop","delete","restart"].contains(verb) else{return}
        busy=true;defer{busy=false;Task{await refresh()}}
        do {
            if verb=="delete" {
                let fresh=try ContainerItem.parse((try await ProcessRunner.checked(cli,["list","--all","--format","json"])).data)
                guard fresh.first(where:{$0.id==item.id})?.running == false else {throw DeskError.message(t("stopBeforeDelete"))}
            }
            if verb=="restart" {
                _=try await ProcessRunner.checked(cli,["stop","--",item.id],timeout:120)
                _=try await ProcessRunner.checked(cli,["start","--",item.id],timeout:120)
            } else {
                _=try await ProcessRunner.checked(cli,[verb,"--",item.id],timeout:120)
            }
            notice=t("operationComplete");error=nil
        }catch{self.error=error.localizedDescription}
    }
    func create(_ request:CreateRequest) async -> Bool {
        guard canMutate,let cli else{return false}
        busy=true;defer{busy=false;Task{await refresh()}}
        do {
            _=try request.arguments()
            try request.validateAllocation(maxCPUs:host.logicalCores ?? ProcessInfo.processInfo.activeProcessorCount,maxMemoryMiB:Int(host.memory/1048576))
            let localImages=try ResourceItem.parseImages((try await ProcessRunner.checked(cli,["image","list","--format","json"])).data)
            guard localImages.contains(where:{$0.id==request.image}) else{throw DeskError.message("selectLocalImage")}
            for (kind,id) in [("network",request.network)] + request.allMounts.filter({$0.kind == .volume}).map({("volume",$0.source)}) where !id.isEmpty {
                let resources=try ResourceItem.parseResources((try await ProcessRunner.checked(cli,[kind,"list","--format","json"])).data)
                guard resources.contains(where:{$0.id==id}) else {throw DeskError.message("resourceDisappeared")}
            }
            _=try await ProcessRunner.checked(cli,try request.arguments(),timeout:600)
            selected=request.name;notice=t("createdStopped");error=nil;return true
        }catch{self.error=t(error.localizedDescription);return false}
    }
    func loadLogs(_ id:String) async {
        guard !logsLoading else{return};logsLoading=true;defer{logsLoading=false}
        logError=nil
        guard let cli else{return}
        do {let r=try await ProcessRunner.checked(cli,["logs","-n","150","--",id]);if selected==id{logs=r.text}}catch{if selected==id{logError=error.localizedDescription}}
    }
    func startService() async {
        guard let cli,!busy,!operationRunning else{return}
        busy=true;defer{busy=false;Task{await refresh()}}
        do{_=try await ProcessRunner.checked(cli,["system","start","--disable-kernel-install"],timeout:90)}catch{self.error=error.localizedDescription}
    }
    func cancelOperation() {operationTask?.cancel()}
    func startOperation(_ title:String, work:@escaping @MainActor () async throws -> Int32) {
        guard canMutate else{return}
        operationTitle=title;operationOutput="";operationResult=nil;operationRunning=true;operationPresented=true
        operationTask=Task {
            do {
                let code=try await work()
                operationResult=code==0 ? "operationComplete" : "operationFailed"
            } catch is CancellationError {operationResult="operationCancelled"}
              catch {operationResult=error.localizedDescription}
            operationRunning=false;operationTask=nil
            await refreshResources()
            await refresh()
        }
    }

}
