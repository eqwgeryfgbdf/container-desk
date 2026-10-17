import Foundation

@main struct WorkflowTests {
    static func main() throws {
        var count=0
        func expect(_ value:Bool,_ message:String)throws {guard value else{throw DeskError.message(message)};count+=1}
        func rejects(_ body:()throws->Void)->Bool {do{try body();return false}catch{return true}}
        var create=CreateRequest();create.name="cd-qa";create.image="python:local"
        create.hostPort="18080";create.containerPort="80"
        create.additionalPorts=[PortMapping(host:"18080",container:"53",transport:"udp"),PortMapping(host:"18081",container:"443")]
        create.mountSource="/tmp/quoted ' folder";create.mountTarget="/data"
        create.additionalMounts=[MountMapping(kind:.volume,source:"qa-data",target:"/database",readOnly:true),MountMapping(source:"/tmp/b",target:"/config")]
        let args=try create.arguments()
        try expect(args.filter{$0=="--publish"}.count==3 && args.contains("127.0.0.1:18080:53/udp"),"TCP/UDP can share the host port and all mappings survive")
        try expect(args.filter{$0=="--volume"}.count==3 && args.contains("qa-data:/database:ro") && args.contains("/tmp/quoted ' folder:/data"),"Multiple bind and volume mappings remain literal")
        create.additionalPorts.append(PortMapping(host:"018080",container:"8080"))
        try expect(rejects{_=try create.arguments()},"Reject numerically identical host port and protocol")
        create.additionalPorts.removeLast()
        for port in [PortMapping(),PortMapping(host:"0",container:"80"),PortMapping(host:"8000",container:"65536"),PortMapping(host:"8000",container:"80",transport:"sctp")] {
            create.additionalPorts.append(port);try expect(rejects{_=try create.arguments()},"Reject incomplete and invalid extra port rows");create.additionalPorts.removeLast()
        }
        for path in ["/data/","//data","/./data","/data/../other","relative","/tmp\nfoo"] {
            create.additionalMounts.append(MountMapping(source:"/tmp/a",target:path))
            try expect(rejects{_=try create.arguments()},"Reject duplicate normalized targets and invalid paths")
            create.additionalMounts.removeLast()
        }
        create.additionalMounts.append(MountMapping(kind:.volume,source:"",target:"/empty"))
        try expect(rejects{_=try create.arguments()},"Do not silently ignore an incomplete extra mount")
        let stopped=ContainerItem(id:"qa",state:"stopped",image:"qa:local",cpus:1,memory:268435456,ports:[],networks:[],mounts:[])
        var running=stopped;running.state="running"
        try expect(try BatchVerb.start.commands(for:stopped,current:stopped)==[["start","--","qa"]],"Start one reviewed target")
        try expect(try BatchVerb.restart.commands(for:running,current:running)==[["stop","--","qa"],["start","--","qa"]],"Restart in order without force")
        for action in BatchVerb.allCases {
            try expect(rejects{_=try action.commands(for:stopped,current:nil)},"Reject disappeared target")
            try expect(rejects{_=try action.commands(for:stopped,current:running)},"Reject changed state")
        }
        for action in [BatchVerb.start,.delete] {try expect(rejects{_=try action.commands(for:running,current:running)},"Never stop a running container implicitly")}
        for action in [BatchVerb.stop,.restart] {try expect(rejects{_=try action.commands(for:stopped,current:stopped)},"Skip stopped restart or stop")}
        var unknown=stopped;unknown.state="starting"
        try expect(rejects{_=try BatchVerb.delete.commands(for:unknown,current:unknown)},"Unknown/transitional state cannot be deleted")
        try expect(BatchVerb.delete.completed(nil) && !BatchVerb.delete.completed(stopped),"Deletion needs absence readback")
        try expect(BatchVerb.start.completed(running) && !BatchVerb.start.completed(stopped),"Start needs running readback")
        try expect(LogSnapshot.filtered("Info ready\nERROR failed\nerror retry\n",query:"error")=="ERROR failed\nerror retry","Case insensitive line filtering")
        try expect(LogSnapshot.filtered("原始\n",query:"")=="原始\n","Unfiltered export preserves raw output")
        try expect(LogSnapshot.filtered("a\nb",query:"z").isEmpty,"Empty matches")
        print("PASS: \(count) workflow checks (multi-port/mount validation, batch state protection, log snapshot filtering)")
    }
}
