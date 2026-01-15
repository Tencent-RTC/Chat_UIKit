import AVFoundation
import Foundation
import TIMCommon
import TUIChat
import TUICore

/// Service for automatic text-to-voice message features:
/// - Auto text-to-voice conversion for incoming text messages
/// - Auto play queue management for TTS messages
///
/// Architecture:
/// - This service manages the auto-play queue and conversion triggers
/// - TUIAudioPlaybackManager handles actual audio playback (centralized)
/// - TUITextToVoiceDataProvider handles TTS data management
/// - TUITextToVoiceView is a pure UI component that listens to playback notifications
public class TUITextToVoiceAutoService: NSObject, V2TIMAdvancedMsgListener {
    
    // MARK: - Singleton
    
    public static let shared = TUITextToVoiceAutoService()
    
    // MARK: - Properties
    
    /// Current conversation ID
    private var currentConversationID: String?
    
    /// Auto play queue (ordered by timestamp)
    private var autoPlayQueue: [V2TIMMessage] = []
    
    /// Whether auto play is in progress
    private var isAutoPlaying: Bool = false
    
    /// Current playing message ID
    private var currentPlayingMsgID: String?
    
    /// Messages pending TTS conversion (will be added to queue after conversion)
    private var pendingTTSMessages: Set<String> = []
    
    /// Retry count for TTS conversion (msgID -> retryCount)
    private var ttsRetryCount: [String: Int] = [:]
    
    /// Maximum retry attempts for TTS conversion
    private let maxTTSRetryCount = 3
    
    /// Base retry delay in seconds (will be multiplied by 2^retryCount for exponential backoff)
    private let baseRetryDelay: TimeInterval = 1.0
    
    // MARK: - Config Accessors
    
    private var isAutoTextToVoiceEnabled: Bool {
        return TUITextToVoiceConfig.shared.autoTextToVoiceEnabled
    }
    
    /// Check if auto text-to-voice is enabled for current conversation
    /// Priority: Conversation setting > Global setting
    private func isAutoTextToVoiceEnabledForCurrentConversation() -> Bool {
        guard let conversationID = currentConversationID, !conversationID.isEmpty else {
            return isAutoTextToVoiceEnabled
        }
        return TUITextToVoiceConversationConfig.shared.shouldEnable(
            for: conversationID,
            type: .autoTextToVoice,
            globalEnabled: isAutoTextToVoiceEnabled
        )
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        registerListeners()
    }
    
