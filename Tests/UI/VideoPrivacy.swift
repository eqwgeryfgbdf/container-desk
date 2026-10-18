import Foundation
import AVFoundation
import Vision
import AppKit

/// Sample the actual exported video for a host-name leak. This supplements,
/// rather than replaces, visual review of the full walkthrough and transitions.
@main struct VideoPrivacy {
    static func main() async throws {
        let asset=AVURLAsset(url:URL(fileURLWithPath:CommandLine.arguments[1]))
        let seconds=try await asset.load(.duration).seconds
        let generator=AVAssetImageGenerator(asset:asset)
        generator.appliesPreferredTrackTransform=true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let host=Host.current().localizedName ?? ""
        let prefix=String(host.prefix(4)).lowercased()
        guard prefix.count>=3 else{throw NSError(domain:"Privacy",code:1)}
        var checked=0,leaks:[Double]=[]
        for time in stride(from:0.0,to:seconds,by:0.25) {
            let cg=try await generator.image(at:CMTime(seconds:time,preferredTimescale:600)).image
            let request=VNRecognizeTextRequest();request.recognitionLevel = .accurate
            request.usesLanguageCorrection=false;request.minimumTextHeight=0.006
            try VNImageRequestHandler(cgImage:cg).perform([request])
            if (request.results ?? []).contains(where:{$0.topCandidates(1).first?.string.lowercased().contains(prefix)==true}){leaks.append(time)}
            checked+=1
        }
        guard leaks.isEmpty else{fputs("FAIL: possible host-name text at seconds \(leaks)\n",stderr);exit(1)}
        print("PASS: no host-name prefix detected in \(checked) frames sampled every 0.25 s; visual review still required")
    }
}
