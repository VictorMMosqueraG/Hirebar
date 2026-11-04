import AppKit
import HirebarCore
import HirebarEngine

final class StatusMenu: NSObject, NSMenuDelegate {
    static let shared = StatusMenu()

    var onRefresh: ((Bool) -> Void)?
    private let freelanceHeader = NSMenuItem(title: "Radar freelance", action: nil, keyEquivalent: "")
    private let jobsHeader = NSMenuItem(title: "Radar empleo", action: nil, keyEquivalent: "")
    private let telegramHeader = NSMenuItem(title: "Telegram", action: nil, keyEquivalent: "")
    private let scheduleHeader = NSMenuItem(title: "Seguimientos e informe", action: nil, keyEquivalent: "")
    private let followUpNext = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let reportNext = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let claudeItem = NSMenuItem(title: "Claude: en espera", action: nil, keyEquivalent: "")
    private let quotaWorkana = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let quotaFreelancer = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let telegramState = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var toggles: [(NSMenuItem, String)] = []
    private var ticker: Timer?

    static let sourceTitles = [
        "workana": "Buscar en Workana", "freelancer": "Buscar en Freelancer",
        "linkedin": "LinkedIn", "getonboard": "Get on Board", "computrabajo": "Computrabajo",
        "elempleo": "elempleo", "magneto": "Magneto",
    ]

    func install(in menu: NSMenu) {
        let freelance = NSMenu()
        Config.freelanceSources.forEach { freelance.addItem(toggle($0)) }
        freelance.addItem(.separator())
        quotaWorkana.isEnabled = false
        quotaFreelancer.isEnabled = false
        freelance.addItem(quotaWorkana)
        freelance.addItem(quotaFreelancer)
        freelance.addItem(.separator())
        freelance.addItem(action("Buscar proyectos ahora", #selector(freelanceNow)))
        freelanceHeader.submenu = freelance
        menu.addItem(freelanceHeader)

        let jobs = NSMenu()
        Config.jobSources.forEach { jobs.addItem(toggle($0)) }
        jobs.addItem(.separator())
        jobs.addItem(action("Buscar vacantes ahora", #selector(jobsNow)))
        jobsHeader.submenu = jobs
        menu.addItem(jobsHeader)

        let schedule = NSMenu()
        followUpNext.isEnabled = false
        reportNext.isEnabled = false
        schedule.addItem(followUpNext)
        schedule.addItem(reportNext)
        schedule.addItem(.separator())
        schedule.addItem(action("Hacer seguimientos ahora", #selector(followUpNow)))
        schedule.addItem(action("Armar informe semanal ahora", #selector(reportNow)))
        schedule.addItem(action("Abrir informes", #selector(openReports)))
        scheduleHeader.submenu = schedule
        menu.addItem(scheduleHeader)

        let telegram = NSMenu()
        telegramState.isEnabled = false
        telegram.addItem(telegramState)
        telegram.addItem(.separator())
        telegram.addItem(action("Configurar bot…", #selector(configureTelegram)))
        telegram.addItem(action("Enviar aviso de prueba", #selector(sendTest)))
        telegram.addItem(action("Volver a vincular el chat", #selector(forgetChat)))
        telegramHeader.submenu = telegram
        menu.addItem(telegramHeader)

        menu.addItem(.separator())
        claudeItem.isEnabled = false
        menu.addItem(claudeItem)
        menu.addItem(action("Ver registro", #selector(openLog)))
        menu.addItem(action("Abrir carpeta de datos", #selector(openFolder)))
        menu.delegate = self

        FreelanceRadar.shared.onStatusChange = { [weak self] _ in self?.refresh() }
        JobRadar.shared.onStatusChange = { [weak self] _ in self?.refresh() }
        Controller.shared.onStatusChange = { [weak self] _ in self?.refresh() }
        let timer = Timer(timeInterval: 20, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    func refresh() {
        let config = Config.load()
        for (item, source) in toggles { item.state = config.isEnabled(source) ? .on : .off }
        freelanceHeader.title = "Radar freelance: \(FreelanceRadar.shared.status)"
            + (config.freelanceOn ? " · próxima \(TextTools.countdown(FreelanceRadar.shared.nextRun))" : "")
        jobsHeader.title = "Radar empleo: \(JobRadar.shared.status)"
            + (config.jobsOn ? " · próxima \(TextTools.countdown(JobRadar.shared.nextRun))" : "")
        claudeItem.title = "Claude: \(Controller.shared.status)"
        quotaWorkana.title = "Workana: \(Quotas.describe("workana"))"
        quotaFreelancer.title = "Freelancer: \(Quotas.describe("freelancer"))"
        followUpNext.title = "Seguimientos (10 a. m. y 4 p. m.): \(TextTools.countdown(Scheduler.shared.nextFollowUp))"
        reportNext.title = "Informe (domingo 6 p. m.): \(TextTools.countdown(Scheduler.shared.nextReport))"
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

    private func toggle(_ source: String) -> NSMenuItem {
        let item = NSMenuItem(title: Self.sourceTitles[source] ?? source, action: #selector(flip(_:)), keyEquivalent: "")
        item.target = self
        item.tag = toggles.count
        toggles.append((item, source))
        return item
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func flip(_ sender: NSMenuItem) {
        guard sender.tag < toggles.count else { return }
        let source = toggles[sender.tag].1
        var config = Config.load()
        let enabled = !config.isEnabled(source)
        config.setEnabled(source, enabled)
        config.save()
        refresh()
        guard enabled else { return }
        if Config.freelanceSources.contains(source) { FreelanceRadar.shared.checkNow() } else { JobRadar.shared.checkNow() }
    }

    @objc private func freelanceNow() { FreelanceRadar.shared.checkNow() }
    @objc private func jobsNow() { JobRadar.shared.checkNow() }
    @objc private func followUpNow() { Controller.shared.runScheduled(.followUp, manual: true) }
    @objc private func reportNow() { Controller.shared.runScheduled(.weeklyReport, manual: true) }

    @objc private func openReports() {
        Paths.ensure()
        NSWorkspace.shared.open(Paths.reports)
    }

    @objc private func configureTelegram() {
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

    @objc private func sendTest() {
        guard Notifier.canUseTelegram else {
            info("Primero configura el bot y envíale /start desde tu celular.")
            return
        }
        Notifier.tell("Aviso de prueba: tu celular ya recibe Hirebar.\n\n" + Controller.shared.statusReport())
    }

    @objc private func forgetChat() {
        var config = Config.load()
        config.chatId = 0
        config.save()
        refresh()
        info("Listo. El próximo mensaje que reciba el bot (envíale /start) quedará como tu chat.")
    }

    @objc private func openLog() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Paths.log.path) {
            try? fm.createDirectory(at: Paths.logs, withIntermediateDirectories: true)
            fm.createFile(atPath: Paths.log.path, contents: nil)
        }
        NSWorkspace.shared.open(Paths.log)
    }

    @objc private func openFolder() {
        Paths.ensure()
        NSWorkspace.shared.open(Paths.root)
    }

    func info(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Hirebar"
        alert.informativeText = message
        alert.runModal()
    }
}