    private func registerListeners() {
        V2TIMManager.sharedInstance().addAdvancedMsgListener(listener: self)
        
        // Conversation lifecycle
        TUICore.registerEvent("TUICore_TUIChatNotify", subKey: "TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey", object: self)
        TUICore.registerEvent("TUICore_TUIChatNotify", subKey: "TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey", object: self)
        TUICore.registerEvent("TUICore_TUIChatNotify", subKey: "TUICore_TUIChatNotify_ChatVC_ViewWillDisappearSubKey", object: self)
        
        // TTS playback finished - trigger next in queue
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onTTSPlaybackFinished(_:)),
            name: NSNotification.Name("TUITextToVoicePlaybackFinished"),
            object: nil
        )
        
        // Audio playback finished (from TUIAudioPlaybackManager)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onAudioPlaybackFinished(_:)),
            name: .TUIAudioPlaybackFinished,
            object: nil
        )
    }
    
    deinit {
        V2TIMManager.sharedInstance().removeAdvancedMsgListener(listener: self)
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - V2TIMAdvancedMsgListener
    
    public func onRecvNewMessage(msg: V2TIMMessage) {
        guard !msg.isSelf else { return }
        
        // Only process messages for current conversation
        guard let currentConvID = currentConversationID,
              isMessageInConversation(msg, conversationID: currentConvID)
        else { return }
        
        // Auto text-to-voice conversion (use conversation-level setting)
        if isAutoTextToVoiceEnabledForCurrentConversation(), msg.elemType == .ELEM_TYPE_TEXT {
            startAutoTextToVoice(msg)
            
            // Mark as pending for auto play
            if let msgID = msg.msgID {
                pendingTTSMessages.insert(msgID)
            }
        }
    }
    
    /// Check if message belongs to the specified conversation
    private func isMessageInConversation(_ message: V2TIMMessage, conversationID: String) -> Bool {
        // conversationID format: "c2c_userID" for C2C, "group_groupID" for group
        if conversationID.hasPrefix("c2c_") {
            let userID = String(conversationID.dropFirst(4))
            return message.userID == userID
        } else if conversationID.hasPrefix("group_") {
            let groupID = String(conversationID.dropFirst(6))
            return message.groupID == groupID
        }
        return false
    }
    
    // MARK: - Auto Text-to-Voice Conversion
    
    private func startAutoTextToVoice(_ message: V2TIMMessage) {
        guard let textElem = message.textElem,
              let text = textElem.text,
              !text.isEmpty,
              TUITextToVoiceDataProvider.getTextToVoiceStatus(message) == .hidden
        else { return }
        
        TUITextToVoiceDataProvider.setLoadingStatus(message)
        notifyMessageChanged(message)
        
        // Convert emoji tags to localizable display text (e.g., [TUIEmoji_Haha] -> [哈哈哈])
        // Then remove brackets to avoid TTS reading them
        let displayText = text.getLocalizableStringWithFaceContent()
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        performTTSConversion(message: message, text: displayText)
    }
    
    private func performTTSConversion(message: V2TIMMessage, text: String) {
        guard let msgID = message.msgID else { return }
        
        // Get effective voice ID for current conversation
        let voiceId = TUITextToVoiceDataProvider.getEffectiveVoiceId(for: currentConversationID)
        
        TUITextToVoiceDataProvider.convertTextToVoice(text: text, voiceId: voiceId) { [weak self] code, desc, audioUrl in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard self.isAutoTextToVoiceEnabledForCurrentConversation() else {
                    TUITextToVoiceDataProvider.clearTextToVoice(message)
                    self.notifyMessageChanged(message)
                    self.ttsRetryCount.removeValue(forKey: msgID)
                    return
                }
                
                if code == 0, let audioUrl = audioUrl, !audioUrl.isEmpty {
                    TUITextToVoiceDataProvider.fetchAudioDuration(from: audioUrl) { duration in
                        if duration > 0 {
                            TUITextToVoiceDataProvider.saveTextToVoiceUrl(message, url: audioUrl, duration: duration)
                            self.notifyMessageChanged(message)
                            self.ttsRetryCount.removeValue(forKey: msgID)
                            
                            // Check if should auto play
                            if self.pendingTTSMessages.remove(msgID) != nil {
                                self.addToAutoPlayQueue(message)
                            }
                        } else {
                            // Failed to fetch duration, retry with backoff
                            print("[TUITextToVoiceAutoService] fetchAudioDuration failed for url: \(audioUrl)")
                            self.handleTTSConversionFailure(message: message, text: text)
                        }
                    }
                } else {
                    print("[TUITextToVoiceAutoService] convertTextToVoice failed: code=\(code), desc=\(desc ?? "nil")")
                    
                    // For text too long error (6017), don't retry
                    if code == 6017 {
                        TUITextToVoiceDataProvider.setFailedStatus(message)
                        self.notifyMessageChanged(message)
                        self.ttsRetryCount.removeValue(forKey: msgID)
                    } else {
                        self.handleTTSConversionFailure(message: message, text: text)
                    }
                }
            }
        }
    }
    
    private func handleTTSConversionFailure(message: V2TIMMessage, text: String) {
        guard let msgID = message.msgID else {
            TUITextToVoiceDataProvider.clearTextToVoice(message)
            notifyMessageChanged(message)
            return
        }
        
        let currentRetry = ttsRetryCount[msgID] ?? 0
        
        if currentRetry < maxTTSRetryCount {
            // Schedule retry with exponential backoff
            let delay = baseRetryDelay * pow(2.0, Double(currentRetry))
            ttsRetryCount[msgID] = currentRetry + 1
            
            print("[TUITextToVoiceAutoService] Scheduling TTS retry \(currentRetry + 1)/\(maxTTSRetryCount) after \(delay)s for msgID: \(msgID)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self,
                      self.isAutoTextToVoiceEnabledForCurrentConversation(),
                      TUITextToVoiceDataProvider.getTextToVoiceStatus(message) == .loading
                else {
                    self?.ttsRetryCount.removeValue(forKey: msgID)
                    return
                }
                
                self.performTTSConversion(message: message, text: text)
            }
        } else {
            // Max retries reached, give up silently (no Toast for auto events)
            print("[TUITextToVoiceAutoService] TTS conversion failed after \(maxTTSRetryCount) retries for msgID: \(msgID)")
            TUITextToVoiceDataProvider.clearTextToVoice(message)
            notifyMessageChanged(message)
            ttsRetryCount.removeValue(forKey: msgID)
            pendingTTSMessages.remove(msgID)
        }
    }
    
    // MARK: - Auto Play Queue Management
    
    private func addToAutoPlayQueue(_ message: V2TIMMessage) {
        guard isAutoTextToVoiceEnabledForCurrentConversation(),
              let msgID = message.msgID,
              !autoPlayQueue.contains(where: { $0.msgID == msgID }),
              !isMessagePlayed(message)
        else {
            print("[TUITextToVoiceAutoService] addToAutoPlayQueue skipped - msgID: \(message.msgID ?? "nil"), isEnabled: \(isAutoTextToVoiceEnabledForCurrentConversation()), alreadyInQueue: \(autoPlayQueue.contains(where: { $0.msgID == message.msgID })), isPlayed: \(isMessagePlayed(message))")
            return
        }
        
        // Check if TTS conversion is complete
        guard TUITextToVoiceDataProvider.getTextToVoiceStatus(message) == .shown else {
            print("[TUITextToVoiceAutoService] addToAutoPlayQueue skipped - TTS not ready for msgID: \(msgID)")
            return
        }
        
        autoPlayQueue.append(message)
        print("[TUITextToVoiceAutoService] addToAutoPlayQueue - msgID: \(msgID), queueSize: \(autoPlayQueue.count), isAutoPlaying: \(isAutoPlaying), currentPlayingMsgID: \(currentPlayingMsgID ?? "nil")")
        
        // Start playing if not already playing, or if previous playback finished but state wasn't reset
        if !isAutoPlaying || (isAutoPlaying && currentPlayingMsgID == nil) {
            playNextInQueue()
        }
    }
    
    private func playNextInQueue() {
        guard isAutoTextToVoiceEnabledForCurrentConversation(), !autoPlayQueue.isEmpty else {
            print("[TUITextToVoiceAutoService] playNextInQueue - stopping, enabled: \(isAutoTextToVoiceEnabledForCurrentConversation()), queueEmpty: \(autoPlayQueue.isEmpty)")
            isAutoPlaying = false
            currentPlayingMsgID = nil
            return
        }
        
        isAutoPlaying = true
        let message = autoPlayQueue.removeFirst()
        currentPlayingMsgID = message.msgID
        
        print("[TUITextToVoiceAutoService] playNextInQueue - playing msgID: \(message.msgID ?? "nil"), remaining: \(autoPlayQueue.count)")
        
        playTTSMessage(message)
    }
    
    private func playTTSMessage(_ message: V2TIMMessage) {
        print("[TUITextToVoiceAutoService] playTTSMessage - msgID: \(message.msgID ?? "nil")")
        
        // Track if playback actually started
        var playbackStarted = false
        
        // Use TUITextToVoiceDataProvider to play
        // Callback: true = playback started, false = stopped/finished
        // onTTSPlaybackFinished handles completion, so only handle start failure here
        TUITextToVoiceDataProvider.shared.playAudio(for: message) { [weak self] playing in
            print("[TUITextToVoiceAutoService] playTTSMessage callback - msgID: \(message.msgID ?? "nil"), playing: \(playing), playbackStarted: \(playbackStarted)")
            
            if playing {
                // Playback started successfully
                playbackStarted = true
            } else if !playbackStarted {
                // Failed to start playback (never got playing=true)
                // Move to next in queue
                print("[TUITextToVoiceAutoService] playTTSMessage - playback failed to start, moving to next")
                self?.playNextInQueue()
            }
            // If playbackStarted is true and playing is false, it means playback finished
            // This is handled by onTTSPlaybackFinished notification
        }
    }
    
    private func isMessagePlayed(_ message: V2TIMMessage) -> Bool {
        return TUITextToVoiceDataProvider.isTextToVoicePlayed(message)
    }
    
    // MARK: - Notification Handlers
    
    @objc private func onTTSPlaybackFinished(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let msgID = userInfo["msgID"] as? String
        else { return }
        
        print("[TUITextToVoiceAutoService] onTTSPlaybackFinished - msgID: \(msgID), currentPlayingMsgID: \(currentPlayingMsgID ?? "nil")")
        
        guard currentPlayingMsgID == msgID else { return }
        
        currentPlayingMsgID = nil
        playNextInQueue()
    }
    
    @objc private func onAudioPlaybackFinished(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let msgID = userInfo["msgID"] as? String
        else { return }
        
        print("[TUITextToVoiceAutoService] onAudioPlaybackFinished - msgID: \(msgID), currentPlayingMsgID: \(currentPlayingMsgID ?? "nil"), isAutoPlaying: \(isAutoPlaying)")
        
        // Check if this is the message we're tracking for auto-play
        // Also handle the case where currentPlayingMsgID was cleared but isAutoPlaying is still true
        if currentPlayingMsgID == msgID || (isAutoPlaying && currentPlayingMsgID == nil) {
            currentPlayingMsgID = nil
            // Small delay to allow UI to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.playNextInQueue()
            }
        }
    }
    
    // MARK: - Public Methods
    
    public func stopAutoPlay() {
        let stoppedMsgID = currentPlayingMsgID
        
        isAutoPlaying = false
        currentPlayingMsgID = nil
        autoPlayQueue.removeAll()
        pendingTTSMessages.removeAll()
        ttsRetryCount.removeAll()
        
        // Stop all audio using centralized manager
        TUIAudioPlaybackManager.shared.stopCurrentAudio()
        
        currentConversationID = nil
        
        // Notify UI to reset if needed
        if let msgID = stoppedMsgID {
            NotificationCenter.default.post(
                name: NSNotification.Name("TUITextToVoicePlaybackStateChanged"),
                object: nil,
                userInfo: ["msgID": msgID, "isPlaying": false]
            )
        }
    }
    
    // MARK: - Helpers
    
    private func notifyMessageChanged(_ message: V2TIMMessage) {
        let cellData = TUIMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        cellData.innerMessage = message
        
        let param: [String: Any] = ["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData]
        TUICore.notifyEvent("TUICore_TUIPluginNotify",
                            subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey",
                            object: nil,
                            param: param)
    }
}

