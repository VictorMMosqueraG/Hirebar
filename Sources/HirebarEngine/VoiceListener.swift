import AVFoundation
import Foundation
import HirebarCore
import Speech

/// Momento en que se dice cada palabra.
struct WordTiming {
    let word: String
    let start: Double
    let end: Double
}

/// Escucha la nota de voz con el reconocimiento de voz de macOS (en el Mac, gratis) para saber en qué segundo
/// se dice cada palabra. Si no hay permiso o no se reconoce, devuelve una lista vacía y el video se reparte por largo.
enum VoiceListener {
    static let locales = ["es-CO", "es-MX", "es-US", "es-419", "es-ES"]

    static func words(in audio: URL) -> [WordTiming] {
        guard authorize() else {
            Log.write("Contenido: sin permiso de reconocimiento de voz; el video se reparte por largo del texto")
            return []
        }
        guard let recognizer = locales.lazy.compactMap({ SFSpeechRecognizer(locale: Locale(identifier: $0)) })
            .first(where: { $0.isAvailable }) else {
            Log.write("Contenido: el reconocimiento de voz en español no está disponible")
            return []
        }
        let request = SFSpeechURLRecognitionRequest(url: audio)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        request.taskHint = .dictation
        final class Box: @unchecked Sendable {
            var segments: [Double: WordTiming] = [:]
            var finished = false
        }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        let task = recognizer.recognitionTask(with: request) { result, error in
            guard !box.finished else { return }
            if let result {
                // En audios largos el reconocimiento puede entregar varias partes: se juntan todas por su tiempo.
                for segment in result.bestTranscription.segments {
                    box.segments[segment.timestamp] = WordTiming(word: segment.substring, start: segment.timestamp,
                                                                 end: segment.timestamp + segment.duration)
                }
            }
            if result?.isFinal == true || error != nil {
                box.finished = true
                done.signal()
            }
        }
        if done.wait(timeout: .now() + 180) == .timedOut { task.cancel() }
        let words = box.segments.values.sorted { $0.start < $1.start }
        Log.write("Contenido: reconocí \(words.count) palabras en tu audio")
        return words
    }

    static func authorize() -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        default:
            let done = DispatchSemaphore(value: 0)
            var granted = false
            SFSpeechRecognizer.requestAuthorization { status in
                granted = status == .authorized
                done.signal()
            }
            _ = done.wait(timeout: .now() + 120)
            return granted
        }
    }

    static func duration(_ file: URL) -> Double? {
        guard let audio = try? AVAudioFile(forReading: file), audio.fileFormat.sampleRate > 0 else { return nil }
        let seconds = Double(audio.length) / audio.fileFormat.sampleRate
        return seconds > 0.3 ? seconds : nil
    }
}

/// Reparte la voz entre las escenas emparejando cada palabra del guion con la que se dijo (no solo contando),
/// para que una palabra dicha distinto, una pausa o una muletilla no corran el resto del video.
enum ScriptAligner {
    struct SceneTiming {
        let start: Double
        let end: Double
        let words: [WordTiming]
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .filter { $0.isLetter || $0.isNumber }
    }

    static func tokens(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map { normalize(String($0)) }.filter { !$0.isEmpty }
    }

    /// Sin palabras reconocidas: corta las escenas en las pausas de la voz (donde termina cada frase), escogiendo
    /// para cada corte la pausa más cercana a donde debería caer según el largo del texto.
    static func splitByPauses(_ texts: [String], pauses: [(start: Double, end: Double)], duration: Double) -> [SceneTiming] {
        let counts = texts.map { max(1, tokens($0).count) }
        let total = Double(counts.reduce(0, +))
        var starts: [Double] = [0]
        var used = Set<Int>()
        for index in 1..<max(1, texts.count) {
            let expected = duration * Double(counts[..<index].reduce(0, +)) / total
            let previous = starts.last ?? 0
            let candidates = pauses.indices.filter { !used.contains($0) && (pauses[$0].start + pauses[$0].end) / 2 > previous + 0.6 }
            if let best = candidates.min(by: { abs(mid(pauses[$0]) - expected) < abs(mid(pauses[$1]) - expected) }),
               abs(mid(pauses[best]) - expected) < max(1.5, duration * 0.12) {
                used.insert(best)
                // La escena nueva arranca justo al final de la pausa, cuando empieza la frase.
                starts.append(max(previous + 0.6, pauses[best].end - 0.05))
            } else {
                starts.append(max(previous + 0.6, expected))
            }
        }
        return starts.indices.map { index in
            let start = starts[index]
            let end = index + 1 < starts.count ? starts[index + 1] : duration + 0.5
            // Subtítulos repartidos dentro del tramo en que se dice la frase (sin la pausa del final).
            let talking = pauses.first { $0.start > start + 0.3 && $0.start < end }?.start ?? end
            return SceneTiming(start: start, end: end, words: spread(texts[index], over: max(0.5, talking - start)))
        }
    }

    static func mid(_ pause: (start: Double, end: Double)) -> Double { (pause.start + pause.end) / 2 }

