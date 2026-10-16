import Foundation

enum ResourceKind: String, CaseIterable {
    case image, network, volume
    var title: String { rawValue == "image" ? "images" : rawValue == "network" ? "networks" : "volumes" }
    var icon: String { rawValue == "image" ? "square.stack.3d.up" : rawValue == "network" ? "network" : "externaldrive" }
}

struct ResourceRequest {
    enum Operation: String { case pull, build, tag, load, save, createNetwork, createVolume }
    var operation: Operation
    var name = ""
    var source = ""
    var path = ""
    var dockerfile = "Dockerfile"
    var architecture = "arm64"
    var subnet = ""
    var internalNetwork = false
    var volumeGiB = "1"
    var noCache = false

    static func validName(_ name: String) -> Bool {
        name.range(of: "^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$", options: .regularExpression) != nil
    }
    static func validImage(_ image: String) -> Bool {
        !image.isEmpty && image.utf8.count <= 512 && !image.hasPrefix("-") &&
        !image.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }
    }
    func arguments() throws -> [String] {
        func image(_ value: String) throws { if !Self.validImage(value) { throw DeskError.message("invalidImage") } }
        func file(_ value: String) throws { if !value.hasPrefix("/") || value.contains("\0") { throw DeskError.message("chooseLocalPath") } }
        guard ["arm64", "amd64"].contains(architecture) else { throw DeskError.message("invalidArchitecture") }
        switch operation {
        case .pull:
            try image(name)
            return ["image", "pull", "--progress", "plain", "--arch", architecture, "--", name]
        case .tag:
            try image(source); try image(name)
            return ["image", "tag", "--", source, name]
        case .load:
            try file(path)
            return ["image", "load", "--input", path]
        case .save:
            try image(source); try file(path)
            return ["image", "save", "--output", path, "--", source]
        case .build:
            try image(name); try file(path)
            guard !dockerfile.isEmpty, !dockerfile.contains("\0") else { throw DeskError.message("chooseDockerfile") }
            let filePath = dockerfile.hasPrefix("/") ? dockerfile : URL(fileURLWithPath:path).appendingPathComponent(dockerfile).path
            return ["build", "--progress", "plain", "--arch", architecture, "--tag", name, "--file", filePath] + (noCache ? ["--no-cache"] : []) + ["--",path]
        case .createNetwork:
            guard Self.validName(name) else { throw DeskError.message("invalidName") }
            if !subnet.isEmpty {
                let parts = subnet.split(separator:"/", omittingEmptySubsequences:false)
                guard parts.count == 2, let prefix = Int(parts[1]), (0...32).contains(prefix),
                      parts[0].split(separator:".",omittingEmptySubsequences:false).count == 4,
                      parts[0].split(separator:".",omittingEmptySubsequences:false).allSatisfy({Int($0).map{(0...255).contains($0)} ?? false}) else { throw DeskError.message("invalidSubnet") }
            }
            return ["network","create"] + (internalNetwork ? ["--internal"] : []) + (subnet.isEmpty ? [] : ["--subnet",subnet]) + ["--",name]
        case .createVolume:
            guard Self.validName(name) else { throw DeskError.message("invalidName") }
            guard let size = Int(volumeGiB), (1...1024).contains(size) else { throw DeskError.message("invalidVolumeSize") }
            return ["volume","create","-s","\(size)G","--",name]
        }
    }
}

enum ResourceSafety {
    static func rows(_ data: Data) throws -> [[String:Any]] {
        guard let rows = try JSONSerialization.jsonObject(with:data) as? [[String:Any]] else { throw DeskError.message("resourcesUnavailable") }
        return rows
    }
    /// Recheck fresh metadata immediately before deleting. Never infer that a failed read means unused.
    static func validateDeletion(kind: ResourceKind, id: String, inventory: Data, containers: Data) throws {
        let resources = try rows(inventory)
        guard let row = resources.first(where: {
            let config = $0["configuration"] as? [String:Any] ?? [:]
            return (config["name"] as? String ?? $0["name"] as? String ?? $0["id"] as? String) == id
        }) else { throw DeskError.message("resourceDisappeared") }
        let config = row["configuration"] as? [String:Any] ?? [:]
        if kind == .network {
            let labels = config["labels"] as? [String:String] ?? [:]
            guard id != "default", id != "none", labels["com.apple.container.resource.role"] != "builtin" else { throw DeskError.message("protectedResource") }
        }
        let digest = (config["descriptor"] as? [String:Any])?["digest"] as? String
        for container in try rows(containers) {
            guard let c = container["configuration"] as? [String:Any] else { throw DeskError.message("resourcesUnavailable") }
            let used: Bool
            switch kind {
            case .image:
                guard let image = c["image"] as? [String:Any], let reference = image["reference"] as? String else { throw DeskError.message("resourcesUnavailable") }
                let otherDigest = (image["descriptor"] as? [String:Any])?["digest"] as? String
                used = reference == id || (digest != nil && digest == otherDigest)
            case .network:
                guard let networks = c["networks"] as? [[String:Any]] else { throw DeskError.message("resourcesUnavailable") }
                used = networks.contains { $0["network"] as? String == id }
            case .volume:
                guard let mounts = c["mounts"] as? [[String:Any]] else { throw DeskError.message("resourcesUnavailable") }
                let source=config["source"] as? String
                used = mounts.contains { mount in
                    let volume=(mount["type"] as? [String:Any])?["volume"] as? [String:Any]
                    let mountSource=mount["source"] as? String
                    return volume?["name"] as? String == id || mountSource == id || (source != nil && source == mountSource)
                }
            }
            if used { throw DeskError.message("resourceInUse") }
        }
    }
}