// MARK: - TUINotificationProtocol

extension TUITextToVoiceAutoService: TUINotificationProtocol {
    public func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIChatNotify" {
            if subKey == "TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey" {
                // C2C chat: get userID and build conversationID
                if let userID = param?["TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey_UserID"] as? String, !userID.isEmpty {
                    currentConversationID = "c2c_\(userID)"
                    print("[TUITextToVoiceAutoService] ViewDidLoad - Set currentConversationID: \(currentConversationID ?? "nil")")
                }
                // Group chat: get groupID and build conversationID
                else if let groupID = param?["TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey_GroupID"] as? String, !groupID.isEmpty {
                    currentConversationID = "group_\(groupID)"
                    print("[TUITextToVoiceAutoService] ViewDidLoad - Set currentConversationID: \(currentConversationID ?? "nil")")
                }
            } else if subKey == "TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey" {
                // Restore conversationID when returning from sub-pages (e.g., friend profile, group info)
                if let userID = param?["TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey_UserID"] as? String, !userID.isEmpty {
                    currentConversationID = "c2c_\(userID)"
                    print("[TUITextToVoiceAutoService] ViewWillAppear - Restored currentConversationID: \(currentConversationID ?? "nil")")
                } else if let groupID = param?["TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey_GroupID"] as? String, !groupID.isEmpty {
                    currentConversationID = "group_\(groupID)"
                    print("[TUITextToVoiceAutoService] ViewWillAppear - Restored currentConversationID: \(currentConversationID ?? "nil")")
                }
            } else if subKey == "TUICore_TUIChatNotify_ChatVC_ViewWillDisappearSubKey" {
                // Only clear when actually leaving the chat (not just pushing to sub-page)
                // The ViewWillAppear will restore it if we're returning
                print("[TUITextToVoiceAutoService] ViewWillDisappear - Clearing currentConversationID (was: \(currentConversationID ?? "nil"))")
                stopAutoPlay()
                currentConversationID = ""
            }
        }
    }
}
