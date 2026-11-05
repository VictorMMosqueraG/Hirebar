import Foundation
import HirebarCore

/// Momento en que se dice cada palabra de una narración.
struct WordTiming {
    let word: String
    let start: Double
    let end: Double
}

/// Voz de una escena ya generada.
struct Narration {
    let file: URL
    let duration: Double
    /// Tiempos exactos por palabra (solo con ElevenLabs); si faltan, los subtítulos se reparten por largo de palabra.
    let words: [WordTiming]?
}

/// Pone voz a la narración de cada escena con el motor elegido en la cuenta.
public enum Narrator {
    static let elevenLabsModel = "eleven_multilingual_v2"

    struct Problem: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func speak(_ text: String, previous: String?, account: ContentAccount, to base: URL) throws -> Narration {
        switch account.voiceEngine {
        case .macos:
            guard let voice = SpeechVoices.pick(account.voice) else {
                throw Problem(message: "no hay voces en español instaladas en el Mac")
            }
            let file = base.appendingPathExtension("aiff")
            guard SpeechVoices.speak(text, voice: voice, to: file), let length = SpeechVoices.duration(file) else {
                throw Problem(message: "la voz del Mac no pudo leer el texto")
            }
            return Narration(file: file, duration: length, words: nil)
        case .edge:
            do {
                return try EdgeVoices.speak(text, voice: account.voice.isEmpty ? VoiceEngine.edgeDefaultVoice : account.voice,
                                            to: base.appendingPathExtension("mp3"))
            } catch {
                // Si el servicio de Microsoft no responde, se usa la voz del Mac para no quedarse sin video.
                Log.write("Contenido: la voz de Microsoft falló (\(error.localizedDescription)); se usa la del Mac")
                var fallback = account
                fallback.voiceEngine = .macos
                fallback.voice = ""
                return try speak(text, previous: previous, account: fallback, to: base)
            }
        case .azure:
            return try azure(text, voice: account.voice.isEmpty ? VoiceEngine.azureDefaultVoice : account.voice,
                             to: base.appendingPathExtension("mp3"))
        case .elevenlabs:
            return try elevenLabs(text, previous: previous, voice: account.voice, to: base.appendingPathExtension("mp3"))
        }
    }

    // MARK: - Microsoft Azure Speech

    public static var azureKey: String? { Keychain.read(account: VoiceEngine.azureKeychain) }
    public static var azureRegion: String { Keychain.read(account: VoiceEngine.azureRegionKeychain) ?? "eastus" }

    /// Ritmo un poco más rápido que el normal, como en los Shorts.
    static let azureRate = "+8%"

