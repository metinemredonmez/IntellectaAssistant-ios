// AnswerStreamer.swift
import Foundation

struct AskBody: Encodable { let text: String }

actor AnswerStreamer {
    func streamAnswer(text: String) async throws -> AsyncThrowingStream<String, Error> {
        var req = URLRequest(url: Config.baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(Config.bearer)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(AskBody(text: text))

        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        cfg.timeoutIntervalForResource = 15
        let session = URLSession(configuration: cfg)

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            throw NSError(domain: "api", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }

        return AsyncThrowingStream { cont in
            Task {
                do {
                    for try await line in bytes.lines { cont.yield(line) }
                    cont.finish()
                } catch { cont.finish(throwing: error) }
            }
        }
    }
}
