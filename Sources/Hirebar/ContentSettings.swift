import AppKit
import HirebarCore
import HirebarEngine
import SwiftUI

/// Ajustes → Cuentas de contenido: una sección por cuenta (empresa, personal…), cada una con su red, nombre, días y paleta.
struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
}

struct ContentAccountsEditor: View {
    @Binding var accounts: [EditableAccount]
    @State private var elevenKey = ""
    @State private var elevenVoices: [VoiceOption] = []
    @State private var keyMessage: String?
    @State private var hasKey = false
    @State private var azureKey = ""
    @State private var azureRegion = Narrator.azureRegion
    @State private var azureVoices: [VoiceOption] = []
    @State private var azureMessage: String?
    @State private var hasAzureKey = false
    @State private var edgeVoices: [VoiceOption] = []

    var body: some View {
        Form {
            Section {
                Text("Cada cuenta recibe sus propias publicaciones con imágenes, con su nombre y sus colores. Por ejemplo, una para tu empresa en Instagram y otra para ti en LinkedIn. En Telegram: \"post <identificador>\" y \"publica <identificador>\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    accounts.append(EditableAccount(account: ContentAccount(id: "cuenta-\(accounts.count + 1)")))
                } label: {
                    Label("Agregar cuenta", systemImage: "plus")
                }
            }
            ForEach($accounts) { $item in
                ContentAccountSection(account: $item.account, canRemove: accounts.count > 1,
                                      elevenVoices: elevenVoices, azureVoices: azureVoices, edgeVoices: edgeVoices) {
                    accounts.removeAll { $0.id == item.id }
                }
            }
            Section {
                SecureField("Clave de Azure Speech", text: $azureKey,
                            prompt: Text(hasAzureKey ? "Guardada (escribe otra para cambiarla)" : "Clave 1 de tu recurso de Voz"))
                TextField("Región", text: $azureRegion, prompt: Text("eastus"))
                HStack {
                    Button(hasAzureKey && azureKey.isEmpty ? "Recargar voces" : "Guardar clave y cargar voces") { saveAzure() }
                    if let azureMessage {
                        Text(azureMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Voces de Microsoft Azure (gratis, recomendado)")
            } footer: {
                Text("Voces neuronales naturales, con acento colombiano. El plan gratis (F0) da medio millón de caracteres al mes y permite uso comercial; un Short usa unos 500. En portal.azure.com crea un recurso de \"Voz\" (Speech) con el plan F0 y copia la Clave 1 y la región (por ejemplo, eastus). Se guardan en el Llavero del Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                SecureField("Clave de ElevenLabs", text: $elevenKey,
                            prompt: Text(hasKey ? "Guardada (escribe otra para cambiarla)" : "sk_…"))
                HStack {
                    Button(hasKey && elevenKey.isEmpty ? "Recargar voces" : "Guardar clave y cargar voces") { saveKeyAndLoad() }
                    if let keyMessage {
                        Text(keyMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Voces de ElevenLabs (para los videos)")
            } footer: {
                Text("Suenan mucho más naturales que las del Mac. Crea una cuenta en elevenlabs.io y copia tu clave (API key) en la configuración de tu perfil. Tiene plan gratis con un cupo de caracteres al mes; un Short usa unos 500. Para una voz con acento latino, agrega una de su biblioteca de voces a \"Mis voces\" y aparecerá aquí. La clave se guarda en el Llavero del Mac, no en archivos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            hasKey = Narrator.elevenLabsKey != nil
            if hasKey && elevenVoices.isEmpty { loadVoices() }
            hasAzureKey = Narrator.azureKey != nil
            if hasAzureKey && azureVoices.isEmpty { loadAzureVoices() }
            if edgeVoices.isEmpty {
                DispatchQueue.global(qos: .userInitiated).async {
                    let list = EdgeVoices.spanishVoices().map { VoiceOption(id: $0.id, name: $0.name) }
                    DispatchQueue.main.async { edgeVoices = list }
                }
            }
        }
    }

    private func saveAzure() {
        let key = azureKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = azureRegion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "")
        if !region.isEmpty { Keychain.save(region, account: VoiceEngine.azureRegionKeychain) }
        if !key.isEmpty {
            guard Keychain.save(key, account: VoiceEngine.azureKeychain) else {
                azureMessage = "No pude guardar la clave en el Llavero."
                return
            }
            azureKey = ""
            hasAzureKey = true
        }
        loadAzureVoices()
    }

    private func loadAzureVoices() {
        guard let key = Narrator.azureKey else {
            azureMessage = "Primero pega tu clave."
            return
        }
        let region = Narrator.azureRegion
        azureMessage = "Cargando voces…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Narrator.azureVoices(key: key, region: region)
            DispatchQueue.main.async {
                azureVoices = result.voices.map { VoiceOption(id: $0.id, name: $0.name) }
                azureMessage = result.problem.map { "No pude cargar las voces: \($0)." }
                    ?? "Funciona: \(azureVoices.count) voces en español."
            }
        }
    }

    private func saveKeyAndLoad() {
        let key = elevenKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            guard Keychain.save(key, account: VoiceEngine.elevenLabsKeychain) else {
                keyMessage = "No pude guardar la clave en el Llavero."
                return
            }
            elevenKey = ""
            hasKey = true
        }
        loadVoices()
    }

    private func loadVoices() {
        guard let key = Narrator.elevenLabsKey else {
            keyMessage = "Primero pega tu clave."
            return
        }
        keyMessage = "Cargando voces…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Narrator.elevenLabsVoices(key: key)
            DispatchQueue.main.async {
                elevenVoices = result.voices.map { VoiceOption(id: $0.id, name: $0.name) }
                keyMessage = result.problem.map { "No pude cargar las voces: \($0)." } ?? "\(elevenVoices.count) voces disponibles."
            }
        }
    }
}

struct ContentAccountSection: View {
    @Binding var account: ContentAccount
    let canRemove: Bool
    let elevenVoices: [VoiceOption]
    let azureVoices: [VoiceOption]
    let edgeVoices: [VoiceOption]
    let onRemove: () -> Void
    @State private var voices: [String] = []
    @State private var choosing = false
    @State private var chooseMessage: String?

    var body: some View {
        Section {
            Toggle("Prendida", isOn: $account.enabled)
            Picker("Red", selection: $account.network) {
                ForEach(ContentNetwork.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            TextField("Identificador (para Telegram)", text: $account.id, prompt: Text("empresa"))
            TextField("Nombre en las imágenes", text: $account.name, prompt: Text("Mi Empresa"))
            TextField("Línea bajo el nombre", text: $account.tagline, prompt: Text("Software a medida · Backend y nube"))
            TextField("Usuario", text: $account.handle, prompt: Text("@mi_empresa"))
            TextField("De qué habla y para quién", text: $account.focus, axis: .vertical)
                .lineLimit(2...5)
            LabeledContent("Días") { DaysPicker(days: $account.days) }
            Toggle("También un video corto con voz (Reel o Short)", isOn: $account.video)
            if account.video {
                Picker("Motor de voz", selection: $account.voiceEngine) {
                    ForEach(VoiceEngine.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .onChange(of: account.voiceEngine) { _ in account.voice = "" }
                if account.voiceEngine == .edge {
                    Picker("Voz del video", selection: $account.voice) {
                        Text("La recomendada (Gonzalo · Colombia · hombre)").tag("")
                        ForEach(edgeVoices) { Text($0.name).tag($0.id) }
                        if !account.voice.isEmpty && !edgeVoices.contains(where: { $0.id == account.voice }) {
                            Text(account.voice).tag(account.voice)
                        }
                    }
                    Text(edgeVoices.isEmpty
                         ? "Preparando la lista de voces (la primera vez Hirebar instala la herramienta de voz; tarda un minuto)."
                         : "Voces neuronales de Microsoft, sin cuenta ni clave. Si el servicio no responde, el video usa la voz del Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if account.voiceEngine == .azure {
                    Picker("Voz del video", selection: $account.voice) {
                        Text("La recomendada (Gonzalo · Colombia · hombre)").tag("")
                        ForEach(azureVoices) { Text($0.name).tag($0.id) }
                        if !account.voice.isEmpty && !azureVoices.contains(where: { $0.id == account.voice }) {
                            Text(account.voice).tag(account.voice)
                        }
                    }
                    if azureVoices.isEmpty {
                        Text("Pega tu clave de Azure al final de esta página para ver todas las voces en español.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if account.voiceEngine == .macos {
                    Picker("Voz del video", selection: $account.voice) {
                        Text("La mejor disponible").tag("")
                        ForEach(voices, id: \.self) { Text($0).tag($0) }
                        if !account.voice.isEmpty && !voices.contains(account.voice) {
                            Text("\(account.voice) (no instalada)").tag(account.voice)
                        }
                    }
                    .onAppear { if voices.isEmpty { voices = SpeechVoices.spanishNames() } }
                    Text("Las voces \"Mejorada\" o \"Premium\" suenan más naturales. Se descargan gratis en Ajustes del Sistema → Accesibilidad → Contenido leído → Voz del sistema → Gestionar voces → Español.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Voz del video", selection: $account.voice) {
                        Text("Escoge una voz").tag("")
                        ForEach(elevenVoices) { Text($0.name).tag($0.id) }
                        if !account.voice.isEmpty && !elevenVoices.contains(where: { $0.id == account.voice }) {
                            Text("Voz guardada (\(account.voice))").tag(account.voice)
                        }
                    }
                    HStack {
                        Button(choosing ? "Buscando…" : "Escoger la mejor voz para Shorts") { chooseBest() }
                            .disabled(choosing)
                        if let chooseMessage {
                            Text(chooseMessage).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if elevenVoices.isEmpty {
                        Text("Pega tu clave de ElevenLabs al final de esta página para ver tus voces.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Subtítulos palabra por palabra", isOn: $account.captions)
                Text("Música de fondo (opcional): pon un archivo musica.mp3 en la carpeta de la cuenta (workspace/contenido/\(account.id)/).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Paleta", selection: preset) {
                Text("Personalizada").tag("")
                ForEach(PalettePreset.all) { Text($0.title).tag($0.id) }
            }
            ColorField(title: "Fondo", hex: $account.palette.background)
            ColorField(title: "Tarjetas y bloques", hex: $account.palette.surface)
            ColorField(title: "Acento", hex: $account.palette.accent)
            ColorField(title: "Texto", hex: $account.palette.text)
            ColorField(title: "Texto secundario", hex: $account.palette.muted)
            TextField("Estilo de las imágenes", text: $account.style, axis: .vertical)
                .lineLimit(2...5)
            PalettePreview(account: account)

            if canRemove {
                Button("Quitar esta cuenta", role: .destructive, action: onRemove)
            }
        } header: {
            Label(account.title, systemImage: account.network == .instagram ? "camera" : "person.crop.rectangle")
        } footer: {
            Text("La IA usa estos colores y este estilo en cada imagen. Al escoger una paleta se llenan los colores y el estilo; después puedes cambiarlos. Con el video prendido llega también un video vertical de 15 a 30 segundos.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chooseBest() {
        guard let key = Narrator.elevenLabsKey else {
            chooseMessage = "Primero pega tu clave de ElevenLabs al final de la página."
            return
        }
        choosing = true
        chooseMessage = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let chosen = Narrator.chooseShortsVoice(key: key)
            DispatchQueue.main.async {
                choosing = false
                if let chosen {
                    account.voice = chosen.id
                    chooseMessage = "Escogida: \(chosen.name). Guarda para aplicarla."
                } else {
                    chooseMessage = "No pude escoger una voz (revisa la clave)."
                }
            }
        }
    }

    private var preset: Binding<String> {
        Binding(
            get: { PalettePreset.all.first { $0.palette == account.palette }?.id ?? "" },
            set: { id in
                guard let chosen = PalettePreset.all.first(where: { $0.id == id }) else { return }
                account.palette = chosen.palette
                account.style = chosen.style
            })
    }
}

struct DaysPicker: View {
    @Binding var days: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TaskEditor.days) { day in
                Toggle(day.title, isOn: binding(day.id))
                    .toggleStyle(.button)
                    .controlSize(.small)
            }
        }
    }

    private var selected: Set<String> {
        let names = Set(days.map { TextTools.normalize($0).trimmingCharacters(in: .whitespaces) })
        if names.contains("todos") { return Set(TaskEditor.days.map(\.id)) }
        if names.contains("habiles") { return TaskEditor.workdays.union(names.subtracting(["habiles"])) }
        return names
    }

    private func binding(_ key: String) -> Binding<Bool> {
        Binding(get: { selected.contains(key) }, set: { on in
            var chosen = selected
            if on { chosen.insert(key) } else { chosen.remove(key) }
            days = chosen.count == 7 ? ["todos"] : TaskEditor.days.map(\.id).filter { chosen.contains($0) }
        })
    }
}

struct ColorField: View {
    let title: String
    @Binding var hex: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                TextField("", text: $hex, prompt: Text("#000000"))
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 90)
                ColorPicker("", selection: color, supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }

    private var color: Binding<Color> {
        Binding(get: { Color(hex: hex) }, set: { hex = $0.hexString })
    }
}

struct PalettePreview: View {
    let account: ContentAccount

    var body: some View {
        let p = account.palette
        VStack(alignment: .leading, spacing: 8) {
            Text("ASÍ SE VEN")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: p.accent))
                .foregroundColor(Color(hex: p.background))
            (Text("Tus imágenes, ").foregroundColor(Color(hex: p.text))
             + Text("con tus colores").foregroundColor(Color(hex: p.accent)).italic())
                .font(.system(size: 22, weight: .bold))
            HStack {
                Text(account.name.isEmpty ? "Tu nombre" : account.name)
                Spacer()
                Text("1/5")
            }
            .font(.caption)
            .foregroundColor(Color(hex: p.muted))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(Color(hex: p.background))
                .overlay(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(hex: p.surface))
                        .frame(width: 70, height: 40)
                        .padding(12)
                }
        )
    }
}

extension Color {
    static func isHex(_ text: String) -> Bool {
        text.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }

    init(hex: String) {
        let clean = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        let value = UInt32(clean, radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255,
                  opacity: 1)
    }

    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
    }
}
