import Foundation
import HirebarCore

enum AgentPrompts {
    static func prompt(for batch: Batch, items: [BatchItem], owner: String) -> String {
        let list = items.enumerated().map { index, item in
            "\(index + 1). [\(item.kind)] \(item.platform): \(item.title)\n   \(item.url)\n   \(item.detail)"
        }.joined(separator: "\n")
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let week = Metrics.weekKey()
        let browser = "Usa su navegador con las herramientas de Claude in Chrome."
        switch batch.mode {
        case .followUp:
            return """
            Revisión de seguimientos \(batch.id) (\(now), semana \(week)). Revisa seguimiento.json y haz los seguimientos \
            que tocan según tus instrucciones, sin pedir confirmación. \(browser)
            """
        case .weeklyReport:
            return """
            Informe semanal \(batch.id) (\(now)). Cierra la semana \(week): analiza las métricas y los registros \
            según tus instrucciones, escribe el informe y deja los ajustes propuestos en ajustes-propuestos.json. \
            No cambies ningún archivo de configuración: solo propones.
            """
        case .linkedInDraft:
            let note = (try? String(contentsOf: Paths.linkedIn.appendingPathComponent("cambios.txt"), encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let change = note.isEmpty ? "" : "\n\nCambio que pidió \(owner) sobre el borrador anterior: \(note)"
            return """
            Borrador LinkedIn \(batch.id) (\(now)). Escribe la publicación de esta semana según tus instrucciones \
            y guárdala en linkedin/borrador.md. NO publiques nada: \(owner) la aprueba primero desde Telegram.\(change)
            """
        case .prospecting:
            return """
            Prospección \(batch.id) (\(now), semana \(week)). Busca empresas y negocios según tus instrucciones, revisa \
            respuestas y seguimientos pendientes, y deja la lista del día en prospeccion/pendientes.json. NO envíes \
            ningún correo: \(owner) aprueba la lista desde Telegram. \(browser)
            """
        case .prospectingSend:
            return """
            Envío de prospección \(batch.id) (\(now)). \(owner) aprobó desde Telegram los correos indicados en \
            prospeccion/aprobados.json de la lista prospeccion/pendientes.json. Envíalos desde su Gmail según tus \
            instrucciones. \(browser)
            """
        case .social:
            return """
            Búsqueda en redes \(batch.id) (\(now), semana \(week)). Busca publicaciones de las últimas horas que ofrezcan \
            vacantes o proyectos para \(owner) y actúa según tus instrucciones, sin pedir confirmación. \
            \(browser) Si no hay nada nuevo, responde solo \(Controller.noNewsMarker).
            """
        case .linkedInPublish:
            return """
            Publicar LinkedIn \(batch.id) (\(now)). \(owner) respondió "publica" en Telegram: publica en su LinkedIn \
            EXACTAMENTE el texto de linkedin/borrador.md, según tus instrucciones. \(browser)
            """
        case .adjustments:
            return """
            Aplicar ajustes \(batch.id) (\(now)). \(owner) aprobó desde Telegram estos ajustes del informe semanal. \
            Aplícalos según tus instrucciones y confirma qué cambiaste.

            \(list)
            """
        case .jobs:
            return """
            Lote \(batch.id) (\(now)). \(owner) respondió SÍ desde Telegram: postúlalo YA a estas vacantes, \
            sin pedirle más confirmación, siguiendo tus instrucciones (perfil.md y las reglas de empleo). \(browser)

            \(list)
            """
        case .freelance:
            return """
            Lote \(batch.id) (\(now)). \(owner) respondió SÍ desde Telegram: analiza la competencia, redacta y ENVÍA YA \
            la propuesta de cada uno de estos proyectos, sin pedirle más confirmación, siguiendo tus instrucciones \
            (perfil.md y las reglas de propuestas). \(browser)

            \(list)
            """
        }
    }

    static func statusText(for mode: Mode, count: Int, since hour: String) -> String {
        switch mode {
        case .followUp: return "revisando seguimientos (desde \(hour))"
        case .weeklyReport: return "armando el informe semanal (desde \(hour))"
        case .prospecting: return "buscando empresas y negocios (desde \(hour))"
        case .prospectingSend: return "enviando correos aprobados (desde \(hour))"
        case .social: return "buscando en redes (desde \(hour))"
        case .linkedInDraft: return "escribiendo el borrador de LinkedIn (desde \(hour))"
        case .linkedInPublish: return "publicando en LinkedIn (desde \(hour))"
        case .adjustments: return "aplicando \(count) ajuste(s) (desde \(hour))"
        case .jobs: return "haciendo \(count) postulaciones (desde \(hour))"
        case .freelance: return "haciendo \(count) propuestas (desde \(hour))"
        }
    }
}
