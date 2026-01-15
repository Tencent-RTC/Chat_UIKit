import Foundation
import SnapKit
import TIMCommon
import TUIChat
import TUICore

public class TUITextToVoiceExtensionObserver: NSObject, TUIExtensionProtocol, TUIServiceProtocol {
    weak var navVC: UINavigationController?
    
    static let shared: TUITextToVoiceExtensionObserver = {
        let instance = TUITextToVoiceExtensionObserver()
        return instance
    }()
    
    override init() {
        super.init()
        // Register TopContainer extensions for displaying TTS view
        TUICore.registerExtension("TUICore_TUIChatExtension_TopContainer_ClassicExtensionID", object: self)
        TUICore.registerExtension("TUICore_TUIChatExtension_TopContainer_MinimalistExtensionID", object: self)
        
        // Register service for topContainerInsetTop calculation
        TUICore.registerService("TUICore_TUITextToVoiceService", object: self)
    }
    
    @objc public static func swiftLoad() {
        // Initialize auto service for TTS features
        _ = TUITextToVoiceAutoService.shared
        
        // NOTE: Global settings menu entry is NOT registered here.
        // TTS settings are integrated into TUIVoiceMessageSettingsController via TUICore service.
        
        // UI extensions in pop menu when message is long pressed
        TUICore.registerExtension("TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID", object: TUITextToVoiceExtensionObserver.shared)
        TUICore.registerExtension("TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID", object: TUITextToVoiceExtensionObserver.shared)
        
        // UI extensions for friend profile settings (conversation-level auto-play switch)
        TUICore.registerExtension("TUICore_TUIContactExtension_FriendProfileSettingsSwitch_ClassicExtensionID", object: TUITextToVoiceExtensionObserver.shared)
        TUICore.registerExtension("TUICore_TUIContactExtension_FriendProfileSettingsSwitch_MinimalistExtensionID", object: TUITextToVoiceExtensionObserver.shared)
        
        // UI extensions for group profile settings (conversation-level auto-play switch)
        TUICore.registerExtension("TUICore_TUIChatExtension_GroupProfileSettingsSwitch_ClassicExtensionID", object: TUITextToVoiceExtensionObserver.shared)
        TUICore.registerExtension("TUICore_TUIChatExtension_GroupProfileSettingsSwitch_MinimalistExtensionID", object: TUITextToVoiceExtensionObserver.shared)
    }
    
    // MARK: - TUIServiceProtocol
    
    public func onCall(_ method: String, param: [AnyHashable: Any]?) -> Any? {
        switch method {
        case "TUICore_TUITextToVoiceService_CalculateTopContainerInsetTopMethod":
            guard let cellData = param?["cellData"] as? TUIMessageCellData else {
                return NSNumber(value: 0)
            }
            let insetTop = calculateTopContainerInsetTopValue(for: cellData)
            return NSNumber(value: insetTop)
            
        case "TUICore_TUITextToVoiceService_GetGlobalSettingsMethod":
            return getGlobalSettingsData(param: param)
            
        case "TUICore_TUITextToVoiceService_UpdateSettingMethod":
            updateSetting(param: param)
            return nil
            
        case "TUICore_TUITextToVoiceService_NavigateToSettingMethod":
            navigateToSetting(param: param)
            return nil
            
        default:
            return nil
        }
    }
    
    // MARK: - Global Settings Service Methods
    
