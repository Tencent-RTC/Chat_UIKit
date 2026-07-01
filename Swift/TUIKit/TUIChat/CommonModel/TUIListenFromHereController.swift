import AVFoundation
import Foundation
import TIMCommon

/// Drives sequential "listen from here" playback over a prebuilt plan.
///
/// Text items are read via `TUITTSPlaybackHelper`; voice items read their
/// sender prefix with TTS and then play the original audio. Playback stops
/// (no looping) after the last item.
public final class TUIListenFromHereController: NSObject {
    // MARK: - Callbacks

    /// Invoked once when playback is requested, before any audio starts.
    public var onPreparing: (() -> Void)?
    /// Invoked once when the very first audio actually starts playing.
    public var onPlaybackStarted: (() -> Void)?
    /// Invoked at the start of each item with its display text.
    public var onItemChanged: ((String) -> Void)?
    /// Invoked when the whole queue finishes (or is empty).
    public var onFinished: (() -> Void)?

    // MARK: - State

    private let items: [TUIListenItem]
    private let conversationID: String?
    private let ttsPlaybackHelper = TUITTSPlaybackHelper()

    private var currentIndex: Int = 0
    private var isStopped: Bool = false
    private var hasStartedFirstPlayback: Bool = false
    private weak var currentVoiceData: TUIVoiceMessageCellData?

    // MARK: - Lifecycle

    public init(items: [TUIListenItem], conversationID: String?) {
        self.items = items
        self.conversationID = conversationID
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Control

    public func start() {
        guard !items.isEmpty else {
            onFinished?()
            return
        }
        isStopped = false
        currentIndex = 0
        hasStartedFirstPlayback = false
        registerInterruptionObserver()
        onPreparing?()
        playCurrent()
    }

    public func stop() {
        isStopped = true
        removeInterruptionObserver()
        ttsPlaybackHelper.stop()
        if let voiceData = currentVoiceData {
            voiceData.audioPlayerDidFinishPlayingBlock = nil
            voiceData.stopVoiceMessage()
        }
        currentVoiceData = nil
    }

    // MARK: - Interruption

    private func registerInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRecordingDidStart),
            name: .TUIAudioRecordingDidStart,
            object: nil
        )
    }

    private func removeInterruptionObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.removeObserver(
            self,
            name: .TUIAudioRecordingDidStart,
            object: nil
        )
    }

    @objc private func handleRecordingDidStart() {
        DispatchQueue.main.async { [weak self] in
            self?.endSessionExternally()
        }
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType),
              type == .began else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.endSessionExternally()
        }
    }

    private func endSessionExternally() {
        guard !isStopped else { return }
        stop()
        onFinished?()
    }

    // MARK: - Playback

    private func playCurrent() {
        guard !isStopped else { return }
        guard currentIndex < items.count else {
            finishAll()
            return
        }

        let item = items[currentIndex]
        onItemChanged?(item.displayText)

        switch item.kind {
        case let .tts(text):
            speakText(text)
        case let .voice(prefix, voiceData):
            playVoice(prefix: prefix, voiceData: voiceData)
        }
    }

    private func speakText(_ text: String) {
        ttsPlaybackHelper.speak(
            text: text,
            conversationID: conversationID,
            onStart: { [weak self] in self?.markFirstPlaybackStarted() },
            onFinish: { [weak self] in self?.advance() },
            onError: { [weak self] _ in self?.advance() }
        )
    }

    private func playVoice(prefix: String, voiceData: TUIVoiceMessageCellData) {
        currentVoiceData = voiceData
        voiceData.audioPlayerDidFinishPlayingBlock = { [weak self, weak voiceData] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard self.currentVoiceData === voiceData else { return }
                self.currentVoiceData = nil
                guard !self.isStopped else { return }
                self.advance()
            }
        }

        if prefix.isEmpty {
            markFirstPlaybackStarted()
            voiceData.playVoiceMessage()
            return
        }

        ttsPlaybackHelper.speak(
            text: prefix,
            conversationID: conversationID,
            onStart: { [weak self] in self?.markFirstPlaybackStarted() },
            onFinish: { [weak self] in self?.startVoiceAudioOnMain() },
            onError: { [weak self] _ in self?.startVoiceAudioOnMain() }
        )
    }

    private func startVoiceAudioOnMain() {
        if Thread.isMainThread {
            startVoiceAudio()
        } else {
            DispatchQueue.main.async { [weak self] in self?.startVoiceAudio() }
        }
    }

    private func startVoiceAudio() {
        guard !isStopped, let voiceData = currentVoiceData else { return }
        voiceData.playVoiceMessage()
    }

    private func advance() {
        guard !isStopped else { return }
        currentIndex += 1
        playCurrent()
    }

    private func markFirstPlaybackStarted() {
        guard !hasStartedFirstPlayback else { return }
        hasStartedFirstPlayback = true
        onPlaybackStarted?()
    }

    private func finishAll() {
        guard !isStopped else { return }
        isStopped = true
        onFinished?()
    }
}
