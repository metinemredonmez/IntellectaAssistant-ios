import AVFoundation
import Speech
import Combine
import Accelerate

enum SpeechAuthError: Error { case notAuthorized }

final class SpeechManager: NSObject, ObservableObject {
    @Published var partial: String = ""
    @Published var finalized: String = ""
    @Published var isRunning: Bool = false
    @Published var level: Float = 0          // 0...1 ses seviyesi

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))!
    private let audioEngine = AVAudioEngine()
    private var request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    // Otomatik durdurma için sessizlik takibi
    private var lastVoice = Date()
    private var silenceTimer: DispatchSourceTimer?
    private let silenceSec: TimeInterval = 1.2

    func start() async throws {
        // İzinler
        let auth = await withCheckedContinuation {
            (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard auth == .authorized else { throw SpeechAuthError.notAuthorized }

        // Audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true)

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        // Request
        request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        // Mikrofon tap + seviye ölçümü
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.request.append(buffer)

            // RMS seviye (0..1)
            if let ch = buffer.floatChannelData?.pointee {
                let n = vDSP_Length(buffer.frameLength)
                var ms: Float = 0
                vDSP_measqv(ch, 1, &ms, n)
                let rms = sqrtf(ms)
                let scaled = min(max(rms * 20, 0), 1)   // kaba ölçekleme
                DispatchQueue.main.async {
                    self.level = scaled
                    if scaled > 0.03 { self.lastVoice = Date() } // ses var say
                }
            }
        }

        // Başlat
        audioEngine.prepare()
        try audioEngine.start()
        DispatchQueue.main.async { self.isRunning = true }

        // Sessizlik zamanlayıcısı
        startSilenceTimer()

        // Tanıma
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let r = result {
                let txt = r.bestTranscription.formattedString
                if r.isFinal {
                    DispatchQueue.main.async {
                        self.finalized = txt
                        self.partial = ""
                        self.stop() // finalde otomatik kapat
                    }
                } else {
                    DispatchQueue.main.async {
                        self.partial = txt
                        self.lastVoice = Date()
                    }
                }
            }
            if error != nil { self.stop() }
        }
    }

    private func startSilenceTimer() {
        silenceTimer?.cancel()
        let t = DispatchSource.makeTimerSource()
        t.schedule(deadline: .now() + 0.5, repeating: 0.25)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            guard self.isRunning else { return }
            if Date().timeIntervalSince(self.lastVoice) >= self.silenceSec {
                // Uzun sessizlik: partial'ı finalize et ve dur
                DispatchQueue.main.async {
                    if !self.partial.isEmpty {
                        self.finalized = self.partial
                        self.partial = ""
                    }
                    self.stop()
                }
            }
        }
        silenceTimer = t
        t.resume()
    }

    func stop() {
        silenceTimer?.cancel(); silenceTimer = nil

        if !partial.isEmpty && finalized.isEmpty {
            finalized = partial
            partial = ""
        }
        task?.cancel(); task = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request.endAudio()

        DispatchQueue.main.async {
            self.isRunning = false
            self.level = 0
        }
    }
}
