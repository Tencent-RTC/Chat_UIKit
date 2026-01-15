import AVFoundation
import Foundation

// MARK: - Notification Names

public extension Notification.Name {
    /// Notification posted when any audio playback state changes
    /// userInfo: ["msgID": String, "isPlaying": Bool]
    static let TUIAudioPlaybackStateChanged = Notification.Name("TUIAudioPlaybackStateChanged")
    
    /// Notification posted when audio playback finishes
    /// userInfo: ["msgID": String]
    static let TUIAudioPlaybackFinished = Notification.Name("TUIAudioPlaybackFinished")
    
    /// Notification to stop all audio playback
    static let TUIStopAllAudioPlayback = Notification.Name("TUIStopAllAudioPlayback")
}

// MARK: - Audio Playback Style

/// Audio playback output style
@objc public enum TUIAudioPlaybackStyle: Int {
    case loudspeaker = 1
    case handset = 2
}

// MARK: - TUIAudioPlaybackManagerDelegate

/// Delegate protocol for audio playback events
@objc public protocol TUIAudioPlaybackManagerDelegate: AnyObject {
    /// Called when playback state changes
    @objc optional func audioPlaybackManager(_ manager: TUIAudioPlaybackManager, didChangePlayingState isPlaying: Bool, forMsgID msgID: String)
    
    /// Called when playback finishes
    @objc optional func audioPlaybackManager(_ manager: TUIAudioPlaybackManager, didFinishPlayingForMsgID msgID: String)
    
    /// Called when playback fails
    @objc optional func audioPlaybackManager(_ manager: TUIAudioPlaybackManager, didFailWithError error: Error?, forMsgID msgID: String)
}

// MARK: - TUIAudioPlaybackManager

