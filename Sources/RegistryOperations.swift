import Foundation
import Darwin

struct RegistryAccount:Identifiable {
    let name:String
    let username:String
    var id:String{name}
    static func parse(_ data:Data)throws->[RegistryAccount] {
        let rows=try ResourceSafety.rows(data)
        return try rows.map {row in
            guard let name=row["name"] as? String,let username=row["username"] as? String else{throw DeskError.message("registryUnavailable")}
            return RegistryAccount(name:name,username:username)
        }.sorted{$0.name<$1.name}
    }
}
struct RegistryLogin {
    var server=""
    var username=""
    var password=""
    var localHTTP=false
    static func validateServer(_ server:String,http:Bool=false)throws {
        guard server.range(of:#"^(?:[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?|\[::1\])(?::[0-9]{1,5})?$"#,options:.regularExpression) != nil,
              let url=URLComponents(string:"https://"+server),let host=url.host,
              url.port.map({(1...65535).contains($0)}) ?? true else {throw DeskError.message("invalidRegistry")}
        if http && !["localhost","127.0.0.1","[::1]","::1"].contains(host.lowercased()){throw DeskError.message("registryHTTPSRequired")}
    }
    func arguments()throws->[String] {
        guard !localHTTP else{throw DeskError.message("registryHTTPSRequired")}
        try Self.validateServer(server)
        guard !username.isEmpty,username.utf8.count<=256,!username.contains(where:{$0.isNewline || $0=="\0"}),
              !password.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,password.utf8.count<=4096,!password.contains("\0") else{throw DeskError.message("registryCredentialsRequired")}
        return ["registry","login","--scheme",localHTTP ? "http":"https","--password-stdin","--username",username,"--",server]
    }
}

/// Credentials go through an anonymous pipe only. Both output streams are
/// discarded, even on failure, because a remote authentication error can echo
/// input. No password is written to argv, environment, a file or an app log.
@MainActor enum CredentialProcess {
    static func login(_ cli:String,request:RegistryLogin,timeout:TimeInterval=60) async throws {
        let arguments=try request.arguments();try Task.checkCancellation()
        let p=Process(),input=Pipe()
        p.executableURL=URL(fileURLWithPath:cli);p.arguments=arguments
        p.standardInput=input;p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice
        guard fcntl(input.fileHandleForWriting.fileDescriptor,F_SETNOSIGPIPE,1)==0 else{throw DeskError.message("registryLoginFailed")}
        try p.run()
        defer {try? input.fileHandleForWriting.close();try? input.fileHandleForReading.close()}
        do {
            try input.fileHandleForWriting.write(contentsOf:Data(request.password.utf8))
            try input.fileHandleForWriting.close()
            let deadline=Date().addingTimeInterval(timeout)
            while p.isRunning {
                try Task.checkCancellation()
                guard Date()<deadline else{throw DeskError.message("commandTimeout")}
                try await Task.sleep(for:.milliseconds(100))
            }
            try Task.checkCancellation()
            guard p.terminationStatus==0 else{throw DeskError.message("registryLoginFailed")}
        } catch {
            if p.isRunning {p.terminate();await Task.detached{try? await Task.sleep(for:.milliseconds(500))}.value;if p.isRunning{kill(p.processIdentifier,SIGKILL)};await Task.detached{p.waitUntilExit()}.value}
            if error is CancellationError {throw CancellationError()}
            throw DeskError.message("registryLoginFailed")
        }
    }
}

@MainActor extension Store {
    func loginRegistry(_ request:RegistryLogin) {
        guard canMutate,let cli else{return}
        startOperation("registryLogin") {
            try await CredentialProcess.login(cli,request:request)
            self.operationOutput=request.server+"\n"+self.t("registryCredentialNote")
            return 0
        }
    }
    func logoutRegistry(_ server:String) {
        guard canMutate,let cli else{return}
        startOperation("registryLogout") {
            try RegistryLogin.validateServer(server)
            return try await StreamingProcess.run(cli,["registry","logout","--",server]){self.operationOutput=$0}
        }
    }
    func pushImage(source:String,target:String,localHTTP:Bool) {
        guard canMutate,let cli else{return}
        startOperation("pushImage") {
            guard ResourceRequest.validImage(source),ResourceRequest.validImage(target),let slash=target.firstIndex(of:"/") else{throw DeskError.message("registryQualifiedImage")}
            let host=String(target[..<slash]);try RegistryLogin.validateServer(host,http:localHTTP)
            guard host.contains(".") || host.contains(":") || host=="localhost",!target.contains("@") else{throw DeskError.message("registryQualifiedImage")}
            let inventory=try ResourceItem.parseImages((try await ProcessRunner.checked(cli,["image","list","--format","json"])).data)
            guard inventory.contains(where:{$0.id==source}) else{throw DeskError.message("selectLocalImage")}
            if source != target {
                guard !inventory.contains(where:{$0.id==target}) else{throw DeskError.message("imageTagExists")}
                try Task.checkCancellation()
                _=try await ProcessRunner.checked(cli,["image","tag","--",source,target])
            }
            try Task.checkCancellation()
            return try await StreamingProcess.run(cli,["image","push","--scheme",localHTTP ? "http":"https","--progress","plain","--",target]){self.operationOutput=$0}
        }
    }
}
