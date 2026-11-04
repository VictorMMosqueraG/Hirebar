import Foundation
import HirebarCore

extension Controller {
    static let help = """
    Comandos:
    si: Claude envía/postula a toda la última lista
    si 1 3: solo esos números
    no: descarta la lista
    estado: cupos, próximas búsquedas y qué está haciendo Claude
    buscar: busca proyectos y vacantes ya (o "buscar freelance", "buscar empleo")
    seguimientos: revisa y hace seguimientos ahora
    informe: arma ya el informe semanal
    anota <texto>: guarda algo para el informe (ej: anota entrevista el jueves)
    post: arma ya un borrador de publicación para LinkedIn (te llega aquí antes de subirlo)
    publica: sube a LinkedIn el último borrador que te mandé
    post cambia <qué>: rehace el borrador con tu cambio · post salta: descarta el borrador
    envia correos: envía la lista de correos del día (o "envia correos 1 3", "no correos")
    logro <texto>: agrega un logro a tu perfil y regenera tus hojas de vida
    trabajo <texto>: registra un cambio de trabajo (ej: trabajo nuevo Backend Senior en Acme desde dic 2026)
    habilidad <nombre> <domino|conozco|evito>: cambia una habilidad; afecta búsquedas y filtros al instante
    habilidades: muestra tus habilidades por nivel
    hv: regenera tus hojas de vida sin cambios
    agentes: estado de cada agente (empleo, freelance, clientes, contenido, perfil, analista)
    agente <nombre> on / off: prende o apaga un agente
    corre <nombre>: corre ya las tareas de un agente (ej: corre clientes)
    auto si / auto no: envío automático de empleo y freelance (o "auto <agente> si", ej: "auto clientes si")
    (Puedes responder citando un aviso para elegir cuál lista.)
    """

    static let approveVerbs: Set<String> = ["si", "dale", "ok", "listo", "envia", "enviar", "postula", "aplica"]
    static let emailVerbs: Set<String> = ["envia", "enviar", "envialos", "envie", "si", "dale", "ok", "no", "aprobado", "aprueba"]

