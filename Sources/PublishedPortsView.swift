import SwiftUI
import AppKit

struct PublishedPortsView: View {
    @EnvironmentObject var s: Store
    let ports: [PublishedPort]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(s.t("ports")).font(.caption).foregroundStyle(.secondary)
            if ports.isEmpty {
                Text(s.t("none")).font(.callout)
            } else {
                ForEach(ports.indices, id: \.self) { index in
                    PublishedPortRow(port: ports[index])
                }
            }
        }
    }
}

private struct PublishedPortRow: View {
    @EnvironmentObject var s: Store
    let port: PublishedPort

    var body: some View {
        if let url = port.webURL {
            Link(destination: url) {
                Label(port.display, systemImage: "arrow.up.right.square")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout)
            .help(Text(s.t("openPortInBrowser") + "\n" + url.absoluteString))
            .accessibilityLabel(Text(s.t("openPortInBrowser") + ": " + port.display))
            .accessibilityValue(Text(url.absoluteString))
            .contextMenu {
                Button(s.t("copyPortURL")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.absoluteString, forType: .string)
                }
            }
        } else {
            Text(port.display).font(.callout).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
