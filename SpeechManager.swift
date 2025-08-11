import AVFoundation
import Speech
import Combine

enum SpeechAuthError: Error { case notAuthorized }

final class SpeechManager: NSObject, ObservableObject {
    @Published var partial: String = ""
    @Published var finalized: String = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))!
    private let audioEngine = AVAudioEngine()
    private var request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    func start() async throws {
        // Authorization (closure -> async bridge)
        let auth = await withCheckedContinuation {
            (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard auth == .authorized else { throw SpeechAuthError.notAuthorized }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                let txt = r.bestTranscription.formattedString
                if r.isFinal { self.finalized = txt; self.partial = "" }
                else { self.partial = txt }
            }
            if error != nil { self.stop() }
        }
    }

    func stop() {
        task?.cancel(); task = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request.endAudio()
    }
}
