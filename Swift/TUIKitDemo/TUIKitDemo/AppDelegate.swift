import TIMAppKit
import TIMCommon

import TIMPush
import TUIChat
import TUIContact
import TUICore
import UIKit
import UserNotifications

#if ENABLELIVE
import TXLiteAVSDK_TRTC
#endif
@main
class AppDelegate: UIResponder, UIApplicationDelegate, V2TIMConversationListener, TUILoginListener, TUIThemeSelectControllerDelegate, TUILanguageSelectControllerDelegate, V2TIMAPNSListener, V2TIMSDKListener, TIMPushDelegate, TIMPushListener {
    var window: UIWindow?
    let contactDataProvider: TUIContactViewDataProvider = .init()
    private var _loginConfig: TUILoginConfig?
    weak var callsRecordItem: TUITabBarItem?
    var preloadMainVC: UITabBarController?
    var userID: String?
    var userSig: String?
    var clickNotificationInfo: [String: String] = [:]
    var lastLoginResultCode = 0
    var allowRotation = false
    var unReadCount: UInt = 0

    var pendencyCntObservation: NSKeyValueObservation?

    static var sharedInstance = AppDelegate()

    // MARK: - Life cycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.sharedInstance = self

        lastLoginResultCode = 0

        NSSetUncaughtExceptionHandler { exception in
            print("CRASH: \(exception)")
            print("Stack Trace: \(exception.callStackSymbols)")
        }

