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
    auto si / auto no: envío automático sin esperar tu "si" (también "auto freelance si", "auto empleo no", "auto correos si")
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
        Freelance: \(FreelanceRadar.shared.status) · próxima \(TextTools.countdown(FreelanceRadar.shared.nextRun))
        Empleo: \(JobRadar.shared.status) · próxima \(TextTools.countdown(JobRadar.shared.nextRun))
        Seguimientos: próximos \(TextTools.countdown(Scheduler.shared.nextFollowUp))
        Informe semanal: \(TextTools.countdown(Scheduler.shared.nextReport))
        """
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
        reply(target.mode == .adjustments ? "Listo, no cambio nada." : "Descartada. Sigo buscando cada hora.")
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
        let target = ["freelance", "empleo", "correos"].contains(rest.first ?? "") ? rest.first ?? "ambos" : "ambos"
        var config = Config.load()
        if let value = rest.last, ["si", "on", "no", "off"].contains(value) {
            let on = value == "si" || value == "on"
            if target == "correos" {
                config.autoEmails = on
            } else {
                if target != "empleo" { config.autoFreelance = on }
                if target != "freelance" { config.autoJobs = on }
            }
            config.save()
        }
        reply("Envío automático · freelance: \(config.autoFreelance ? "SÍ" : "no") (busca cada \(config.freelanceMinutes) min) · empleo: \(config.autoJobs ? "SÍ" : "no") (busca cada \(config.jobMinutes) min) · correos: \(config.autoEmails ? "SÍ" : "no").\nCambiar: \"auto si\", \"auto no\", \"auto freelance si\", \"auto empleo no\", \"auto correos si\".")
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
