import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import HirebarCore
import ImageIO

/// Arma el Short/Reel de una cuenta (1080×1920) solo con lo que trae macOS:
/// - convierte cada escena HTML en imagen con Chrome sin ventana,
/// - le pone voz en español a la narración de cada escena (comando `say`); la escena dura lo que dura su voz,
/// - dibuja subtítulos grandes palabra por palabra (la palabra que suena va en el color de acento),
/// - mueve la imagen (entrada con rebote y acercamiento lento) y funde una escena con la siguiente,
/// - mezcla la voz y, si existe, la música de fondo de la cuenta (musica.mp3) a volumen bajo.
public enum ReelRenderer {
    static let width = 1080
    static let height = 1920
    static let fps: Int32 = 30
    static let fade = 0.2
    static let captionCenterFromTop = 1300.0
    static let wordsPerCaption = 3
    static let musicVolume: Float = 0.12

    struct Scene: Decodable {
        let archivo: String
        let texto: String?
        let segundos: Double?
    }

    struct Script: Decodable {
        let escenas: [Scene]
    }

    struct Clip {
        let image: CGImage
        let seconds: Double
        let spoken: Double
        let words: [String]
        let audio: URL?
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

    static func make(_ account: ContentAccount) throws -> URL {
        let folder = account.videoFolder
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("guion.json")),
              let script = try? JSONDecoder().decode(Script.self, from: data), !script.escenas.isEmpty else {
            throw Problem(message: "\(AI.name) no dejó el guion del video (video/guion.json)")
        }
        guard let chrome = CVRenderer.chromePath() else { throw Problem(message: "no encontré Google Chrome") }
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-chrome", isDirectory: true)
        let voice = SpeechVoices.pick(account.voice)
        if voice == nil { Log.write("Contenido (\(account.id)): no hay voces en español instaladas; el video sale sin voz") }

