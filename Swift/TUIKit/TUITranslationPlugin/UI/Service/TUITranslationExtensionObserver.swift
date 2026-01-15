import TIMCommon
import TUIChat
import TUICore
import UIKit

public class TUITranslationExtensionObserver: NSObject, TUIExtensionProtocol, TUIServiceProtocol {
    weak var navVC: UINavigationController?
    weak var cellData: TUICommonTextCellData?
    
    static let sharedInstance: TUITranslationExtensionObserver = {
        let instance = TUITranslationExtensionObserver()
        return instance
    }()
    
    override init() {
        super.init()
        TUICore.registerExtension("TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID", object: self)
        TUICore.registerExtension("TUICore_TUIChatExtension_BottomContainer_MinimalistExtensionID", object: self)
        
        // Register service for translation state queries
        TUICore.registerService("TUICore_TUITranslationService", object: self)
    }
    
    @objc public static func swiftLoad() {
        TUISwift.tuiRegisterThemeResourcePath(TUISwift.tuiTranslationThemePath(), themeModule: TUIThemeModule.translation)
        
        // UI extensions in pop menu when message is long pressed.
        TUICore.registerExtension("TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID", object: TUITranslationExtensionObserver.sharedInstance)
        TUICore.registerExtension("TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID", object: TUITranslationExtensionObserver.sharedInstance)
        
        // UI extensions of setting.
        TUICore.registerExtension("TUICore_TUIContactExtension_MeSettingMenu_ClassicExtensionID", object: TUITranslationExtensionObserver.sharedInstance)
        TUICore.registerExtension("TUICore_TUIContactExtension_MeSettingMenu_MinimalistExtensionID", object: TUITranslationExtensionObserver.sharedInstance)
        
        // Initialize translation data provider to register message listener
        _ = TUITranslationDataProvider.shared
    }
    
    // MARK: - TUIServiceProtocol
    
    public func onCall(_ method: String, param: [AnyHashable: Any]?) -> Any? {
        if method == "TUICore_TUITranslationService_GetShouldHideOriginalTextMethod" {
            guard let message = param?["message"] as? V2TIMMessage else {
                return NSNumber(value: false)
            }
            let shouldHide = TUITranslationDataProvider.shouldHideOriginalText(message)
            return NSNumber(value: shouldHide)
        }
        return nil
    }
    
    // MARK: - TUIExtensionProtocol

    public func onRaiseExtension(_ extensionID: String, parentView: UIView, param: [AnyHashable: Any]?) -> Bool {
        if extensionID == "TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID" ||
            extensionID == "TUICore_TUIChatExtension_BottomContainer_MinimalistExtensionID"
        {
            guard let data = param?["TUICore_TUIChatExtension_BottomContainer_CellData"] as? TUIMessageCellData, data.innerMessage?.elemType == .ELEM_TYPE_TEXT else {
                return false
            }
            
            var cacheMap = parentView.tui_extValueObj as? [String: Any] ?? [:]
            var cacheView = cacheMap["TUITranslationView"] as? TUITranslationView
            
            cacheView?.removeFromSuperview()
            cacheView = nil
            
            let view = TUITranslationView(data: data)
            parentView.addSubview(view)
            cacheMap["TUITranslationView"] = view
            parentView.tui_extValueObj = cacheMap
            return true
        }
        return false
    }
    
    public func onGetExtension(_ extensionID: String, param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID" ||
            extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID"
        {
            guard let param = param, let cell = param["TUICore_TUIChatExtension_PopMenuActionItem_ClickCell"] as? TUIMessageCell else { return nil }
            
            if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID" {
                if !(cell is TUITextMessageCell || cell is TUIReferenceMessageCell || cell is TUIReplyMessageCell) {
                    return nil
                }
            } else if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID" {
                if !(cell is TUITextMessageCell_Minimalist || cell is TUIReferenceMessageCell_Minimalist || cell is TUIReplyMessageCell_Minimalist) {
                    return nil
                }
            }
            
