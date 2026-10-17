import Foundation
import Virtualization

enum DeploymentRuntime {
    static var rosettaReady:Bool{VZLinuxRosettaDirectoryShare.availability == .installed}
    static var rosettaStatus:String {
        switch VZLinuxRosettaDirectoryShare.availability {
        case .installed:return "deployRosettaReady"
        case .notInstalled:return "deployRosettaMissing"
        case .notSupported:return "deployRosettaUnsupported"
        @unknown default:return "deployRosettaUnsupported"
        }
    }
}

/// Accept registry references and canonical Docker Hub repository links only.
/// A web page URL is never passed directly to a shell or registry CLI.
enum DeploymentSource {
    static func image(_ input:String,tag:String="latest")throws->String {
        var value=input.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty else{throw DeskError.message("invalidImage")}
        if value.contains("://") {
            guard let url=URLComponents(string:value),url.scheme=="https",url.host=="hub.docker.com",url.user==nil,url.password==nil,url.port==nil,url.fragment==nil else{throw DeskError.message("hubURLInvalid")}
            let parts=url.path.split(separator:"/").map(String.init)
            if parts.count==2,parts[0]=="_" {value="docker.io/library/"+parts[1]}
            else if parts.count==3,parts[0]=="r" {value="docker.io/"+parts[1]+"/"+parts[2]}
            else if parts.count==3,parts[0]=="_",parts[2]=="tags" {value="docker.io/library/"+parts[1]}
            else if parts.count==4,parts[0]=="r",parts[3]=="tags" {value="docker.io/"+parts[1]+"/"+parts[2]}
            else{throw DeskError.message("hubURLInvalid")}
        }
        guard ResourceRequest.validImage(value),!value.contains("%"),!value.contains("?"),!value.contains("#"),!value.contains("\\"),!value.contains("//") else{throw DeskError.message("invalidImage")}
        let digest=value.components(separatedBy:"@")
        guard digest.count<=2 else{throw DeskError.message("invalidImage")}
        if digest.count==2 {guard digest[1].range(of:"^sha256:[a-f0-9]{64}$",options:.regularExpression) != nil else{throw DeskError.message("invalidImage")}}
        let last=digest[0].split(separator:"/").last.map(String.init) ?? ""
        let tagged=last.contains(":")
        if !tagged && digest.count==1 {
            guard tag.range(of:"^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$",options:.regularExpression) != nil else{throw DeskError.message("invalidImage")}
            value+=":"+tag
        }
        let first=value.split(separator:"/").first.map(String.init) ?? ""
        if !value.contains("/"){value="docker.io/library/"+value}
        else if !first.contains("."),!first.contains(":"),first != "localhost" {value="docker.io/"+value}
        if value.hasPrefix("docker.io/"),value.split(separator:"/").count==2 {value=value.replacingOccurrences(of:"docker.io/",with:"docker.io/library/")}
        let repository=value.components(separatedBy:"@")[0]
        let components=repository.split(separator:"/",omittingEmptySubsequences:false)
        guard components.count>=2,components.dropFirst().dropLast().allSatisfy({!$0.contains(":")}),components.dropFirst().allSatisfy({!$0.isEmpty && $0 != "." && $0 != ".." && $0.range(of:"^[a-z0-9][a-z0-9_.-]*(?::[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?$",options:.regularExpression) != nil}) else{throw DeskError.message("invalidImage")}
        try RegistryLogin.validateServer(String(components[0]))
        return value
    }
}

@MainActor extension Store {
    func prepareDeployment(_ image:String,architecture:String="arm64") {
        guard canMutate,let cli else{return}
            startOperation("quickDeploy",present:false) {
                guard ["arm64","amd64"].contains(architecture) else{throw DeskError.message("invalidArchitecture")}
                let existing=try await ProcessRunner.run(cli,["image","inspect","--",image])
                let hasVariant=existing.code==0 ? try ImagePlatform.hasVariant(existing.data,architecture:architecture):false
                if !hasVariant {
                    let code=try await StreamingProcess.run(cli,["image","pull","--progress","plain","--platform","linux/"+architecture,"--",image]){self.operationOutput=$0}
                    guard code==0 else{return code}
                }
                let inspected=try await ProcessRunner.checked(cli,["image","inspect","--",image])
                guard try ImagePlatform.hasVariant(inspected.data,architecture:architecture) else{throw DeskError.message("deployArchitectureMismatch")}
                await self.refreshImages()
                guard self.images.contains(where:{$0.id==image}) else{throw DeskError.message("resourceDisappeared")}
                return 0
            }
    }
}
