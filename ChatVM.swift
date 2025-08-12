import Foundation
import Combine

@MainActor
final class ChatVM: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isListening = false
    @Published var partial: String = ""
    @Published var level: Float = 0

    private let speech = SpeechManager()
    private let api = AnswerStreamer()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Final cümle geldi
        speech.$finalized
            .dropFirst()
            .sink { [weak self] t in self?.handleFinal(t) }
            .store(in: &cancellables)

        // Partial
        speech.$partial
            .receive(on: RunLoop.main)
            .sink { [weak self] t in self?.partial = t }
            .store(in: &cancellables)

        // Ses seviyesi
        speech.$level
            .receive(on: RunLoop.main)
            .assign(to: &$level)

        // Dinleme durumu → buton
        speech.$isRunning
            .receive(on: RunLoop.main)
            .assign(to: &$isListening)
    }

    func toggle() {
        if isListening {
            // sadece durdur; finalize işini SpeechManager yapar
            speech.stop()
        } else {
            Task { try? await speech.start() }
        }
    }

    func sendTyped(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        messages.append(.init(role: .user, text: t))
        Task { await ask(text: t) }
    }

    private func handleFinal(_ t: String) {
        let txt = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !txt.isEmpty else { return }
        messages.append(.init(role: .user, text: txt))
        // her finalized metin backend'e gider
        Task { await ask(text: txt) }
    }

    private func appendAssistantPlaceholder() -> Int {
        messages.append(.init(role: .assistant, text: ""))
        return messages.count - 1
    }

    private func updateAssistant(_ idx: Int, append chunk: String) {
        guard messages.indices.contains(idx) else { return }
        messages[idx].text += chunk
        objectWillChange.send()
    }

    private func ask(text: String) async {
        let idx = appendAssistantPlaceholder()
        do {
            let stream = try await api.streamAnswer(text: text)
            for try await chunk in stream { updateAssistant(idx, append: chunk) }
        } catch {
            messages[idx].text = "(error: \(error.localizedDescription))"
        }
    }
}