    /// Alinea TODO el guion contra todo lo que se escuchó (alineamiento por programación dinámica que tolera palabras
    /// mal reconocidas), ubica las palabras no reconocidas entre sus vecinas, corta cada escena en la pausa más cercana
    /// a su primera palabra y deja los subtítulos con el texto del guion (bien escrito) al ritmo de la voz.
    static func align(_ texts: [String], heard: [WordTiming], pauses: [(start: Double, end: Double)], duration: Double) -> [SceneTiming] {
        // Palabras del guion: (escena, palabra tal cual, palabra normalizada).
        var script: [(scene: Int, word: String, key: String)] = []
        for (scene, text) in texts.enumerated() {
            for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
                let key = normalize(word)
                if !key.isEmpty { script.append((scene, word, key)) }
            }
        }
        guard !script.isEmpty else { return splitByPauses(texts, pauses: pauses, duration: duration) }
        let spoken = heard.map { normalize($0.word) }

        // Alineamiento: máximo de parejas parecidas en orden.
        let n = script.count, m = spoken.count
        var score = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let same = similar(script[i - 1].key, spoken[j - 1]) ? score[i - 1][j - 1] + 1 : 0
                    score[i][j] = max(same, score[i - 1][j], score[i][j - 1])
                }
            }
        }
        var pair = [Int?](repeating: nil, count: n)
        var i = n, j = m
        while i > 0 && j > 0 {
            if similar(script[i - 1].key, spoken[j - 1]) && score[i][j] == score[i - 1][j - 1] + 1 {
                pair[i - 1] = j - 1
                i -= 1
                j -= 1
            } else if score[i - 1][j] >= score[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        let matched = pair.compactMap { $0 }.count
        Log.write("Contenido: \(matched) de \(n) palabras del guion encontradas en tu voz")
        guard matched >= max(3, n / 4) else { return splitByPauses(texts, pauses: pauses, duration: duration) }

        // Tiempo de cada palabra del guion: la escuchada, o repartida entre las vecinas encontradas.
        var starts = [Double](repeating: 0, count: n)
        var ends = [Double](repeating: 0, count: n)
        var index = 0
        while index < n {
            if let k = pair[index] {
                starts[index] = heard[k].start
                ends[index] = heard[k].end
                index += 1
                continue
            }
            var next = index
            while next < n && pair[next] == nil { next += 1 }
            let from = index == 0 ? 0 : ends[index - 1]
            let to = next < n ? heard[pair[next]!].start : duration
            let weights = (index..<next).map { Double(script[$0].key.count) + 1.5 }
            let total = max(0.001, weights.reduce(0, +))
            var cursor = from
            for (offset, position) in (index..<next).enumerated() {
                let length = max(0, to - from) * weights[offset] / total
                starts[position] = cursor
                ends[position] = cursor + length
                cursor += length
            }
            index = next
        }

        // Corte de cada escena: justo antes de su primera palabra, ajustado al final de la pausa más cercana.
        var cuts: [Double] = [0]
        for scene in 1..<max(1, texts.count) {
            guard let first = script.firstIndex(where: { $0.scene == scene }) else {
                cuts.append(min(duration, (cuts.last ?? 0) + 1))
                continue
            }
            var cut = starts[first] - 0.08
            if let pause = pauses.min(by: { abs($0.end - starts[first]) < abs($1.end - starts[first]) }),
               abs(pause.end - starts[first]) < 0.5 {
                cut = pause.end - 0.05
            }
            cuts.append(max((cuts.last ?? 0) + 0.6, cut))
        }
        return cuts.indices.map { scene in
            let start = cuts[scene]
            let end = scene + 1 < cuts.count ? cuts[scene + 1] : duration + 0.5
            let words = script.indices.filter { script[$0].scene == scene }.map {
                WordTiming(word: script[$0].word, start: max(0, starts[$0] - start), end: max(0, ends[$0] - start))
            }
            return SceneTiming(start: start, end: max(start + 0.6, end), words: words)
        }
    }

    /// Dos palabras se parecen si son iguales, una empieza con la otra, o difieren en una letra (en palabras largas).
    static func similar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.count >= 3 && b.count >= 3 && (a.hasPrefix(b) || b.hasPrefix(a)) { return true }
        guard a.count >= 4, b.count >= 4, abs(a.count - b.count) <= 1 else { return false }
        return distance(Array(a), Array(b)) <= 1 + (max(a.count, b.count) >= 8 ? 1 : 0)
    }

    static func distance(_ a: [Character], _ b: [Character]) -> Int {
        var previous = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, y) in b.enumerated() {
                current[j + 1] = min(previous[j + 1] + 1, current[j] + 1, previous[j] + (x == y ? 0 : 1))
            }
            previous = current
        }
        return previous[b.count]
    }

    /// Tiempos repartidos por el largo de cada palabra (cuando no se pudo escuchar la voz).
    static func spread(_ text: String, over seconds: Double) -> [WordTiming] {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        let weights = words.map { Double($0.count) + 1.5 }
        let total = weights.reduce(0, +)
        guard total > 0 else { return [] }
        var cursor = 0.0
        return zip(words, weights).map { word, weight in
            let length = seconds * weight / total
            defer { cursor += length }
            return WordTiming(word: word, start: cursor, end: cursor + length)
        }
    }
}
