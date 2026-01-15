// Swift/UI/Service/TUIVoiceToTextExtensionObserver.swift

import Foundation
import TIMCommon
import TUIChat
import TUICore

public class TUIVoiceToTextExtensionObserver: NSObject, TUIExtensionProtocol {
    weak var navVC: UINavigationController?
    weak var cellData: TUICommonTextCellData?
    
    static let shared: TUIVoiceToTextExtensionObserver = {
        let instance = TUIVoiceToTextExtensionObserver()
        return instance
    }()
    
    override init() {
        super.init()
        TUICore.registerExtension("TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID", object: self)
        TUICore.registerExtension("TUICore_TUIChatExtension_BottomContainer_MinimalistExtensionID", object: self)
    }
    
    @objc public static func swiftLoad() {
        TUISwift.tuiRegisterThemeResourcePath(TUISwift.tuiVoiceToTextThemePath(), themeModule: TUIThemeModule.voiceToText)
        
        // Initialize auto service for voice message features
        _ = TUIVoiceMessageAutoService.shared
        
        // UI extensions of setting menu (global settings)
        TUICore.registerExtension("TUICore_TUIContactExtension_MeSettingMenu_ClassicExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
        TUICore.registerExtension("TUICore_TUIContactExtension_MeSettingMenu_MinimalistExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
        
        // UI extensions in pop menu when message is long pressed.
        TUICore.registerExtension("TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
        TUICore.registerExtension("TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
        
        // UI extensions for friend profile settings (conversation-level switches)
        TUICore.registerExtension("TUICore_TUIContactExtension_FriendProfileSettingsSwitch_ClassicExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
        TUICore.registerExtension("TUICore_TUIContactExtension_FriendProfileSettingsSwitch_MinimalistExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
        
        // UI extensions for group profile settings (conversation-level switches)
        TUICore.registerExtension("TUICore_TUIChatExtension_GroupProfileSettingsSwitch_ClassicExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
        TUICore.registerExtension("TUICore_TUIChatExtension_GroupProfileSettingsSwitch_MinimalistExtensionID", object: TUIVoiceToTextExtensionObserver.shared)
    }
    
    // MARK: - TUIExtensionProtocol

    public func onRaiseExtension(_ extensionID: String, parentView: UIView, param: [AnyHashable: Any]?) -> Bool {
        guard let data = param?["TUICore_TUIChatExtension_BottomContainer_CellData"] as? TUIMessageCellData,
              data.innerMessage?.elemType == .ELEM_TYPE_SOUND,
              data.innerMessage?.status == .MSG_STATUS_SEND_SUCC
        else {
            return false
        }
        
        var cacheMap = parentView.tui_extValueObj as? [String: Any] ?? [:]
        var cacheView = cacheMap["TUIVoiceToTextView"] as? TUIVoiceToTextView
        
        cacheView?.removeFromSuperview()
        cacheView = nil
        
        let view = TUIVoiceToTextView(data: data)
        parentView.addSubview(view)
        
        cacheMap["TUIVoiceToTextView"] = view
        parentView.tui_extValueObj = cacheMap
        return true
    }
    
    public func onGetExtension(_ extensionID: String, param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        // Settings menu extension (global settings page entry)
        if extensionID == "TUICore_TUIContactExtension_MeSettingMenu_ClassicExtensionID" ||
           extensionID == "TUICore_TUIContactExtension_MeSettingMenu_MinimalistExtensionID" {
            return getSettingsMenuExtension(param: param)
        }
        
        // Pop menu extension for voice-to-text action
        if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID" ||
           extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID" {
            return getPopMenuExtension(param: param)
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
    
    // MARK: - Settings Menu Extension (Global Settings Page Entry)
    
    private func getSettingsMenuExtension(param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        guard let param = param else { return nil }
        if let navVC = param["TUICore_TUIContactExtension_MeSettingMenu_Nav"] as? UINavigationController {
            self.navVC = navVC
        }
        
        let data = TUICommonTextCellData()
        data.key = TUISwift.timCommonLocalizableString("VoiceMessageSettings")
        data.showAccessory = true
        cellData = data
        
        let cell = TUICommonTextCell()
        cell.fill(with: data)
        cell.mm_height(60).mm_width(TUISwift.screen_Width())
        let tap = UITapGestureRecognizer(target: self, action: #selector(onClickedVoiceMessageSettingsCell(_:)))
        cell.addGestureRecognizer(tap)
        
        let info = TUIExtensionInfo()
        var infoData = [String: Any]()
        infoData["TUICore_TUIContactExtension_MeSettingMenu_Weight"] = 440
        infoData["TUICore_TUIContactExtension_MeSettingMenu_View"] = cell
        infoData["TUICore_TUIContactExtension_MeSettingMenu_Data"] = data
        info.data = infoData
        return [info]
    }
    
    @objc func onClickedVoiceMessageSettingsCell(_ cell: TUICommonTextCell) {
        let vc = TUIVoiceMessageSettingsController()
        navVC?.pushViewController(vc, animated: true)
    }
    
    // MARK: - Pop Menu Extension (Voice-to-Text Action)
    
    private func getPopMenuExtension(param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        guard let param = param,
              TUIChatConfig.shared.enablePopMenuConvertAction,
              let cell = param["TUICore_TUIChatExtension_PopMenuActionItem_ClickCell"] as? TUIMessageCell,
              cell.messageData?.innerMessage?.elemType == .ELEM_TYPE_SOUND,
              cell.messageData?.innerMessage?.status == .MSG_STATUS_SEND_SUCC,
              let msg = cell.messageData?.innerMessage,
              !TUIVoiceToTextDataProvider.shouldShowConvertedText(msg),
              !msg.hasRiskContent
        else {
            return nil
        }
        
        let info = TUIExtensionInfo()
        info.weight = 2000
        info.text = TUISwift.timCommonLocalizableString("TUIKitConvertToText")
        info.icon = TUISwift.tuiChatBundleThemeImage("chat_icon_convert_voice_to_text_img", defaultImage: "icon_convert_voice_to_text")
        
        info.onClicked = { _ in
            guard let cellData = cell.messageData else { return }
            let message = cellData.innerMessage
            guard message?.elemType == .ELEM_TYPE_SOUND else { return }
            
            TUIVoiceToTextDataProvider.convertMessage(cellData) { code, _, _, status, text in
                if code != 0 || (text.count == 0 && status == TUIVoiceToTextViewStatus.hidden.rawValue) {
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitConvertToTextFailed"))
                }
                let param = ["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData]
                TUICore.notifyEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey", object: nil, param: param)
            }
        }
        
        return [info]
    }
    
    // MARK: - Friend Profile Settings Switch Extension
    
    private func getFriendProfileSettingsSwitchExtension(param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        guard let param = param,
              let userID = param["userID"] as? String,
              !userID.isEmpty
        else { return nil }
        
        let conversationID = "c2c_\(userID)"
        var extensions: [TUIExtensionInfo] = []
        
        // 1. Auto play voice messages switch
        let autoPlayInfo = createSettingSwitchExtension(
            conversationID: conversationID,
            type: .autoPlayVoice,
            titleKey: "AutoPlayVoice",
            globalEnabled: TUIVoiceToTextConfig.shared.autoPlayVoiceEnabled,
            weight: 200
        )
        extensions.append(autoPlayInfo)
        
        // 2. Auto voice-to-text switch
        let voiceToTextInfo = createSettingSwitchExtension(
            conversationID: conversationID,
            type: .autoVoiceToText,
            titleKey: "AutoVoiceToText",
            globalEnabled: TUIVoiceToTextConfig.shared.autoVoiceToTextEnabled,
            weight: 199
        )
        extensions.append(voiceToTextInfo)
        
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
        
        // 1. Auto play voice messages switch
        let autoPlayInfo = createSettingSwitchExtension(
            conversationID: conversationID,
            type: .autoPlayVoice,
            titleKey: "AutoPlayVoice",
            globalEnabled: TUIVoiceToTextConfig.shared.autoPlayVoiceEnabled,
            weight: 200
        )
        extensions.append(autoPlayInfo)
        
        // 2. Auto voice-to-text switch
        let voiceToTextInfo = createSettingSwitchExtension(
            conversationID: conversationID,
            type: .autoVoiceToText,
            titleKey: "AutoVoiceToText",
            globalEnabled: TUIVoiceToTextConfig.shared.autoVoiceToTextEnabled,
            weight: 199
        )
        extensions.append(voiceToTextInfo)
        
        return extensions
    }
    
    // MARK: - Helper for Creating Setting Extension (Tri-state: On/Off/FollowGlobal)
    
    private func createSettingSwitchExtension(
        conversationID: String,
        type: TUIVoiceMessageSettingType,
        titleKey: String,
        globalEnabled: Bool,
        weight: Int
    ) -> TUIExtensionInfo {
        let conversationSetting = TUIVoiceMessageConversationConfig.shared.getSetting(for: conversationID, type: type)
        
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
        type: TUIVoiceMessageSettingType,
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
            TUIVoiceMessageConversationConfig.shared.removeSetting(for: conversationID, type: type)
            invokeReloadCallback()
        }
        if currentState == 0 {
            followAction.setValue(true, forKey: "checked")
        }
        ac.addAction(followAction)
        
        // On option
        let onAction = UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitOn"), style: .default) { _ in
            TUIVoiceMessageConversationConfig.shared.setSetting(true, for: conversationID, type: type)
            invokeReloadCallback()
        }
        if currentState == 1 {
            onAction.setValue(true, forKey: "checked")
        }
        ac.addAction(onAction)
        
        // Off option
        let offAction = UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitOff"), style: .default) { _ in
            TUIVoiceMessageConversationConfig.shared.setSetting(false, for: conversationID, type: type)
            invokeReloadCallback()
        }
        if currentState == 2 {
            offAction.setValue(true, forKey: "checked")
        }
        ac.addAction(offAction)
        
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        viewController.present(ac, animated: true, completion: nil)
    }
}
