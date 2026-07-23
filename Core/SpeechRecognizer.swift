import Foundation
import Combine
import Speech
import AVFoundation

/// On-device speech-to-text using Apple's Speech framework.
/// Supports Indonesian (id-ID) with English (en-US) fallback.
/// All speech recognition resources are lazily created only when the user taps the mic.
@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var recognizedText = ""
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var errorMessage: String? = nil
    
    private var speechRecognizer: SFSpeechRecognizer? = nil
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var silenceTimer: DispatchWorkItem?
    
    var isAvailable: Bool {
        if speechRecognizer != nil { return true }
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "id-ID"))
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.defaultTaskHint = .dictation
        return speechRecognizer != nil
    }
    
    func requestAuthorization() async {
        guard isAvailable else {
            errorMessage = "Speech recognition not available on this device."
            return
        }
        
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        var micGranted = false
        switch micStatus {
        case .authorized:          micGranted = true
        case .notDetermined:       micGranted = await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .audio) { ok in cont.resume(returning: ok) }
            }
        default:                   micGranted = false
        }
        
        isAuthorized = (speechStatus == .authorized) && micGranted
        
        if !isAuthorized {
            if speechStatus != .authorized {
                errorMessage = "Speech recognition not authorized. Enable in System Settings → Privacy → Speech Recognition."
            } else if !micGranted {
                errorMessage = "Microphone access denied. Enable in System Settings → Privacy → Microphone."
            }
        }
    }
    
    func startRecording() {
        guard isAvailable, let recognizer = speechRecognizer else {
            errorMessage = "Speech recognition not available on this device."
            return
        }
        guard isAuthorized else {
            errorMessage = "Speech recognition not authorized."
            return
        }
        
        stopRecording()
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            return
        }
        #endif
        
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        let inputNode = engine.inputNode
        
        guard inputNode.numberOfInputs > 0 else {
            errorMessage = "No microphone detected. Connect a microphone and try again."
            return
        }
        
        let recordingFormat = inputNode.inputFormat(forBus: 0)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        if #available(macOS 13, iOS 16, *) {
            recognitionRequest.addsPunctuation = true
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        engine.prepare()
        do {
            try engine.start()
        } catch {
            errorMessage = "Audio engine start failed: \(error.localizedDescription)"
            return
        }
        
        isRecording = true
        recognizedText = ""
        errorMessage = nil
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            // SFSpeechRecognitionTask callback runs on background queue — hop to MainActor
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.recognizedText = result.bestTranscription.formattedString
                    self.resetSilenceTimer()
                }
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
        
        resetSilenceTimer()
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.stopRecording()
        }
        silenceTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }
    
    func stopRecording() {
        silenceTimer?.cancel()
        silenceTimer = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
        isRecording = false
        
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }
}
