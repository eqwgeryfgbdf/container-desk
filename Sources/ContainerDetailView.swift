import SwiftUI
import Charts
import AppKit

struct ContainerDetailView: View {
    @EnvironmentObject var s: Store
    let item: ContainerItem
    let onStop: () -> Void
    let onDelete: () -> Void
    @State private var tab = "info"
    private var usage: Usage? { item.running && s.connected ? s.usage[item.id] : nil }
    private var samples: [ContainerMetricSample] { s.containerHistory.samples[item.id] ?? [] }
    private var firstURL: URL? { item.ports.compactMap(\.webURL).first }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(24)
            Divider()
            if tab == "info" {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        metrics
                        HStack {
                            Label(s.t("resourceTrends"), systemImage: "waveform.path.ecg").font(.headline)
                            Spacer()
                            Text(s.t("historyWindow")).font(.caption).foregroundStyle(.secondary)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                            ContainerTrendCard(title: s.t("cpuUsage"), unit: "%", samples: samples, memory: false,
                                               waiting: s.t("collecting"), note: s.t("cpuExplanation"))
                            ContainerTrendCard(title: s.t("memoryUsed"), unit: "MiB", samples: samples, memory: true,
                                               waiting: s.t("collecting"), note: s.t("actualMemorySamples"))
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), alignment: .leading, spacing: 16) {
                            connections
                            configuration
                        }
                        mounts
                    }.padding(24)
                }
            } else {
                ContainerDetailLogs(containerID: item.id).padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "shippingbox.fill").font(.system(size: 30))
                    .foregroundStyle(Color.accentColor).frame(width: 56, height: 56)
                    .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(item.id).font(.title).fontWeight(.semibold).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.image).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                StatusView(item: item)
            }
            HStack(spacing: 12) {
                Picker(s.t("details"), selection: $tab) {
                    Text(s.t("info")).tag("info")
                    Text(s.t("logs")).tag("logs")
                }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
                Spacer()
                if let url = firstURL {
                    Link(destination: url) { Label(s.t("openService"), systemImage: "arrow.up.right.square") }
                        .buttonStyle(.bordered).help(url.absoluteString)
                }
                Button {
                    if item.running { onStop() } else { Task { await s.action("start", item) } }
                } label: {
                    Label(s.t(item.running ? "stop" : "start"), systemImage: item.running ? "stop.fill" : "play.fill")
                }.disabled(!s.canMutate)
                Menu {
                    Button(s.t("copyName")) { copy(item.id) }
                    Button(s.t("copyImageReference")) { copy(item.image) }
                    Divider()
                    Button(s.t("delete"), role: .destructive, action: onDelete).disabled(item.running || !s.canMutate)
                } label: { Label(s.t("moreActions"), systemImage: "ellipsis") }
                .menuStyle(.borderlessButton).fixedSize()
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
            ContainerMetricCard(title: s.t("cpuUsage"), icon: "cpu", color: .blue,
                value: usage?.cpu.map { String(format: "%.1f%%", $0) } ?? "—",
                detail: "\(s.t("cpuAllocation")) · \(item.cpus) \(s.t("cores"))",
                fraction: usage?.cpu.map { $0 / Double(max(1, item.cpus) * 100) })
            ContainerMetricCard(title: s.t("memoryUsed"), icon: "memorychip", color: .purple,
                value: usage.map { bytes($0.memory) } ?? "—",
                detail: "\(s.t("memoryLimit")) · \(bytes(item.memory))",
                fraction: usage.flatMap { item.memory > 0 ? Double($0.memory) / Double(item.memory) : nil })
            ContainerMetricCard(title: s.t("processes"), icon: "square.stack.3d.up", color: .orange,
                value: usage.map { String($0.processes) } ?? "—",
                detail: s.t(usage == nil ? "statsUnavailable" : "liveData"), fraction: nil)
            ContainerMetricCard(title: s.t("networkIO"), icon: "network", color: .teal,
                value: usage.map { bytes($0.rx) + " ↓" } ?? "—",
                detail: usage.map { bytes($0.tx) + " ↑ · " + s.t("networkCumulative") } ?? s.t("statsUnavailable"), fraction: nil)
        }
    }

    private var connections: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                PublishedPortsView(ports: item.ports)
                Divider()
                Text(s.t("network")).font(.caption).foregroundStyle(.secondary)
                if item.networks.isEmpty { Text(s.t("none")).foregroundStyle(.secondary) }
                ForEach(item.networks, id: \.self) { network in
                    Label(network, systemImage: "network").textSelection(.enabled)
                }
            }.frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading).padding(10)
        } label: { Label(s.t("connections"), systemImage: "point.3.connected.trianglepath.dotted") }
    }

    private var configuration: some View {
        GroupBox {
            VStack(spacing: 14) {
                field(s.t("cpuAllocation"), "\(item.cpus) \(s.t("cores"))")
                field(s.t("memoryLimit"), bytes(item.memory))
                Divider()
                field(s.t("runtimeEngine"), s.version)
                field(s.t("lastObservation"), s.lastRefresh.map { $0.formatted(date: .omitted, time: .standard) } ?? "—")
            }.frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading).padding(10)
        } label: { Label(s.t("configuration"), systemImage: "slider.horizontal.3") }
    }

    private var mounts: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text(s.t("mountDirection")).font(.caption).foregroundStyle(.secondary)
                if item.mounts.isEmpty {
                    Label(s.t("noMounts"), systemImage: "externaldrive").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(item.mounts.enumerated()), id: \.offset) { index, mount in
                        if index > 0 { Divider() }
                        Label { Text(mount).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        } icon: { Image(systemName: "folder").foregroundStyle(.secondary) }
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        } label: {
            Label(s.t("mounts") + " · \(item.mounts.count)", systemImage: "externaldrive")
        }
    }

    private func field(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).textSelection(.enabled).multilineTextAlignment(.trailing)
        }
    }
    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct ContainerMetricCard: View {
    let title: String
    let icon: String
    let color: Color
    let value: String
    let detail: String
    let fraction: Double?
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: icon).font(.callout).foregroundStyle(color)
                Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(height: 30, alignment: .topLeading)
                if let fraction {
                    ProgressView(value: min(1, max(0, fraction))).tint(color).frame(height: 12)
                        .accessibilityLabel(Text(title))
                } else { Color.clear.frame(height: 12).accessibilityHidden(true) }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ContainerTrendCard: View {
    let title: String
    let unit: String
    let samples: [ContainerMetricSample]
    let memory: Bool
    let waiting: String
    let note: String
    private var points: [ContainerMetricSample] { memory ? samples : samples.filter { $0.cpu != nil } }
    private var ceiling: Double {
        let maximum = points.map { memory ? Double($0.memory) / 1_048_576 : ($0.cpu ?? 0) }.max() ?? 0
        return max(memory ? 1 : 100, maximum * 1.2)
    }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if points.count > 1 {
                    Chart(points) { point in
                        LineMark(x: .value("Time", point.date),
                                 y: .value(unit, memory ? Double(point.memory) / 1_048_576 : (point.cpu ?? 0)))
                        .foregroundStyle(memory ? Color.purple : Color.blue)
                        .interpolationMethod(.linear)
                    }
                    .chartYScale(domain: 0...ceiling)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.minute().second())
                        }
                    }
                    .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
                    .frame(height: 145)
                    .accessibilityLabel(Text(title + " (" + unit + ")"))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "waveform.path").font(.title2)
                        Text(waiting).font(.callout)
                    }.foregroundStyle(.secondary).frame(maxWidth: .infinity).frame(height: 145)
                }
                Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(2).frame(height: 30, alignment: .topLeading)
            }.padding(10)
        } label: { Text(title + " · " + unit) }
    }
}

private struct ContainerDetailLogs: View {
    @EnvironmentObject var s: Store
    let containerID: String
    @State private var follow = true
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(s.t("recentLogs"), systemImage: "text.alignleft").font(.headline)
                Spacer()
                Toggle(s.t("autoRefresh"), isOn: $follow).toggleStyle(.checkbox)
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s.logs, forType: .string) }
                    label: { Label(s.t("copyLogs"), systemImage: "doc.on.doc") }
            }
            ScrollView([.vertical, .horizontal]) {
                Text(s.logError ?? (s.logs.isEmpty ? s.t("noLogs") : s.logs))
                    .font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading).padding(16)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        }
        .task(id: containerID) {
            s.logs=""; s.logError=nil
            await s.loadLogs(containerID)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if follow && !Task.isCancelled { await s.loadLogs(containerID) }
            }
        }
    }
}
