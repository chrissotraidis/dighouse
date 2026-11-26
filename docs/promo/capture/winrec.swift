
import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia
import AppKit

/// Record one window, and only that window, with no pointer: winrec <window id> <out.mov> <max seconds>
/// Stops early when a file named <out.mov>.stop appears.
final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    var started = false
    var frames = 0

    init(url: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 30_000_000, AVVideoExpectedSourceFrameRateKey: 30],
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sb.isValid,
              let info = (CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]])?.first,
              let raw = info[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let pixels = sb.imageBuffer else { return }
        let t = sb.presentationTimeStamp
        if !started { writer.startWriting(); writer.startSession(atSourceTime: t); started = true }
        if input.isReadyForMoreMediaData, adaptor.append(pixels, withPresentationTime: t) { frames += 1 }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) { print("stream stopped:", error) }
}

_ = NSApplication.shared   // the window server must be connected before ScreenCaptureKit is asked anything
let args = CommandLine.arguments
guard args.count >= 4, let wid = UInt32(args[1]), let limit = Double(args[3]) else { print("usage: winrec id out.mov seconds"); exit(1) }
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let window = content.windows.first(where: { $0.windowID == wid }) else { print("no such window"); exit(2) }
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2
        config.height = Int(window.frame.height) * 2
        config.showsCursor = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.ignoreShadowsSingleWindow = true
        let rec = try Recorder(url: URL(fileURLWithPath: args[2]), width: config.width, height: config.height)
        let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window), configuration: config, delegate: rec)
        try stream.addStreamOutput(rec, type: .screen, sampleHandlerQueue: DispatchQueue(label: "winrec"))
        try await stream.startCapture()
        print("recording", config.width, config.height); fflush(stdout)
        let began = Date()
        while Date().timeIntervalSince(began) < limit, !FileManager.default.fileExists(atPath: args[2] + ".stop") {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        try await stream.stopCapture()
        rec.input.markAsFinished()
        await rec.writer.finishWriting()
        print("done", rec.frames, "frames"); exit(0)
    } catch { print("error:", error); exit(3) }
}
dispatchMain()

