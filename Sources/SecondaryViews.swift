import SwiftUI
import Charts
import AppKit

struct OverviewView:View {
    @EnvironmentObject var s:Store
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:28) {
                VStack(alignment:.leading,spacing:8){Text(s.t("overviewTitle")).font(.largeTitle).fontWeight(.semibold);Text(s.t("overviewSubtitle")).foregroundStyle(.secondary)}
                HStack(spacing:0){metric("running",String(s.active),.green);Divider().frame(height:48);metric("stopped",String(s.containers.count-s.active),.secondary);Divider().frame(height:48);metric("memoryUsed",s.usage.isEmpty ? "—":bytes(s.totalMemory),.primary);Divider().frame(height:48);metric("hostMemory",bytes(Int64(s.host.memory)),.primary)}.padding(.vertical,10)
                HostSpecsView()
                Divider()
                HStack{Text(s.t("containerCPU")).font(.headline);Spacer();Text(s.t("sinceOpened")).font(.caption).foregroundStyle(.secondary)}
                if s.history.count>1 {
                    Chart(s.history){p in LineMark(x:.value("Time",p.date),y:.value("CPU",p.cpu)).foregroundStyle(Color.accentColor).interpolationMethod(.linear)}.chartYScale(domain:0...max(100,(s.history.map(\.cpu).max() ?? 0)*1.2)).frame(height:190)
                }else{ContentUnavailableView{Label(s.t("collecting"),systemImage:"waveform.path")}description:{Text(s.t("cpuExplanation"))}.frame(height:190)}
                Text(s.t("cpuExplanation")).font(.caption).foregroundStyle(.secondary)
                Divider()
                HStack{Text(s.t("containerStatus")).font(.headline);Spacer();Button(s.t("viewAll")){s.section="containers"}.buttonStyle(.link)}
                ForEach(s.containers.prefix(6)){c in
                    HStack(spacing:14){Image(systemName:"shippingbox").foregroundStyle(.secondary);VStack(alignment:.leading,spacing:4){Text(c.id).fontWeight(.medium);Text(c.image).font(.caption).foregroundStyle(.secondary).lineLimit(1)};Spacer();Text(s.usage[c.id].map{bytes($0.memory)} ?? "—").monospacedDigit().foregroundStyle(.secondary);StatusView(item:c).frame(width:100,alignment:.leading)}.padding(.vertical,3)
                    Divider()
                }
                if s.containers.isEmpty{Text(s.t("noContainers")).foregroundStyle(.secondary)}
            }.padding(32)
        }
    }
    func metric(_ title:String,_ value:String,_ color:Color)->some View{VStack(alignment:.leading,spacing:8){Text(value).font(.system(size:30,weight:.semibold,design:.rounded)).monospacedDigit().foregroundStyle(color);Text(s.t(title)).font(.callout).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(.leading,16)}
}
struct CoreView:View {
    @EnvironmentObject var s:Store
    @EnvironmentObject var c:CoreManager
    @State private var confirmInstall=false
    @State private var confirmMigration=false
    var body:some View {
        ScrollView{
            VStack(alignment:.leading,spacing:24){
                HStack(spacing:16){Image(systemName:"cpu").font(.system(size:40,weight:.light)).foregroundStyle(.tint);VStack(alignment:.leading,spacing:6){Text("Apple Container").font(.largeTitle).fontWeight(.semibold);Text(s.t("coreSubtitle")).foregroundStyle(.secondary)};Spacer();Label(s.t(s.cli==nil ? "notInstalled":s.connected ? "ready":"disconnected"),systemImage:s.connected ? "checkmark.circle.fill":"circle").foregroundStyle(s.connected ? Color.green:Color.secondary)}
                Text(s.t("dependency")).fixedSize(horizontal:false,vertical:true)
                HStack{Link(s.t("officialProject"),destination:URL(string:"https://github.com/apple/container")!);Link(s.t("officialReleases"),destination:URL(string:"https://github.com/apple/container/releases")!)}
                Form{
                    Section(s.t("installation")){
                        LabeledContent(s.t("installedVersion"),value:c.installedVersion(s) ?? s.t("notInstalled"))
                        LabeledContent(s.t("location"),value:s.cli ?? "—").textSelection(.enabled)
                        LabeledContent(s.t("source"),value:"github.com/apple/container")
                        if !c.managed(s){
                            Label(s.t("externalInstall"),systemImage:"info.circle").foregroundStyle(.secondary)
                            Button(s.t("migrateCore")){confirmMigration=true}.disabled(!c.canMigrate(s) || s.active>0 || s.busy || s.operationRunning || c.installing)
                            Text(s.t(s.active>0 ? "updateDeferred":"migrationPolicy")).font(.caption).foregroundStyle(.secondary)
                        }
                        if s.cli != nil && !s.connected {Button(s.t("startCore")){Task{await s.startService()}}.disabled(s.busy || s.operationRunning)}
                    }
                    Section(s.t("updates")){
                        LabeledContent(s.t("latestVersion"),value:c.release?.tag_name ?? "—")
                        if let date=c.lastChecked{LabeledContent(s.t("lastChecked"),value:date.formatted())}
                        Toggle(s.t("automaticallyCheck"),isOn:$c.autoCheck)
                        Toggle(s.t("automaticallyInstall"),isOn:$c.autoInstall).disabled(!c.managed(s))
                        Text(s.t("automaticPolicy")).font(.caption).foregroundStyle(.secondary)
                        if let r=c.release,!r.tested{Label(s.t("compatibilityPending"),systemImage:"exclamationmark.triangle")}
                        if c.updateAvailable(s){Label(s.t("updateAvailable"),systemImage:"arrow.down.circle").foregroundStyle(.tint)}
                        else if c.release != nil,s.cli != nil{Label(s.t("upToDate"),systemImage:"checkmark.circle").foregroundStyle(.green)}
                    }
                }.formStyle(.grouped).scrollDisabled(true).frame(height:(c.release==nil ? 370:420)+(c.managed(s) ? 0:110))
                HStack{
                    Button{Task{await c.check()}}label:{Label(s.t("checkUpdates"),systemImage:"arrow.clockwise")}.disabled(c.checking || c.installing)
                    if c.checking{ProgressView().controlSize(.small)}
                    Spacer()
                    Button(s.t(s.cli==nil ? "installCore":"updateCore")){confirmInstall=true}.buttonStyle(.borderedProminent).disabled(c.release==nil || !(c.release?.tested ?? false) || !c.managed(s) || c.installing || s.busy || s.operationRunning || (s.cli != nil && !c.updateAvailable(s)))
                }
                if c.installing {HStack{ProgressView().controlSize(.small);Text(s.t(c.phase))}}
                if let e=c.failure{Label(s.t(e),systemImage:"exclamationmark.triangle").foregroundStyle(.red).textSelection(.enabled)}
                if c.phase=="installed"{Label(s.t("installComplete"),systemImage:"checkmark.circle.fill").foregroundStyle(.green)}
                if let notes=c.release?.body {DisclosureGroup(s.t("releaseNotes")){Text(notes).font(.callout).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}}
                Text(s.t("kernelNote")).font(.caption).foregroundStyle(.secondary)
                Text(s.t("independentApp")).font(.caption).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth:920,alignment:.leading).frame(maxWidth:.infinity)
        }
        .confirmationDialog(s.t("migrateCore"),isPresented:$confirmMigration,titleVisibility:.visible){Button(s.t("continue")){Task{await c.install(s,migrate:true)}};Button(s.t("cancel"),role:.cancel){}}message:{Text(s.t("migrationImpact"))}
        .confirmationDialog(s.t("installConfirm"),isPresented:$confirmInstall,titleVisibility:.visible){Button(s.t("continue")){Task{await c.install(s)}};Button(s.t("cancel"),role:.cancel){}}message:{Text(s.t("installImpact"))}
    }
}
struct PreferencesView:View {
    @EnvironmentObject var s:Store
    @EnvironmentObject var c:CoreManager
    var body:some View {
        Form{
            Section(s.t("appearance")){
                Picker(s.t("theme"),selection:$s.appearance){Text(s.t("systemDefault")).tag("system");Text(s.t("light")).tag("light");Text(s.t("dark")).tag("dark")}
                Picker(s.t("language"),selection:$s.language){Text(s.t("systemDefault")).tag("system");Text("English").tag("en");Text("中文（简体）").tag("zh-Hans");Text("中文（繁體）").tag("zh-Hant")}
                Text(s.t("languageNote")).font(.caption).foregroundStyle(.secondary)
            }
            Section(s.t("about")){
                LabeledContent(s.t("appVersion"),value:"0.1.2 · Developer Preview")
                LabeledContent(s.t("platform"),value:s.host.osVersion+" · "+(s.host.architecture ?? "—"))
                Link(s.t("officialProject"),destination:URL(string:"https://github.com/apple/container")!)
                Text(s.t("independentApp")).font(.caption).foregroundStyle(.secondary)
                Text(s.t(Bundle.main.object(forInfoDictionaryKey:"ContainerDeskDistribution") as? String == "release" ? "releaseBuild":"developmentBuild")).font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(minWidth:500,idealWidth:660,minHeight:500).padding(16)
    }
}

struct HostSpecsView:View {
    @EnvironmentObject var s:Store
    func value(_ v:String?)->String{v ?? s.t("unavailable")}
    var body:some View {
        GroupBox {
            Grid(alignment:.leading,horizontalSpacing:36,verticalSpacing:12){
                row("hostName",s.host.name)
                row("hostModel",[s.host.modelName,s.host.modelIdentifier].compactMap{$0}.joined(separator:" · "))
                row("hostChip",value(s.host.chip))
                row("physicalCores",s.host.physicalCores.map(String.init) ?? s.t("unavailable"))
                row("logicalCores",s.host.logicalCores.map(String.init) ?? s.t("unavailable"))
                if let p=s.host.performanceCores,let e=s.host.efficiencyCores{row("coreTypes","\(p) / \(e)")}
                row("hostMemory",bytes(Int64(s.host.memory)))
                row("hostOS",s.host.osVersion+" ("+value(s.host.osBuild)+")")
                row("architecture",value(s.host.architecture))
                row("hostDisk",value(s.host.diskName))
                row("diskCapacity",s.host.diskTotal.map(bytes) ?? s.t("unavailable"))
                row("diskFree",s.host.diskFree.map(bytes) ?? s.t("unavailable"))
            }.frame(maxWidth:.infinity,alignment:.leading).padding(12)
            Text(s.t("hostSource")).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity,alignment:.leading).padding([.horizontal,.bottom],12)
        } label:{Label(s.t("hostSpecs"),systemImage:s.host.icon).font(.headline)}
    }
    func row(_ key:String,_ text:String)->some View {GridRow{Text(s.t(key)).foregroundStyle(.secondary);Text(text.isEmpty ? s.t("unavailable"):text).textSelection(.enabled)}}
}