        TUISwift.tuiRegisterThemeResourcePath(TUISwift.tuiBundlePath("TUIDemoTheme", key: "TIMAppKit.TUIKit"), themeModule: TUIThemeModule.demo)
        TUIThemeSelectController.applyLastTheme()
        setupListener()
        setupGlobalUI()
        setupConfig()
        tryPreloadMainVC()
        tryAutoLogin()
        TIMPushManager.addPushListener(listener: self);
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return allowRotation ? .all : .portrait
    }

    @objc func startFullScreen() {
        allowRotation = true
        if #available(iOS 16.0, *) {
            self.window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    @objc func endFullScreen() {
        allowRotation = false
        if #available(iOS 16.0, *) {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: UIInterfaceOrientationMask.portrait)) { error in
                print("Error requesting geometry update: \(error.localizedDescription)")
            }
        } else {
            if UIDevice.current.responds(to: NSSelectorFromString("setOrientation:")) {
                UIDevice.current.setValue(UIDeviceOrientation.landscapeLeft.rawValue, forKey: "orientation")
                UINavigationController.attemptRotationToDeviceOrientation()
            }
        }
    }

    // MARK: - Public

    func getLoginController() -> UIViewController {
        let board = UIStoryboard(name: "Main", bundle: Bundle.main)
        let login = board.instantiateViewController(withIdentifier: "LoginController") as! LoginController
        let nav = UINavigationController(rootViewController: login)
        return nav
    }

    func applyPrivateBasicInfo() {
        // Subclass override
    }

    func tryPreloadMainVC() {
        TCLoginModel.sharedInstance.loadIsDirectlyLogin()
        TCLoginModel.sharedInstance.loadLastLoginInfo()
        userID = TCLoginModel.sharedInstance.userID
        userSig = TCLoginModel.sharedInstance.userSig
        if userID == nil || userSig == nil {
            window?.rootViewController = getLoginController()
            NotificationCenter.default.post(name: NSNotification.Name("TUILoginShowPrivacyPopViewNotfication"), object: nil)
            return
        }
        applyPrivateBasicInfo()

        preloadMainVC = getMainController()

        let config = TUILoginConfig()
        config.initLocalStorageOnly = true
        TUILogin.login(Int32(SDKAPPID), userID: userID!, userSig: userSig!, config: config, succ: {
            self.window?.rootViewController = self.preloadMainVC
            self.redpoint_setupTotalUnreadCount()
        }, fail: { code, msg in
            print("preloadMainController failed, code:\(code) desc:\(msg ?? "")")
        })
    }

    @objc func loginSDK(_ userID: String, userSig: String, succ: TSucc?, fail: TFail?) {
        self.userID = userID
        self.userSig = userSig
        TUILogin.login(Int32(SDKAPPID), userID: userID, userSig: userSig, config: loginConfig, succ: {
            if self.preloadMainVC != nil, self.window?.rootViewController == self.preloadMainVC {
                // main vc has load
            } else {
                self.window?.rootViewController = self.getMainController()
            }
            self.redpoint_setupTotalUnreadCount()
            TUITool.makeToast(NSLocalizedString("AppLoginSucc", comment: ""), duration: 1)
            succ?()
        }, fail: { code, msg in
            self.lastLoginResultCode = Int(code)
            self.window?.rootViewController = self.getLoginController()
            NotificationCenter.default.post(name: NSNotification.Name("TUILoginShowPrivacyPopViewNotfication"), object: nil)
            fail?(code, msg)
        })
    }

    // MARK: - Private

    func setupListener() {
        TUILogin.add(self)
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
        V2TIMManager.sharedInstance().addConversationListener(listener: self)
        V2TIMManager.sharedInstance().setAPNSListener(apnsListener: self)

        NotificationCenter.default.addObserver(self, selector: #selector(updateMarkUnreadCount(_:)), name: NSNotification.Name("TUIKitNotification_onConversationMarkUnreadCountChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onLoginSucc), name: NSNotification.Name("TUILoginSuccessNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onLogoutSucc), name: NSNotification.Name("TUILogoutSuccessNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDisplayCallsRecordForMinimalist(_:)), name: NSNotification.Name(kEnableCallsRecord_mini), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDisplayCallsRecordForClassic(_:)), name: NSNotification.Name(kEnableCallsRecord), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startFullScreen), name: NSNotification.Name("kEnableAllRotationOrientationNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(endFullScreen), name: NSNotification.Name("kDisableAllRotationOrientationNotification"), object: nil)
    }

    func tryAutoLogin() {
        let userID = TCLoginModel.sharedInstance.userID ?? nil
        let userSig = TCLoginModel.sharedInstance.userSig ?? nil
        if userID != nil, userSig != nil {
            loginSDK(userID!, userSig: userSig!, succ: nil, fail: nil)
        }
    }

    @objc func onLogoutSucc() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    // MARK: - - Setup UI

    func setupGlobalUI() {
        _ = UIViewController.swizzleSetTitle
        setupChatSecurityWarningView()
    }

    func setupChatSecurityWarningView() {
        let tips = NSLocalizedString("ChatSecurityWarning", comment: "")
        let buttonTitle = NSLocalizedString("ChatSecurityWarningReport", comment: "")
        let gotButtonTitle = NSLocalizedString("ChatSecurityWarningGot", comment: "")

        var tipsView = TUIWarningView(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: 0),
                                      tips: tips,
                                      buttonTitle: buttonTitle,
                                      buttonAction: nil,
                                      gotButtonTitle: gotButtonTitle,
                                      gotButtonAction: nil)

        tipsView.buttonAction = {
            if let url = URL(string: "https://cloud.tencent.com/act/event/report-platform") {
                TUITool.openLink(with: url)
            }
        }
        tipsView.gotButtonAction = { [weak tipsView] in
            guard let tipsView = tipsView else { return }
            tipsView.frame = .zero
            tipsView.removeFromSuperview()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: TUICore_TUIChatExtension_ChatViewTopArea_ChangedNotification), object: nil)
        }

        TUIBaseChatViewController.customTopView = tipsView
    }

    var loginConfig: TUILoginConfig {
        if _loginConfig == nil {
            _loginConfig = TUILoginConfig()
            #if DEBUG
            _loginConfig?.logLevel = TUILogLevel.LOG_DEBUG
            #else
            _loginConfig?.logLevel = TUILogLevel.LOG_INFO
            #endif
            _loginConfig?.onLog = { [weak self] logLevel, logContent in
                self?.onLog(logLevel, logContent: logContent ?? "")
            }
        }
        return _loginConfig!
    }

    // MARK: - V2TIMConversationListener

    @objc func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        print("\(#function), totalUnreadCount:\(totalUnreadCount)")
    }

    // MARK: V2TIMSDKListener

    func onConnecting() {}

    func onConnectFailed(code: Int, err: String) {}

    func onConnectSuccess() {
        let lastLoginIsNetworkError = (lastLoginResultCode >= 9501 && lastLoginResultCode <= 9525)
        if V2TIMManager.sharedInstance().getLoginStatus() == V2TIMLoginStatus.STATUS_LOGOUT, userID?.isEmpty == false, userSig?.isEmpty == false, lastLoginIsNetworkError {
            lastLoginResultCode = 0
            TUILogin.login(Int32(SDKAPPID), userID: userID!, userSig: userSig!, config: loginConfig, succ: {
                self.redpoint_setupTotalUnreadCount()
                TUITool.makeToast(NSLocalizedString("AppLoginSucc", comment: ""), duration: 1)
            }, fail: { code, _ in
                let currentLoginIsNetworkError = (code >= 9501 && code <= 9525)
                if !currentLoginIsNetworkError {
                    self.window?.rootViewController = self.getLoginController()
                    NotificationCenter.default.post(name: NSNotification.Name("TUILoginShowPrivacyPopViewNotfication"), object: nil)
                }
                self.lastLoginResultCode = Int(code)
            })
        }
    }

    // MARK: - TUILoginListener

    func onConnectFailed(_ code: Int32, err: String?) {}

    func onUserSigExpired() {
        onUserStatus(.sigExpired)
    }

    func onKickedOffline() {
        onUserStatus(.forceOffline)
    }

    func onLog(_ logLevel: Int, logContent: String) {}

    func onUserStatus(_ status: TUIUserStatus) {
        switch status {
        case TUIUserStatus.forceOffline:
            showKickOffAlert()
        case TUIUserStatus.reConnFailed:
            print("\(#function), status:\(status)")
        case TUIUserStatus.sigExpired:
            userSigExpiredAction()
            print("\(#function), status:\(status)")
        default:
            break
        }
    }

    func showKickOffAlert() {
        showAlertWithTitle(NSLocalizedString("AppOfflineTitle", comment: ""), message: NSLocalizedString("AppOfflineDesc", comment: ""), cancelAction: { _, _ in
            TUILogin.logout({
                print("logout sdk succeed")
            }, fail: { code, msg in
                print("logout sdk failed, code: \(code), msg: \(msg ?? "")")
            })
            self.window?.rootViewController = self.getLoginController()
            NotificationCenter.default.post(name: NSNotification.Name("TUILoginShowPrivacyPopViewNotfication"), object: nil)
        }, confirmAction: { _, _ in
            let userID = TCLoginModel.sharedInstance.userID
            let userSig = TCLoginModel.sharedInstance.userSig
            self.loginSDK(userID ?? "", userSig: userSig ?? "", succ: nil, fail: nil)
        })
    }

    func userSigExpiredAction() {
        TUILogin.logout({
            print("logout sdk succeed")
        }, fail: { code, msg in
            print("logout sdk failed, code: \(code), msg: \(msg ?? "")")
        })
        window?.rootViewController = getLoginController()
        NotificationCenter.default.post(name: NSNotification.Name("TUILoginShowPrivacyPopViewNotfication"), object: nil)
    }

    // MARK: - TUILanguageSelectControllerDelegate

    func onSelectLanguage(_ cellModel: TUILanguageSelectCellModel) {
        UserDefaults.standard.set(true, forKey: "need_recover_login_page_info")
        UserDefaults.standard.synchronize()

        let loginVc = getLoginController()
        var navVc: UINavigationController?
        if let nav = loginVc as? UINavigationController {
            navVc = nav
        } else {
            navVc = loginVc.navigationController
        }
        guard let nav = navVc else { return }

        let languageVc = TUILanguageSelectController()
        languageVc.delegate = self
        nav.pushViewController(languageVc, animated: false)

        DispatchQueue.main.async {
            TUITool.applicationKeywindow()?.rootViewController = nav
        }

        setupChatSecurityWarningView()
    }

    // MARK: - ThemeSelectControllerDelegate

    func onSelectTheme(_ cellModel: TUIThemeSelectCollectionViewCellModel) {
        UserDefaults.standard.set(true, forKey: "need_recover_login_page_info")
        UserDefaults.standard.synchronize()

        let loginVc = getLoginController()
        var navVc: UINavigationController?
        if let nav = loginVc as? UINavigationController {
            navVc = nav
        } else {
            navVc = loginVc.navigationController
        }
        guard let nav = navVc else { return }

        let themeVc = TUIThemeSelectController()
        themeVc.disable = true
        themeVc.delegate = self
        themeVc.view.makeToastActivity(TUICSToastPositionCenter)
        nav.pushViewController(themeVc, animated: false)

        DispatchQueue.main.async {
            TUITool.applicationKeywindow()?.rootViewController = nav
            if #available(iOS 13.0, *) {
                if cellModel.themeID == "system" {
                    TUITool.applicationKeywindow()?.overrideUserInterfaceStyle = .unspecified
                } else if cellModel.themeID == "dark" {
                    TUITool.applicationKeywindow()?.overrideUserInterfaceStyle = .dark
                } else {
                    TUITool.applicationKeywindow()?.overrideUserInterfaceStyle = .light
                }
            }
            themeVc.view.hideToastActivity()
            themeVc.disable = false
        }
    }

    // MARK: - NSNotification

    // @objc func updateMarkUnreadCount(_ notice: Notification) {}

    @objc func onDisplayCallsRecordForClassic(_ notice: Notification) {
        onDisplayCallsRecord(notice, isMinimalist: false)
    }

    @objc func onDisplayCallsRecordForMinimalist(_ notice: Notification) {
        onDisplayCallsRecord(notice, isMinimalist: true)
    }

    func onDisplayCallsRecord(_ notice: Notification, isMinimalist: Bool) {
        guard let tabVC = window?.rootViewController as? TUITabBarController else { return }
        guard let value = notice.object as? NSNumber else { return }
        var items = tabVC.tabBarItems
        let isOn = value.boolValue
        if isOn {
            if let callsRecordItem = callsRecordItem {
                items.removeAll(where: { $0.identity == callsRecordItem.identity })
            }
            if let item = getCallsRecordTabBarItem(isMinimalist) {
                items.insert(item, at: 1)
                callsRecordItem = item
            }
            tabVC.setTabBarItems(items)
        } else {
            if let callsRecordItem = callsRecordItem {
                items.removeAll(where: { $0.identity == callsRecordItem.identity })
            }
            tabVC.setTabBarItems(items)
        }

        tabVC.layoutBadgeViewIfNeeded()
    }

    // MARK: - Other

    typealias CancelHandler = (UIAlertAction, String?) -> Void
    typealias ConfirmHandler = (UIAlertAction, String?) -> Void

    func showAlertWithTitle(_ title: String, message: String, cancelAction: CancelHandler?, confirmAction: ConfirmHandler?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let cancel = UIAlertAction(title: NSLocalizedString("AppCancelRelogin", comment: ""), style: .cancel) { action in
            cancelAction?(action, nil)
        }

        let confirm = UIAlertAction(title: NSLocalizedString("AppConfirmRelogin", comment: ""), style: .default) { action in
            confirmAction?(action, nil)
        }

        alertController.tuitheme_addAction(cancel)
        alertController.tuitheme_addAction(confirm)

        window?.rootViewController?.present(alertController, animated: false, completion: nil)
    }

    // MARK: - Classic & Minimalist

    func setupConfig() {
        if TUIStyleSelectViewController.isClassicEntrance() {
            setupConfig_Classic()
        } else {
            setupConfig_Minimalist()
        }
    }

    func getMainController() -> UITabBarController {
        if TUIStyleSelectViewController.isClassicEntrance() {
            return getMainController_Classic()
        } else {
            return getMainController_Minimalist()
        }
    }

    func getMainController_Classic() -> UITabBarController {
        var backimg = TUISwift.tuiDynamicImage("nav_back_img", themeModule: TUIThemeModule.timCommon, defaultImage: UIImage.safeImage(TUISwift.timCommonImagePath("nav_back")))
        backimg = backimg.rtlImageFlippedForRightToLeftLayoutDirection()

        let tbc = TUITabBarController()
        var items: [TUITabBarItem] = []

        let msgItem = TUITabBarItem()
        msgItem.title = NSLocalizedString("TabBarItemMessageText", comment: "")
        msgItem.identity = "msgItem"
        msgItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_msg_selected_img", defaultImage: UIImage.safeImage("session_selected"))
        msgItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_msg_normal_img", defaultImage: UIImage.safeImage("session_normal"))
        let msgNav = TUINavigationController(rootViewController: ConversationController())
        msgNav.navigationItemBackArrowImage = backimg
        msgItem.controller = msgNav
        msgItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: TUISwift.tController_Background_Color(), dark: TUISwift.tController_Background_Color_Dark())
        msgItem.badgeView = TUIBadgeView()
        msgItem.badgeView?.clearCallback = { [weak self] in
            self?.redpoint_clearUnreadMessage()
        }
        items.append(msgItem)

        if let callsItem = getCallsRecordTabBarItem(false) {
            items.append(callsItem)
            callsRecordItem = callsItem
        }

        let contactItem = TUITabBarItem()
        contactItem.title = NSLocalizedString("TabBarItemContactText", comment: "")
        contactItem.identity = "contactItem"
        contactItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_contact_selected_img", defaultImage: UIImage.safeImage("contact_selected"))
        contactItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_contact_normal_img", defaultImage: UIImage.safeImage("contact_normal"))
        let contactNav = TUINavigationController(rootViewController: ContactsController())
        contactNav.navigationItemBackArrowImage = backimg
        contactItem.controller = contactNav
        contactItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: TUISwift.tController_Background_Color(), dark: TUISwift.tController_Background_Color_Dark())
        contactItem.badgeView = TUIBadgeView()
        items.append(contactItem)

        let setItem = TUITabBarItem()
        setItem.title = NSLocalizedString("TabBarItemMeText", comment: "")
        setItem.identity = "setItem"
        setItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_me_selected_img", defaultImage: UIImage.safeImage("myself_selected"))
        setItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_me_normal_img", defaultImage: UIImage.safeImage("myself_normal"))
        let setVC = SettingController()
        setVC.lastLoginUser = userID
        setVC.confirmLogout = {
            TUILogin.logout({
                TCLoginModel.sharedInstance.clearLoginedInfo()
                let loginVc = self.getLoginController()
                self.window?.rootViewController = loginVc
                NotificationCenter.default.post(name: NSNotification.Name("TUILoginShowPrivacyPopViewNotfication"), object: nil)
            }, fail: { _, _ in
                print("logout fail")
            })
        }
        let setNav = TUINavigationController(rootViewController: setVC)
        setNav.navigationItemBackArrowImage = backimg
        setItem.controller = setNav
        setItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: TUISwift.tController_Background_Color(), dark: TUISwift.tController_Background_Color_Dark())
        items.append(setItem)
        tbc.setTabBarItems(items)

        return tbc
    }

    func setupConfig_Classic() {
        if let _ = UserDefaults.standard.object(forKey: kEnableMsgReadStatus) {
            TUIChatConfig.shared.msgNeedReadReceipt = UserDefaults.standard.bool(forKey: kEnableMsgReadStatus)
        } else {
            TUIChatConfig.shared.msgNeedReadReceipt = false
            UserDefaults.standard.set(false, forKey: kEnableMsgReadStatus)
            UserDefaults.standard.synchronize()
        }
        TUIConfig.default().displayOnlineStatusIcon = UserDefaults.standard.bool(forKey: kEnableOnlineStatus)
        TUIChatConfig.shared.enableMultiDeviceForCall = false

        if UserDefaults.standard.object(forKey: kEnableCallsRecord) == nil {
            UserDefaults.standard.set(false, forKey: kEnableCallsRecord)
            UserDefaults.standard.synchronize()
        }
    }

    func setupConfig_Minimalist() {
        if let _ = UserDefaults.standard.object(forKey: kEnableMsgReadStatus_mini) {
            TUIChatConfig.shared.msgNeedReadReceipt = UserDefaults.standard.bool(forKey: kEnableMsgReadStatus_mini)
        } else {
            TUIChatConfig.shared.msgNeedReadReceipt = false
            UserDefaults.standard.set(false, forKey: kEnableMsgReadStatus_mini)
            UserDefaults.standard.synchronize()
        }
        TUIConfig.default().displayOnlineStatusIcon = UserDefaults.standard.bool(forKey: kEnableOnlineStatus_mini)
        TUIChatConfig.shared.enableMultiDeviceForCall = false
        TUIConfig.default().avatarType = TUIKitAvatarType.TAvatarTypeRounded

        if UserDefaults.standard.object(forKey: kEnableCallsRecord_mini) == nil {
            UserDefaults.standard.set(true, forKey: kEnableCallsRecord_mini)
            UserDefaults.standard.synchronize()
        }
    }

    @objc func onSelectStyle(_ cellModel: TUIStyleSelectCellModel) {
        UserDefaults.standard.set(true, forKey: "need_recover_login_page_info")
        UserDefaults.standard.synchronize()
        reloadCombineData()

        let loginVc = getLoginController()
        var navVc: UINavigationController?
        if let nav = loginVc as? UINavigationController {
            navVc = nav
        } else {
            navVc = loginVc.navigationController
        }
        guard let nav = navVc else { return }

        let styleSelectVC = TUIStyleSelectViewController()
        styleSelectVC.delegate = self as? TUIStyleSelectControllerDelegate
        nav.pushViewController(styleSelectVC, animated: false)

        DispatchQueue.main.async {
            TUITool.applicationKeywindow()?.rootViewController = nav
            if !TUIStyleSelectViewController.isClassicEntrance() {
                TUIThemeSelectController.applyTheme("light")
                UserDefaults.standard.set("light", forKey: "current_theme_id")
                UserDefaults.standard.synchronize()
            }
            self.setupChatSecurityWarningView()
        }
    }

    func reloadCombineData() {
        setupConfig()
    }

    func getMainController_Minimalist() -> UITabBarController {
        let backimg = UIImage.safeImage("icon_back_blue").rtlImageFlippedForRightToLeftLayoutDirection()

        let tbc = TUITabBarController()
        var items: [TUITabBarItem] = []

        let msgItem = TUITabBarItem()
        msgItem.title = NSLocalizedString("TabBarItemMessageText_mini", comment: "")
        msgItem.identity = "msgItem"
        msgItem.selectedImage = TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("session_selected")))
        msgItem.normalImage = TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("session_normal")))
        let convVC = ConversationController_Minimalist()
        convVC.getUnReadCount = { [weak self] in
            return UInt(self?.unReadCount ?? 0)
        }
        convVC.clearUnreadMessage = { [weak self] in
            self?.redpoint_clearUnreadMessage()
        }

        let msgNav = TUINavigationController(rootViewController: convVC)
        msgItem.controller = msgNav

        msgNav.navigationItemBackArrowImage = backimg
        msgNav.navigationBackColor = .white
        msgItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: .white, dark: TUISwift.tController_Background_Color_Dark())
        msgItem.badgeView = TUIBadgeView()
        msgItem.badgeView?.clearCallback = { [weak self] in
            self?.redpoint_clearUnreadMessage()
        }
        items.append(msgItem)

        if let callsItem = getCallsRecordTabBarItem(true) {
            items.append(callsItem)
            callsRecordItem = callsItem
        }

        let contactItem = TUITabBarItem()
        contactItem.title = NSLocalizedString("TabBarItemContactText_mini", comment: "")
        contactItem.identity = "contactItem"
        contactItem.selectedImage = TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("contact_selected")))
        contactItem.normalImage = TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("contact_normal")))
        let contactNav = TUINavigationController(rootViewController: ContactsController_Minimalist())
        contactNav.navigationItemBackArrowImage = backimg
        contactNav.navigationBackColor = .white
        contactItem.controller = contactNav
        contactItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: .white, dark: TUISwift.tController_Background_Color_Dark())
        contactItem.badgeView = TUIBadgeView()
        items.append(contactItem)

        let setItem = TUITabBarItem()
        setItem.title = NSLocalizedString("TabBarItemSettingText_mini", comment: "")
        setItem.identity = "setItem"
        setItem.selectedImage = TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("setting_selected")))
        setItem.normalImage = TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("setting_normal")))
        let setVC = SettingController_Minimalist()
        setVC.lastLoginUser = userID
        setVC.confirmLogout = {
            TUILogin.logout({
                TCLoginModel.sharedInstance.clearLoginedInfo()
                let loginVc = self.getLoginController()
                self.window?.rootViewController = loginVc
                NotificationCenter.default.post(name: NSNotification.Name("TUILoginShowPrivacyPopViewNotfication"), object: nil)
            }, fail: { _, _ in
                print("logout fail")
            })
        }

        let setNav = TUINavigationController(rootViewController: setVC)
        setNav.navigationItemBackArrowImage = backimg
        setNav.navigationBackColor = .white
        setItem.controller = setNav
        setItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: .white, dark: TUISwift.tController_Background_Color_Dark())
        items.append(setItem)
        tbc.setTabBarItems(items)

        tbc.tabBar.backgroundColor = .white
        tbc.tabBar.barTintColor = .white
        return tbc
    }

    func getCallsRecordTabBarItem(_ isMinimalist: Bool) -> TUITabBarItem? {
        let showCallsRecord = isMinimalist ? UserDefaults.standard.bool(forKey: kEnableCallsRecord_mini) : UserDefaults.standard.bool(forKey: kEnableCallsRecord)
        let callsVc = TUICallingHistoryViewController.createCallingHistoryViewController(isMimimalist: isMinimalist)
        if showCallsRecord, let callsVc = callsVc {
            let title = isMinimalist
                ? NSLocalizedString("TabBarItemCallsRecordText_mini", comment: "")
                : NSLocalizedString("TabBarItemCallsRecordText_mini", comment: "")
            let selected = isMinimalist
                ? TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("tab_calls_selected")))
                : TUISwift.tuiDemoDynamicImage("tab_calls_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("tab_calls_selected")))
            let normal = isMinimalist
                ? TUISwift.tuiDynamicImage("", themeModule: .demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("tab_calls_normal")))
                : TUISwift.tuiDemoDynamicImage("tab_calls_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("tab_calls_normal")))
            let callsItem = TUITabBarItem()
            callsItem.title = title
            callsItem.identity = "callsItem"
            callsItem.selectedImage = selected
            callsItem.normalImage = normal
            let callNav = TUINavigationController(rootViewController: callsVc)
            callNav.navigationBackColor = .white
            callsItem.controller = callNav

            return callsItem
        }
        return nil
    }

    // MARK: - TIMPush

    // TIMPushDelegate
    @objc func businessID() -> Int32 {
        let kAPNSBusiIdByType = UserDefaults.standard.integer(forKey: "kAPNSBusiIdByType")
        if kAPNSBusiIdByType > 0 {
            return Int32(kAPNSBusiIdByType)
        }
        return Int32(Int(kAPNSBusiId))
    }

    @objc func applicationGroupID() -> String {
        return ""
    }

    @objc func onRemoteNotificationReceived(_ notice: String?) -> Bool {
        /*
         - If true is returned, TIMPush will no longer execute the built-in TUIKit offline push parsing logic, leaving it entirely to you to handle;
                 let ext = notice
                 let info = OfflinePushExtInfo.create(withExtString: ext)
                 return true
         
        - If false is returned, TIMPush will continue to execute the built-in TUIKit offline push parsing logic and continue the callback - navigateToBuiltInChatViewController:groupID:
               return false
         
        */
        
        return false
    }

    @objc func navigateToBuiltInChatViewController(userID: String?, groupID: String?) {
        if V2TIMManager.sharedInstance().getLoginStatus() == .STATUS_LOGINED {
            navigateToBuiltInChatViewControllerImpl(userID, groupID: groupID)
        } else {
            if let userID = userID {
                clickNotificationInfo["userID"] = userID
            }
            if let groupID = groupID {
                clickNotificationInfo["groupID"] = groupID
            }
        }
    }

    @objc func onLoginSucc() {
        let userID = clickNotificationInfo["userID"]
        let groupID = clickNotificationInfo["groupID"]
        if userID != nil || groupID != nil {
            self.navigateToBuiltInChatViewControllerImpl(userID, groupID: groupID)
            self.clickNotificationInfo.removeAll()
        }
    }

   @objc func navigateToBuiltInChatViewControllerImpl(_ userID: String?, groupID: String?) {
        let tab: UITabBarController = getMainController()
        if tab.selectedIndex != 0 {
            tab.selectedIndex = 0
        }
        window?.rootViewController = tab
        guard let nav = tab.selectedViewController as? UINavigationController else { return }

        guard let vc = nav.viewControllers.first else { return }
        // Check if it's ConversationController or ConversationController_Minimalist
        if !vc.isKind(of: NSClassFromString("ConversationController") ?? NSObject.self) &&
           !vc.isKind(of: NSClassFromString("ConversationController_Minimalist") ?? NSObject.self) {
            return
        }
        
        // Use the correct method signature matching OC version: pushToChatViewController:userID:
        if vc.responds(to: NSSelectorFromString("pushToChatViewController:userID:")) {
            vc.perform(NSSelectorFromString("pushToChatViewController:userID:"), with: groupID, with: userID)
        }
    }
    
    // MARK: - TIMPushListener

    func onRecvPushMessage(_ message: TIMPushMessage) {
        NSLog("onRecvPushMessage:%@",message)
    }
    
    func onRevokePushMessage(_ messageID: String) {
        NSLog("onRevokePushMessage:%@",messageID)
    }
    
    func onNotificationClicked(_ ext: String) {
        NSLog("onNotificationClicked:%@",ext)
    }
}

extension UIViewController {
    static let swizzleSetTitle: Void = {
        let originalSelector = #selector(setter: UIViewController.title)
        let swizzledSelector = #selector(swizzled_setTitle(_:))

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector) else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc private func swizzled_setTitle(_ title: String?) {
        swizzled_setTitle(title)
        navigationItem.titleView = {
            let titleLabel = UILabel()
            titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
            titleLabel.text = title
            return titleLabel
        }()
        navigationItem.title = ""
    }
}
