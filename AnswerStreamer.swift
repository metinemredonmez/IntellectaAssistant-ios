// AnswerStreamer.swift
import Foundation

// Server'ın beklediği alanlar:
// force_english_question, min_chars, require_dev_keyword
struct AskBody: Encodable {
    let text: String
    let forceEnglishQuestion: Bool = true   // 204'i önlemek için true
    let minChars: Int = 0                   // minimum karakter filtresi kapalı
    let requireDevKeyword: Bool = false     // anahtar kelime filtresi kapalı
}

actor AnswerStreamer {
    func streamAnswer(text: String) async throws -> AsyncThrowingStream<String, Error> {
        var req = URLRequest(url: Config.baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(Config.bearer)", forHTTPHeaderField: "Authorization")

        // server api.py snake_case bekliyor → otomatik çevir
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try enc.encode(AskBody(text: text))

        // iOS tarafında hafif uzun time-out
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 60
        let session = URLSession(configuration: cfg)

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard http.statusCode == 200 else {
            throw NSError(
                domain: "api",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
        }

        return AsyncThrowingStream { cont in
            Task {
                do {
                    for try await line in bytes.lines {
                        cont.yield(line)
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
        }
    }
}
