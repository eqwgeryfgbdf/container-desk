import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContainerLogsView:View {
    @EnvironmentObject var s:Store
    let containerID:String
    @State private var follow=true
    @State private var query=""
    @State private var limit=500
    @State private var boot=false
    @State private var output=""
    @State private var failure:String?
    @State private var loading=false
    @State private var refreshed:Date?
    @State private var refreshToken=UUID()
    private var filtered:String {LogSnapshot.filtered(output,query:query)}
    private var identity:String {containerID+"/\(limit)/\(boot)/"+refreshToken.uuidString}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            TextField(s.t("searchLogs"),text:$query).textFieldStyle(.roundedBorder)
            ViewThatFits(in:.horizontal) {
                HStack {options;Spacer();actions}
                VStack(alignment:.leading,spacing:10){options;HStack{actions;Spacer()}}
            }
            HStack {
                Toggle(s.t("autoRefresh"),isOn:$follow).toggleStyle(.checkbox)
                Spacer()
                if loading {ProgressView().controlSize(.small)}
                Button {refreshToken=UUID()} label:{Image(systemName:"arrow.clockwise")}.help(s.t("refresh")).accessibilityLabel(s.t("refresh"))
            }
            if let failure {Text(failure).foregroundStyle(.red).font(.caption).textSelection(.enabled)}
            ScrollView([.horizontal,.vertical]) {
                Text(filtered.isEmpty ? s.t(output.isEmpty ? "noLogs":"noLogMatches"):filtered)
                    .font(.system(.caption,design:.monospaced)).textSelection(.enabled)
                    .frame(maxWidth:.infinity,alignment:.topLeading).padding(12)
            }.frame(maxWidth:.infinity,maxHeight:.infinity)
                .background(Color(nsColor:.textBackgroundColor),in:RoundedRectangle(cornerRadius:10))
            Text(s.t("logSnapshotNote")).font(.caption).foregroundStyle(.secondary)
            if let refreshed {
                Text(s.t("updated")+" "+refreshed.formatted(date:.omitted,time:.standard)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .task(id:identity) {
            output="";failure=nil;refreshed=nil
            await fetch()
            while !Task.isCancelled {
                do {try await Task.sleep(nanoseconds:3_000_000_000)}catch{return}
                if follow {await fetch()}
            }
        }
    }
    private var options:some View {
        HStack {
            Picker(s.t("logSource"),selection:$boot) {
                Text(s.t("applicationLogs")).tag(false);Text(s.t("bootLogs")).tag(true)
            }.labelsHidden().fixedSize().accessibilityLabel(s.t("logSource"))
            Picker(s.t("recentLines"),selection:$limit) {
                ForEach([150,500,2000,10000],id:\.self){Text("\($0)").tag($0)}
            }.labelsHidden().fixedSize().accessibilityLabel(s.t("recentLines"))
        }
    }
    private var actions:some View {
        HStack {
            Button {NSPasteboard.general.clearContents();NSPasteboard.general.setString(filtered,forType:.string)} label:{Image(systemName:"doc.on.doc")}.help(s.t("copyVisibleLogs")).accessibilityLabel(s.t("copyVisibleLogs"))
            Button(action:export) {Image(systemName:"square.and.arrow.up")}.help(s.t("exportLogs")).accessibilityLabel(s.t("exportLogs"))
        }.disabled(filtered.isEmpty || failure != nil)
    }
    private func fetch() async {
        guard let cli=s.cli else {failure=s.t("disconnected");return}
        loading=true;defer{loading=false}
        do {
            let result=try await ProcessRunner.checked(cli,["logs"]+(boot ? ["--boot"]:[])+["-n",String(limit),"--",containerID])
            try Task.checkCancellation()
            output=result.text;failure=nil;refreshed=Date()
        }catch is CancellationError {}catch{if !Task.isCancelled {failure=error.localizedDescription}}
    }
    private func export() {
        // Freeze exactly what the user sees before the save dialog; polling
        // cannot change the exported snapshot while the dialog is open.
        let snapshot=filtered
        let panel=NSSavePanel();panel.allowedContentTypes=[.plainText]
        panel.nameFieldStringValue=containerID+(boot ? "-boot":"")+".log"
        panel.begin {response in
            guard response == .OK,let url=panel.url else{return}
            do {try snapshot.write(to:url,atomically:true,encoding:.utf8)}catch{failure=error.localizedDescription}
        }
    }
}
