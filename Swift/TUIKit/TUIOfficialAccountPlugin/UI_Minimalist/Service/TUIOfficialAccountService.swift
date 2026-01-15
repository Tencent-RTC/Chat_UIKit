import Foundation
import TIMCommon
import TUICore
import TUIChat

public class TUIOfficialAccountService: NSObject, TUIServiceProtocol {
    static let sharedInstance = TUIOfficialAccountService()

    @objc public class func swiftLoad() {
        print("TUIOfficialAccountService load")
        _ = TUIOfficialAccountService.sharedInstance
        // Theme resources are loaded from self-contained bundle, no TUICore registration needed

        if V2TIMManager.sharedInstance().getLoginStatus() == V2TIMLoginStatus.STATUS_LOGINED {
            TUIOfficialAccountService.logPluginVersion()
        }
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onLoginSucceeded),
            name: NSNotification.Name("TUILoginSuccessNotification"),
            object: nil
        )
        registerService()
        registerCustomMessageCell()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Service Registration

    private func registerService() {
        TUICore.registerService(TUIOfficialAccountServiceKey.serviceName, object: self)
    }

    private func registerCustomMessageCell() {
        TUIChatConfig_Minimalist.shared.registerCustomMessage(
            businessID: OfficialAccountMessageBusinessID,
            messageCellClassName: "TUIOfficialAccountPlugin.TUIOfficialAccountMessageCell",
            messageCellDataClassName: "TUIOfficialAccountPlugin.TUIOfficialAccountMessageCellData"
        )
    }

    // MARK: - TUIServiceProtocol

    public func onCall(_ method: String, param: [AnyHashable: Any]?) -> Any? {
        guard let param = param else { return nil }

        switch method {
        case TUIOfficialAccountServiceKey.showOfficialAccountListMethod:
            return handleShowOfficialAccountList(param: param)
        case TUIOfficialAccountServiceKey.showOfficialAccountInfoMethod:
            return handleShowOfficialAccountInfo(param: param)
        case TUIOfficialAccountServiceKey.getOfficialAccountInfoMethod:
            return handleGetOfficialAccountInfo(param: param)
        default:
            return nil
        }
    }

    // MARK: - Service Handlers

    private func handleShowOfficialAccountList(param: [AnyHashable: Any]) -> Any? {
        guard let navController = param[TUIOfficialAccountParamKey.navigationController] as? UINavigationController else {
            return nil
        }

        let listVC = TUIOfficialAccountListViewController()
        navController.pushViewController(listVC, animated: true)
        return nil
    }

    private func handleShowOfficialAccountInfo(param: [AnyHashable: Any]) -> Any? {
        guard let navController = param[TUIOfficialAccountParamKey.navigationController] as? UINavigationController,
              let accountID = param[TUIOfficialAccountParamKey.officialAccountID] as? String else {
            return nil
        }

        let isFromChatPage = param[TUIOfficialAccountParamKey.isFromChatPage] as? Bool ?? false
        let infoVC = TUIOfficialAccountInfoViewController(accountID: accountID, isFromChatPage: isFromChatPage)
        navController.pushViewController(infoVC, animated: true)
        return nil
    }

    private func handleGetOfficialAccountInfo(param: [AnyHashable: Any]) -> Any? {
        guard let accountID = param[TUIOfficialAccountParamKey.officialAccountID] as? String else {
            return nil
        }

        // Return account info asynchronously through callback if provided
        // For now, return nil as the actual implementation depends on backend API
        return nil
    }

    // MARK: - Login Notification

    @objc private func onLoginSucceeded() {
        TUIOfficialAccountService.logPluginVersion()
    }

    // MARK: - Version Logging

    static func logPluginVersion() {
        guard let info = Bundle(for: self).infoDictionary else { return }

        let build = info["CFBundleVersion"] as? String ?? ""
        let version = info["CFBundleShortVersionString"] as? String ?? ""
        let content = "TUIOfficialAccount version: \(version), build: \(build)"

        let param: [String: Any] = [
            "logLevel": V2TIMLogLevel.LOG_INFO.rawValue,
            "fileName": "TUIOfficialAccount",
            "funcName": "logPluginVersion",
            "lineNumber": 100,
            "logContent": content
        ]

        guard let dataParam = try? JSONSerialization.data(withJSONObject: param, options: .prettyPrinted),
              let strParam = String(data: dataParam, encoding: .utf8) as? NSObject else {
            print("Failed to serialize param to JSON")
            return
        }

        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "writeLog",
            param: strParam,
            succ: { _ in
                print("TUIOfficialAccount log success")
            },
            fail: { code, desc in
                print("TUIOfficialAccount log error: \(code) \(desc ?? "")")
            }
        )
    }
}
