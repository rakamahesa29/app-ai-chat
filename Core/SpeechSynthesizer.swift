@preconcurrency import AVFoundation
import Combine

/// Text-to-speech output using on-device AVSpeechSynthesizer.
/// Supports Indonesian (id-ID) with English (en-US) fallback.
@MainActor
final class SpeechSynthesizer: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    @Published var speakingMessageId: String? = nil

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speak text aloud. Stops any in-progress speech first.
    func speak(_ text: String, messageId: String, language: String = "id-ID") {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 1.0
        speakingMessageId = messageId
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
        speakingMessageId = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.speakingMessageId = nil
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.speakingMessageId = nil
        }
    }
}