    /// Provide TTS settings data for unified settings page
    private func getGlobalSettingsData(param: [AnyHashable: Any]?) -> [String: Any] {
        let conversationID = param?["conversationID"] as? String
        
        // TTS settings items
        var settingsItems: [[String: Any]] = []
        
        // Auto text-to-voice switch
        let autoTTSEnabled: Bool
        if let convID = conversationID {
            if let setting = TUITextToVoiceConversationConfig.shared.getSetting(for: convID, type: .autoTextToVoice) {
                autoTTSEnabled = setting.boolValue
            } else {
                autoTTSEnabled = TUITextToVoiceConfig.shared.autoTextToVoiceEnabled
            }
        } else {
            autoTTSEnabled = TUITextToVoiceConfig.shared.autoTextToVoiceEnabled
        }
        
        settingsItems.append([
            "title": TUISwift.timCommonLocalizableString("AutoTextToVoice"),
            "description": TUISwift.timCommonLocalizableString("AutoTextToVoiceDescription"),
            "isOn": autoTTSEnabled,
            "settingType": TUITextToVoiceSettingType.autoTextToVoice.rawValue
        ])
        
        // Voice selection items
        var voiceSelectionItems: [[String: Any]] = []
        
        // Voice clone entry
        voiceSelectionItems.append([
            "title": TUISwift.timCommonLocalizableString("VoiceClone"),
            "description": TUISwift.timCommonLocalizableString("VoiceCloneDescription"),
            "detailText": "",
            "itemType": "voiceClone"
        ])
        
        // Voice list entry
        let selectedVoiceName: String
        if let convID = conversationID {
            selectedVoiceName = TUITextToVoiceConversationConfig.shared.getDisplayVoiceName(for: convID)
        } else {
            selectedVoiceName = TUITextToVoiceConfig.shared.getSelectedVoiceDisplayName()
        }
        
        voiceSelectionItems.append([
            "title": TUISwift.timCommonLocalizableString("VoiceSelection"),
            "description": TUISwift.timCommonLocalizableString("VoiceSelectionDescription"),
            "detailText": selectedVoiceName,
            "itemType": "voiceList"
        ])
        
        return [
            "settingsItems": settingsItems,
            "voiceSelectionItems": voiceSelectionItems
        ]
    }
    
    /// Update TTS setting from unified settings page
    private func updateSetting(param: [AnyHashable: Any]?) {
        guard let settingTypeRaw = param?["settingType"] as? Int,
              let value = param?["value"] as? Bool
        else { return }
        
        let conversationID = param?["conversationID"] as? String
        
        if settingTypeRaw == TUITextToVoiceSettingType.autoTextToVoice.rawValue {
            if let convID = conversationID {
                TUITextToVoiceConversationConfig.shared.setSetting(value, for: convID, type: .autoTextToVoice)
            } else {
                TUITextToVoiceConfig.shared.autoTextToVoiceEnabled = value
            }
        }
    }
    
    /// Navigate to TTS setting page from unified settings page
    private func navigateToSetting(param: [AnyHashable: Any]?) {
        guard let itemType = param?["itemType"] as? String,
              let navVC = param?["navigationController"] as? UINavigationController
        else { return }
        
        let conversationID = param?["conversationID"] as? String
        
        switch itemType {
        case "voiceClone":
            let voiceCloneVC = TUIVoiceCloneController()
            navVC.pushViewController(voiceCloneVC, animated: true)
        case "voiceList":
            let voiceListVC = TUIVoiceListController()
            voiceListVC.conversationID = conversationID
            navVC.pushViewController(voiceListVC, animated: true)
        default:
            break
        }
    }
    
    
    // MARK: - TUIExtensionProtocol
    
    public func onRaiseExtension(_ extensionID: String, parentView: UIView, param: [AnyHashable: Any]?) -> Bool {
        if extensionID == "TUICore_TUIChatExtension_TopContainer_ClassicExtensionID" ||
           extensionID == "TUICore_TUIChatExtension_TopContainer_MinimalistExtensionID" {
            guard let data = param?["TUICore_TUIChatExtension_TopContainer_CellData"] as? TUIMessageCellData,
                  let message = data.innerMessage,
                  message.elemType == .ELEM_TYPE_TEXT
            else {
                return false
            }
            
            // Check if this message has text-to-voice audio
            let status = TUITextToVoiceDataProvider.getTextToVoiceStatus(message)
            guard status == .shown else {
                return false
            }
            
            // Remove existing TTS view if any
            var cacheMap = parentView.tui_extValueObj as? [String: Any] ?? [:]
            if let existingView = cacheMap["TUITextToVoiceView"] as? TUITextToVoiceView {
                existingView.removeFromSuperview()
            }
            
            // Calculate view size first using static method
            let viewSize = TUITextToVoiceView.getViewSize(for: message)
            
            // Update cellData's topContainerSize
            data.topContainerSize = viewSize
            
            // Calculate topContainerInsetTop for incoming messages with name shown
            calculateTopContainerInsetTop(for: data, topContainerSize: viewSize)
            
            // Create and add TTS view
            guard let ttsView = TUITextToVoiceView(cellData: data) else {
                return false
            }
            parentView.addSubview(ttsView)
            
            // Use SnapKit to fill the parentView (topContainer)
            ttsView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            // Update cache
            cacheMap["TUITextToVoiceView"] = ttsView
            parentView.tui_extValueObj = cacheMap
            
            return true
        }
        return false
    }
    
