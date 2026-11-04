import Foundation

public enum Notifier {
    public static var canUseTelegram: Bool { Telegram.shared.isConfigured && Config.load().chatId != 0 }

    public static func announce(_ batch: Batch, title: String, footer: String) {
        var lines = [title, ""]
        for (index, item) in batch.items.enumerated() {
            lines.append("\(index + 1). [\(item.kind)] \(item.title)")
            lines.append(item.detail)
            if !item.url.isEmpty { lines.append(item.url) }
            lines.append("")
        }
        lines.append(footer)
        let text = lines.joined(separator: "\n")
        if canUseTelegram {
            let label = batch.mode == .jobs ? "Sí, postular a todas" : "Sí, enviar todas"
            Telegram.shared.send(text, chatId: Config.load().chatId,
                                 buttons: [[(label, "si:\(batch.id)"), ("No", "no:\(batch.id)")]]) { id in
                guard let id, var stored = BatchStore.find(id: batch.id) else { return }
                stored.messageId = id
                BatchStore.upsert(stored)
            }
        } else {
            ntfy(title: title, message: text + "\n\n(Configura Telegram en el menú de Hirebar para responder \"si\" desde el celular.)")
        }
    }

    public static func tell(_ text: String) {
        if canUseTelegram {
            Telegram.shared.send(text, chatId: Config.load().chatId)
        } else {
            ntfy(title: "Hirebar", message: text)
        }
    }

    public static func sendFile(_ file: URL, caption: String) {
        guard canUseTelegram else {
            Log.write("Archivo listo sin canal para enviarlo: \(file.path)")
            return
        }
        Telegram.shared.sendDocument(file, caption: caption, chatId: Config.load().chatId)
    }

    public static func sendPhotos(_ files: [URL], caption: String, completion: @escaping () -> Void) {
        guard canUseTelegram, !files.isEmpty else {
            if !files.isEmpty { Log.write("Imágenes listas sin canal para enviarlas: \(files.first?.deletingLastPathComponent().path ?? "")") }
            completion()
            return
        }
        Telegram.shared.sendPhotos(files, caption: caption, chatId: Config.load().chatId, completion: completion)
    }

    public static func sendVideo(_ file: URL, caption: String, completion: @escaping () -> Void) {
        guard canUseTelegram else {
            Log.write("Video listo sin canal para enviarlo: \(file.path)")
            completion()
            return
        }
        Telegram.shared.sendVideo(file, caption: caption, chatId: Config.load().chatId, completion: completion)
    }

    public static func ntfy(title: String, message: String) {
        let topic = Config.load().ntfyTopic
        guard !topic.isEmpty, let url = URL(string: "https://ntfy.sh/") else {
            Log.write("Aviso sin canal (configura Telegram o ntfy): \(title)")
            return
        }
        let body: [String: Any] = ["topic": topic, "title": title,
                                   "message": String(message.prefix(3800)), "priority": 4, "tags": ["briefcase"]]
        DispatchQueue.global(qos: .utility).async { _ = Net.postJSON(url, body, timeout: 20) }
    }
}
