import Foundation
@main struct ConvenienceTests {
 static func main()throws {
  func check(_ value:Bool,_ message:String)throws {if !value{throw DeskError.message(message)}}
  func reject(_ action:()throws->Void)throws {do{try action()}catch{return};throw DeskError.message("Expected refusal")}
  let process:[String:Any] = ["executable":"sleep","arguments":["600"],"environment":["EXAMPLE=value"],"workingDirectory":"/","user":["id":["uid":1000,"gid":1000]],"terminal":false,"rlimits":[],"supplementalGroups":[]]
  var c:[String:Any] = ["id":"original","image":["reference":"docker.io/library/busybox:1.37","descriptor":["digest":"sha256:abc"]],"resources":["cpus":2,"memoryInBytes":Int64(768*1048576)],"platform":["os":"linux","architecture":"arm64"],"initProcess":process,"networks":[["network":"default","options":["hostname":"original","mtu":1280]]],"mounts":[["type":["volume":["name":"saved"]],"source":"/engine/data","destination":"/data","options":[]]],"runtimeHandler":"container-runtime-linux","labels":[:],"dns":["nameservers":[],"options":[],"searchDomains":[]]]
  func data(_ c:[String:Any],_ state:String="stopped")throws->Data {try JSONSerialization.data(withJSONObject:[["configuration":c,"status":["state":state]]])}
  let plan=try ContainerClonePlan(data(c))
  let empty=plan.request(environment:false,mounts:false,writable:false)
  try check(empty.environment.isEmpty && empty.allMounts.isEmpty && empty.hostPort.isEmpty,"Clone must not silently share secrets, mounts or ports")
  try check(empty.user=="1000:1000" && empty.memoryMB==768 && empty.cpus==2 && empty.name=="original-copy","Allocation/user/name")
  let shared=plan.request(environment:true,mounts:true,writable:false)
  try check(shared.environment=="EXAMPLE=value" && shared.allMounts[0].readOnly,"Opt-in environment and read-only mount")
  try plan.origin(requireStopped:true).validate(data(c))
  try reject{try plan.origin(requireStopped:true).validate(data(c,"running"))}
  try plan.origin(requireStopped:false).validate(data(c,"running"))
  c["readOnly"]=true
  try reject{_=try ContainerClonePlan(data(c))}
  try reject{try plan.origin(requireStopped:false).validate(data(c))}
  c["readOnly"]=false;c["networks"]=[["network":"custom","options":["mtu":1500]]]
  try reject{_=try ContainerClonePlan(data(c))}
  c["networks"]=[];var p=process;p["arguments"]=["line\nbreak"];c["initProcess"]=p
  try reject{_=try ContainerClonePlan(data(c))}
  let disk=try JSONDecoder().decode([String:DiskUsageEntry].self,from:Data(#"{"images":{"active":1,"total":2,"sizeInBytes":300,"reclaimable":100}}"#.utf8))
  try check(disk["images"]?.reclaimable==100,"Engine disk sizes")
  let img=try JSONSerialization.data(withJSONObject:[["variants":[["platform":["architecture":"arm64"],"config":["config":["Entrypoint":["python3"],"Cmd":["-m","http.server"],"ExposedPorts":["8000/tcp":[:]]]]]]]])
  let defaults=try ImageDefaults(img,architecture:"arm64")
  try check(defaults.entrypoint==["python3"] && defaults.ports==["8000/tcp"],"Image defaults and declared ports")
  try reject{_=try ImageDefaults(img,architecture:"amd64")}
  print("PASS: convenience planning, source fingerprint/running protection, explicit secret/mount policies, unsupported configuration refusal, disk schema and image defaults")
 }
}
