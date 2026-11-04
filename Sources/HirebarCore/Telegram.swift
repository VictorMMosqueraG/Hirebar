import Foundation

public struct TelegramMessage: Sendable {
    public let chatId: Int64
    public let text: String
    public let replyTo: Int?
    public let callbackId: String?
}

public final class Telegram: @unchecked Sendable {
    public static let shared = Telegram()
    static let keychainAccount = "telegram-bot"
    static let offsetKey = "telegram.offset"

    public var onMessage: ((TelegramMessage) -> Void)?
    private var polling = false
    private let lock = NSLock()
    private var cachedToken: String?

    public var isConfigured: Bool { currentToken() != nil }

    private func currentToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cachedToken
    }

    public func reloadToken() {
        let value = Keychain.read(account: Self.keychainAccount)
        lock.lock()
        cachedToken = value
        lock.unlock()
    }

    @discardableResult
    public func saveToken(_ token: String) -> Bool {
        let ok = Keychain.save(token, account: Self.keychainAccount)
        UserDefaults.standard.set(0, forKey: Self.offsetKey)
        reloadToken()
        return ok
    }

    public func start() {
        reloadToken()
        guard !polling else { return }
        polling = true
        Thread.detachNewThread { [weak self] in self?.pollLoop() }
    }

    private func call(_ method: String, _ params: [String: Any], timeout: TimeInterval = 30) -> [String: Any]? {
        guard let token = currentToken(),
              let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)") else { return nil }
        return Net.postJSON(url, params, timeout: timeout)
    }

    private func pollLoop() {
        var offset = UserDefaults.standard.integer(forKey: Self.offsetKey)
        var lastToken = currentToken()
        while true {
            guard let token = currentToken() else {
                Thread.sleep(forTimeInterval: 15)
                continue
            }
            if token != lastToken {
                lastToken = token
                offset = 0
            }
            let params: [String: Any] = ["offset": offset, "timeout": 50, "allowed_updates": ["message", "callback_query"]]
            guard let json = call("getUpdates", params, timeout: 70), (json["ok"] as? Bool) == true,
                  let updates = json["result"] as? [[String: Any]] else {
                Thread.sleep(forTimeInterval: 15)
                continue
            }
            for update in updates {
                let updateId = (update["update_id"] as? NSNumber)?.intValue ?? 0
                offset = max(offset, updateId + 1)
                UserDefaults.standard.set(offset, forKey: Self.offsetKey)
                if let message = Self.parse(update) {
                    DispatchQueue.main.async { [weak self] in self?.onMessage?(message) }
                }
            }
        }
    }

    public static func parse(_ update: [String: Any]) -> TelegramMessage? {
        if let callback = update["callback_query"] as? [String: Any] {
            let message = callback["message"] as? [String: Any]
            let chat = (message?["chat"] as? [String: Any])?["id"] as? NSNumber
            return TelegramMessage(chatId: chat?.int64Value ?? 0,
                                   text: callback["data"] as? String ?? "",
                                   replyTo: (message?["message_id"] as? NSNumber)?.intValue,
                                   callbackId: callback["id"] as? String)
        }
        guard let message = update["message"] as? [String: Any],
              let text = message["text"] as? String,
              let chat = (message["chat"] as? [String: Any])?["id"] as? NSNumber else { return nil }
        let reply = (message["reply_to_message"] as? [String: Any])?["message_id"] as? NSNumber
        return TelegramMessage(chatId: chat.int64Value, text: text, replyTo: reply?.intValue, callbackId: nil)
    }

    public func send(_ text: String, chatId: Int64, buttons: [[(String, String)]] = [], completion: ((Int?) -> Void)? = nil) {
        var params: [String: Any] = ["chat_id": chatId, "text": String(text.prefix(4000)),
                                     "disable_web_page_preview": true]
        if !buttons.isEmpty {
            params["reply_markup"] = ["inline_keyboard": buttons.map { row in
                row.map { ["text": $0.0, "callback_data": $0.1] }
            }]
        }
        let payload = params
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = self?.call("sendMessage", payload)
            let id = ((result?["result"] as? [String: Any])?["message_id"] as? NSNumber)?.intValue
            if id == nil { Log.write("Telegram: no se pudo enviar (\(result?["description"] ?? "sin respuesta"))") }
            DispatchQueue.main.async { completion?(id) }
        }
    }

    public func answerCallback(_ id: String, text: String? = nil) {
        var params: [String: Any] = ["callback_query_id": id]
        if let text { params["text"] = text }
        let payload = params
        DispatchQueue.global(qos: .utility).async { [weak self] in _ = self?.call("answerCallbackQuery", payload) }
    }

    public func removeButtons(chatId: Int64, messageId: Int) {
        let params: [String: Any] = ["chat_id": chatId, "message_id": messageId,
                                     "reply_markup": ["inline_keyboard": [[String: String]]()]]
        DispatchQueue.global(qos: .utility).async { [weak self] in _ = self?.call("editMessageReplyMarkup", params) }
    }
}
