import Foundation
import Darwin

struct PublishedPort: Hashable {
    let hostAddress: String
    let hostPort: Int?
    let containerPort: Int?
    let transport: String

    init(_ raw: [String: Any]) {
        hostAddress = raw["hostAddress"] as? String ?? "?"
        hostPort = raw["hostPort"] as? Int
        containerPort = raw["containerPort"] as? Int
        transport = (raw["proto"] as? String ?? "?").lowercased()
    }

    var display: String {
        let host = hostAddress.contains(":") ? "[\(hostAddress)]" : hostAddress
        return "\(host):\(hostPort.map(String.init) ?? "?") → \(containerPort.map(String.init) ?? "?")/\(transport)"
    }

    var webURL: URL? {
        guard transport == "tcp", let hostPort, (1...65535).contains(hostPort),
              let containerPort, (1...65535).contains(containerPort) else { return nil }
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        let host: String
        if inet_pton(AF_INET, hostAddress, &ipv4) == 1 {
            host = ipv4.s_addr == 0 ? "127.0.0.1" : hostAddress
        } else if inet_pton(AF_INET6, hostAddress, &ipv6) == 1 {
            let wildcard = withUnsafeBytes(of: ipv6) { $0.allSatisfy { $0 == 0 } }
            host = "[\(wildcard ? "::1" : hostAddress)]"
        } else if hostAddress == "localhost" {
            host = hostAddress
        } else {
            return nil
        }
        // Port metadata cannot detect the application protocol. Use HTTPS for
        // container port 443; other TCP services open as HTTP by default.
        var url = URLComponents()
        url.scheme = containerPort == 443 ? "https" : "http"
        url.host = host
        url.port = hostPort
        return url.url
    }
}

struct ContainerItem: Identifiable, Hashable {
    let id: String
    var state: String
    var image: String
    var cpus: Int
    var memory: Int64
    var ports: [PublishedPort]
    var networks: [String]
    var mounts: [String]
    var running: Bool { state == "running" }
    static func parse(_ raw: Data) throws -> [ContainerItem] {
        guard let rows = try JSONSerialization.jsonObject(with: raw) as? [[String: Any]] else { throw DeskError.message("Invalid container response") }
        return rows.compactMap { row in
            let c = row["configuration"] as? [String:Any] ?? [:]
            guard let id = row["id"] as? String ?? c["id"] as? String else { return nil }
            let status = row["status"] as? [String:Any] ?? [:]
            let resources = c["resources"] as? [String:Any] ?? [:]
            let image = (c["image"] as? [String:Any])?["reference"] as? String ?? "—"
            let ports = (c["publishedPorts"] as? [[String:Any]] ?? []).map(PublishedPort.init)
            let mounts = (c["mounts"] as? [[String:Any]] ?? []).map { m in
                let source=((m["type"] as? [String:Any])?["volume"] as? [String:Any])?["name"] as? String ?? m["source"] as? String ?? ""
                return "\(source.isEmpty ? (m["type"] as? String ?? "—") : source) → \(m["destination"] ?? "—")"
            }
            let networks = (c["networks"] as? [[String:Any]] ?? []).compactMap { $0["network"] as? String }
            return ContainerItem(id:id, state:status["state"] as? String ?? "unknown", image:image, cpus:resources["cpus"] as? Int ?? 0, memory:(resources["memoryInBytes"] as? NSNumber)?.int64Value ?? 0, ports:ports, networks:networks, mounts:mounts)
        }.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

}
struct Usage: Identifiable {
    let id: String
    var cpu: Double?
    var memory: Int64
    var processes: Int
    var rx: Int64
    var tx: Int64
}
struct ContainerMetricSample: Identifiable {
    let id = UUID()
    let date: Date
    let cpu: Double?
    let memory: Int64
}

struct ContainerMetricHistory {
    private(set) var samples: [String: [ContainerMetricSample]] = [:]
    mutating func record(_ usage: [String: Usage], at date: Date, existingIDs: Set<String>) {
        samples = samples.filter { existingIDs.contains($0.key) }
        for (id, value) in usage where existingIDs.contains(id) {
            var points = samples[id] ?? []
            points.append(ContainerMetricSample(date: date, cpu: value.cpu, memory: value.memory))
            samples[id] = Array(points.suffix(120))
        }
    }
}
struct ResourceItem: Identifiable {
    let id: String
    let detail: String
    let extra: String
    static func parseResources(_ data:Data) throws -> [ResourceItem] {
        guard let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]] else {throw DeskError.message("resourcesUnavailable")}
        return rows.compactMap { row in
            let c=row["configuration"] as? [String:Any] ?? row
            let status=row["status"] as? [String:Any] ?? [:]
            guard let id=c["name"] as? String ?? row["id"] as? String else {return nil}
            let size=(c["sizeInBytes"] as? NSNumber)?.int64Value ?? (row["sizeInBytes"] as? NSNumber)?.int64Value
            return ResourceItem(id:id,detail:status["ipv4Subnet"] as? String ?? c["driver"] as? String ?? c["source"] as? String ?? "—",extra:size.map(bytes) ?? c["mode"] as? String ?? "")
        }.sorted{$0.id.localizedStandardCompare($1.id) == .orderedAscending}
    }
    static func parseImages(_ data:Data) throws -> [ResourceItem] {
        guard let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]] else{throw DeskError.message("imagesUnavailable")}
        var seen=Set<String>()
        return rows.compactMap { row in
            guard let config=row["configuration"] as? [String:Any],let name=config["name"] as? String,!name.isEmpty,
                  let variants=row["variants"] as? [[String:Any]],!variants.isEmpty,seen.insert(name).inserted else{return nil}
            let architectures=Set(variants.compactMap{($0["platform"] as? [String:Any])?["architecture"] as? String}).sorted().joined(separator:", ")
            let size=variants.reduce(Int64(0)){$0+(($1["size"] as? NSNumber)?.int64Value ?? 0)}
            return ResourceItem(id:name,detail:architectures,extra:bytes(size))
        }.sorted{$0.id.localizedStandardCompare($1.id) == .orderedAscending}
    }
}
struct Sample: Identifiable {
    let id = UUID()
    let date: Date
    let cpu: Double
}
struct DeskError: LocalizedError {
    let description: String
    static func message(_ value: String) -> DeskError { .init(description:value) }
    var errorDescription: String? { description }
}
func bytes(_ value: Int64) -> String {
    ByteCountFormatter.string(fromByteCount:value, countStyle:.memory)
}
func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of:"'",with:"'\\''") + "'" }
func appleScriptQuote(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\"",with:"\\\"").replacingOccurrences(of:"\n",with:"\\n") + "\""
}
struct PortMapping: Identifiable {
    let id = UUID()
    var host = ""
    var container = ""
    var transport = "tcp"
}
struct MountMapping: Identifiable {
    enum Kind: String, CaseIterable { case folder, volume }
    let id = UUID()
    var kind: Kind = .folder
    var source = ""
    var target = "/data"
    var readOnly = false
}

