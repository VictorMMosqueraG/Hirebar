import AppKit
import HirebarCore
import SwiftUI

enum SettingsPage: Hashable {
    case agent(AgentKind)
    case skills
}

final class SettingsWindowController {
    private let model = SettingsModel()
    private var window: NSWindow?

    var onSaved: (() -> Void)? {
        get { model.onSaved }
        set { model.onSaved = newValue }
    }

    func show(_ page: SettingsPage? = nil) {
        model.reload()
        if let page { model.selection = page }
        if window == nil {
            let controller = NSHostingController(rootView: SettingsView(model: model))
            let window = NSWindow(contentViewController: controller)
            window.title = "Ajustes de Hirebar"
            window.setContentSize(NSSize(width: 820, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct EditableSkill: Identifiable {
    let id = UUID()
    var skill: Skill
}

struct DayOption: Identifiable {
    let id: String
    let title: String
}

final class SettingsModel: ObservableObject {
    @Published var agents: [AgentSettings] = []
    @Published var sources: [String: Bool] = [:]
    @Published var skills: [EditableSkill] = []
    @Published var portals: [CustomPortal] = []
    @Published var selection: SettingsPage? = .agent(.jobs)
    @Published var message: String?

    var onSaved: (() -> Void)?

    func reload() {
        agents = AgentStore.all()
        let config = Config.load()
        sources = Dictionary(uniqueKeysWithValues: (Config.jobSources + Config.freelanceSources).map { ($0, config.isEnabled($0)) })
        skills = Profile.load().skills.map { EditableSkill(skill: $0) }
        portals = PortalStore.load()
        message = nil
    }

    func save() {
        let invalid = portals.filter { !$0.isValid }
        guard invalid.isEmpty else {
            message = "Revisa los portales: cada uno necesita nombre y un enlace que empiece por https://"
            return
        }
        for var agent in agents {
            if !portals.filter({ $0.agent == agent.id && $0.enabled }).isEmpty { agent.ensurePortalScanTask() }
            agent.name = agent.name.trimmingCharacters(in: .whitespaces).isEmpty ? AgentSettings.defaults(for: agent.id).name : agent.name
            if let minutes = agent.searchEveryMinutes { agent.searchEveryMinutes = max(15, minutes) }
            if let limit = agent.dailyLimit { agent.dailyLimit = max(0, limit) }
            agent.tasks = agent.tasks.map { task in
                var task = task
                task.hours = Array(Set(task.hours.filter { (0...23).contains($0) })).sorted()
                task.windowHours = max(1, task.windowHours)
                return task
            }
            AgentStore.save(agent)
        }
        var config = Config.load()
        for (source, on) in sources { config.setEnabled(source, on) }
        config.save()
        let result: String
        do {
            try PortalStore.save(portals)
            try ProfileEditor.saveSkills(skills.map(\.skill))
            result = "Guardado. Aplica desde la próxima búsqueda."
        } catch {
            result = "Los agentes se guardaron, pero no pude guardar las habilidades: \(error.localizedDescription)"
        }
        reload()
        message = result
        onSaved?()
    }

    func agentBinding(_ kind: AgentKind) -> Binding<AgentSettings>? {
        guard let current = agents.first(where: { $0.id == kind }) else { return nil }
        return Binding(
            get: { [weak self] in self?.agents.first(where: { $0.id == kind }) ?? current },
            set: { [weak self] value in
                guard let self, let index = self.agents.firstIndex(where: { $0.id == kind }) else { return }
                self.agents[index] = value
            })
    }

    func portalsBinding(_ kind: AgentKind) -> Binding<[CustomPortal]> {
        Binding(
            get: { [weak self] in self?.portals.filter { $0.agent == kind } ?? [] },
            set: { [weak self] value in
                guard let self else { return }
                self.portals = self.portals.filter { $0.agent != kind } + value
            })
    }

    func addPortal(_ kind: AgentKind) {
        portals.append(CustomPortal(name: "", agent: kind, url: "https://"))
    }

    func sourceBinding(_ source: String) -> Binding<Bool> {
        Binding(get: { [weak self] in self?.sources[source] ?? true },
                set: { [weak self] value in self?.sources[source] = value })
    }

    func revealFile() {
        Paths.ensure()
        AgentStore.writeMissingDefaults()
        switch selection {
        case .skills:
            NSWorkspace.shared.activateFileViewerSelecting([Profile.url])
        case .agent(let kind):
            NSWorkspace.shared.activateFileViewerSelecting([AgentStore.url(for: kind)])
        case nil:
            NSWorkspace.shared.open(Paths.workspace)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $model.selection) {
                Section("Agentes") {
                    ForEach(AgentKind.allCases, id: \.self) { kind in
                        Label(model.agents.first(where: { $0.id == kind })?.name ?? kind.rawValue,
                              systemImage: AgentStyle.symbol(kind))
                            .tag(SettingsPage.agent(kind))
                    }
                }
                Section("Perfil") {
                    Label("Habilidades", systemImage: "star.fill")
                        .tag(SettingsPage.skills)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 210)
            Divider()
            VStack(spacing: 0) {
                content
                Divider()
                footer
            }
        }
        .frame(minWidth: 760, minHeight: 500)
    }

    @ViewBuilder
    private var content: some View {
        switch model.selection {
        case .agent(let kind):
            if let agent = model.agentBinding(kind) {
                AgentEditor(agent: agent, model: model)
                    .id(kind)
            }
        case .skills:
            SkillsEditor(skills: $model.skills)
        case nil:
            Text("Elige un agente a la izquierda.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("Mostrar archivo") { model.revealFile() }
            Spacer()
            if let message = model.message {
                Text(message).foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
            }
            Button("Descartar") { model.reload() }
            Button("Guardar") { model.save() }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }
}

struct AgentEditor: View {
    @Binding var agent: AgentSettings
    @ObservedObject var model: SettingsModel

    private var sourceIDs: [String] {
        switch agent.id {
        case .jobs: return Config.jobSources
        case .freelance: return Config.freelanceSources
        default: return []
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Nombre", text: $agent.name)
                TextField("Descripción", text: $agent.purpose, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Prendido", isOn: $agent.enabled)
                if [.jobs, .freelance, .clients].contains(agent.id) {
                    Toggle("Envío automático (sin esperar tu \"si\" en Telegram)", isOn: $agent.autoApprove)
                }
            } header: {
                Label(agent.name, systemImage: AgentStyle.symbol(agent.id))
            }

            if agent.hasSearch {
                Section {
                    Stepper(value: minutes, in: 15...240, step: 5) {
                        LabeledContent("Buscar cada", value: "\(minutes.wrappedValue) min")
                    }
                    ForEach(sourceIDs, id: \.self) { source in
                        Toggle(StatusMenu.sourceTitles[source] ?? source, isOn: model.sourceBinding(source))
                    }
                } header: {
                    Text("Portales incluidos")
                } footer: {
                    Text("Se revisan solos, sin usar a Claude: leen las páginas públicas y te avisan lo que encaja con tu perfil.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CustomPortalsSection(portals: model.portalsBinding(agent.id)) {
                    model.addPortal(agent.id)
                }
            }

            if [.jobs, .freelance, .clients].contains(agent.id) {
                Section {
                    Stepper(value: limit, in: 0...100) {
                        LabeledContent("Cupo diario", value: limit.wrappedValue == 0 ? "sin límite" : "\(limit.wrappedValue)")
                    }
                } footer: {
                    Text("Se le indica a Claude como máximo de envíos por día para este agente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(agent.tasks.indices, id: \.self) { index in
                TaskEditor(task: $agent.tasks[index])
            }

            if agent.tasks.isEmpty && !agent.hasSearch {
                Section {
                    Text(agent.id == .profile
                         ? "Corre cuando se lo pides: \"logro\", \"trabajo\" o \"hv\" en Telegram, o Regenerar HV en el panel."
                         : "Este agente no tiene tareas programadas.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var minutes: Binding<Int> {
        Binding(get: { agent.searchEveryMinutes ?? 30 }, set: { agent.searchEveryMinutes = $0 })
    }

    private var limit: Binding<Int> {
        Binding(get: { agent.dailyLimit ?? 0 }, set: { agent.dailyLimit = $0 == 0 ? nil : $0 })
    }
}

struct TaskEditor: View {
    @Binding var task: AgentTask
    @State private var hoursText = ""

    static let days = [
        DayOption(id: "lun", title: "L"), DayOption(id: "mar", title: "M"), DayOption(id: "mie", title: "X"),
        DayOption(id: "jue", title: "J"), DayOption(id: "vie", title: "V"), DayOption(id: "sab", title: "S"),
        DayOption(id: "dom", title: "D"),
    ]
    static let workdays: Set<String> = ["lun", "mar", "mie", "jue", "vie"]

    var body: some View {
        Section {
            LabeledContent("Días") {
                HStack(spacing: 4) {
                    ForEach(Self.days) { day in
                        Toggle(day.title, isOn: dayBinding(day.id))
                            .toggleStyle(.button)
                            .controlSize(.small)
                    }
                }
            }
            TextField("Horas (0 a 23, separadas por coma)", text: $hoursText, prompt: Text("8, 14"))
                .onAppear { hoursText = task.hours.sorted().map(String.init).joined(separator: ", ") }
                .onChange(of: hoursText) { text in
                    task.hours = text.split(whereSeparator: { $0 == "," || $0 == " " })
                        .compactMap { Int($0) }
                        .filter { (0...23).contains($0) }
                }
            Stepper(value: $task.windowHours, in: 1...48) {
                LabeledContent("Si el Mac estaba dormido, puede correr hasta", value: "\(task.windowHours) h después")
            }
        } header: {
            Text(task.mode.title)
        } footer: {
            Text(task.hours.isEmpty ? "Sin horas: esta tarea no corre sola." : "Corre \(task.scheduleText).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var selectedDays: Set<String> {
        let names = Set(task.days.map { TextTools.normalize($0).trimmingCharacters(in: .whitespaces) })
        if names.contains("todos") { return Set(Self.days.map(\.id)) }
        if names.contains("habiles") { return Self.workdays.union(names.subtracting(["habiles"])) }
        return names
    }

    private func dayBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { selectedDays.contains(key) }, set: { on in
            var days = selectedDays
            if on { days.insert(key) } else { days.remove(key) }
            if days.count == 7 {
                task.days = ["todos"]
            } else if days == Self.workdays {
                task.days = ["habiles"]
            } else {
                task.days = Self.days.map(\.id).filter { days.contains($0) }
            }
        })
    }
}

struct SkillsEditor: View {
    @Binding var skills: [EditableSkill]

    var body: some View {
        Form {
            Section {
                ForEach($skills) { $item in
                    SkillRow(skill: $item.skill) {
                        let id = item.id
                        skills.removeAll { $0.id == id }
                    }
                }
                Button("Agregar habilidad") {
                    skills.append(EditableSkill(skill: Skill(name: "", level: .familiar)))
                }
            } header: {
                Text("Habilidades")
            } footer: {
                Text("Domino: se busca y cuenta como ENCAJA. Conozco: se busca como RETO. Evito: se descarta. Los otros nombres sirven para reconocerla en los avisos (por ejemplo, Node.js: node, nodejs).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct SkillRow: View {
    @Binding var skill: Skill
    let onDelete: () -> Void
    @State private var aliasesText = ""

    var body: some View {
        HStack(spacing: 8) {
            TextField("Nombre", text: $skill.name, prompt: Text("Node.js"))
                .frame(width: 150)
            Picker("Nivel", selection: $skill.level) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 210)
            TextField("Otros nombres", text: $aliasesText, prompt: Text("node, nodejs"))
                .onAppear { aliasesText = skill.aliases.joined(separator: ", ") }
                .onChange(of: aliasesText) { text in
                    skill.aliases = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .labelsHidden()
    }
}

struct CustomPortalsSection: View {
    @Binding var portals: [CustomPortal]
    let onAdd: () -> Void

    var body: some View {
        Section {
            ForEach($portals) { $portal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Toggle("", isOn: $portal.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                        TextField("Nombre", text: $portal.name, prompt: Text("Torre"))
                            .frame(width: 140)
                        TextField("Enlace de búsqueda", text: $portal.url, prompt: Text("https://torre.ai/search/jobs?q=backend"))
                        Button {
                            let id = portal.id
                            portals.removeAll { $0.id == id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Quitar este portal")
                    }
                    TextField("Indicaciones (opcional)", text: $portal.notes,
                              prompt: Text("Ej.: filtra por remoto y Colombia; ignora las de inglés"))
                        .font(.caption)
                    if !portal.isValid {
                        Text("Falta el nombre o un enlace que empiece por https://")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .labelsHidden()
                .padding(.vertical, 2)
            }
            Button("Agregar portal", action: onAdd)
        } header: {
            Text("Tus portales")
        } footer: {
            Text("Pega el enlace de una búsqueda ya filtrada en el portal que quieras. Claude lo revisa con tu Chrome (sirve aunque pida sesión iniciada) a las horas de la tarea \"Revisar tus portales\" y te manda lo que encuentre en la lista de siempre.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
