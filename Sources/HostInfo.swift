import Foundation
import Darwin

/// Only non-identifying hardware fields are retained. Serial numbers and hardware UUIDs are not retained by this model.
struct HostInfo {
    var name = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    var modelIdentifier = stringSysctl("hw.model")
    var modelName: String?
    var chip = stringSysctl("machdep.cpu.brand_string")
    var physicalCores = intSysctl("hw.physicalcpu")
    var logicalCores = intSysctl("hw.logicalcpu")
    var performanceCores = intSysctl("hw.perflevel0.physicalcpu")
    var efficiencyCores = intSysctl("hw.perflevel1.physicalcpu")
    var memory = ProcessInfo.processInfo.physicalMemory
    var osVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }
    var osBuild = stringSysctl("kern.osversion")
    var architecture = stringSysctl("hw.machine")
    var diskName: String?
    var diskTotal: Int64?
    var diskFree: Int64?
    var updated = Date()
    var icon: String {
        let value = (modelName ?? modelIdentifier ?? "").lowercased()
        return value.contains("macbook") ? "laptopcomputer" : value.contains("mini") ? "macmini" : "desktopcomputer"
    }
    mutating func refreshDisk() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let values = try? home.resourceValues(forKeys:[.volumeNameKey,.volumeTotalCapacityKey,.volumeAvailableCapacityKey])
        diskName = values?.volumeName
        diskTotal = values?.volumeTotalCapacity.map(Int64.init)
        diskFree = values?.volumeAvailableCapacity.map(Int64.init)
        updated = Date()
    }
    mutating func loadModelName() async {
        guard let result = try? await ProcessRunner.checked("/usr/sbin/system_profiler",["SPHardwareDataType","-json"],timeout:20),
              let json = try? JSONSerialization.jsonObject(with:result.data) as? [String:Any],
              let row = (json["SPHardwareDataType"] as? [[String:Any]])?.first else { return }
        modelName = row["machine_name"] as? String
        if chip == nil { chip = row["chip_type"] as? String }
    }
    static func stringSysctl(_ key:String) -> String? {
        var count=0
        guard sysctlbyname(key,nil,&count,nil,0)==0,count>1 else{return nil}
        var buffer=[CChar](repeating:0,count:count)
        guard sysctlbyname(key,&buffer,&count,nil,0)==0 else{return nil}
        return String(cString:buffer)
    }
    static func intSysctl(_ key:String) -> Int? {
        var value:Int32=0;var count=MemoryLayout<Int32>.size
        guard sysctlbyname(key,&value,&count,nil,0)==0 else{return nil}
        return Int(value)
    }
}
