import AVFoundation
import Foundation
import TIMCommon
import TUIChat
import TUICore

/// Service for automatic voice message features:
/// - Auto voice-to-text conversion for incoming voice messages
/// - Auto play queue management for voice messages
///
/// Architecture:
/// - This service manages the auto-play queue and conversion triggers for voice messages
/// - TUIAudioPlaybackManager handles actual audio playback (centralized)
/// - TTS (Text-to-Voice) functionality is handled by TUITextToVoicePlugin
public class TUIVoiceMessageAutoService: NSObject, V2TIMAdvancedMsgListener {
    
    // MARK: - Singleton
    
    public static let shared = TUIVoiceMessageAutoService()
    
    // MARK: - Properties
    
    /// Current conversation ID
    private var currentConversationID: String?
    
    /// Auto play queue (ordered by timestamp) - only for voice messages
    private var autoPlayQueue: [V2TIMMessage] = []
    
    /// Whether auto play is in progress
    private var isAutoPlaying: Bool = false
    
    /// Current playing message ID
    private var currentPlayingMsgID: String?
    
    // MARK: - Config Accessors
    
    private var isAutoVoiceToTextEnabled: Bool {
        return TUIVoiceToTextConfig.shared.autoVoiceToTextEnabled
    }
    
    private var isAutoPlayVoiceEnabled: Bool {
        return TUIVoiceToTextConfig.shared.autoPlayVoiceEnabled
    }
    
    /// Check if auto voice-to-text is enabled for current conversation
    /// Priority: Conversation setting > Global setting
    private func isAutoVoiceToTextEnabledForCurrentConversation() -> Bool {
        guard let conversationID = currentConversationID, !conversationID.isEmpty else {
            return isAutoVoiceToTextEnabled
        }
        return TUIVoiceMessageConversationConfig.shared.shouldEnable(
            for: conversationID,
            type: .autoVoiceToText,
            globalEnabled: isAutoVoiceToTextEnabled
        )
    }
    
