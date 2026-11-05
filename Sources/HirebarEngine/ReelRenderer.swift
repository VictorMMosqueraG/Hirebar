import AppKit
import AVFoundation
import CoreGraphics
import Foundation
import HirebarCore
import ImageIO

/// Arma el Short/Reel de una cuenta (1080×1920) en el Mac:
/// - pone voz a la narración de cada escena (ElevenLabs o la voz del Mac); la escena dura lo que dura su voz,
/// - graba cada escena HTML ANIMADA cuadro por cuadro (30 por segundo) con el motor web de macOS,
///   y si una escena no se puede animar usa una imagen fija de Chrome con un acercamiento suave,
/// - dibuja subtítulos grandes palabra por palabra (la palabra que suena va en el color de acento),
/// - mezcla la voz y, si existe, la música de fondo de la cuenta (musica.mp3) a volumen bajo.
public enum ReelRenderer {
    static let width = 1080
    static let height = 1920
    static let fps: Int32 = 30
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
        let page: URL
        let seconds: Double
        let words: [WordTiming]
        let audio: URL?
    }

    /// El video salió, pero con algo menos (por ejemplo, sin voz).
    struct PartialProblem: LocalizedError {
        let video: URL
        let message: String
        var errorDescription: String? { message }
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
            } catch let partial as PartialProblem {
                result = (partial.video, partial.message)
            } catch {
                result = (nil, error.localizedDescription)
            }
            if result.0 == nil, let problem = result.1 { Log.write("Contenido (\(account.id)): no salió el video: \(problem)") }
            DispatchQueue.main.async { completion(result.0, result.1) }
        }
    }

    /// Si hay clave de ElevenLabs y la cuenta no tiene una voz escogida, escoge sola la mejor voz para Shorts
    /// y la deja guardada en la cuenta.
    static func ensureVoice(_ account: ContentAccount) -> ContentAccount {
        // Sin nada que configurar: si la cuenta seguía con la voz del Mac por defecto, o escogió Azure o ElevenLabs
        // pero no hay clave, pasa a la voz neuronal de Microsoft (sin cuenta).
        let noKey = (account.voiceEngine == .azure && Narrator.azureKey == nil)
            || (account.voiceEngine == .elevenlabs && Narrator.elevenLabsKey == nil)
        if noKey || (account.voiceEngine == .macos && account.voice.isEmpty) {
            var updated = account
            updated.voiceEngine = .edge
            updated.voice = ""
            var all = ContentAccountStore.load()
            if let index = all.firstIndex(where: { $0.id == account.id }) {
                all[index].voiceEngine = .edge
                all[index].voice = ""
                try? ContentAccountStore.save(all)
            }
            return updated
        }
        guard account.voice.isEmpty, account.voiceEngine == .azure || account.voiceEngine == .elevenlabs else { return account }
        let engine: VoiceEngine
        let voice: String
        if Narrator.azureKey != nil, account.voiceEngine != .elevenlabs {
            engine = .azure
            voice = VoiceEngine.azureDefaultVoice
        } else if let key = Narrator.elevenLabsKey, account.voiceEngine != .azure,
                  let chosen = Narrator.chooseShortsVoice(key: key) {
            engine = .elevenlabs
            voice = chosen.id
        } else {
            return account
        }
        var updated = account
        updated.voiceEngine = engine
        updated.voice = voice
        var all = ContentAccountStore.load()
        if let index = all.firstIndex(where: { $0.id == account.id }) {
            all[index].voiceEngine = engine
            all[index].voice = voice
            try? ContentAccountStore.save(all)
        }
        return updated
    }

    static func make(_ original: ContentAccount) throws -> URL {
        let account = ensureVoice(original)
        let folder = account.videoFolder
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("guion.json")),
              let script = try? JSONDecoder().decode(Script.self, from: data), !script.escenas.isEmpty else {
            throw Problem(message: "\(AI.name) no dejó el guion del video (video/guion.json)")
        }
        var clips: [Clip] = []
        var voiceProblem: String?
        var previous: String?
        for (index, scene) in script.escenas.enumerated() {
            let page = folder.appendingPathComponent(scene.archivo)
            guard FileManager.default.fileExists(atPath: page.path) else { continue }
            let text = (scene.texto ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            var narration: Narration?
            if !text.isEmpty && voiceProblem == nil {
                do {
                    narration = try Narrator.speak(text, previous: previous, account: account,
                                                   to: folder.appendingPathComponent("voz-\(index + 1)"))
                } catch {
                    voiceProblem = error.localizedDescription
                }
            }
            previous = text
            let spoken = narration?.duration ?? scene.segundos ?? max(1.5, Double(text.split(separator: " ").count) / 2.6)
            let seconds = min(12, max(1.2, spoken + 0.3))
            let words = account.captions ? timings(text, narration: narration, spoken: spoken) : []
            clips.append(Clip(page: page, seconds: seconds, words: words, audio: narration?.file))
        }
        guard !clips.isEmpty else { throw Problem(message: "no encontré las escenas del video") }
        if let voiceProblem { Log.write("Contenido (\(account.id)): el video sale sin voz: \(voiceProblem)") }
        Log.write("Contenido (\(account.id)): voz lista, grabando \(clips.count) escenas")

        let silent = folder.appendingPathComponent("reel-sin-sonido.mp4")
        let target = output(account)
        try? FileManager.default.removeItem(at: silent)
        try? FileManager.default.removeItem(at: target)
        let animated = try writeVideo(clips, accent: color(account.palette.accent), to: silent)
        let music = account.music
        if clips.contains(where: { $0.audio != nil }) || music != nil {
            try mix(video: silent, clips: clips, music: music, to: target)
            try? FileManager.default.removeItem(at: silent)
        } else {
            try FileManager.default.moveItem(at: silent, to: target)
        }
        let total = clips.reduce(0) { $0 + $1.seconds }
        Log.write("Contenido (\(account.id)): video de \(clips.count) escenas (\(animated) animadas) y \(Int(total)) s listo"
                  + (voiceProblem == nil ? " con voz (\(account.voiceEngine.rawValue))" : " sin voz")
                  + (music == nil ? "" : " y música"))
        if let voiceProblem { throw PartialProblem(video: target, message: "salió sin voz: \(voiceProblem)") }
        return target
    }

    /// Tiempos de cada palabra: los exactos de la voz si los hay; si no, repartidos por el largo de cada palabra.
    static func timings(_ text: String, narration: Narration?, spoken: Double) -> [WordTiming] {
        if let exact = narration?.words, !exact.isEmpty { return exact }
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let weights = words.map { Double($0.count) + 1.5 }
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }
        var cursor = 0.0
        return zip(words, weights).map { word, weight in
            let length = spoken * weight / total
            defer { cursor += length }
            return WordTiming(word: word, start: cursor, end: cursor + length)
        }
    }

    // MARK: - Imagen

    /// Escribe el video sin sonido. Devuelve cuántas escenas salieron animadas.
    static func writeVideo(_ clips: [Clip], accent: NSColor, to url: URL) throws -> Int {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
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

        let capture = WebFrameCapture(width: width, height: height)
        defer { capture.close() }
        let chrome = CVRenderer.chromePath()
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-chrome", isDirectory: true)
        var animated = 0
        var frameIndex: Int64 = 0
        for (number, clip) in clips.enumerated() {
            let count = max(1, Int((clip.seconds * Double(fps)).rounded()))
            let started = Date()
            // Animada: se graba cuadro por cuadro. Si no carga o no da imagen, queda fija (Chrome) con acercamiento.
            var live = capture.load(clip.page, seconds: clip.seconds)
            var still: CGImage?
            if live, capture.frame(at: 0) == nil { live = false }
            if !live, let chrome { still = stillImage(clip.page, chrome: chrome, scratch: scratch) }
            if live { animated += 1 } else { Log.write("Contenido: la escena \(clip.page.lastPathComponent) sale fija (no se pudo animar)") }
            for frame in 0..<count {
                let elapsed = Double(frame) / Double(fps)
                var image: CGImage?
                var zoom = 1.0
                if live {
                    image = capture.frame(at: elapsed)
                    if image == nil {
                        // Si el Mac deja de dar cuadros, la escena sigue fija para no quedarse esperando.
                        live = false
                        Log.write("Contenido: la escena \(clip.page.lastPathComponent) dejó de animarse en el segundo \(String(format: "%.1f", elapsed))")
                    }
                }
                if image == nil {
                    if still == nil, let chrome { still = stillImage(clip.page, chrome: chrome, scratch: scratch) }
                    image = still
                    zoom = 1.0 + 0.035 * (elapsed / clip.seconds)
                }
                guard let image else { throw Problem(message: "no se pudo dibujar la escena \(clip.page.lastPathComponent)") }
                let caption = captionWords(clip.words, at: elapsed)
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                guard let buffer = pixelBuffer(pool: adaptor.pixelBufferPool, image: image, zoom: zoom,
                                               caption: caption, accent: accent) else {
                    throw Problem(message: "no se pudo dibujar un cuadro del video")
                }
                adaptor.append(buffer, withPresentationTime: CMTime(value: frameIndex, timescale: fps))
                frameIndex += 1
            }
            Log.write("Contenido: escena \(number + 1) de \(clips.count) grabada (\(live ? "animada" : "fija"), "
                      + "\(count) cuadros en \(Int(Date().timeIntervalSince(started))) s)")
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw writer.error ?? Problem(message: "no se pudo terminar el video") }
        return animated
    }

    static func stillImage(_ page: URL, chrome: String, scratch: URL) -> CGImage? {
        let png = page.deletingPathExtension().appendingPathExtension("png")
        guard SlideRenderer.shoot(page, to: png, chrome: chrome, scratch: scratch, width: width, height: height),
              let source = CGImageSourceCreateWithURL(png as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Grupo de palabras que se ve en pantalla en ese momento y cuál de ellas está sonando.
    static func captionWords(_ words: [WordTiming], at elapsed: Double) -> (words: [String], active: Int)? {
        guard let first = words.first, elapsed >= first.start - 0.05 else { return nil }
        var active = words.count - 1
        for (index, word) in words.enumerated() where elapsed < word.end {
            active = index
            break
        }
        let start = (active / wordsPerCaption) * wordsPerCaption
        let end = min(words.count, start + wordsPerCaption)
        return (words[start..<end].map(\.word), active - start)
    }

    static func pixelBuffer(pool: CVPixelBufferPool?, image: CGImage, zoom: Double,
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
        context.draw(image, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h))
        if let caption { drawCaption(caption.words, active: caption.active, accent: accent, in: context) }
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
        let font = NSFont.systemFont(ofSize: 84, weight: .heavy)
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
