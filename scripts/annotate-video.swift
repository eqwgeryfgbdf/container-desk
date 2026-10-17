import Foundation
import AVFoundation
import AppKit
import CoreImage

/// Adds chapter captions and masks host-name rectangles to actual window footage.
/// No generated UI frames or simulated product output are used.
@main struct AnnotateVideo {
    static func main() async throws {
        let args=CommandLine.arguments
        guard args.count==5 else {fatalError("raw.mov window.json ui.log output.mp4")}
        let raw=URL(fileURLWithPath:args[1]),destination=URL(fileURLWithPath:args[4])
        let metadata=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [String:Any]
        let bounds=metadata["bounds"] as! [String:Double]
        let privateRects=metadata["privateRects"] as! [[String:Double]]
        guard !privateRects.isEmpty else{throw NSError(domain:"Video",code:1,userInfo:[NSLocalizedDescriptionKey:"No host-name privacy regions were captured; review before export."])}
        let asset=AVURLAsset(url:raw)
        let duration=try await asset.load(.duration)
        let track=try await asset.loadTracks(withMediaType:.video).first!
        let size=try await track.load(.naturalSize)
        guard abs(size.width-bounds["Width"]!)<2,abs(size.height-bounds["Height"]!)<2 else{fatalError("Recording/window dimensions differ; privacy masks would be misaligned")}
        let lines=try String(contentsOfFile:args[3],encoding:.utf8).components(separatedBy:.newlines)
        let chapters=try lines.filter{$0.hasPrefix("CHAPTER ")}.map {line -> (Double,String) in
            let item=try JSONSerialization.jsonObject(with:Data(line.dropFirst(8).utf8)) as! [String:Any]
            return ((item["seconds"] as! Double)+1.4,item["title"] as! String)
        }
        guard lines.contains(where:{$0.hasPrefix("PASS: UI scenario complete")}),!lines.contains(where:{$0.hasPrefix("FAIL:")}) else{fatalError("Do not promote a failed UI recording")}
        guard let elapsed=lines.first(where:{$0.hasPrefix("DURATION ")}).flatMap({Double($0.dropFirst(9))}),duration.seconds>=elapsed+1 else{fatalError("Recording ended before the UI scenario completed")}
        let finalDuration=CMTime(seconds:min(duration.seconds,elapsed+2),preferredTimescale:600)
        let detailsStart=chapters.first(where:{$0.1.hasPrefix("雙擊展開")})?.0 ?? 0
        let imagesStart=chapters.first(where:{$0.1.hasPrefix("下載與快速部署")})?.0 ?? duration.seconds
        func overlay(_ title:String)->CIImage {
            let image=NSImage(size:NSSize(width:size.width,height:76));image.lockFocus()
            NSColor(calibratedWhite:0.07,alpha:0.94).setFill();NSRect(x:0,y:0,width:size.width,height:76).fill()
            (title as NSString).draw(at:NSPoint(x:28,y:31),withAttributes:[.font:NSFont.systemFont(ofSize:23,weight:.medium),.foregroundColor:NSColor.white])
            ("REAL APP FOOTAGE  ·  DEVELOPMENT PREVIEW" as NSString).draw(at:NSPoint(x:29,y:11),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor(calibratedWhite:0.7,alpha:1)])
            image.unlockFocus();return CIImage(cgImage:image.cgImage(forProposedRect:nil,context:nil,hints:nil)!)
        }
        let titles=chapters.map{($0.0,overlay($0.1))}
        let composition=AVMutableVideoComposition(asset:asset,applyingCIFiltersWithHandler:{request in
            let time=request.compositionTime.seconds
            var frame=request.sourceImage
            for r in privateRects {
                // Sidebar stays visible on most pages. Overview's second hostname
                // only needs masking through the initial page transition.
                if r["x"]!>220 && time>6 {continue}
                if r["x"]!<=220 && time>detailsStart+0.8 && time<imagesStart {continue}
                let rect=CGRect(x:r["x"]!,y:size.height-r["y"]!-r["height"]!,width:r["width"]!,height:r["height"]!)
                frame=CIImage(color:CIColor(red:0.94,green:0.95,blue:0.96)).cropped(to:rect).composited(over:frame)
            }
            if let title=titles.last(where:{$0.0<=time})?.1 ?? titles.first?.1 {frame=title.composited(over:frame)}
            request.finish(with:frame,context:nil)
        })
        composition.frameDuration=CMTime(value:1,timescale:30)
        guard let exporter=AVAssetExportSession(asset:asset,presetName:AVAssetExportPresetHighestQuality) else{fatalError("No video exporter")}
        exporter.videoComposition=composition
        exporter.timeRange=CMTimeRange(start:.zero,duration:finalDuration)
        try await exporter.export(to:destination,as:.mp4)
        let result=AVURLAsset(url:destination)
        let seconds=try await result.load(.duration).seconds
        guard seconds>15,abs(seconds-finalDuration.seconds)<1 else{fatalError("Video duration verification failed")}
        let generator=AVAssetImageGenerator(asset:result);generator.appliesPreferredTrackTransform=true
        for (i,t) in [1.0,min(12,seconds/3),min(30,seconds/2),seconds-3].enumerated() {
            let cg=try await generator.image(at:CMTime(seconds:t,preferredTimescale:600)).image
            let bitmap=NSBitmapImageRep(cgImage:cg)
            try bitmap.representation(using:.png,properties:[:])!.write(to:destination.deletingPathExtension().appendingPathExtension("frame\(i).png"))
        }
        print("PASS: \(String(format:"%.1f",seconds)) seconds, \(Int(size.width))×\(Int(size.height)), chapter captions and host-name redactions; four review frames exported")
    }
}
