import TIMCommon
import TUIChat
import TUICore

public class TUIOfficialAccountExtensionObserver: NSObject, TUIExtensionProtocol {
    static let shared = TUIOfficialAccountExtensionObserver()

    @objc public class func swiftLoad() {
        // Register for Minimalist extension
        TUICore.registerExtension(
            "TUICore_TUIContactExtension_ContactMenu_MinimalistExtensionID",
            object: TUIOfficialAccountExtensionObserver.shared
        )
    }

    // MARK: - TUIExtensionProtocol

    public func onGetExtension(_ extensionID: String, param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        switch extensionID {
        case "TUICore_TUIContactExtension_ContactMenu_MinimalistExtensionID":
            return getContactListExtension(param: param)
        default:
            return nil
        }
    }

    // MARK: - Extension Handlers

    private func getContactListExtension(param: [AnyHashable: Any]?) -> [TUIExtensionInfo]? {
        let info = TUIExtensionInfo()
        info.weight = 150
        info.text = TUISwift.timCommonLocalizableString("TUIKitOfficialAccount")
        info.icon = TUISwift.tuiOfficialAccountBundleThemeImage(
            "service_official_account_img",
            defaultImage: "official_account_icon"
        )
        info.onClicked = { [weak self] clickParam in
            guard let navController = clickParam["navigationController"] as? UINavigationController else {
                return
            }
            let listVC = TUIOfficialAccountListViewController()
            navController.pushViewController(listVC, animated: true)
        }
        return [info]
    }
}
