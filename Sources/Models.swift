import Foundation

struct ContainerItem: Identifiable, Hashable {
    let id: String
    var state: String
    var image: String
    var cpus: Int
    var memory: Int64
    var ports: [String]
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
            let ports = (c["publishedPorts"] as? [[String:Any]] ?? []).map { p in
                "\(p["hostAddress"] ?? "127.0.0.1"):\(p["hostPort"] ?? "?") → \(p["containerPort"] ?? "?")/\(p["proto"] ?? "tcp")"
            }
            let mounts = (c["mounts"] as? [[String:Any]] ?? []).map { m in
                let source=m["source"] as? String ?? ""
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
struct ResourceItem: Identifiable {
    let id: String
    let detail: String
    let extra: String
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
struct CreateRequest {
    var name = ""
    var image = ""
    var cpus = 2
    var memoryMB = 512
    var hostPort = ""
    var containerPort = ""
    var environment = ""
    var mountSource = ""
    var mountTarget = "/data"
    var readOnly = false
    func validateAllocation(maxCPUs:Int,maxMemoryMiB:Int) throws {
        guard (1...max(1,maxCPUs)).contains(cpus),memoryMB>=200,memoryMB<=maxMemoryMiB else {throw DeskError.message("allocationOutOfRange")}
    }
    func arguments() throws -> [String] {
        guard name.range(of:"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$",options:.regularExpression) != nil else { throw DeskError.message("invalidName") }
        guard !image.isEmpty, !image.hasPrefix("-"), !image.contains(where:{$0.isWhitespace}) else { throw DeskError.message("invalidImage") }
        guard cpus > 0, memoryMB >= 200 else { throw DeskError.message("invalidResources") }
        var a = ["create","--name",name,"--cpus",String(cpus),"--memory","\(memoryMB)M"]
        if !hostPort.isEmpty || !containerPort.isEmpty {
            guard let h=Int(hostPort),let c=Int(containerPort),(1...65535).contains(h),(1...65535).contains(c) else { throw DeskError.message("invalidPort") }
            a += ["--publish","127.0.0.1:\(h):\(c)"]
        }
        for line in environment.split(separator:"\n").map(String.init).filter({!$0.isEmpty}) {
            guard let eq=line.firstIndex(of:"="),String(line[..<eq]).range(of:"^[A-Za-z_][A-Za-z0-9_]*$",options:.regularExpression) != nil else { throw DeskError.message("invalidEnvironment") }
            a += ["--env",line]
        }
        if !mountSource.isEmpty {
            guard mountSource.hasPrefix("/"),mountTarget.hasPrefix("/"),!mountSource.contains(":"),!mountTarget.contains(":"),!mountSource.contains("\n") else { throw DeskError.message("invalidMount") }
            a += ["--volume",mountSource+":"+mountTarget+(readOnly ? ":ro" : "")]
        }
        a += [image]
        return a
    }
}