/// Centralized audio playback manager for TUI components
/// Handles audio playback for voice messages, text-to-voice, and other audio content
@objcMembers
public class TUIAudioPlaybackManager: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = TUIAudioPlaybackManager()
    
    // MARK: - Properties
    
    /// Current playing message ID
    public private(set) var currentPlayingMsgID: String?
    
    /// Audio player instance
    private var audioPlayer: AVAudioPlayer?
    
    /// State callbacks for each message
    private var stateCallbacks: [String: (Bool) -> Void] = [:]
    
    /// Finish callbacks for each message
    private var finishCallbacks: [String: () -> Void] = [:]
    
    /// Weak delegate references
    private var delegates = NSHashTable<AnyObject>.weakObjects()
    
    /// Lock for thread safety
    private let lock = NSLock()
    
    /// Timer for progress updates
    private var progressTimer: Timer?
    
    /// Current playback style (loudspeaker or handset)
    private var currentPlaybackStyle: TUIAudioPlaybackStyle = .loudspeaker
    
    /// UserDefaults key for playback style
    private static let playbackStyleKey = "tui_audioPlaybackStyle"
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        // Listen for stop all audio notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onStopAllAudioPlayback),
            name: .TUIStopAllAudioPlayback,
            object: nil
        )
        
        // Listen for audio interruption (e.g., phone call)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    // MARK: - Delegate Management
    
    /// Add a delegate to receive playback events
    public func addDelegate(_ delegate: TUIAudioPlaybackManagerDelegate) {
        lock.lock()
        defer { lock.unlock() }
        
        if !delegates.contains(delegate) {
            delegates.add(delegate)
        }
    }
    
    /// Remove a delegate
    public func removeDelegate(_ delegate: TUIAudioPlaybackManagerDelegate) {
        lock.lock()
        defer { lock.unlock() }
        
        delegates.remove(delegate)
    }
    
    // MARK: - Playback Style
    
    /// Get current audio playback style
    public static func getAudioPlaybackStyle() -> TUIAudioPlaybackStyle {
        let style = UserDefaults.standard.string(forKey: playbackStyleKey)
        if style == "1" {
            return .loudspeaker
        } else if style == "2" {
            return .handset
        }
        return .loudspeaker
    }
    
    /// Toggle audio playback style between loudspeaker and handset
    public static func toggleAudioPlaybackStyle() {
        let style = getAudioPlaybackStyle()
        if style == .loudspeaker {
            UserDefaults.standard.set("2", forKey: playbackStyleKey)
        } else {
            UserDefaults.standard.set("1", forKey: playbackStyleKey)
        }
        UserDefaults.standard.synchronize()
    }
    
    /// Set audio playback style
    public static func setAudioPlaybackStyle(_ style: TUIAudioPlaybackStyle) {
        UserDefaults.standard.set(String(style.rawValue), forKey: playbackStyleKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Playback Control
    
    /// Play audio from local file path
    /// - Parameters:
    ///   - path: Local file path
    ///   - msgID: Message ID for tracking
    ///   - stateCallback: Callback for playback state changes (true = playing, false = stopped)
    ///   - finishCallback: Callback when playback finishes naturally
    public func playAudio(fromPath path: String, msgID: String, stateCallback: ((Bool) -> Void)? = nil, finishCallback: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.playAudioInternal(fromPath: path, msgID: msgID, stateCallback: stateCallback, finishCallback: finishCallback)
        }
    }
    
    private func playAudioInternal(fromPath path: String, msgID: String, stateCallback: ((Bool) -> Void)?, finishCallback: (() -> Void)?) {
        // Stop current playing audio
        stopCurrentAudio()
        
        currentPlayingMsgID = msgID
        
        // Notify to stop other audio players
        NotificationCenter.default.post(name: .TUIStopAllAudioPlayback, object: self)
        
        // Store callbacks
        if let callback = stateCallback {
            stateCallbacks[msgID] = callback
        }
        if let callback = finishCallback {
            finishCallbacks[msgID] = callback
        }
        
        // Play local file
        let url = URL(fileURLWithPath: path)
        do {
            try configureAudioSession()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            let success = audioPlayer?.play() ?? false
            
            if success {
                // Start progress timer
                startProgressTimer()
                
                // Notify playing started
                notifyPlaybackStateChanged(msgID: msgID, isPlaying: true)
                stateCallback?(true)
            } else {
                print("[TUIAudioPlaybackManager] Failed to start playback")
                notifyPlaybackFailed(msgID: msgID, error: nil)
                stateCallback?(false)
                currentPlayingMsgID = nil
            }
        } catch {
            print("[TUIAudioPlaybackManager] Failed to play audio: \(error)")
            notifyPlaybackFailed(msgID: msgID, error: error)
            stateCallback?(false)
            currentPlayingMsgID = nil
        }
    }
    
    /// Play audio from Data
    /// - Parameters:
    ///   - data: Audio data
    ///   - msgID: Message ID for tracking
    ///   - stateCallback: Callback for playback state changes
    ///   - finishCallback: Callback when playback finishes naturally
    public func playAudio(fromData data: Data, msgID: String, stateCallback: ((Bool) -> Void)? = nil, finishCallback: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.playAudioDataInternal(data, msgID: msgID, stateCallback: stateCallback, finishCallback: finishCallback)
        }
    }
    
    private func playAudioDataInternal(_ data: Data, msgID: String, stateCallback: ((Bool) -> Void)?, finishCallback: (() -> Void)?) {
        // Stop current playing audio
        stopCurrentAudio()
        
        // Set current playing message ID BEFORE sending notification
        // This ensures other listeners can correctly identify the new playing message
        currentPlayingMsgID = msgID
        
        // Notify to stop other audio players
        NotificationCenter.default.post(name: .TUIStopAllAudioPlayback, object: self)
        
        // Store callbacks
        if let callback = stateCallback {
            stateCallbacks[msgID] = callback
        }
        if let callback = finishCallback {
            finishCallbacks[msgID] = callback
        }
        
        do {
            try configureAudioSession()
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            let success = audioPlayer?.play() ?? false
            
            if success {
                // Start progress timer
                startProgressTimer()
                
                // Notify playing started
                notifyPlaybackStateChanged(msgID: msgID, isPlaying: true)
                stateCallback?(true)
            } else {
                print("[TUIAudioPlaybackManager] Failed to start playback from data")
                notifyPlaybackFailed(msgID: msgID, error: nil)
                stateCallback?(false)
                currentPlayingMsgID = nil
            }
        } catch {
            print("[TUIAudioPlaybackManager] Failed to play audio data: \(error)")
            notifyPlaybackFailed(msgID: msgID, error: error)
            stateCallback?(false)
            currentPlayingMsgID = nil
        }
    }
    
    /// Play audio from URL (downloads first)
    /// - Parameters:
    ///   - url: Remote URL
    ///   - msgID: Message ID for tracking
    ///   - stateCallback: Callback for playback state changes
    public func playAudio(fromURL url: URL, msgID: String, stateCallback: ((Bool) -> Void)? = nil) {
        // Stop current playing audio
        stopCurrentAudio()
        
        // Set current playing message ID BEFORE sending notification
        currentPlayingMsgID = msgID
        
        // Notify to stop other audio players
        NotificationCenter.default.post(name: .TUIStopAllAudioPlayback, object: self)
        
        // Store callback
        if let callback = stateCallback {
            stateCallbacks[msgID] = callback
        }
        
        // Notify playing started (loading)
        notifyPlaybackStateChanged(msgID: msgID, isPlaying: true)
        stateCallback?(true)
        
        // Download and play
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Check if still the same message
                guard self.currentPlayingMsgID == msgID else { return }
                
                guard let data = data, error == nil else {
                    print("[TUIAudioPlaybackManager] Download failed: \(error?.localizedDescription ?? "unknown")")
                    self.notifyPlaybackFailed(msgID: msgID, error: error)
                    self.stateCallbacks[msgID]?(false)
                    self.currentPlayingMsgID = nil
                    return
                }
                
                self.playAudioDataInternal(data, msgID: msgID, stateCallback: self.stateCallbacks[msgID], finishCallback: self.finishCallbacks[msgID])
            }
        }
        task.resume()
    }
    
    /// Stop current audio playback
    public func stopCurrentAudio() {
        let stoppedMsgID = currentPlayingMsgID
        
        // Stop timer
        stopProgressTimer()
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        if let msgID = stoppedMsgID {
            stateCallbacks[msgID]?(false)
            notifyPlaybackStateChanged(msgID: msgID, isPlaying: false)
        }
        
        currentPlayingMsgID = nil
    }
    
    /// Stop audio for specific message ID
    public func stopAudio(forMsgID msgID: String) {
        guard currentPlayingMsgID == msgID else { return }
        stopCurrentAudio()
    }
    
    // MARK: - State Query
    
    /// Check if specific message is currently playing
    public func isPlaying(msgID: String) -> Bool {
        return currentPlayingMsgID == msgID && (audioPlayer?.isPlaying ?? false)
    }
    
    /// Check if any audio is currently playing
    public var isAnyAudioPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    /// Get current playback progress (0.0 - 1.0)
    public var currentProgress: Double {
        guard let player = audioPlayer, player.duration > 0 else { return 0 }
        return player.currentTime / player.duration
    }
    
    /// Get current playback time in seconds
    public var currentTime: TimeInterval {
        return audioPlayer?.currentTime ?? 0
    }
    
    /// Get total duration in seconds
    public var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        let style = TUIAudioPlaybackManager.getAudioPlaybackStyle()
        currentPlaybackStyle = style
        
        if style == .handset {
            try session.setCategory(.playAndRecord, mode: .default)
        } else {
            try session.setCategory(.playback, mode: .default)
        }
        try session.setActive(true)
    }
    
    // MARK: - Progress Timer
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.notifyProgressUpdate()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func notifyProgressUpdate() {
        guard let msgID = currentPlayingMsgID else { return }
        let time = audioPlayer?.currentTime ?? 0
        
        // Post notification for progress update
        NotificationCenter.default.post(
            name: Notification.Name("TUIAudioPlaybackProgressChanged"),
            object: self,
            userInfo: ["msgID": msgID, "currentTime": time]
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc private func onStopAllAudioPlayback(_ notification: Notification) {
        // Don't stop if we sent the notification
        guard notification.object as? TUIAudioPlaybackManager !== self else { return }
        stopCurrentAudio()
    }
    
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio was interrupted (e.g., phone call)
            stopCurrentAudio()
        case .ended:
            // Interruption ended, could resume if needed
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Notification Helpers
    
    private func notifyPlaybackStateChanged(msgID: String, isPlaying: Bool) {
        print("[TUIAudioPlaybackManager] notifyPlaybackStateChanged - msgID: \(msgID), isPlaying: \(isPlaying)")
        
        // Post notification
        NotificationCenter.default.post(
            name: .TUIAudioPlaybackStateChanged,
            object: self,
            userInfo: ["msgID": msgID, "isPlaying": isPlaying]
        )
        
        // Notify delegates
        for delegate in delegates.allObjects {
            if let delegate = delegate as? TUIAudioPlaybackManagerDelegate {
                delegate.audioPlaybackManager?(self, didChangePlayingState: isPlaying, forMsgID: msgID)
            }
        }
    }
    
    private func notifyPlaybackFinished(msgID: String) {
        print("[TUIAudioPlaybackManager] notifyPlaybackFinished - msgID: \(msgID)")
        
        // Post notification
        NotificationCenter.default.post(
            name: .TUIAudioPlaybackFinished,
            object: self,
            userInfo: ["msgID": msgID]
        )
        
        // Notify delegates
        for delegate in delegates.allObjects {
            if let delegate = delegate as? TUIAudioPlaybackManagerDelegate {
                delegate.audioPlaybackManager?(self, didFinishPlayingForMsgID: msgID)
            }
        }
    }
    
    private func notifyPlaybackFailed(msgID: String, error: Error?) {
        print("[TUIAudioPlaybackManager] notifyPlaybackFailed - msgID: \(msgID), error: \(error?.localizedDescription ?? "nil")")
        
        // Notify delegates
        for delegate in delegates.allObjects {
            if let delegate = delegate as? TUIAudioPlaybackManagerDelegate {
                delegate.audioPlaybackManager?(self, didFailWithError: error, forMsgID: msgID)
            }
        }
        
        // Also notify state changed to false
        notifyPlaybackStateChanged(msgID: msgID, isPlaying: false)
    }
}

// MARK: - AVAudioPlayerDelegate

extension TUIAudioPlaybackManager: AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedMsgID = currentPlayingMsgID
        
        // Stop timer
        stopProgressTimer()
        
        // Call state callback
        if let msgID = currentPlayingMsgID, let callback = stateCallbacks[msgID] {
            callback(false)
        }
        
        // Call finish callback
        if let msgID = currentPlayingMsgID, let callback = finishCallbacks[msgID] {
            callback()
            finishCallbacks.removeValue(forKey: msgID)
        }
        
        currentPlayingMsgID = nil
        
        // Notify UI
        if let msgID = finishedMsgID {
            notifyPlaybackStateChanged(msgID: msgID, isPlaying: false)
            notifyPlaybackFinished(msgID: msgID)
        }
    }
    
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let failedMsgID = currentPlayingMsgID
        
        // Stop timer
        stopProgressTimer()
        
        if let msgID = currentPlayingMsgID {
            stateCallbacks[msgID]?(false)
            finishCallbacks.removeValue(forKey: msgID)
        }
        currentPlayingMsgID = nil
        
        if let msgID = failedMsgID {
            notifyPlaybackFailed(msgID: msgID, error: error)
        }
    }
}