struct CreateRequest {
    var name = ""
    var image = ""
    var cpus = 2
    var memoryMB = 512
    var hostPort = ""
    var containerPort = ""
    var portTransport = "tcp"
    var additionalPorts: [PortMapping] = []
    var additionalMounts: [MountMapping] = []
    var environment = ""
    var mountSource = ""
    var mountTarget = "/data"
    var readOnly = false
    var network = ""
    var namedVolume = ""
    var volumeTarget = "/data"
    var volumeReadOnly = false
    var architecture = "arm64"
    var rosetta = false
    var entrypoint = ""
    var workingDirectory = ""
    var commandArguments = ""
    var allMounts:[MountMapping] {
        var mounts=additionalMounts
        if !mountSource.isEmpty {mounts.insert(MountMapping(source:mountSource,target:mountTarget,readOnly:readOnly),at:0)}
        if !namedVolume.isEmpty {mounts.append(MountMapping(kind:.volume,source:namedVolume,target:volumeTarget,readOnly:volumeReadOnly))}
        return mounts
    }
    func validateAllocation(maxCPUs:Int,maxMemoryMiB:Int) throws {
        guard (1...max(1,maxCPUs)).contains(cpus),memoryMB>=200,memoryMB<=maxMemoryMiB else {throw DeskError.message("allocationOutOfRange")}
    }
    func arguments() throws -> [String] {
        guard name.range(of:"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$",options:.regularExpression) != nil else { throw DeskError.message("invalidName") }
        guard !image.isEmpty, !image.hasPrefix("-"), !image.contains(where:{$0.isWhitespace}) else { throw DeskError.message("invalidImage") }
        guard cpus > 0, memoryMB >= 200 else { throw DeskError.message("invalidResources") }
        var a = ["create","--name",name,"--cpus",String(cpus),"--memory","\(memoryMB)M"]
        var usedPorts=Set<String>()
        let primaryPorts = hostPort.isEmpty && containerPort.isEmpty ? [] : [PortMapping(host:hostPort,container:containerPort,transport:portTransport)]
        for port in primaryPorts + additionalPorts {
            guard let h=Int(port.host),let c=Int(port.container),(1...65535).contains(h),(1...65535).contains(c),["tcp","udp"].contains(port.transport) else {throw DeskError.message("invalidPort")}
            guard usedPorts.insert("\(h)/\(port.transport)").inserted else {throw DeskError.message("duplicatePort")}
            // TCP's omitted suffix preserves compatibility with saved command previews.
            a += ["--publish","127.0.0.1:\(h):\(c)"+(port.transport == "udp" ? "/udp":"")]
        }
        for line in environment.split(separator:"\n").map(String.init).filter({!$0.isEmpty}) {
            guard let eq=line.firstIndex(of:"="),String(line[..<eq]).range(of:"^[A-Za-z_][A-Za-z0-9_]*$",options:.regularExpression) != nil else { throw DeskError.message("invalidEnvironment") }
            a += ["--env",line]
        }
        var targets=Set<String>()
        for mount in allMounts {
            let target=mount.target
            guard target.hasPrefix("/"),!target.contains(":"),!target.contains(where:{$0.isNewline || $0 == "\0"}),
                  !target.split(separator:"/").contains("..") else {throw DeskError.message("invalidMount")}
            let canonical="/"+target.split(separator:"/").filter{$0 != "."}.joined(separator:"/")
            guard targets.insert(canonical).inserted else {throw DeskError.message("duplicateMount")}
            if mount.kind == .folder {
                guard mount.source.hasPrefix("/"),!mount.source.contains(":"),!mount.source.contains(where:{$0.isNewline || $0 == "\0"}) else {throw DeskError.message("invalidMount")}
            } else {
                guard mount.source.range(of:"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$",options:.regularExpression) != nil else {throw DeskError.message("invalidMount")}
            }
            a += ["--volume",mount.source+":"+canonical+(mount.readOnly ? ":ro":"")]
        }
        guard ["arm64","amd64"].contains(architecture) else {throw DeskError.message("invalidArchitecture")}
        a += ["--arch",architecture]
        if rosetta && architecture == "amd64" {a += ["--rosetta"]}
        if !network.isEmpty {
            guard network.range(of:"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$",options:.regularExpression) != nil else {throw DeskError.message("invalidName")}
            a += ["--network",network]
        }
        if !entrypoint.isEmpty {
            guard !entrypoint.contains("\n"),!entrypoint.contains("\0") else {throw DeskError.message("invalidEntrypoint")}
            a += ["--entrypoint",entrypoint]
        }
        if !workingDirectory.isEmpty {
            guard workingDirectory.hasPrefix("/"),!workingDirectory.contains("\n"),!workingDirectory.contains("\0") else {throw DeskError.message("invalidWorkingDirectory")}
            a += ["--workdir",workingDirectory]
        }
        guard !commandArguments.contains("\0") else {throw DeskError.message("invalidArguments")}
        a += ["--",image]
        a += commandArguments.split(separator:"\n",omittingEmptySubsequences:true).map(String.init)
        return a
    }
}

