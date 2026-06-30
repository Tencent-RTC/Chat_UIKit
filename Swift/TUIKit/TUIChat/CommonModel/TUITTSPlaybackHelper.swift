import Foundation
import TIMCommon
import TUICore

/// Shared helper that turns text into speech and plays it back.
///
/// Pipeline: text -> selected voice id (resolved via TUICore from the
/// TextToVoice plugin, falls back to system default) -> `convertTextToVoice`
/// -> remote audio url -> `TUIAudioPlaybackManager`.
///
/// Each consumer (record translation, listen-from-here, ...) should hold its
/// own instance so playback state stays isolated, while the underlying
/// `TUIAudioPlaybackManager` still guarantees only one audio plays at a time.
public class TUITTSPlaybackHelper: NSObject {
    // MARK: - Types

    public typealias VoidHandler = () -> Void
    public typealias ErrorHandler = (String?) -> Void

    // MARK: - Public State

    /// True between a successful `speak` start and its finish/stop/failure.
    public private(set) var isSpeaking: Bool = false

    // MARK: - Private State

    private let playbackMsgID: String = "tui_tts_playback_\(UUID().uuidString)"
    private var onStartHandler: VoidHandler?
    private var onFinishHandler: VoidHandler?
    private var onStopHandler: VoidHandler?
    private var onErrorHandler: ErrorHandler?
    private var isConverting: Bool = false

    // MARK: - Service Keys

    private static let textToVoiceServiceName = "TUICore_TUITextToVoiceService"
    private static let getVoiceIdMethod = "TUICore_TUITextToVoiceService_GetEffectiveVoiceIdMethod"

    /// Error message used when the requested text is empty after trimming.
    public static let emptyTextErrorMessage = "TTS text is empty"

    // MARK: - Lifecycle

    public override init() {
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Convert `text` to speech with the selected voice and play it.
    /// - Parameters:
    ///   - text: Text to read aloud.
    ///   - conversationID: Optional conversation used to resolve a per-conversation voice.
    ///   - voiceId: Explicit voice id. When nil, the selected voice is resolved automatically.
    ///   - onStart: Called once playback actually starts.
    ///   - onFinish: Called when playback ends naturally.
    ///   - onError: Called when conversion fails or no audio is produced.
    public func speak(text: String,
                      conversationID: String? = nil,
                      voiceId: String? = nil,
                      onStart: VoidHandler? = nil,
                      onFinish: VoidHandler? = nil,
                      onError: ErrorHandler? = nil) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.speak(text: text,
                            conversationID: conversationID,
                            voiceId: voiceId,
                            onStart: onStart,
                            onFinish: onFinish,
                            onError: onError)
            }
            return
        }

        stop()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            onError?(TUITTSPlaybackHelper.emptyTextErrorMessage)
            return
        }

        onStartHandler = onStart
        onFinishHandler = onFinish
        onErrorHandler = onError
        isConverting = true

        let resolvedVoiceId = voiceId ?? TUITTSPlaybackHelper.resolveVoiceId(conversationID: conversationID)
        requestAudioURL(text: trimmed, voiceId: resolvedVoiceId)
    }

    /// Stop converting/playing immediately. Invokes the stop handler if active.
    public func stop() {
        let wasActive = isSpeaking || isConverting
        isConverting = false

        if TUIAudioPlaybackManager.shared.isPlaying(msgID: playbackMsgID) {
            TUIAudioPlaybackManager.shared.stopAudio(forMsgID: playbackMsgID)
        }

        isSpeaking = false
        if wasActive {
            onStopHandler?()
        }
        clearHandlers()
    }

    /// Register a handler invoked whenever playback is stopped by `stop()`.
    public func setStopHandler(_ handler: VoidHandler?) {
        onStopHandler = handler
    }

    // MARK: - Conversion

    private func requestAudioURL(text: String, voiceId: String) {
        let effectiveVoiceId = voiceId.isEmpty ? nil : voiceId
        TUIAIMediaProcessManager.shared.convertTextToVoice(text: text, voiceId: effectiveVoiceId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.isConverting else { return }
                self.isConverting = false
                switch result {
                case .success(let audioURL):
                    self.playRemoteAudio(urlString: audioURL)
                case .failure(let error):
                    self.handleFailure(message: error.message)
                }
            }
        }
    }

    private func playRemoteAudio(urlString: String) {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            handleFailure(message: nil)
            return
        }

        isSpeaking = true
        TUIAudioPlaybackManager.shared.playAudio(
            fromURL: url,
            msgID: playbackMsgID,
            stateCallback: { [weak self] playing in
                guard let self = self else { return }
                if playing {
                    self.onStartHandler?()
                }
            },
            finishCallback: { [weak self] in
                self?.handleNaturalFinish()
            }
        )
    }

    // MARK: - Completion

    private func handleNaturalFinish() {
        guard isSpeaking else { return }
        isSpeaking = false
        let finishHandler = onFinishHandler
        clearHandlers()
        finishHandler?()
    }

    private func handleFailure(message: String?) {
        isSpeaking = false
        isConverting = false
        let errorHandler = onErrorHandler
        clearHandlers()
        errorHandler?(message)
    }

    private func clearHandlers() {
        onStartHandler = nil
        onFinishHandler = nil
        onErrorHandler = nil
    }

    // MARK: - Voice Resolution

    /// Ask the TextToVoice plugin (if integrated) for the effective voice id.
    /// Returns an empty string when the plugin is absent (system default voice).
    private static func resolveVoiceId(conversationID: String?) -> String {
        var param: [String: Any] = [:]
        if let conversationID = conversationID, !conversationID.isEmpty {
            param["conversationID"] = conversationID
        }
        if let result = TUICore.callService(textToVoiceServiceName, method: getVoiceIdMethod, param: param) as? String {
            return result
        }
        return ""
    }
}
