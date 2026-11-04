import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class DataBox: @unchecked Sendable {
    public var value: Data?
    public init() {}
}

public enum Net {
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"

    public static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("es-CO,es;q=0.9", forHTTPHeaderField: "Accept-Language")
        return await withCheckedContinuation { continuation in
            URLSession.shared.dataTask(with: request) { data, response, _ in
                let ok = (response as? HTTPURLResponse)?.statusCode == 200
                continuation.resume(returning: ok ? data : nil)
            }.resume()
        }
    }

    public static func fetchText(_ address: String) async -> String? {
        guard let url = URL(string: address), let data = await fetch(url) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public static func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    public static func postJSON(_ url: URL, _ body: [String: Any], timeout: TimeInterval = 30) -> [String: Any]? {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let box = DataBox()
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            box.value = data
            done.signal()
        }.resume()
        done.wait()
        guard let data = box.value else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