    /// Check if auto play voice is enabled for current conversation
    /// Priority: Conversation setting > Global setting
    private func isAutoPlayVoiceEnabledForCurrentConversation() -> Bool {
        guard let conversationID = currentConversationID, !conversationID.isEmpty else {
            return isAutoPlayVoiceEnabled
        }
        return TUIVoiceMessageConversationConfig.shared.shouldEnable(
            for: conversationID,
            type: .autoPlayVoice,
            globalEnabled: isAutoPlayVoiceEnabled
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
        
        // Voice message playback result
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onVoiceMessagePlayResult(_:)),
            name: NSNotification.Name("TUIChat_AutoPlayVoiceMessageResult"),
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
        
        // Auto voice-to-text conversion (use conversation-level setting)
        if isAutoVoiceToTextEnabledForCurrentConversation(), msg.elemType == .ELEM_TYPE_SOUND {
            startAutoVoiceToText(msg)
        }
        
        // Auto play queue for voice messages (use conversation-level setting)
        if isAutoPlayVoiceEnabledForCurrentConversation(), msg.elemType == .ELEM_TYPE_SOUND {
            addToAutoPlayQueue(msg)
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
    
    // MARK: - Auto Voice-to-Text Conversion
    
    private func startAutoVoiceToText(_ message: V2TIMMessage) {
        guard !TUIVoiceToTextDataProvider.shouldShowConvertedText(message) else { return }
        
        let cellData = TUIMessageCellData(direction: .incoming)
        cellData.innerMessage = message
        
        TUIVoiceToTextDataProvider.saveConvertedResult(message, text: "", status: .loading)
        notifyMessageChanged(message)
        
        TUIVoiceToTextDataProvider.convertMessage(cellData) { [weak self] _, _, _, _, _ in
            self?.notifyMessageChanged(message)
        }
    }
    
    // MARK: - Auto Play Queue Management (Voice Messages Only)
    
    private func addToAutoPlayQueue(_ message: V2TIMMessage) {
        guard isAutoPlayVoiceEnabledForCurrentConversation(),
              message.elemType == .ELEM_TYPE_SOUND,
              let msgID = message.msgID,
              !autoPlayQueue.contains(where: { $0.msgID == msgID }),
              !isMessagePlayed(message)
        else {
            print("[TUIVoiceMessageAutoService] addToAutoPlayQueue skipped - msgID: \(message.msgID ?? "nil"), isEnabled: \(isAutoPlayVoiceEnabledForCurrentConversation()), alreadyInQueue: \(autoPlayQueue.contains(where: { $0.msgID == message.msgID })), isPlayed: \(isMessagePlayed(message))")
            return
        }
        
        autoPlayQueue.append(message)
        print("[TUIVoiceMessageAutoService] addToAutoPlayQueue - msgID: \(msgID), queueSize: \(autoPlayQueue.count), isAutoPlaying: \(isAutoPlaying), currentPlayingMsgID: \(currentPlayingMsgID ?? "nil")")
        
        // Start playing if not already playing, or if previous playback finished but state wasn't reset
        if !isAutoPlaying || (isAutoPlaying && currentPlayingMsgID == nil) {
            playNextInQueue()
        }
    }
    
    private func playNextInQueue() {
        guard isAutoPlayVoiceEnabledForCurrentConversation(), !autoPlayQueue.isEmpty else {
            print("[TUIVoiceMessageAutoService] playNextInQueue - stopping, enabled: \(isAutoPlayVoiceEnabledForCurrentConversation()), queueEmpty: \(autoPlayQueue.isEmpty)")
            isAutoPlaying = false
            currentPlayingMsgID = nil
            return
        }
        
        isAutoPlaying = true
        let message = autoPlayQueue.removeFirst()
        currentPlayingMsgID = message.msgID
        
        print("[TUIVoiceMessageAutoService] playNextInQueue - playing msgID: \(message.msgID ?? "nil"), elemType: \(message.elemType.rawValue), remaining: \(autoPlayQueue.count)")
        
        if message.elemType == .ELEM_TYPE_SOUND {
            playVoiceMessage(message)
        } else {
            playNextInQueue()
        }
    }
    
    private func playVoiceMessage(_ message: V2TIMMessage) {
        guard let msgID = message.msgID else {
            playNextInQueue()
            return
        }
        
        // Request TUIBaseMessageController to play voice message
        NotificationCenter.default.post(
            name: NSNotification.Name("TUIChat_AutoPlayVoiceMessage"),
            object: nil,
            userInfo: ["msgID": msgID]
        )
        
        // Timeout fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.currentPlayingMsgID == msgID else { return }
            self.playNextInQueue()
        }
    }
    
    private func isMessagePlayed(_ message: V2TIMMessage) -> Bool {
        if message.elemType == .ELEM_TYPE_SOUND {
            return message.localCustomInt != 0
        }
        return false
    }
    
    // MARK: - Notification Handlers
    
    @objc private func onVoiceMessagePlayResult(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let msgID = userInfo["msgID"] as? String,
              let success = userInfo["success"] as? Bool,
              currentPlayingMsgID == msgID
        else { return }
        
        print("[TUIVoiceMessageAutoService] onVoiceMessagePlayResult - msgID: \(msgID), success: \(success)")
        
        if !success {
            // Failed to start, move to next
            playNextInQueue()
        }
        // If success, wait for onAudioPlaybackFinished to trigger next
    }
    
    @objc private func onAudioPlaybackFinished(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let msgID = userInfo["msgID"] as? String
        else { return }
        
        print("[TUIVoiceMessageAutoService] onAudioPlaybackFinished - msgID: \(msgID), currentPlayingMsgID: \(currentPlayingMsgID ?? "nil"), isAutoPlaying: \(isAutoPlaying)")
        
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
        isAutoPlaying = false
        currentPlayingMsgID = nil
        autoPlayQueue.removeAll()
        
        // Stop all audio using centralized manager
        TUIAudioPlaybackManager.shared.stopCurrentAudio()
        
        currentConversationID = nil
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

extension TUIVoiceMessageAutoService: TUINotificationProtocol {
    public func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIChatNotify" {
            if subKey == "TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey" {
                // C2C chat: get userID and build conversationID
                if let userID = param?["TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey_UserID"] as? String, !userID.isEmpty {
                    currentConversationID = "c2c_\(userID)"
                    print("[TUIVoiceMessageAutoService] ViewDidLoad - Set currentConversationID: \(currentConversationID ?? "nil")")
                }
                // Group chat: get groupID and build conversationID
                else if let groupID = param?["TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey_GroupID"] as? String, !groupID.isEmpty {
                    currentConversationID = "group_\(groupID)"
                    print("[TUIVoiceMessageAutoService] ViewDidLoad - Set currentConversationID: \(currentConversationID ?? "nil")")
                }
            } else if subKey == "TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey" {
                // Restore conversationID when returning from sub-pages (e.g., friend profile, group info)
                if let userID = param?["TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey_UserID"] as? String, !userID.isEmpty {
                    currentConversationID = "c2c_\(userID)"
                    print("[TUIVoiceMessageAutoService] ViewWillAppear - Restored currentConversationID: \(currentConversationID ?? "nil")")
                } else if let groupID = param?["TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey_GroupID"] as? String, !groupID.isEmpty {
                    currentConversationID = "group_\(groupID)"
                    print("[TUIVoiceMessageAutoService] ViewWillAppear - Restored currentConversationID: \(currentConversationID ?? "nil")")
                }
            } else if subKey == "TUICore_TUIChatNotify_ChatVC_ViewWillDisappearSubKey" {
                // Only clear when actually leaving the chat (not just pushing to sub-page)
                // The ViewWillAppear will restore it if we're returning
                print("[TUIVoiceMessageAutoService] ViewWillDisappear - Clearing currentConversationID (was: \(currentConversationID ?? "nil"))")
                stopAutoPlay()
                currentConversationID = ""
            }
        }
    }
}
