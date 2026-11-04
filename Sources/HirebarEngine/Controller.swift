import Foundation
import HirebarCore

public final class Controller {
    public static let shared = Controller()
    static let noNewsMarker = "SIN_NOVEDADES"
    static let maxRunSeconds: TimeInterval = 3600
    static let authAlertEvery: TimeInterval = 3600

    public var onStatusChange: ((String) -> Void)?
    public private(set) var status = "en espera"
    var queue: [(Batch, [BatchItem])] = []
    private var running: Process?
    private var runningBatch: String?
    private var runningMode: Mode?
    private var runStarted: Date?
    private var watchdog: Timer?
    private var lastAuthAlert: Date?

    public var isIdle: Bool { running == nil && queue.isEmpty }
    public var runningAgent: AgentKind? { runningMode.map(AgentKind.owner) }

    public func start() {
        if watchdog == nil {
            let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in self?.stopIfStuck() }
            RunLoop.main.add(timer, forMode: .common)
            watchdog = timer
        }
        Paths.ensure()
        Telegram.shared.onMessage = { [weak self] message in self?.handle(message) }
        Telegram.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.recoverInterrupted() }
    }

    func setStatus(_ text: String) {
        status = text
        onStatusChange?(text)
    }

    func reply(_ text: String) { Notifier.tell(text) }

    public func autoApprove(_ batch: Batch) {
        approve(batch, picks: [])
    }

    func approve(_ found: Batch?, picks: [Int]) {
        guard var batch = found else {
            reply("No tengo listas pendientes de las últimas 24 horas.")
            return
        }
        guard batch.status == .pending else {
            reply("Esa lista ya está \(batch.status.rawValue).")
            return
        }
        let chosen = picks.isEmpty ? batch.items
            : picks.filter { $0 >= 1 && $0 <= batch.items.count }.map { batch.items[$0 - 1] }
        guard !chosen.isEmpty else {
            reply("Esos números no están en la lista (van del 1 al \(batch.items.count)).")
            return
        }
        batch.status = .running
        BatchStore.upsert(batch)
        Metrics.bump(batch.mode, "aprobados", chosen.count)
        if let id = batch.messageId { Telegram.shared.removeButtons(chatId: Config.load().chatId, messageId: id) }
        queue.append((batch, chosen))
        if running == nil {
            runNext()
        } else {
            reply("Anotado: Claude está terminando otra lista y sigue con esta.")
        }
    }

    public func runScheduled(_ mode: Mode, manual: Bool = false) {
        if Scheduler.isIdlePortalScan(mode) {
            if manual { reply("No tienes portales propios activos. Agrégalos en Ajustes → \(AgentStore.load(AgentKind.owner(of: mode)).name).") }
            return
        }
        if runningMode == mode || queue.contains(where: { $0.0.mode == mode }) {
            if manual { reply("Eso ya está en curso.") }
            return
        }
        let batch = Batch(mode: mode, status: .running, manual: manual)
        BatchStore.upsert(batch)
        queue.append((batch, []))
        if manual {
            switch mode {
            case .weeklyReport: reply("Preparando el informe semanal; te lo mando al terminar.")
            case .linkedInDraft: reply("Armando el borrador para LinkedIn; te lo mando antes de publicar nada.")
            case .linkedInPublish: reply("Publicando en LinkedIn el borrador que aprobaste; te confirmo al terminar.")
            case .followUp: reply("Revisando seguimientos ahora; te aviso si escribo a algún cliente.")
            case .prospectingSend: reply("Enviando los correos aprobados; te confirmo al terminar.")
            case .social: reply("Buscando vacantes publicadas en redes; te aviso si encuentro algo.")
            case .prospecting: reply("Buscando empresas y negocios para escribirles; te mando la lista al terminar.")
            case .profileUpdate: reply("Actualizando tu perfil y tus hojas de vida; te mando los PDF al terminar.")
            default: break
            }
        }
        if running == nil { runNext() }
    }

    private func stopIfStuck() {
        guard let process = running, process.isRunning, let started = runStarted,
              Date().timeIntervalSince(started) > Self.maxRunSeconds else { return }
        Log.write("Claude: lote \(runningBatch ?? "?") lleva más de 1 hora, se detiene")
        process.terminate()
    }

    private func recoverInterrupted() {
        let since = Date().addingTimeInterval(-24 * 3600)
        for var batch in BatchStore.load() where batch.status == .running {
            if !batch.items.isEmpty && batch.created > since && batch.mode.hasItems {
                batch.status = .pending
                BatchStore.upsert(batch)
                Notifier.announce(batch, title: "Quedaron sin terminar estas \(Self.noun(for: batch.mode)) (la Mac se durmió o se cerró la app)",
                                  footer: "Responde \"si\" para reintentar, \"si 1 3\" para elegir o \"no\" para descartar.")
            } else {
                batch.status = .interrupted
                BatchStore.upsert(batch)
            }
        }
    }

    static func noun(for mode: Mode) -> String {
        mode == .jobs ? "postulaciones" : "propuestas"
    }

    private func runNext() {
        guard running == nil, !queue.isEmpty else { return }
        let (pending, items) = queue.removeFirst()
        var batch = pending
        guard let claude = ClaudeCLI.path() else {
            batch.status = .failed
            BatchStore.upsert(batch)
            reply("No encontré Claude Code en el Mac. Instálalo con: curl -fsSL https://claude.ai/install.sh | bash, inicia sesión con 'claude' y vuelve a responder si.")
            setStatus("falta instalar Claude Code")
            runNext()
            return
        }
        Paths.ensure()
        let outURL = Paths.runs.appendingPathComponent("\(batch.id).txt")
        let errURL = Paths.runs.appendingPathComponent("\(batch.id).log")
        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let owner = Config.load().ownerName
        let process = ClaudeCLI.process(executable: claude,
                                        prompt: AgentPrompts.prompt(for: batch, items: items, owner: owner),
                                        playbook: Paths.playbook(for: batch.mode),
                                        output: outURL, errors: errURL)
        let batchId = batch.id
        let mode = batch.mode
        process.terminationHandler = { finished in
            let code = finished.terminationStatus
            DispatchQueue.main.async {
                Controller.shared.finished(batchId, mode: mode, items: items, code: code, outURL: outURL, errURL: errURL)
            }
        }
        do {
            try process.run()
        } catch {
            batch.status = .failed
            BatchStore.upsert(batch)
            reply("No pude abrir Claude Code: \(error.localizedDescription)")
            runNext()
            return
        }
        running = process
        runningBatch = batchId
        runningMode = mode
        runStarted = Date()
        setStatus(AgentPrompts.statusText(for: mode, count: items.count, since: TextTools.shortTime()))
        if mode == .freelance || mode == .jobs {
            reply("Claude empezó: \(items.count) \(Self.noun(for: mode)). Te aviso cuando termine (suele tardar 5–20 min).")
        }
        Log.write("Claude: inicia lote \(batchId) con \(items.count) elemento(s)")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxRunSeconds) { [weak self] in
            guard let self, self.runningBatch == batchId, let process = self.running, process.isRunning else { return }
            Log.write("Claude: lote \(batchId) superó 1 hora, se detiene")
            process.terminate()
        }
    }

    private func finished(_ batchId: String, mode: Mode, items: [BatchItem], code: Int32, outURL: URL, errURL: URL) {
        running = nil
        runningBatch = nil
        runningMode = nil
        let output = ((try? String(contentsOf: outURL, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let errors = (try? String(contentsOf: errURL, encoding: .utf8)) ?? ""
        Log.write("Claude: lote \(batchId) terminó con código \(code)")

        if code != 0 && ClaudeCLI.isAuthFailure(output + "\n" + errors) {
            handleAuthFailure(batchId, mode: mode, items: items)
        } else {
            if var batch = BatchStore.find(id: batchId) {
                batch.status = code == 0 ? .done : .failed
                batch.result = String(output.suffix(2000))
                BatchStore.upsert(batch)
            }
            report(batchId, mode: mode, code: code, output: output)
        }
        setStatus(queue.isEmpty ? "en espera" : "siguiente lista…")
        runNext()
    }

    private func handleAuthFailure(_ batchId: String, mode: Mode, items: [BatchItem]) {
        if var batch = BatchStore.find(id: batchId) {
            batch.status = mode.hasItems ? .pending : .interrupted
            if mode.hasItems { batch.items = items }
            BatchStore.upsert(batch)
        }
        Log.write("Claude: la sesión de Claude Code venció; lote \(batchId) queda para reintentar")
        let now = Date()
        if lastAuthAlert.map({ now.timeIntervalSince($0) > Self.authAlertEvery }) ?? true {
            lastAuthAlert = now
            reply("La sesión de Claude Code se venció y no pude trabajar. Abre Terminal, escribe claude y luego /login. Las listas de propuestas y postulaciones quedaron guardadas: responde \"si\" para reintentar la última.")
        }
    }

    private func report(_ batchId: String, mode: Mode, code: Int32, output: String) {
        if code == 0 && (mode == .portalScanJobs || mode == .portalScanFreelance) {
            offerPortalFindings(mode)
            if output.contains(Self.noNewsMarker) { return }
        }
        if code == 0 && (mode == .followUp || mode == .social || mode == .portalScanJobs || mode == .portalScanFreelance)
            && output.contains(Self.noNewsMarker) {
            Log.write("\(mode.rawValue): sin novedades")
            if batchId.hasPrefix("gm-") {
                let summary = output.replacingOccurrences(of: Self.noNewsMarker, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                reply("Seguimientos: hoy no tocaba escribirle a nadie.\n\n" + (summary.isEmpty ? "Sin más detalle." : String(summary.suffix(3500))))
            }
            return
        }
        guard code == 0 && !output.isEmpty else {
            let detail = output.isEmpty ? "sin salida" : String(output.suffix(1500))
            reply("Claude terminó con error (código \(code)). Detalle: \(detail)\nRegistro: workspace/ejecuciones/\(batchId).log")
            return
        }
        reply(String(output.suffix(3800)))
        switch mode {
        case .prospecting: offerProspectingEmails()
        case .profileUpdate: finishProfileUpdate()
        case .linkedInDraft:
            reply("¿Lo subo a LinkedIn? Responde \"publica\" para subirlo tal cual, \"post cambia <qué>\" para ajustarlo o \"post salta\" para no publicarlo esta semana.")
        default: break
        }
    }

    static let portalSeenKey = "portals.seen"

    private func offerPortalFindings(_ mode: Mode) {
        let agent: AgentKind = mode == .portalScanJobs ? .jobs : .freelance
        let now = Date()
        var seen = UserDefaults.standard.dictionary(forKey: Self.portalSeenKey) as? [String: Date] ?? [:]
        seen = seen.filter { now.timeIntervalSince($0.value) < 30 * 86400 }
        var hits: [Hit] = []
        for finding in PortalStore.takeFindings() where !finding.url.isEmpty && seen[finding.url] == nil {
            seen[finding.url] = now
            let fit: Fit = (finding.encaje ?? "").uppercased().contains("RETO") ? .stretch : .strong
            let detail = [finding.portal, finding.detalle ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
            hits.append(Hit(id: "cp:" + finding.url, platform: finding.portal, fit: fit, title: finding.titulo,
                            url: finding.url, detail: detail, score: fit.rank))
        }
        UserDefaults.standard.set(seen, forKey: Self.portalSeenKey)
        guard !hits.isEmpty else { return }
        let target: Mode = agent == .jobs ? .jobs : .freelance
        let batch = Batch(mode: target, items: hits.sorted(by: Hit.ranked).map(BatchItem.init), status: .pending)
        BatchStore.upsert(batch)
        Metrics.bump(target, "avisados", hits.count)
        let auto = AgentStore.load(agent).autoApprove
        let noun = agent == .jobs ? "vacante(s)" : "proyecto(s)"
        Notifier.announce(batch, title: "Tus portales: \(hits.count) \(noun) para ti" + (auto ? " (envío automático)" : ""),
                          footer: auto ? "Claude ya los está procesando; te aviso al terminar."
                                       : "Responde \"si\" para que Claude los procese, \"si 1 3\" para elegir o \"no\" para descartar.")
        if auto { autoApprove(batch) }
    }

    private func finishProfileUpdate() {
        ProfileRequests.clear()
        let profile = Profile.load()
        guard !profile.cvVariants.isEmpty else {
            reply("perfil.json no tiene hojas de vida definidas (cvVariants), así que no generé PDF.")
            return
        }
        CVRenderer.renderAll(profile) { [weak self] result in
            for file in result.made {
                Notifier.sendFile(file, caption: "Hoja de vida actualizada: \(file.lastPathComponent)")
            }
            var lines = ["Hojas de vida: \(result.made.count) de \(profile.cvVariants.count) listas."]
            if !result.missing.isEmpty { lines.append("Claude no dejó el HTML de: \(result.missing.joined(separator: ", ")).") }
            if !result.failed.isEmpty { lines.append("No pude crear el PDF de: \(result.failed.joined(separator: ", ")) (revisa que Google Chrome esté instalado).") }
            self?.reply(lines.joined(separator: "\n"))
        }
    }

    private func offerProspectingEmails() {
        let pending = Paths.prospecting.appendingPathComponent("pendientes.json")
        guard let list = try? String(contentsOf: pending, encoding: .utf8), list.contains("\"correo\"") else { return }
        guard AgentStore.load(.clients).autoApprove else {
            reply("¿Los envío? Responde \"envia correos\" para todos, \"envia correos 1 3 5\" para elegir o \"no correos\" para no enviar hoy.")
            return
        }
        var automatic: [Int] = []
        var held: [Int] = []
        if let data = list.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let emails = object["correos"] as? [[String: Any]] {
            for email in emails {
                guard let number = (email["n"] as? NSNumber)?.intValue else { continue }
                if (email["tipo"] as? String ?? "").uppercased() == "RESPUESTA" { held.append(number) } else { automatic.append(number) }
            }
        }
        let heldText = held.map(String.init).joined(separator: " ")
        if !automatic.isEmpty {
            writeApproved(automatic.map(String.init).joined(separator: ","))
            reply("Envío automático: mando \(automatic.count) correo(s) de la lista." + (held.isEmpty ? "" : " Las respuestas \(heldText) esperan tu \"envia correos <números>\"."))
            Log.write("Prospección: envío automático de \(automatic.count) correo(s)")
            runScheduled(.prospectingSend)
        } else if !held.isEmpty {
            reply("Hay respuestas para aprobar: \"envia correos \(heldText)\" o \"no correos\".")
        }
    }

    func writeApproved(_ numbers: String?) {
        let value = numbers.map { "[\($0)]" } ?? "\"todos\""
        try? "{\"aprobados\": \(value)}".write(to: Paths.prospecting.appendingPathComponent("aprobados.json"), atomically: true, encoding: .utf8)
    }
}