    func handle(_ message: TelegramMessage) {
        var config = Config.load()
        if config.chatId == 0 {
            config.chatId = message.chatId
            config.save()
            Telegram.shared.send("Listo, este chat quedó vinculado a Hirebar. Te avisaré aquí cada vez que aparezcan proyectos o vacantes para ti.\n\n" + Self.help,
                                 chatId: message.chatId)
            Log.write("Telegram: chat vinculado")
            return
        }
        guard message.chatId == config.chatId else {
            Log.write("Telegram: ignorado un mensaje de otro chat")
            return
        }

        var text = message.text.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var batch: Batch?
        if let callback = message.callbackId {
            Telegram.shared.answerCallback(callback, text: "Recibido")
            if let colon = text.firstIndex(of: ":") {
                batch = BatchStore.find(id: String(text[text.index(after: colon)...]))
                text = String(text[..<colon])
            }
        }
        if batch == nil, let replyTo = message.replyTo { batch = BatchStore.find(messageId: replyTo) }

        let words = text.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let verb = words.first ?? ""
        let numbers = words.compactMap { Int($0) }
        if (words.contains("correos") || words.contains("correo")) && Self.emailVerbs.contains(verb) {
            handleEmails(verb: verb, numbers: numbers)
            return
        }
        switch verb {
        case _ where Self.approveVerbs.contains(verb):
            approve(batch ?? BatchStore.latestPending(), picks: numbers)
        case "no", "descarta", "nada":
            discard(batch ?? BatchStore.latestPending(), chatId: config.chatId)
        case "estado":
            reply(statusReport())
        case "seguimientos", "seguimiento":
            runScheduled(.followUp, manual: true)
        case "informe":
            runScheduled(.weeklyReport, manual: true)
        case "anota", "anotar", "nota":
            let note = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init) ?? ""
            guard !note.isEmpty else {
                reply("Escribe qué anotar, por ejemplo: anota entrevista el jueves")
                return
            }
            Metrics.event(note)
            reply("Anotado para el informe del domingo.")
        case "auto", "automatico":
            handleAuto(Array(words.dropFirst()))
        case "agentes":
            reply(agentsReport())
        case "agente":
            handleAgentSwitch(Array(words.dropFirst()))
        case "corre", "correr":
            handleRunNow(rest(of: message.text))
        case "publica", "publicar":
            let draft = Paths.linkedIn.appendingPathComponent("borrador.md")
            guard let draftText = try? String(contentsOf: draft, encoding: .utf8),
                  draftText.trimmingCharacters(in: .whitespacesAndNewlines).count > 20 else {
                reply("No tengo un borrador pendiente. Escribe \"post\" para que arme uno.")
                return
            }
            runScheduled(.linkedInPublish, manual: true)
        case "post":
            handlePost(message.text)
        case "logro", "logros":
            requestProfileChange("Logro", rest(of: message.text), example: "logro bajé el costo de AWS 20% en KoralAT")
        case "trabajo":
            requestProfileChange("Cambio de trabajo", rest(of: message.text), example: "trabajo nuevo Backend Senior en Acme desde dic 2026")
        case "habilidad", "skill":
            handleSkill(rest(of: message.text))
        case "habilidades", "skills":
            reply(Profile.load().summary)
        case "hv":
            runScheduled(.profileUpdate, manual: true)
        case "buscar":
            let target = words.dropFirst().first ?? ""
            if target != "empleo" { FreelanceRadar.shared.checkNow() }
            if target != "freelance" { JobRadar.shared.checkNow() }
            reply("Buscando ahora; si encuentro algo te aviso.")
        default:
            reply(Self.help)
        }
    }

    public func statusReport() -> String {
        """
        Claude: \(status)
        Cupos: \(Quotas.summary())
        Búsqueda freelance: \(FreelanceRadar.shared.status)
        Búsqueda de empleo: \(JobRadar.shared.status)

        \(agentsReport())
        """
    }

    private func rest(of raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1).dropFirst().first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func requestProfileChange(_ kind: String, _ text: String, example: String) {
        guard !text.isEmpty else {
            reply("Escribe el detalle, por ejemplo: \(example)")
            return
        }
        ProfileRequests.append(kind, text)
        runScheduled(.profileUpdate, manual: true)
    }

    private func handleSkill(_ text: String) {
        var parts = text.split(separator: " ").map(String.init)
        guard parts.count >= 2, let level = SkillLevel.parse(parts.removeLast()) else {
            if !text.isEmpty, let skill = Profile.load().skill(named: text) {
                reply("\(skill.name): \(skill.level.rawValue)")
            } else {
                reply("Escribe: habilidad <nombre> <domino|conozco|evito>, por ejemplo: habilidad Go conozco")
            }
            return
        }
        let name = parts.joined(separator: " ")
        switch ProfileEditor.setSkill(name, level: level) {
        case .added:
            reply("Agregué \(name) como \(level.rawValue). Ya cuenta en la próxima búsqueda.")
        case .updated(let from):
            reply("\(name): \(from.rawValue) → \(level.rawValue). Ya cuenta en la próxima búsqueda.")
        case .unchanged:
            reply("\(name) ya estaba como \(level.rawValue).")
        case .failed(let reason):
            reply("No pude cambiar la habilidad: \(reason)")
        }
    }

    private func discard(_ found: Batch?, chatId: Int64) {
        guard var target = found, target.status == .pending else {
            reply("No tengo listas pendientes.")
            return
        }
        target.status = .discarded
        BatchStore.upsert(target)
        Metrics.bump(target.mode, "listas_descartadas")
        if let id = target.messageId { Telegram.shared.removeButtons(chatId: chatId, messageId: id) }
        reply("Descartada. Sigo buscando.")
    }

    private func handleEmails(verb: String, numbers: [Int]) {
        let pending = Paths.prospecting.appendingPathComponent("pendientes.json")
        guard let pendingText = try? String(contentsOf: pending, encoding: .utf8), pendingText.contains("\"correo\"") else {
            reply("No tengo correos pendientes de aprobar.")
            return
        }
        if verb == "no" {
            try? "{\"aprobados\": [], \"descartada\": true}".write(to: Paths.prospecting.appendingPathComponent("aprobados.json"),
                                                                   atomically: true, encoding: .utf8)
            let stamp = Int(Date().timeIntervalSince1970)
            try? FileManager.default.moveItem(at: pending, to: Paths.prospecting.appendingPathComponent("descartados-\(stamp).json"))
            reply("Listo, no envío los correos de hoy.")
            return
        }
        writeApproved(numbers.isEmpty ? nil : numbers.map(String.init).joined(separator: ","))
        runScheduled(.prospectingSend, manual: true)
    }

    private func handleAuto(_ rest: [String]) {
        let named = rest.count > 1 ? AgentKind.parse(rest.dropLast().joined(separator: " ")) : nil
        let targets: [AgentKind] = named.map { [$0] } ?? [.jobs, .freelance]
        if let value = rest.last, ["si", "on", "no", "off"].contains(value) {
            let on = value == "si" || value == "on"
            for kind in targets { AgentStore.update(kind) { $0.autoApprove = on } }
        }
        let lines = [AgentKind.jobs, .freelance, .clients].map { kind -> String in
            let agent = AgentStore.load(kind)
            return "\(agent.name): \(agent.autoApprove ? "SÍ" : "no")"
        }
        reply("Envío automático · " + lines.joined(separator: " · ") + "\nCambiar: \"auto si\", \"auto no\", \"auto empleo no\", \"auto clientes si\".")
    }

    private func handleAgentSwitch(_ rest: [String]) {
        guard let value = rest.last, ["on", "off", "si", "no"].contains(value),
              let kind = AgentKind.parse(rest.dropLast().joined(separator: " ")) else {
            reply("Escribe: agente <nombre> on / off, por ejemplo: agente clientes off")
            return
        }
        let on = value == "on" || value == "si"
        AgentStore.update(kind) { $0.enabled = on }
        reply("\(AgentStore.load(kind).name): \(on ? "prendido" : "apagado").")
    }

    private func handleRunNow(_ name: String) {
        guard let kind = AgentKind.parse(name) else {
            reply("Escribe: corre <empleo | freelance | clientes | contenido | perfil | analista>")
            return
        }
        runAgentNow(kind)
    }

    public func runAgentNow(_ kind: AgentKind) {
        let agent = AgentStore.load(kind)
        switch kind {
        case .jobs: JobRadar.shared.checkNow()
        case .freelance: FreelanceRadar.shared.checkNow()
        default: break
        }
        if kind == .profile {
            runScheduled(.profileUpdate, manual: true)
        } else {
            for task in agent.tasks { runScheduled(task.mode, manual: true) }
        }
        if agent.tasks.isEmpty && !agent.hasSearch && kind != .profile {
            reply("\(agent.name) no tiene tareas configuradas.")
        } else if agent.hasSearch {
            reply("\(agent.name): buscando ahora.")
        }
    }

    public func agentsReport() -> String {
        AgentStore.all().map { agent in
            var line = "\(agent.name): \(agent.enabled ? "prendido" : "apagado")"
            if agent.enabled {
                if [.jobs, .freelance, .clients].contains(agent.id) { line += " · auto \(agent.autoApprove ? "sí" : "no")" }
                if let next = Scheduler.shared.nextRun(of: agent.id) { line += " · próxima \(TextTools.countdown(next))" }
            }
            return line
        }.joined(separator: "\n")
    }

    private func handlePost(_ raw: String) {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ", maxSplits: 2).map(String.init)
        let sub = parts.count > 1 ? parts[1].lowercased() : ""
        Paths.ensure()
        if sub == "salta" || sub == "no" {
            let draft = Paths.linkedIn.appendingPathComponent("borrador.md")
            let stamp = ISO8601DateFormatter().string(from: Date()).prefix(10)
            try? FileManager.default.moveItem(at: draft, to: Paths.linkedIn.appendingPathComponent("descartado-\(stamp)-\(Int(Date().timeIntervalSince1970)).md"))
            reply("Listo, no se publica. El próximo borrador llega el martes (o escribe \"post\").")
            return
        }
        let note = (sub == "cambia" && parts.count > 2) ? parts[2] : ""
        try? note.write(to: Paths.linkedIn.appendingPathComponent("cambios.txt"), atomically: true, encoding: .utf8)
        runScheduled(.linkedInDraft, manual: true)
    }
}
