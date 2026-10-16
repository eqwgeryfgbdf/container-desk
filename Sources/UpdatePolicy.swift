import Foundation

struct ReleaseAsset: Codable {
    let name:String
    let browser_download_url:String
    let digest:String?
    let size:Int64
}
struct CoreRelease: Codable {
    let tag_name:String
    let html_url:String
    let body:String?
    let prerelease:Bool
    let draft:Bool
    let assets:[ReleaseAsset]
    var signedAsset:ReleaseAsset? {
        assets.first { $0.name == "container-\(tag_name)-installer-signed.pkg" || $0.name == "container-installer-signed.pkg" }
    }
    func isNewer(than installed:String)->Bool { tag_name.compare(installed,options:.numeric) == .orderedDescending }
    var tested:Bool { ["1.5.0"].contains(tag_name) }
    func validatedAsset() throws -> ReleaseAsset {
        guard !prerelease,!draft,tag_name.range(of:"^[0-9]+\\.[0-9]+\\.[0-9]+$",options:.regularExpression) != nil,
              let a=signedAsset,let u=URL(string:a.browser_download_url),u.scheme=="https",u.host=="github.com",u.user==nil,u.password==nil,u.query==nil,u.fragment==nil,
              u.path=="/apple/container/releases/download/\(tag_name)/\(a.name)",
              let d=a.digest,d.range(of:"^sha256:[a-f0-9]{64}$",options:.regularExpression) != nil,a.size>0,a.size<1_000_000_000 else {throw DeskError.message("untrustedRelease")}
        return a
    }
}
