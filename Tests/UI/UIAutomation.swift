import AppKit
import ApplicationServices
import Foundation

struct Failure:Error,CustomStringConvertible {let description:String}
func attribute(_ e:AXUIElement,_ key:String)->CFTypeRef? {var v:CFTypeRef?;AXUIElementCopyAttributeValue(e,key as CFString,&v);return v}
func string(_ e:AXUIElement,_ key:String)->String {attribute(e,key) as? String ?? ""}
func children(_ e:AXUIElement)->[AXUIElement] {attribute(e,kAXChildrenAttribute) as? [AXUIElement] ?? []}
func nodes(_ e:AXUIElement,_ depth:Int=0)->[AXUIElement] {guard depth<24 else{return []};return [e]+children(e).flatMap{nodes($0,depth+1)}}
func text(_ e:AXUIElement)->String {[kAXTitleAttribute,kAXDescriptionAttribute,kAXValueAttribute,kAXIdentifierAttribute,kAXPlaceholderValueAttribute].map{string(e,$0)}.filter{!$0.isEmpty}.joined(separator:" | ")}
func pump(_ seconds:Double){Thread.sleep(forTimeInterval:seconds)}
func check(_ value:Bool,_ reason:String)throws {if !value{throw Failure(description:reason)}}
let args=CommandLine.arguments
let running=NSWorkspace.shared.runningApplications.first{$0.localizedName=="Container Desk"}
guard AXIsProcessTrusted(),let running else{fputs("BLOCKED: launch Container Desk and grant Accessibility to the test runner.\n",stderr);exit(2)}
let app=AXUIElementCreateApplication(running.processIdentifier)
AXUIElementSetMessagingTimeout(app,2)
func find(_ label:String,role:String?=nil)->AXUIElement? {nodes(app).first{e in (role == nil || string(e,kAXRoleAttribute)==role!) && [kAXTitleAttribute,kAXDescriptionAttribute,kAXValueAttribute,kAXIdentifierAttribute,kAXPlaceholderValueAttribute].contains{string(e,$0)==label}}}
func wait(_ label:String,role:String?=nil,seconds:Double=12)throws->AXUIElement {let end=Date().addingTimeInterval(seconds);repeat{if let e=find(label,role:role){return e};pump(0.15)}while Date()<end;throw Failure(description:"UI element not found: \(label) [\(role ?? "any")]")}
func press(_ e:AXUIElement)throws {try check((attribute(e,kAXEnabledAttribute) as? Bool) != false,"Control disabled: \(text(e))");try check(AXUIElementPerformAction(e,kAXPressAction as CFString) == .success,"AXPress failed: \(text(e))");pump(0.3)}
func point(_ e:AXUIElement)throws->CGPoint {guard let v=attribute(e,kAXPositionAttribute),CFGetTypeID(v)==AXValueGetTypeID() else{throw Failure(description:"Missing bounds")};var p=CGPoint.zero;AXValueGetValue(v as! AXValue,.cgPoint,&p);return p}
func click(_ e:AXUIElement,count:Int=1)throws {let p=try point(e);var size=CGSize.zero;if let v=attribute(e,kAXSizeAttribute),CFGetTypeID(v)==AXValueGetTypeID(){AXValueGetValue(v as! AXValue,.cgSize,&size)};let at=CGPoint(x:p.x+size.width/2,y:p.y+size.height/2);for clickIndex in 1...count {for kind:CGEventType in [.leftMouseDown,.leftMouseUp]{let ev=CGEvent(mouseEventSource:nil,mouseType:kind,mouseCursorPosition:at,mouseButton:.left);ev?.setIntegerValueField(.mouseEventClickState,value:Int64(clickIndex));ev?.post(tap:.cghidEventTap)};pump(0.08)};pump(0.4)}
func window()->AXUIElement?{(attribute(app,kAXWindowsAttribute) as? [AXUIElement])?.first}
func privacyRects(_ bounds:[String:Double])->[[String:Double]] {
    let name=Host.current().localizedName ?? ""
    return nodes(app).filter{!name.isEmpty && string($0,kAXValueAttribute)==name}.compactMap { e in
        guard let p=try? point(e),let raw=attribute(e,kAXSizeAttribute),CFGetTypeID(raw)==AXValueGetTypeID() else{return nil}
        var size=CGSize.zero;AXValueGetValue(raw as! AXValue,.cgSize,&size)
        return ["x":p.x-(bounds["X"] ?? 0)-3,"y":p.y-(bounds["Y"] ?? 0)-2,"width":size.width+6,"height":size.height+4]
    }
}
func metadata()throws {let info=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? [];guard let w=info.first(where:{$0[kCGWindowOwnerPID as String] as? Int32==running.processIdentifier && $0[kCGWindowLayer as String] as? Int==0}) else{throw Failure(description:"Window not visible")};let result:[String:Any]=["pid":running.processIdentifier,"windowID":w[kCGWindowNumber as String]!,"bounds":w[kCGWindowBounds as String]!,"privateRects":privacyRects(w[kCGWindowBounds as String] as! [String:Double])];print(String(data:try JSONSerialization.data(withJSONObject:result,options:.sortedKeys),encoding:.utf8)!)}
do {
 if args.count<2 || args[1]=="dump" {for e in nodes(app){let r=string(e,kAXRoleAttribute);if !["AXGroup","AXCell","AXColumn"].contains(r){print(r+" | "+text(e))}}}
 else if args[1]=="metadata" {try metadata()}
 else if args[1]=="run" {
  let scenario=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [[String:Any]]
  running.activate();pump(0.4)
  let started=Date()
  for (i,step) in scenario.enumerated() {
   if let title=step["title"] as? String {let chapter:[String:Any]=["seconds":Date().timeIntervalSince(started),"title":title];print("CHAPTER "+String(data:try JSONSerialization.data(withJSONObject:chapter),encoding:.utf8)!);fflush(stdout)}
   let action=step["action"] as! String,label=step["label"] as? String ?? "",role=step["role"] as? String
   switch action {
   case "press":try press(wait(label,role:role))
   case "click","doubleClick":try click(wait(label,role:role),count:action=="doubleClick" ? 2:1)
   case "nav": if find("Sidebar",role:"AXOutline")==nil,let toggle=find("Show Sidebar",role:"AXButton") ?? find("Hide Sidebar",role:"AXButton"){try press(toggle)};let outline=try wait("Sidebar",role:"AXOutline");guard let row=children(outline).first(where:{nodes($0).contains{string($0,kAXValueAttribute)==label}}) else{throw Failure(description:"Navigation missing: \(label)")};try click(row)
   case "set":
    let e=try wait(label,role:role ?? "AXTextField");try click(e)
    for down in [true,false]{let event=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:down);event?.flags = .maskCommand;event?.post(tap:.cghidEventTap)}
    let value=Array((step["value"] as! String).utf16)
    for down in [true,false]{let event=CGEvent(keyboardEventSource:nil,virtualKey:value.isEmpty ? 51:0,keyDown:down);event?.flags=[];if !value.isEmpty{event?.keyboardSetUnicodeString(stringLength:value.count,unicodeString:value)};event?.post(tap:.cghidEventTap)}
    pump(0.3)

   case "expect":_=try wait(label,role:role,seconds:step["timeout"] as? Double ?? 12)
   case "pause":pump(min(10,step["seconds"] as? Double ?? 1))
   case "key":let code=CGKeyCode(step["code"] as! Int);let flags:CGEventFlags=step["command"] as? Bool==true ? .maskCommand:[];for down in [true,false]{let e=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:down);e?.flags=flags;e?.post(tap:.cghidEventTap)};pump(0.4)
   case "resize":guard let w=window() else{throw Failure(description:"No window")};var s=CGSize(width:step["width"] as! Double,height:step["height"] as! Double);var p=CGPoint(x:60,y:80);_=AXUIElementSetAttributeValue(w,kAXSizeAttribute as CFString,AXValueCreate(.cgSize,&s)!);_=AXUIElementSetAttributeValue(w,kAXPositionAttribute as CFString,AXValueCreate(.cgPoint,&p)!);pump(0.8);var verified=false
    for _ in 0..<20 {
        let list=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
        if let info=list.first(where:{$0[kCGWindowOwnerPID as String] as? Int32==running.processIdentifier && $0[kCGWindowLayer as String] as? Int==0}),let b=info[kCGWindowBounds as String] as? [String:Double],abs((b["Width"] ?? 0)-s.width)<2,abs((b["Height"] ?? 0)-s.height)<2 {verified=true;break}
        pump(0.1)
    }
    try check(verified,"Resize readback failed")
   default:throw Failure(description:"Unknown action \(action)")
   }
   print("PASS UI \(i+1): \(action) \(label)");fflush(stdout)
  }
  print("DURATION \(Date().timeIntervalSince(started))")
  print("PASS: UI scenario complete (\(scenario.count) steps)")
 }
} catch {fputs("FAIL: \(error)\n",stderr);exit(1)}