        var clips: [Clip] = []
        for (index, scene) in script.escenas.enumerated() {
            let page = folder.appendingPathComponent(scene.archivo)
            let png = page.deletingPathExtension().appendingPathExtension("png")
            guard FileManager.default.fileExists(atPath: page.path),
                  SlideRenderer.shoot(page, to: png, chrome: chrome, scratch: scratch, width: width, height: height),
                  let source = CGImageSourceCreateWithURL(png as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
            let text = (scene.texto ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            var audio: URL?
            var spoken = scene.segundos ?? max(1.5, Double(text.split(separator: " ").count) / 2.6)
            if !text.isEmpty, let voice {
                let file = folder.appendingPathComponent("voz-\(index + 1).aiff")
                if SpeechVoices.speak(text, voice: voice, to: file), let length = SpeechVoices.duration(file) {
                    audio = file
                    spoken = length
                }
            }
            let seconds = min(12, max(1.2, spoken + 0.25))
            clips.append(Clip(image: image, seconds: seconds, spoken: spoken,
                              words: text.split(whereSeparator: \.isWhitespace).map(String.init), audio: audio))
        }
        guard !clips.isEmpty else { throw Problem(message: "Chrome no pudo convertir las escenas") }

        let silent = folder.appendingPathComponent("reel-sin-sonido.mp4")
        let target = output(account)
        try? FileManager.default.removeItem(at: silent)
        try? FileManager.default.removeItem(at: target)
        try writeVideo(clips, accent: color(account.palette.accent), to: silent)
        let music = account.music
        if clips.contains(where: { $0.audio != nil }) || music != nil {
            try mix(video: silent, clips: clips, music: music, to: target)
            try? FileManager.default.removeItem(at: silent)
        } else {
            try FileManager.default.moveItem(at: silent, to: target)
        }
        let total = clips.reduce(0) { $0 + $1.seconds }
        Log.write("Contenido (\(account.id)): video de \(clips.count) escenas y \(Int(total)) s listo"
                  + (voice.map { " (voz \($0))" } ?? " (sin voz)") + (music == nil ? "" : " con música"))
        return target
    }

    // MARK: - Imagen

    static func writeVideo(_ clips: [Clip], accent: NSColor, to url: URL) throws {
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
        for (index, clip) in clips.enumerated() {
            let count = max(1, Int((clip.seconds * Double(fps)).rounded()))
            let next = index + 1 < clips.count ? clips[index + 1].image : nil
            for frame in 0..<count {
                let elapsed = Double(frame) / Double(fps)
                let left = clip.seconds - elapsed
                let alpha = (next != nil && left < fade) ? min(1, 1 - left / fade) : 0
                // Entrada con un pequeño rebote y luego un acercamiento lento.
                let entry = min(1, elapsed / 0.25)
                let zoom = 1.0 + 0.06 * (1 - entry) * (1 - entry) + 0.035 * (elapsed / clip.seconds)
                let caption = captionWords(clip, at: elapsed)
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                guard let buffer = pixelBuffer(pool: adaptor.pixelBufferPool, current: clip.image, zoom: zoom,
                                               next: next, alpha: alpha, caption: caption, accent: accent) else {
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

    /// Grupo de palabras que se ve en pantalla en ese momento y cuál de ellas está sonando.
    static func captionWords(_ clip: Clip, at elapsed: Double) -> (words: [String], active: Int)? {
        guard !clip.words.isEmpty, clip.spoken > 0 else { return nil }
        let weights = clip.words.map { Double($0.count) + 1.5 }
        let total = weights.reduce(0, +)
        let target = min(0.999, max(0, elapsed / clip.spoken)) * total
        var sum = 0.0
        var active = clip.words.count - 1
        for (index, weight) in weights.enumerated() {
            sum += weight
            if target < sum { active = index; break }
        }
        let start = (active / wordsPerCaption) * wordsPerCaption
        let end = min(clip.words.count, start + wordsPerCaption)
        return (Array(clip.words[start..<end]), active - start)
    }

    static func pixelBuffer(pool: CVPixelBufferPool?, current: CGImage, zoom: Double, next: CGImage?, alpha: Double,
                            caption: (words: [String], active: Int)?, accent: NSColor) -> CVPixelBuffer? {
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
            context.saveGState()
            context.setAlpha(CGFloat(alpha))
            context.draw(next, in: CGRect(x: 0, y: 0, width: width, height: height))
            context.restoreGState()
        }
        if let caption, alpha < 0.5 { drawCaption(caption.words, active: caption.active, accent: accent, in: context) }
        return buffer
    }

    static func drawCaption(_ words: [String], active: Int, accent: NSColor, in context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        let font = NSFont.systemFont(ofSize: 88, weight: .heavy)
        let text = NSMutableAttributedString()
        for (index, word) in words.enumerated() {
            text.append(NSAttributedString(string: (index == 0 ? "" : " ") + word, attributes: [
                .font: font,
                .foregroundColor: index == active ? accent : NSColor.white,
                .strokeColor: NSColor.black,
                .strokeWidth: -6,
                .paragraphStyle: paragraph,
                .shadow: shadow,
            ]))
        }
        let margin = 90.0
        let box = CGSize(width: Double(width) - margin * 2, height: 600)
        let bounds = text.boundingRect(with: box, options: [.usesLineFragmentOrigin, .usesFontLeading])
        let rect = CGRect(x: margin, y: Double(height) - captionCenterFromTop - bounds.height / 2,
                          width: box.width, height: bounds.height + 12)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
    }

    static func color(_ hex: String) -> NSColor {
        let clean = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return .systemYellow }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    // MARK: - Sonido

    static func mix(video: URL, clips: [Clip], music: URL?, to target: URL) throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        guard let source = videoAsset.tracks(withMediaType: .video).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Problem(message: "no se pudo leer el video para ponerle la voz")
        }
        let total = videoAsset.duration
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: total), of: source, at: .zero)

        if let voiceTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            var cursor = 0.0
            for clip in clips {
                if let audio = clip.audio {
                    let asset = AVURLAsset(url: audio)
                    if let track = asset.tracks(withMediaType: .audio).first {
                        let length = CMTimeMinimum(asset.duration, CMTime(seconds: clip.seconds, preferredTimescale: 600))
                        try? voiceTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: track,
                                                        at: CMTime(seconds: cursor, preferredTimescale: 600))
                    }
                }
                cursor += clip.seconds
            }
        }

        var parameters: [AVMutableAudioMixInputParameters] = []
        if let music, let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let asset = AVURLAsset(url: music)
            if let track = asset.tracks(withMediaType: .audio).first, asset.duration.seconds > 1 {
                var at = CMTime.zero
                while CMTimeCompare(at, total) < 0 {
                    let length = CMTimeMinimum(asset.duration, CMTimeSubtract(total, at))
                    try? musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: track, at: at)
                    at = CMTimeAdd(at, length)
                }
                let volume = AVMutableAudioMixInputParameters(track: musicTrack)
                volume.setVolume(musicVolume, at: .zero)
                parameters.append(volume)
            }
        }

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Problem(message: "no se pudo preparar la exportación del video")
        }
        export.outputURL = target
        export.outputFileType = .mp4
        if !parameters.isEmpty {
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = parameters
            export.audioMix = audioMix
        }
        let done = DispatchSemaphore(value: 0)
        export.exportAsynchronously { done.signal() }
        done.wait()
        guard export.status == .completed else {
            throw export.error ?? Problem(message: "no se pudo exportar el video con voz")
        }
    }
}
