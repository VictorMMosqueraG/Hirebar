import AppKit
import HirebarCore
import HirebarEngine

final class StatusMenu: NSObject, NSMenuDelegate {
    static let shared = StatusMenu()

    var onRefresh: ((Bool) -> Void)?
    var onOpenSettings: ((AgentKind) -> Void)?
    private var headers: [(NSMenuItem, AgentKind)] = []
    private var checks: [(NSMenuItem, () -> Bool)] = []
    private var labels: [(NSMenuItem, () -> String)] = []
    private var actions: [() -> Void] = []
    private let telegramHeader = NSMenuItem(title: "Telegram", action: nil, keyEquivalent: "")
    private let telegramState = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let claudeItem = NSMenuItem(title: "Claude: en espera", action: nil, keyEquivalent: "")
    private var ticker: Timer?

    static let sourceTitles = [
        "workana": "Workana", "freelancer": "Freelancer",
        "linkedin": "LinkedIn", "getonboard": "Get on Board", "computrabajo": "Computrabajo",
        "elempleo": "elempleo", "magneto": "Magneto",
    ]

    func install(in menu: NSMenu) {
        for kind in AgentKind.allCases {
            let header = NSMenuItem(title: kind.rawValue, action: nil, keyEquivalent: "")
            header.submenu = agentMenu(kind)
            headers.append((header, kind))
            menu.addItem(header)
        }

        menu.addItem(.separator())
        let telegram = NSMenu()
        telegramState.isEnabled = false
        telegram.addItem(telegramState)
        telegram.addItem(.separator())
        telegram.addItem(action("Configurar bot…") { [weak self] in self?.configureTelegram() })
        telegram.addItem(action("Enviar aviso de prueba") { [weak self] in self?.sendTest() })
        telegram.addItem(action("Volver a vincular el chat") { [weak self] in self?.forgetChat() })
        telegramHeader.submenu = telegram
        menu.addItem(telegramHeader)

        claudeItem.isEnabled = false
        menu.addItem(claudeItem)
        menu.addItem(action("Abrir informes") { Self.open(Paths.reports) })
        menu.addItem(action("Ver registro") { Self.openLog() })
        menu.addItem(action("Abrir carpeta de datos") { Self.open(Paths.root) })
        menu.delegate = self

        FreelanceRadar.shared.onStatusChange = { [weak self] _ in self?.refresh() }
        JobRadar.shared.onStatusChange = { [weak self] _ in self?.refresh() }
        Controller.shared.onStatusChange = { [weak self] _ in self?.refresh() }
        let timer = Timer(timeInterval: 20, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        refresh()
    }

    private func agentMenu(_ kind: AgentKind) -> NSMenu {
        let menu = NSMenu()
        let purpose = NSMenuItem(title: AgentStore.load(kind).purpose, action: nil, keyEquivalent: "")
        purpose.isEnabled = false
        menu.addItem(purpose)
        menu.addItem(.separator())
        menu.addItem(check("Prendido", { AgentStore.load(kind).enabled }) {
            AgentStore.update(kind) { $0.enabled.toggle() }
        })
        if [.jobs, .freelance, .clients].contains(kind) {
            menu.addItem(check("Envío automático", { AgentStore.load(kind).autoApprove }) {
                AgentStore.update(kind) { $0.autoApprove.toggle() }
            })
        }
        let sources = kind == .jobs ? Config.jobSources : kind == .freelance ? Config.freelanceSources : []
        if !sources.isEmpty {
            menu.addItem(.separator())
            for source in sources {
                menu.addItem(check(Self.sourceTitles[source] ?? source, { Config.load().isEnabled(source) }) {
                    var config = Config.load()
                    config.setEnabled(source, !config.isEnabled(source))
                    config.save()
                })
            }
        }
        if kind == .freelance {
            menu.addItem(.separator())
            menu.addItem(label { "Workana: \(Quotas.describe("workana"))" })
            menu.addItem(label { "Freelancer: \(Quotas.describe("freelancer"))" })
        }
        let tasks = AgentStore.load(kind).tasks
        if !tasks.isEmpty {
            menu.addItem(.separator())
            for task in tasks {
                menu.addItem(label { "\(task.mode.title): \(task.scheduleText)" })
            }
        }
        menu.addItem(.separator())
        menu.addItem(action(kind == .profile ? "Regenerar hojas de vida" : "Correr ahora") {
            Controller.shared.runAgentNow(kind)
        })
        menu.addItem(action("Ajustes…") { [weak self] in self?.onOpenSettings?(kind) })
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    func refresh() {
        for (item, kind) in headers { item.title = headerTitle(kind) }
        for (item, isOn) in checks { item.state = isOn() ? .on : .off }
        for (item, text) in labels { item.title = text() }
        claudeItem.title = "\(AI.capitalizedName): \(Controller.shared.status)"
        let config = Config.load()
        let state: String
        if !Telegram.shared.isConfigured {
            state = "Sin configurar"
        } else if config.chatId == 0 {
            state = "Bot listo: escríbele /start desde tu celular"
        } else {
            state = "Conectado a tu chat"
        }
        telegramState.title = state
        telegramHeader.title = "Telegram: \(state.lowercased())"
        onRefresh?(!Controller.shared.isIdle)
    }

    private func headerTitle(_ kind: AgentKind) -> String {
        let agent = AgentStore.load(kind)
        guard agent.enabled else { return "\(agent.name): apagado" }
        var title = agent.name
        switch kind {
        case .jobs: title += ": \(JobRadar.shared.status)"
        case .freelance: title += ": \(FreelanceRadar.shared.status)"
        default: break
        }
        if let next = Scheduler.shared.nextRun(of: kind) { title += " · próxima \(TextTools.countdown(next))" }
        return title
    }

    private func register(_ item: NSMenuItem, _ handler: @escaping () -> Void) -> NSMenuItem {
        item.target = self
        item.tag = actions.count
        actions.append(handler)
        return item
    }

    private func action(_ title: String, _ handler: @escaping () -> Void) -> NSMenuItem {
        register(NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: ""), handler)
    }

    private func check(_ title: String, _ isOn: @escaping () -> Bool, _ toggle: @escaping () -> Void) -> NSMenuItem {
        let item = action(title) { [weak self] in
            toggle()
            self?.refresh()
        }
        checks.append((item, isOn))
        return item
    }

    private func label(_ text: @escaping () -> String) -> NSMenuItem {
        let item = NSMenuItem(title: text(), action: nil, keyEquivalent: "")
        item.isEnabled = false
        labels.append((item, text))
        return item
    }

    @objc private func runMenuAction(_ sender: NSMenuItem) {
        guard sender.tag >= 0 && sender.tag < actions.count else { return }
        actions[sender.tag]()
    }

    private static func open(_ url: URL) {
        Paths.ensure()
        NSWorkspace.shared.open(url)
    }

    private static func openLog() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Paths.log.path) {
            try? fm.createDirectory(at: Paths.logs, withIntermediateDirectories: true)
            fm.createFile(atPath: Paths.log.path, contents: nil)
        }
        NSWorkspace.shared.open(Paths.log)
    }

    func configureTelegram() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Bot de Telegram de Hirebar"
        alert.informativeText = """
        1. En Telegram abre @BotFather, envía /newbot y ponle un nombre.
        2. Copia el token que te entrega y pégalo aquí.
        3. Después abre tu bot desde el celular y envíale /start: ese chat queda vinculado.
        """
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24))
        field.placeholderString = "123456789:AA…"
        alert.accessoryView = field
        alert.addButton(withTitle: "Guardar")
        alert.addButton(withTitle: "Cancelar")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let token = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.range(of: "^\\d{5,}:[A-Za-z0-9_-]{30,}$", options: .regularExpression) != nil else {
            info("Ese token no parece válido. Debe verse como 123456789:AA… (cópialo completo de @BotFather).")
            return
        }
        guard Telegram.shared.saveToken(token) else {
            info("No pude guardar el token en el Llavero.")
            return
        }
        var config = Config.load()
        config.chatId = 0
        config.save()
        Telegram.shared.start()
        refresh()
        info("Guardado. Ahora abre tu bot en Telegram desde el celular y envíale /start.")
    }

    func sendTest() {
        guard Notifier.canUseTelegram else {
            info("Primero configura el bot y envíale /start desde tu celular.")
            return
        }
        Notifier.tell("Aviso de prueba: tu celular ya recibe Hirebar.\n\n" + Controller.shared.statusReport())
    }

    func forgetChat() {
        var config = Config.load()
        config.chatId = 0
        config.save()
        refresh()
        info("Listo. El próximo mensaje que reciba el bot (envíale /start) quedará como tu chat.")
    }

    func info(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Hirebar"
        alert.informativeText = message
        alert.runModal()
    }
}