// The confirmation captures names and states. Re-read each target immediately
// before mutation; a state change requires a new review rather than a force flag.
enum BatchVerb:String,CaseIterable {
    case start,stop,restart,delete
    func commands(for reviewed:ContainerItem,current:ContainerItem?) throws -> [[String]] {
        guard let current,current.id==reviewed.id else {throw DeskError.message("resourceDisappeared")}
        guard current.state==reviewed.state else {throw DeskError.message("batchStateChanged")}
        let eligible = self == .start || self == .delete ? current.state=="stopped" : current.state=="running"
        guard eligible else {throw DeskError.message("batchIneligible")}
        if self == .restart {return [["stop","--",current.id],["start","--",current.id]]}
        return [[rawValue,"--",current.id]]
    }
    func completed(_ current:ContainerItem?) -> Bool {
        switch self {
        case .delete:return current==nil
        case .start,.restart:return current?.state=="running"
        case .stop:return current?.state=="stopped"
        }
    }
}
struct BatchRequest:Identifiable {
    let id=UUID()
    let verb:BatchVerb
    let items:[ContainerItem]
}

enum LogSnapshot {
    static func filtered(_ text:String,query:String)->String {
        guard !query.isEmpty else{return text}
        return text.components(separatedBy:"\n").filter{$0.localizedCaseInsensitiveContains(query)}.joined(separator:"\n")
    }
}