    static func azure(_ text: String, voice: String, to file: URL) throws -> Narration {
        guard let key = azureKey else {
            throw Problem(message: "falta la clave de Azure Speech (Ajustes → Cuentas de contenido)")
        }
        guard let url = URL(string: "https://\(azureRegion).tts.speech.microsoft.com/cognitiveservices/v1") else {
            throw Problem(message: "la región de Azure no es válida")
        }
        let locale = voice.split(separator: "-").prefix(2).joined(separator: "-")
        let ssml = """
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="\(locale)">\
        <voice name="\(xml(voice))"><prosody rate="\(azureRate)">\(xml(text))</prosody></voice></speak>
        """
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        request.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        request.setValue("audio-48khz-192kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        request.setValue("Hirebar", forHTTPHeaderField: "User-Agent")
        request.httpBody = Data(ssml.utf8)
        let (data, status) = send(request)
        guard status == 200, let data, data.count > 1000 else {
            let reason: String
            switch status {
            case 401: reason = "la clave de Azure no es válida o la región no coincide"
            case 429: reason = "se acabó el cupo gratis de Azure por ahora"
            default: reason = "Azure respondió \(status)"
            }
            throw Problem(message: reason)
        }
        try data.write(to: file, options: .atomic)
        guard let length = SpeechVoices.duration(file) else { throw Problem(message: "Azure devolvió un audio vacío") }
        return Narration(file: file, duration: length, words: nil)
    }

    static func xml(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Voces en español de Azure (para escoger en Ajustes).
    public static func azureVoices(key: String, region: String) -> (voices: [(id: String, name: String)], problem: String?) {
        guard let url = URL(string: "https://\(region).tts.speech.microsoft.com/cognitiveservices/voices/list") else {
            return ([], "la región no es válida")
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        let (data, status) = send(request)
        guard status == 200, let data, let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return ([], status == 401 ? "la clave no es válida o la región no coincide" : "Azure respondió \(status)")
        }
        let voices = list.compactMap { item -> (id: String, name: String)? in
            guard let id = item["ShortName"] as? String, let locale = item["Locale"] as? String, locale.hasPrefix("es-") else { return nil }
            let name = (item["LocalName"] as? String) ?? (item["DisplayName"] as? String) ?? id
            let gender = (item["Gender"] as? String) == "Male" ? "hombre" : "mujer"
            return (id, "\(name) · \(locale) · \(gender)")
        }
        // Primero Colombia y Latinoamérica, después el resto.
        func rank(_ id: String) -> Int { id.hasPrefix("es-CO") ? 0 : (id.hasPrefix("es-ES") ? 2 : 1) }
        return (voices.sorted { (rank($0.id), $0.name) < (rank($1.id), $1.name) }, nil)
    }

    // MARK: - ElevenLabs

    public static var elevenLabsKey: String? { Keychain.read(account: VoiceEngine.elevenLabsKeychain) }

    static func elevenLabs(_ text: String, previous: String?, voice: String, to file: URL) throws -> Narration {
        guard let key = elevenLabsKey else {
            throw Problem(message: "falta la clave de ElevenLabs (Ajustes → Cuentas de contenido)")
        }
        guard !voice.isEmpty else { throw Problem(message: "escoge una voz de ElevenLabs en Ajustes → Cuentas de contenido") }
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voice)/with-timestamps?output_format=mp3_44100_128") else {
            throw Problem(message: "la voz de ElevenLabs no es válida")
        }
        var body: [String: Any] = [
            "text": text,
            "model_id": elevenLabsModel,
            "voice_settings": ["stability": 0.35, "similarity_boost": 0.8, "style": 0.45, "use_speaker_boost": true],
        ]
        if let previous, !previous.isEmpty { body["previous_text"] = previous }
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, status) = send(request)
        guard status == 200, let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let encoded = json["audio_base64"] as? String, let audio = Data(base64Encoded: encoded) else {
            let detail = data.flatMap { String(data: $0, encoding: .utf8) }.map { String($0.prefix(200)) } ?? "sin respuesta"
            throw Problem(message: "ElevenLabs respondió \(status): \(detail)")
        }
        try audio.write(to: file, options: .atomic)
        let words = (json["alignment"] as? [String: Any]).flatMap(wordTimings)
        let length = SpeechVoices.duration(file) ?? words?.last?.end ?? 0
        guard length > 0.2 else { throw Problem(message: "ElevenLabs devolvió un audio vacío") }
        return Narration(file: file, duration: length, words: words)
    }

    /// Une los tiempos por letra de ElevenLabs en tiempos por palabra.
    static func wordTimings(_ alignment: [String: Any]) -> [WordTiming]? {
        guard let characters = alignment["characters"] as? [String],
              let starts = alignment["character_start_times_seconds"] as? [Double],
              let ends = alignment["character_end_times_seconds"] as? [Double],
              characters.count == starts.count, starts.count == ends.count else { return nil }
        var result: [WordTiming] = []
        var current = ""
        var start = 0.0
        var end = 0.0
        for index in characters.indices {
            let character = characters[index]
            if character.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty { result.append(WordTiming(word: current, start: start, end: end)) }
                current = ""
                continue
            }
            if current.isEmpty { start = starts[index] }
            current += character
            end = ends[index]
        }
        if !current.isEmpty { result.append(WordTiming(word: current, start: start, end: end)) }
        return result.isEmpty ? nil : result
    }

    /// Busca en la biblioteca pública de ElevenLabs la voz en español latino más usada para redes sociales
    /// (Reels, Shorts, TikTok), la agrega a la cuenta de ElevenLabs y devuelve su identificador y nombre.
    public static func chooseShortsVoice(key: String) -> (id: String, name: String)? {
        let searches = [
            "language=es&accent=latin%20american&use_cases=social_media&sort=usage_character_count_1y&page_size=30",
            "language=es&accent=latin%20american&sort=usage_character_count_1y&page_size=30",
            "language=es&use_cases=social_media&sort=usage_character_count_1y&page_size=30",
        ]
        for query in searches {
            guard let url = URL(string: "https://api.elevenlabs.io/v1/shared-voices?\(query)") else { continue }
            var request = URLRequest(url: url, timeoutInterval: 30)
            request.setValue(key, forHTTPHeaderField: "xi-api-key")
            let (data, status) = send(request)
            guard status == 200, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let voices = json["voices"] as? [[String: Any]] else { continue }
            let usable = voices.filter { ($0["free_users_allowed"] as? Bool) != false }
            for voice in usable {
                guard let id = voice["voice_id"] as? String, let owner = voice["public_owner_id"] as? String,
                      let name = voice["name"] as? String else { continue }
                if let added = addSharedVoice(key: key, owner: owner, voice: id, name: name) {
                    Log.write("Contenido: voz de ElevenLabs escogida para Shorts: \(name) (\(added))")
                    return (added, name)
                }
            }
        }
        return nil
    }

    static func addSharedVoice(key: String, owner: String, voice: String, name: String) -> String? {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices/add/\(owner)/\(voice)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["new_name": "Hirebar · \(name)"])
        let (data, status) = send(request)
        if status == 200, let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let id = json["voice_id"] as? String {
            return id
        }
        // Si ya estaba en la cuenta, ElevenLabs puede rechazarla; el mismo identificador sirve.
        let detail = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return detail.contains("already") ? voice : nil
    }

    /// Voces de la cuenta de ElevenLabs (para escoger en Ajustes).
    public static func elevenLabsVoices(key: String) -> (voices: [(id: String, name: String)], problem: String?) {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/voices") else { return ([], "dirección no válida") }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        let (data, status) = send(request)
        guard status == 200, let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["voices"] as? [[String: Any]] else {
            return ([], status == 401 ? "la clave no es válida" : "ElevenLabs respondió \(status)")
        }
        let voices = list.compactMap { item -> (id: String, name: String)? in
            guard let id = item["voice_id"] as? String, let name = item["name"] as? String else { return nil }
            let labels = (item["labels"] as? [String: Any])?.values.compactMap { $0 as? String }.joined(separator: ", ") ?? ""
            return (id, labels.isEmpty ? name : "\(name) (\(labels))")
        }
        return (voices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, nil)
    }

    static func send(_ request: URLRequest) -> (Data?, Int) {
        final class Box: @unchecked Sendable {
            var data: Data?
            var status = 0
        }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            box.data = data
            box.status = (response as? HTTPURLResponse)?.statusCode ?? 0
            done.signal()
        }.resume()
        done.wait()
        return (box.data, box.status)
    }
}