            if cell.messageData?.innerMessage?.elemType != .ELEM_TYPE_TEXT {
                return nil
            }
            if TUITranslationDataProvider.shouldShowTranslation(cell.messageData?.innerMessage ?? V2TIMMessage()) {
                return nil
            }
            if !isSelectAllContentOfMessage(cell) {
                return nil
            }
            if !TUIChatConfig.shared.enablePopMenuTranslateAction {
                return nil
            }
            if cell.messageData?.innerMessage?.hasRiskContent ?? false {
                return nil
            }
            
            let info = TUIExtensionInfo()
            info.text = TUISwift.timCommonLocalizableString("TUIKitTranslate")
            if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID" {
                info.icon = TUISwift.tuiChatBundleThemeImage("chat_icon_translate_img", defaultImage: "icon_translate")
                info.weight = 2000
            } else if extensionID == "TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID" {
                info.icon = UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_translate"))
                info.weight = 800
            }
            info.onClicked = { _ in
                guard let cellData = cell.messageData else { return }
                let message = cellData.innerMessage
                if message?.elemType != .ELEM_TYPE_TEXT {
                    return
                }
                TUITranslationDataProvider.translateMessage(cellData) { _, _, _, _, _ in
                    let param: [String: Any] = ["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData]
                    TUICore.notifyEvent("TUICore_TUIPluginNotify",
                                        subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey",
                                        object: nil, param: param)
                }
            }
            return [info]
        } else if extensionID == "TUICore_TUIContactExtension_MeSettingMenu_ClassicExtensionID" || extensionID == "TUICore_TUIContactExtension_MeSettingMenu_MinimalistExtensionID" {
            guard let param = param else { return nil }
            if let navVC = param["TUICore_TUIContactExtension_MeSettingMenu_Nav"] as? UINavigationController {
                self.navVC = navVC
            }
            
            let data = TUICommonTextCellData()
            data.key = TUISwift.timCommonLocalizableString("TranslationSettings")
            data.showAccessory = true
            cellData = data
            
            let cell = TUICommonTextCell()
            cell.fill(with: data)
            cell.mm_height(60).mm_width(TUISwift.screen_Width())
            let tap = UITapGestureRecognizer(target: self, action: #selector(onClickedTargetLanguageCell(_:)))
            cell.addGestureRecognizer(tap)
            
            let info = TUIExtensionInfo()
            var infoData = [String: Any]()
            infoData["TUICore_TUIContactExtension_MeSettingMenu_Weight"] = 450
            infoData["TUICore_TUIContactExtension_MeSettingMenu_View"] = cell
            infoData["TUICore_TUIContactExtension_MeSettingMenu_Data"] = data
            info.data = infoData
            return [info]
        }
        return nil
    }
    
    @objc func onClickedTargetLanguageCell(_ cell: TUICommonTextCell) {
        let vc = TUITranslationSettingsController()
        navVC?.pushViewController(vc, animated: true)
    }
    
    func isSelectAllContentOfMessage(_ cell: TUIMessageCell) -> Bool {
        if let textCell = cell as? TUITextMessageCell {
            if let selectContent = textCell.selectContent, !selectContent.isEmpty {
                return true
            } else {
                let selectedString = textCell.textView.attributedText.attributedSubstring(from: textCell.textView.selectedRange)
                return selectedString.length == 0 || selectedString.length == textCell.textView.attributedText.length
            }
        } else if let refCell = cell as? TUIReferenceMessageCell {
            if let selectContent = refCell.selectContent, !selectContent.isEmpty {
                return true
            } else {
                let selectedString = refCell.textView.attributedText.attributedSubstring(from: refCell.textView.selectedRange)
                return selectedString.length == 0 || selectedString.length == refCell.textView.attributedText.length
            }
        } else if let replyCell = cell as? TUIReplyMessageCell {
            if let selectContent = replyCell.selectContent, !selectContent.isEmpty {
                return true
            } else {
                let selectedString = replyCell.textView.attributedText.attributedSubstring(from: replyCell.textView.selectedRange)
                return selectedString.length == 0 || selectedString.length == replyCell.textView.attributedText.length
            }
        }
        if cell is TUITextMessageCell_Minimalist || cell is TUIReferenceMessageCell_Minimalist || cell is TUIReplyMessageCell_Minimalist {
            return true
        }
        return false
    }
}
