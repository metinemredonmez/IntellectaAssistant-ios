import Foundation
import Combine

@MainActor
final class ChatVM: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isListening = false
    @Published var partial: String = ""

    private let speech = SpeechManager()
    private let api = AnswerStreamer()
    private var cancellables: Set<AnyCancellable> = []

    init() {
        speech.$finalized
            .dropFirst()
            .sink { [weak self] t in self?.handleFinal(t) }
            .store(in: &cancellables)

        speech.$partial
            .receive(on: RunLoop.main)
            .sink { [weak self] t in self?.partial = t }
            .store(in: &cancellables)
    }

    // ChatVM.swift
    func toggle() {
        if isListening {
            speech.stop(); isListening = false
            // <-- partial'ı final gibi işle
            if !partial.isEmpty {
                let t = partial
                partial = ""
                handleFinal(t)
            }
        } else {
            Task { try? await speech.start(); isListening = true }
        }
    }


    func sendTyped(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        messages.append(.init(role: .user, text: t))
        Task { await ask(text: t) }
    }

    private func handleFinal(_ t: String) {
        guard !t.isEmpty else { return }
        messages.append(.init(role: .user, text: t))
        if isEnglishQuestion(t) { Task { await ask(text: t) } }
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
