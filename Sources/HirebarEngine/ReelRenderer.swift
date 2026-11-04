import AVFoundation
import CoreGraphics
import Foundation
import HirebarCore
import ImageIO

/// Arma el video vertical (Reel/Short) de una cuenta: convierte cada escena HTML de 1080×1920 en imagen con Chrome
/// y las une en un MP4 con un acercamiento suave y un fundido entre escenas. Usa solo lo que trae macOS.
public enum ReelRenderer {
    static let width = 1080
    static let height = 1920
    static let fps: Int32 = 30
    static let fade = 0.4

    struct Scene: Decodable {
        let archivo: String
        let segundos: Double?
    }

    struct Script: Decodable {
        let escenas: [Scene]
    }

    struct Problem: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    public static func output(_ account: ContentAccount) -> URL {
        account.videoFolder.appendingPathComponent("reel.mp4")
    }

    public static func render(_ account: ContentAccount, completion: @escaping (_ video: URL?, _ problem: String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result: (URL?, String?)
            do {
                result = (try make(account), nil)
            } catch {
                result = (nil, error.localizedDescription)
            }
            if let problem = result.1 { Log.write("Contenido (\(account.id)): no salió el video: \(problem)") }
            DispatchQueue.main.async { completion(result.0, result.1) }
        }
    }

    static func scenes(in folder: URL) -> [(URL, Double)] {
        let script = folder.appendingPathComponent("guion.json")
        if let data = try? Data(contentsOf: script),
           let parsed = try? JSONDecoder().decode(Script.self, from: data), !parsed.escenas.isEmpty {
            return parsed.escenas.map { (folder.appendingPathComponent($0.archivo), min(8, max(1.5, $0.segundos ?? 3))) }
        }
        return SlideRenderer.pages(in: folder).map { ($0, 3) }
    }

    static func make(_ account: ContentAccount) throws -> URL {
        let folder = account.videoFolder
        let list = scenes(in: folder).filter { FileManager.default.fileExists(atPath: $0.0.path) }
        guard !list.isEmpty else { throw Problem(message: "\(AI.name) no dejó las escenas del video") }
        guard let chrome = CVRenderer.chromePath() else { throw Problem(message: "no encontré Google Chrome") }
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-chrome", isDirectory: true)
        var frames: [(CGImage, Double)] = []
        for (page, seconds) in list {
            let png = page.deletingPathExtension().appendingPathExtension("png")
            guard SlideRenderer.shoot(page, to: png, chrome: chrome, scratch: scratch, width: width, height: height),
                  let source = CGImageSourceCreateWithURL(png as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
            frames.append((image, seconds))
        }
        guard !frames.isEmpty else { throw Problem(message: "Chrome no pudo convertir las escenas") }
        let target = output(account)
        try? FileManager.default.removeItem(at: target)
        try write(frames, to: target)
        Log.write("Contenido (\(account.id)): video de \(frames.count) escenas listo")
        return target
    }

    static func write(_ scenes: [(CGImage, Double)], to url: URL) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw Problem(message: "no se pudo preparar el video") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Problem(message: "no se pudo empezar el video") }
        writer.startSession(atSourceTime: .zero)

        var frameIndex: Int64 = 0
        for (index, scene) in scenes.enumerated() {
            let count = max(1, Int((scene.1 * Double(fps)).rounded()))
            let next = index + 1 < scenes.count ? scenes[index + 1].0 : nil
            for frame in 0..<count {
                let elapsed = Double(frame) / Double(fps)
                let progress = Double(frame) / Double(max(1, count - 1))
                let left = scene.1 - elapsed
                let alpha = (next != nil && left < fade) ? min(1, 1 - left / fade) : 0
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                guard let buffer = pixelBuffer(pool: adaptor.pixelBufferPool, current: scene.0,
                                               zoom: 1 + 0.04 * progress, next: next, alpha: alpha) else {
                    throw Problem(message: "no se pudo dibujar un cuadro del video")
                }
                adaptor.append(buffer, withPresentationTime: CMTime(value: frameIndex, timescale: fps))
                frameIndex += 1
            }
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw writer.error ?? Problem(message: "no se pudo terminar el video") }
    }

    static func pixelBuffer(pool: CVPixelBufferPool?, current: CGImage, zoom: Double, next: CGImage?, alpha: Double) -> CVPixelBuffer? {
        var created: CVPixelBuffer?
        if let pool {
            _ = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created)
        } else {
            _ = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32ARGB, nil, &created)
        }
        guard let buffer = created else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        context.interpolationQuality = .high
        let w = Double(width) * zoom
        let h = Double(height) * zoom
        context.draw(current, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h))
        if let next, alpha > 0 {
            context.setAlpha(CGFloat(alpha))
            context.draw(next, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return buffer
    }
}