    public func onGetExtension(_ extensionID: String, param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        // Pop menu extension for text-to-voice action
        if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID" ||
           extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID" {
            return getPopMenuExtension(extensionID: extensionID, param: param)
        }
        
        // Friend profile settings switch extension
        if extensionID == "TUICore_TUIContactExtension_FriendProfileSettingsSwitch_ClassicExtensionID" ||
           extensionID == "TUICore_TUIContactExtension_FriendProfileSettingsSwitch_MinimalistExtensionID" {
            return getFriendProfileSettingsSwitchExtension(param: param)
        }
        
        // Group profile settings switch extension
        if extensionID == "TUICore_TUIChatExtension_GroupProfileSettingsSwitch_ClassicExtensionID" ||
           extensionID == "TUICore_TUIChatExtension_GroupProfileSettingsSwitch_MinimalistExtensionID" {
            return getGroupProfileSettingsSwitchExtension(param: param)
        }
        
        return nil
    }
    
    // MARK: - Friend Profile Settings Switch Extension
    
    private func getFriendProfileSettingsSwitchExtension(param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        guard let param = param,
              let userID = param["userID"] as? String,
              !userID.isEmpty
        else { return nil }
        
        let conversationID = "c2c_\(userID)"
        var extensions: [TUIExtensionInfo] = []
        
        // Auto text-to-voice switch
        let textToVoiceInfo = createSettingSwitchExtension(
            conversationID: conversationID,
            type: .autoTextToVoice,
            titleKey: "AutoTextToVoice",
            globalEnabled: TUITextToVoiceConfig.shared.autoTextToVoiceEnabled,
            weight: 195
        )
        extensions.append(textToVoiceInfo)
        
        // Voice selection
        let voiceSelectionInfo = createVoiceSelectionExtension(
            conversationID: conversationID,
            weight: 194
        )
        extensions.append(voiceSelectionInfo)
        
        return extensions
    }
    
    // MARK: - Group Profile Settings Switch Extension
    
    private func getGroupProfileSettingsSwitchExtension(param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        guard let param = param,
              let groupID = param["groupID"] as? String,
              !groupID.isEmpty
        else { return nil }
        
        let conversationID = "group_\(groupID)"
        var extensions: [TUIExtensionInfo] = []
        
        // Auto text-to-voice switch
        let textToVoiceInfo = createSettingSwitchExtension(
            conversationID: conversationID,
            type: .autoTextToVoice,
            titleKey: "AutoTextToVoice",
            globalEnabled: TUITextToVoiceConfig.shared.autoTextToVoiceEnabled,
            weight: 195
        )
        extensions.append(textToVoiceInfo)
        
        // Voice selection
        let voiceSelectionInfo = createVoiceSelectionExtension(
            conversationID: conversationID,
            weight: 194
        )
        extensions.append(voiceSelectionInfo)
        
        return extensions
    }
    
    // MARK: - Helper for Creating Voice Selection Extension
    
    private func createVoiceSelectionExtension(
        conversationID: String,
        weight: Int
    ) -> TUIExtensionInfo {
        let info = TUIExtensionInfo()
        info.weight = weight
        info.text = TUISwift.timCommonLocalizableString("VoiceSelection")
        
        let displayValue = TUITextToVoiceConversationConfig.shared.getDisplayVoiceName(for: conversationID)
        
        var infoData: [String: Any] = [
            "conversationID": conversationID,
            "displayValue": displayValue,
            "isVoiceSelection": true
        ]
        info.data = infoData
        
        info.onClicked = { [weak self] clickParam in
            let voiceListVC = TUIVoiceListController()
            voiceListVC.conversationID = conversationID
            
            // Try to get navigationController from clickParam first
            if let navVC = clickParam["pushVC"] as? UINavigationController {
                navVC.pushViewController(voiceListVC, animated: true)
            } else if let navVC = self?.navVC {
                // Fallback to stored navVC
                navVC.pushViewController(voiceListVC, animated: true)
            }
        }
        
        return info
    }
    
    // MARK: - Helper for Creating Setting Extension (Tri-state: On/Off/FollowGlobal)
    
    private func createSettingSwitchExtension(
        conversationID: String,
        type: TUITextToVoiceSettingType,
        titleKey: String,
        globalEnabled: Bool,
        weight: Int
    ) -> TUIExtensionInfo {
        let conversationSetting = TUITextToVoiceConversationConfig.shared.getSetting(for: conversationID, type: type)
        
        let info = TUIExtensionInfo()
        info.weight = weight
        info.text = TUISwift.timCommonLocalizableString(titleKey)
        
        // Determine current state: nil = follow global, true = on, false = off
        // stateValue: 0 = follow global, 1 = on, 2 = off
        let stateValue: Int
        let displayValue: String
        if let setting = conversationSetting {
            if setting.boolValue {
                stateValue = 1
                displayValue = TUISwift.timCommonLocalizableString("TUIKitOn")
            } else {
                stateValue = 2
                displayValue = TUISwift.timCommonLocalizableString("TUIKitOff")
            }
        } else {
            stateValue = 0
            displayValue = TUISwift.timCommonLocalizableString("FollowGlobalSetting")
        }
        
        var infoData: [String: Any] = [
            "conversationID": conversationID,
            "settingType": type.rawValue,
            "stateValue": stateValue,
            "displayValue": displayValue,
            "globalEnabled": globalEnabled
        ]
        info.data = infoData
        
        // onClicked shows ActionSheet for tri-state selection
        info.onClicked = { [weak self] clickParam in
            guard let self = self,
                  let viewController = clickParam["viewController"] as? UIViewController
            else { return }
            
            self.showSettingActionSheet(
                on: viewController,
                title: TUISwift.timCommonLocalizableString(titleKey),
                conversationID: conversationID,
                type: type,
                currentState: stateValue,
                globalEnabled: globalEnabled
            )
        }
        
        return info
    }
    
    /// Show ActionSheet for tri-state setting selection
    private func showSettingActionSheet(
        on viewController: UIViewController,
        title: String,
        conversationID: String,
        type: TUITextToVoiceSettingType,
        currentState: Int,
        globalEnabled: Bool
    ) {
        let globalStatusText = globalEnabled ? TUISwift.timCommonLocalizableString("TUIKitOn") : TUISwift.timCommonLocalizableString("TUIKitOff")
        let followGlobalText = "\(TUISwift.timCommonLocalizableString("FollowGlobalSetting"))(\(globalStatusText))"
        
        let ac = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        
        let invokeReloadCallback = {
            // Notify via TUICore to trigger reload in host controller
            TUICore.notifyEvent(
                "TUICore_TUIVoiceMessageNotify",
                subKey: "TUICore_TUIVoiceMessageNotify_ReloadDataSubKey",
                object: nil,
                param: nil
            )
        }
        
        // Follow global option
        let followAction = UIAlertAction(title: followGlobalText, style: .default) { _ in
            TUITextToVoiceConversationConfig.shared.removeSetting(for: conversationID, type: type)
            invokeReloadCallback()
        }
        if currentState == 0 {
            followAction.setValue(true, forKey: "checked")
        }
        ac.addAction(followAction)
        
        // On option
        let onAction = UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitOn"), style: .default) { _ in
            TUITextToVoiceConversationConfig.shared.setSetting(true, for: conversationID, type: type)
            invokeReloadCallback()
        }
        if currentState == 1 {
            onAction.setValue(true, forKey: "checked")
        }
        ac.addAction(onAction)
        
        // Off option
        let offAction = UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitOff"), style: .default) { _ in
            TUITextToVoiceConversationConfig.shared.setSetting(false, for: conversationID, type: type)
            invokeReloadCallback()
        }
        if currentState == 2 {
            offAction.setValue(true, forKey: "checked")
        }
        ac.addAction(offAction)
        
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        viewController.present(ac, animated: true, completion: nil)
    }
    
    // MARK: - Pop Menu Extension
    
    private func getPopMenuExtension(extensionID: String, param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        guard let param = param,
              TUIChatConfig.shared.enablePopMenuTextToVoiceAction,
              let cell = param["TUICore_TUIChatExtension_PopMenuActionItem_ClickCell"] as? TUIMessageCell
        else { return nil }
        
        // Check if it's a text message type
        let isTextMessage: Bool
        if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID" {
            isTextMessage = cell is TUITextMessageCell || cell is TUIReferenceMessageCell || cell is TUIReplyMessageCell
        } else {
            isTextMessage = cell is TUITextMessageCell_Minimalist || cell is TUIReferenceMessageCell_Minimalist || cell is TUIReplyMessageCell_Minimalist
        }
        
        guard isTextMessage,
              let messageData = cell.messageData,
              let message = messageData.innerMessage,
              message.elemType == .ELEM_TYPE_TEXT,
              message.status == .MSG_STATUS_SEND_SUCC,
              !message.hasRiskContent
        else { return nil }
        
        // Check if already has text-to-voice
        let status = TUITextToVoiceDataProvider.getTextToVoiceStatus(message)
        if status == .shown || status == .loading {
            return nil
        }
        
        let info = TUIExtensionInfo()
        info.text = TUISwift.timCommonLocalizableString("TUIKitTextToVoice")
        
        if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID" {
            info.icon = TUISwift.tuiChatBundleThemeImage("chat_icon_text_to_voice_img", defaultImage: "icon_text_to_voice")
            info.weight = 2800
        } else {
            info.icon = UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_text_to_voice"))
            info.weight = 800
        }
        
        info.onClicked = { [weak self] _ in
            self?.convertTextToVoice(cellData: messageData)
        }
        
        return [info]
    }
    
    // MARK: - Text to Voice Conversion
    
    private func convertTextToVoice(cellData: TUIMessageCellData) {
        guard let message = cellData.innerMessage,
              message.elemType == .ELEM_TYPE_TEXT,
              let textElem = message.textElem,
              let text = textElem.text,
              !text.isEmpty
        else { return }
        
        // Convert emoji tags to localizable display text (e.g., [TUIEmoji_Haha] -> [哈哈哈])
        // Then remove brackets to avoid TTS reading them
        let displayText = text.getLocalizableStringWithFaceContent()
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
        
        // Get conversation ID from message
        let conversationID = getConversationID(from: message)
        
        // Get effective voice ID for this conversation
        let voiceId = TUITextToVoiceDataProvider.getEffectiveVoiceId(for: conversationID)
        
        // Show loading
        TUITool.makeToastActivity()
        
        // Set loading status
        TUITextToVoiceDataProvider.setLoadingStatus(message)
        notifyPluginViewChanged(cellData: cellData)
        
        // Call API to convert text to voice
        TUITextToVoiceDataProvider.convertTextToVoice(text: displayText, voiceId: voiceId) { [weak self] code, desc, audioUrl in
            TUITool.hideToastActivity()
            
            if code == 0, let audioUrl = audioUrl, !audioUrl.isEmpty {
                // Fetch duration and save
                TUITextToVoiceDataProvider.fetchAudioDuration(from: audioUrl) { duration in
                    TUITextToVoiceDataProvider.saveTextToVoiceUrl(message, url: audioUrl, duration: duration)
                    self?.notifyPluginViewChanged(cellData: cellData)
                }
            } else {
                // Set failed status on failure (allows retry from menu)
                TUITextToVoiceDataProvider.setFailedStatus(message)
                self?.notifyPluginViewChanged(cellData: cellData)
                
                // Show specific error message for text too long (code 6017)
                if code == 6017 {
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitErrorTTSTextTooLong"))
                } else {
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitErrorConvertTextToVoiceFailed"))
                }
            }
        }
    }
    
    private func notifyPluginViewChanged(cellData: TUIMessageCellData) {
        let param: [String: Any] = ["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData]
        TUICore.notifyEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey", object: nil, param: param)
    }
    
    /// Get conversation ID from V2TIMMessage
    private func getConversationID(from message: V2TIMMessage) -> String? {
        if let userID = message.userID, !userID.isEmpty {
            return "c2c_\(userID)"
        } else if let groupID = message.groupID, !groupID.isEmpty {
            return "group_\(groupID)"
        }
        return nil
    }
    
    // MARK: - TopContainer Inset Calculation
    
    /// Calculate topContainerInsetTop value and return it (for Service call)
    private func calculateTopContainerInsetTopValue(for data: TUIMessageCellData) -> CGFloat {
        // Only for incoming messages that show name
        guard data.direction == .incoming, data.showName else {
            return 0
        }
        
        // Check if this message has text-to-voice
        guard let message = data.innerMessage,
              TUITextToVoiceDataProvider.getTextToVoiceStatus(message) == .shown else {
            return 0
        }
        
        // Get topContainer size
        let topContainerSize = TUITextToVoiceView.getViewSize(for: message)
        guard topContainerSize.width > 0 else {
            return 0
        }
        
        // Get sender name
        let senderName = data.senderName
        guard !senderName.isEmpty else {
            return 0
        }
        
        // Calculate name label width
        let nameFont = UIFont.systemFont(ofSize: 13)
        let nameWidth = (senderName as NSString).size(withAttributes: [.font: nameFont]).width
        
        // Get bubble width from content size
        guard let textData = data as? TUITextMessageCellData else {
            return 0
        }
        let bubbleWidth = textData.textSize.width + (textData.cellLayout?.bubbleInsets.left ?? 0) + (textData.cellLayout?.bubbleInsets.right ?? 0)
        
        // topContainer is at bubble's trailing edge
        // nameLabel starts at container.leading + 7
        // Check if nameLabel would extend into topContainer area
        let nameLabelLeadingOffset: CGFloat = 7
        let spacing: CGFloat = 8 // minimum spacing between nameLabel and topContainer
        
        // Available width for nameLabel = bubbleWidth - topContainerWidth - spacing - nameLabelLeadingOffset
        let availableWidth = bubbleWidth - topContainerSize.width - spacing - nameLabelLeadingOffset
        
        if nameWidth > availableWidth {
            // Overlap detected, need to move container down
            return 10
        }
        return 0
    }
    
    /// Calculate and set topContainerInsetTop on cellData (for onRaiseExtension)
    private func calculateTopContainerInsetTop(for data: TUIMessageCellData, topContainerSize: CGSize) {
        // Only for incoming messages that show name
        guard data.direction == .incoming, data.showName else {
            data.topContainerInsetTop = 0
            return
        }
        
        guard topContainerSize.width > 0 else {
            data.topContainerInsetTop = 0
            return
        }
        
        // Get sender name
        let senderName = data.senderName
        guard !senderName.isEmpty else {
            data.topContainerInsetTop = 0
            return
        }
        
        // Calculate name label width
        let nameFont = UIFont.systemFont(ofSize: 13)
        let nameWidth = (senderName as NSString).size(withAttributes: [.font: nameFont]).width
        
        // Get bubble width from content size
        guard let textData = data as? TUITextMessageCellData else {
            data.topContainerInsetTop = 0
            return
        }
        let bubbleWidth = textData.textSize.width + (textData.cellLayout?.bubbleInsets.left ?? 0) + (textData.cellLayout?.bubbleInsets.right ?? 0)
        
        // topContainer is at bubble's trailing edge
        // nameLabel starts at container.leading + 7
        // Check if nameLabel would extend into topContainer area
        let nameLabelLeadingOffset: CGFloat = 7
        let spacing: CGFloat = 8 // minimum spacing between nameLabel and topContainer
        
        // Available width for nameLabel = bubbleWidth - topContainerWidth - spacing - nameLabelLeadingOffset
        let availableWidth = bubbleWidth - topContainerSize.width - spacing - nameLabelLeadingOffset
        
        if nameWidth > availableWidth {
            // Overlap detected, need to move container down
            data.topContainerInsetTop = 10
        } else {
            data.topContainerInsetTop = 0
        }
    }
}
