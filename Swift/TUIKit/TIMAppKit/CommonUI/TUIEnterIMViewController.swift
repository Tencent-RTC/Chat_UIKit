//
//  TUIEnterIMViewController.m
//  TUIKitDemo
//
//  Created by lynxzhang on 2022/2/9.
//  Copyright © 2022 Tencent. All rights reserved.
//

import TIMCommon
import TUIChat
import TUIContact
import UIKit

enum DefaultVC: Int {
    case conversation
    case contact
    case setting
}

let kHaveViewedIMIntroduction = "TUIKitDemo_HaveViewedIMIntroduction"

class TUIEnterIMViewController: UIViewController, TUIStyleSelectControllerDelegate, V2TIMConversationListener {
    var defaultVC: DefaultVC = .conversation
    var tbc: TUITabBarController?
    var styleVC: TUIStyleSelectViewController?
    var themeVC: TUIThemeSelectController?
    var contactDataProvider: Observable<TUIContactViewDataProvider> = Observable(TUIContactViewDataProvider())
    var convVC_Mini: ConversationController_Minimalist?
    var contactsVC_Mini: ContactsController_Minimalist?
    var settingVC_Mini: SettingController_Minimalist?
    var callingVC: TUICallingHistoryViewController?
    var themeLabel: UILabel?
    var themeSubLabel: UILabel?
    var unReadCount: UInt = 0
    var markUnreadCount: UInt = 0
    var markHideUnreadCount: UInt = 0

    var windowIsClosed = false
    var dismissWindowBtn: Observable<UIButton?>?
    var convShowLeftBarButtonItems: [UIBarButtonItem] = []
    var convShowRightBarButtonItems: [UIBarButtonItem] = []
    var contactsShowLeftBarButtonItems: [UIBarButtonItem] = []
    var contactsShowRightBarButtonItems: [UIBarButtonItem] = []
    var settingShowLeftBarButtonItems: [UIBarButtonItem] = []
    var inConversationVC: Observable<Bool> = Observable(false)
    var inContactsVC: Observable<Bool> = Observable(false)
    var inSettingVC: Observable<Bool> = Observable(false)
    var inCallsRecordVC: Observable<Bool> = Observable(false)
    var isTencentRTCApp = false
    var originRTCBackImage: UIImage?

    // Observers
    let dismissWindowBtnObserver = Observer()

    let convVCMiniShowLeftBarButtonItemsObserver = Observer()
    let contactsVCMiniShowLeftBarButtonItemsObserver = Observer()
    let settingVCMiniShowLeftBarButtonItemsObserver = Observer()

    let convVCMiniShowRightBarButtonItemsObserver = Observer()
    let contactsVCMiniShowRightBarButtonItemsObserver = Observer()

    let convVCMiniConvObserver = Observer()
    let contactsVCMiniContactObserver = Observer()
    let settingVCMiniSettingObserver = Observer()

    let callingVCCallsVCObserver = Observer()

    let inConversationVCObserver = Observer()
    let inContactsVCObserver = Observer()
    let inSettingVCObserver = Observer()
    let inCallsRecordVCObserver = Observer()

    let contactDataProviderObserver = Observer()

    // MARK: life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if windowIsClosed {
            return
        }
        let appBundleId = Bundle.main.bundleIdentifier
        isTencentRTCApp = (appBundleId == "com.tencent.rtc.app")
        TUIChatConfig.shared.enableWelcomeCustomMessage = !isTencentRTCApp
        TUISwift.tuiRegisterThemeResourcePath(TUISwift.tuiBundlePath("TUIDemoTheme", key: "TIMAppKit.TUIKit"), themeModule: TUIThemeModule.demo)
        TUIThemeSelectController.disableFollowSystemStyle()
        TUIThemeSelectController.applyLastTheme()
        TUITool.configIMErrorMap()

        configIMNavigation()
        setupCustomSticker()
        setupChatSecurityWarningView()
        redpoint_setupTotalUnreadCount()
        setupView()

        V2TIMManager.sharedInstance().addConversationListener(listener: self)
        NotificationCenter.default.addObserver(self, selector: #selector(updateMarkUnreadCount(_:)), name: NSNotification.Name(rawValue: "TUIKitNotification_onConversationMarkUnreadCountChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDisplayCallsRecordForMinimalist(_:)), name: NSNotification.Name(rawValue: kEnableCallsRecord_mini), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDisplayCallsRecordForClassic(_:)), name: NSNotification.Name(rawValue: kEnableCallsRecord), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        dismissWindowBtn?.removeObserver(dismissWindowBtnObserver)

        convVC_Mini?.showLeftBarButtonItems.removeObserver(convVCMiniShowLeftBarButtonItemsObserver)
        contactsVC_Mini?.showLeftBarButtonItems.removeObserver(contactsVCMiniShowLeftBarButtonItemsObserver)
        settingVC_Mini?.showLeftBarButtonItems.removeObserver(settingVCMiniShowLeftBarButtonItemsObserver)

        convVC_Mini?.showRightBarButtonItems.removeObserver(convVCMiniShowRightBarButtonItemsObserver)
        contactsVC_Mini?.showRightBarButtonItems.removeObserver(contactsVCMiniShowRightBarButtonItemsObserver)

        convVC_Mini?.conv.removeObserver(convVCMiniConvObserver)
        contactsVC_Mini?.contact.removeObserver(contactsVCMiniContactObserver)
        settingVC_Mini?.setting.removeObserver(settingVCMiniSettingObserver)

        callingVC?.callsVC.removeObserver(callingVCCallsVCObserver)

        inConversationVC.removeObserver(inConversationVCObserver)
        inContactsVC.removeObserver(inContactsVCObserver)
        inSettingVC.removeObserver(inSettingVCObserver)
        inCallsRecordVC.removeObserver(inCallsRecordVCObserver)

        contactDataProvider.removeObserver(contactDataProviderObserver)
    }

    func tintColor() -> UIColor {
        return TUISwift.timCommonDynamicColor("head_bg_gradient_start_color", defaultColor: "#EBF0F6")
    }

    func configIMNavigation() {
        originRTCBackImage = UINavigationBar.appearance().backgroundImage(for: .default)

        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.shadowColor = nil
            appearance.backgroundEffect = nil
            appearance.backgroundColor = tintColor()
            navigationController?.navigationBar.backgroundColor = tintColor()
            navigationController?.navigationBar.barTintColor = tintColor()
            navigationController?.navigationBar.shadowImage = UIImage()
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            UINavigationBar.appearance().setBackgroundImage(nil, for: .default)
            navigationController?.navigationBar.backgroundColor = tintColor()
            navigationController?.navigationBar.barTintColor = tintColor()
            navigationController?.navigationBar.shadowImage = nil
            navigationController?.navigationBar.setBackgroundImage(nil, for: .default)
        }
    }

    static var g_hasAddedCustomFace = false
    func setupCustomSticker() {
        if TUIEnterIMViewController.g_hasAddedCustomFace {
            return
        }
        TUIEnterIMViewController.g_hasAddedCustomFace = true
        let service = TIMCommonMediator.shared.getObject(for: TUIEmojiMeditorProtocol.self)
        let bundlePath = TUISwift.tuiBundlePath("CustomFaceResource", key: "TIMAppKit.TUIKit")
        // 4350 group
        var faces4350 = [TUIFaceCellData]()
        for i in 0...17 {
            let data = TUIFaceCellData()
            let name = String(format: "yz%02d", i)
            let path = String(format: "4350/%@", name)
            data.name = name
            data.path = bundlePath + "/" + path
            faces4350.append(data)
        }
        if faces4350.count > 0 {
            let group4350 = TUIFaceGroup()
            group4350.groupIndex = 1
            group4350.groupPath = bundlePath + "/4350/"
            group4350.faces = faces4350
            group4350.rowCount = 2
            group4350.itemCountPerRow = 5
            group4350.menuPath = bundlePath + "/4350/menu"
            service?.appendFaceGroup(group4350)
        }
        if isTencentRTCApp {
            return
        }
        // 4351 group
        var faces4351 = [TUIFaceCellData]()
        for i in 0...15 {
            let data = TUIFaceCellData()
            let name = String(format: "ys%02d", i)
            let path = String(format: "4351/%@", name)
            data.name = name
            data.path = bundlePath + "/" + path
            faces4351.append(data)
        }
        if faces4351.count > 0 {
            let group4351 = TUIFaceGroup()
            group4351.groupIndex = 2
            group4351.groupPath = bundlePath + "/4351/"
            group4351.faces = faces4351
            group4351.rowCount = 2
            group4351.itemCountPerRow = 5
            group4351.menuPath = bundlePath + "4351/menu"
            service?.appendFaceGroup(group4351)
        }

        // 4352 group
        var faces4352 = [TUIFaceCellData]()
        for i in 0...16 {
            let data = TUIFaceCellData()
            let name = String(format: "gcs%02d", i)
            let path = String(format: "4352/%@", name)
            data.name = name
            data.path = bundlePath + "/" + path
            faces4352.append(data)
        }
        if faces4352.count > 0 {
            let group4352 = TUIFaceGroup()
            group4352.groupIndex = 3
            group4352.groupPath = bundlePath + "/4352/"
            group4352.faces = faces4352
            group4352.rowCount = 2
            group4352.itemCountPerRow = 5
            group4352.menuPath = bundlePath + "/4352/menu"
            service?.appendFaceGroup(group4352)
        }
    }

    func setupStyleConfig() {
        if TUIStyleSelectViewController.isClassicEntrance() {
            setupStyleConfig_Classic()
        } else {
            TUIThemeSelectController.applyTheme("light")
            UserDefaults.standard.set("light", forKey: "current_theme_id")
            UserDefaults.standard.synchronize()
            setupStyleConfig_Minimalist()
        }
    }

    func setupStyleConfig_Classic() {
        if let _ = UserDefaults.standard.object(forKey: kEnableMsgReadStatus) {
            TUIChatConfig.shared.msgNeedReadReceipt = UserDefaults.standard.bool(forKey: kEnableMsgReadStatus)
        } else {
            TUIChatConfig.shared.msgNeedReadReceipt = true
            UserDefaults.standard.set(true, forKey: kEnableMsgReadStatus)
            UserDefaults.standard.synchronize()
        }
        TUIConfig.default().displayOnlineStatusIcon = UserDefaults.standard.bool(forKey: kEnableOnlineStatus)
        TUIChatConfig.shared.enableMultiDeviceForCall = true
        TUIChatConfig.shared.enableVirtualBackgroundForCall = true
        TUIConfig.default().avatarType = TUIKitAvatarType.TAvatarTypeRadiusCorner
    }

    func setupStyleConfig_Minimalist() {
        if let _ = UserDefaults.standard.object(forKey: kEnableMsgReadStatus_mini) {
            TUIChatConfig.shared.msgNeedReadReceipt = UserDefaults.standard.bool(forKey: kEnableMsgReadStatus_mini)
        } else {
            TUIChatConfig.shared.msgNeedReadReceipt = true
            UserDefaults.standard.set(true, forKey: kEnableMsgReadStatus_mini)
            UserDefaults.standard.synchronize()
        }
        TUIConfig.default().displayOnlineStatusIcon = UserDefaults.standard.bool(forKey: kEnableOnlineStatus_mini)
        TUIChatConfig.shared.enableMultiDeviceForCall = true
        TUIChatConfig.shared.enableVirtualBackgroundForCall = true
        TUIConfig.default().avatarType = TUIKitAvatarType.TAvatarTypeRounded
    }

    func setupChatSecurityWarningView() {
        var tips = TUISwift.timCommonLocalizableString("TIMAppChatSecurityWarning")
        var buttonTitle = TUISwift.timCommonLocalizableString("TIMAppChatSecurityWarningReport")
        let gotButtonTitle = TUISwift.timCommonLocalizableString("TIMAppChatSecurityWarningGot")
        var buttonAction: (() -> Void)? = {
            if let url = URL(string: "https://cloud.tencent.com/act/event/report-platform") {
                TUITool.openLink(with: url)
            }
        }

        if isTencentRTCApp {
            tips = TUISwift.timCommonLocalizableString("TIMTencentRTCAppChatSecurityWarning")
            buttonAction = nil
            buttonTitle = ""
        }

        let tipsView = TUIWarningView(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: 0),
                                      tips: tips,
                                      buttonTitle: buttonTitle,
                                      buttonAction: buttonAction,
                                      gotButtonTitle: gotButtonTitle,
                                      gotButtonAction: nil)
        tipsView.gotButtonAction = { [weak tipsView] in
            guard let tipsView = tipsView else { return }
            tipsView.frame = .zero
            tipsView.removeFromSuperview()
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TUICore_TUIChatExtension_ChatViewTopArea_ChangedNotification"), object: nil)
        }

        if TUIStyleSelectViewController.isClassicEntrance() {
            TUIBaseChatViewController.customTopView = tipsView
        } else {
            TUIBaseChatViewController_Minimalist.customTopView = tipsView
        }
    }

    func setupView() {
        if UserDefaults.standard.object(forKey: kHaveViewedIMIntroduction) != nil {
            enterIM()
            return
        } else {
            UserDefaults.standard.set(true, forKey: kHaveViewedIMIntroduction)
            UserDefaults.standard.synchronize()
        }
        view.backgroundColor = .white

        let imLogo = UIImageView(frame: CGRect(x: TUISwift.kScale390(24), y: 56, width: 62, height: 31))
        imLogo.image = TUISwift.tuiDemoDynamicImage("", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("im_logo")))
        view.addSubview(imLogo)

        let cloudLogo = UIImageView(frame: CGRect(x: view.frame.width - 229, y: 6, width: 229, height: 215))
        cloudLogo.image = TUISwift.tuiDemoDynamicImage("", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("cloud_logo")))
        view.addSubview(cloudLogo)

        let imLabel = UILabel(frame: CGRect(x: TUISwift.kScale390(24), y: imLogo.frame.maxY + 10, width: 100, height: 36))
        imLabel.text = TUISwift.timCommonLocalizableString("TIMAppTencentCloudIM")
        imLabel.font = UIFont.systemFont(ofSize: 24)
        imLabel.textColor = .black
        view.addSubview(imLabel)

        let welcomeLabel = UILabel(frame: CGRect(x: TUISwift.kScale390(24), y: imLabel.frame.maxY + 9, width: 240, height: 17))
        welcomeLabel.text = TUISwift.timCommonLocalizableString("TIMAppWelcomeToChat")
        welcomeLabel.font = UIFont.systemFont(ofSize: 12)
        welcomeLabel.textColor = UIColor(red: 102/255, green: 102/255, blue: 102/255, alpha: 1)
        view.addSubview(welcomeLabel)

        let welcomeBtn = UIButton(type: .custom)
        welcomeBtn.frame = CGRect(x: welcomeLabel.frame.maxX + TUISwift.kScale390(10), y: welcomeLabel.frame.origin.y, width: 16, height: 16)
        welcomeBtn.setImage(TUISwift.tuiDemoDynamicImage("", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("im_welcome"))), for: .normal)
        welcomeBtn.addTarget(self, action: #selector(welcomeIM), for: .touchUpInside)
        view.addSubview(welcomeBtn)

        let styleLabel = UILabel(frame: CGRect(x: TUISwift.kScale390(24), y: welcomeLabel.frame.maxY + 42, width: TUISwift.kScale390(70), height: 22))
        styleLabel.text = TUISwift.timCommonLocalizableString("TIMAppSelectStyle")
        styleLabel.font = UIFont.systemFont(ofSize: 16)
        styleLabel.textColor = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1)
        view.addSubview(styleLabel)

        let styleSubLabel = UILabel(frame: CGRect(x: styleLabel.frame.maxX + TUISwift.kScale390(9), y: styleLabel.frame.origin.y + 4, width: 100, height: 17))
        styleSubLabel.text = TUISwift.timCommonLocalizableString("TIMAppChatStyles")
        styleSubLabel.font = UIFont.systemFont(ofSize: 12)
        styleSubLabel.textColor = UIColor(red: 153/255, green: 153/255, blue: 153/255, alpha: 1)
        view.addSubview(styleSubLabel)

        styleVC = TUIStyleSelectViewController()
        styleVC?.delegate = self
        styleVC?.view.frame = CGRect(x: 0, y: styleSubLabel.frame.maxY + 9, width: view.frame.width, height: 92)
        styleVC?.view.autoresizingMask = .flexibleTopMargin
        addChild(styleVC!)
        view.addSubview(styleVC!.view)
        styleVC?.setBackGroundColor(.white)

        themeLabel = UILabel(frame: CGRect(x: styleLabel.frame.origin.x, y: styleVC!.view.frame.maxY + 20, width: styleLabel.frame.width, height: styleLabel.frame.height))
        themeLabel?.text = TUISwift.timCommonLocalizableString("TIMAppChangeTheme")
        themeLabel?.font = UIFont.systemFont(ofSize: 16)
        themeLabel?.textColor = UIColor(red: 51/255, green: 51/255, blue: 51/255, alpha: 1)
        view.addSubview(themeLabel!)

        themeSubLabel = UILabel(frame: CGRect(x: themeLabel!.frame.maxX + TUISwift.kScale390(9), y: themeLabel!.frame.origin.y + 4, width: styleSubLabel.frame.width, height: styleSubLabel.frame.height))
        themeSubLabel?.text = TUISwift.timCommonLocalizableString("TIMAppChatThemes")
        themeSubLabel?.font = UIFont.systemFont(ofSize: 12)
        themeSubLabel?.textColor = UIColor(red: 153/255, green: 153/255, blue: 153/255, alpha: 1)
        view.addSubview(themeSubLabel!)

        themeVC = TUIThemeSelectController()
        themeVC?.view.frame = CGRect(x: 0, y: themeSubLabel!.frame.maxY + 9, width: view.frame.size.width, height: 350)
        themeVC?.view.autoresizingMask = .flexibleTopMargin
        addChild(themeVC!)
        view.addSubview(themeVC!.view)
        themeVC?.setBackGroundColor(.white)

        if !TUIStyleSelectViewController.isClassicEntrance() {
            themeLabel?.isHidden = true
            themeSubLabel?.isHidden = true
            themeVC?.view.isHidden = true
        }

        let enterBtn = UIButton(type: .custom)
        enterBtn.backgroundColor = UIColor(red: 16/255, green: 78/255, blue: 245/255, alpha: 1)
        let btnWidth: CGFloat = 202
        let btnHeight: CGFloat = 42
        enterBtn.frame = CGRect(x: (view.frame.width - btnWidth)/2, y: view.frame.height - btnHeight - TUISwift.bottom_SafeHeight(), width: btnWidth, height: btnHeight)
        enterBtn.setTitle(TUISwift.timCommonLocalizableString("TIMAppEnterChat"), for: .normal)
        enterBtn.setTitleColor(.white, for: .normal)
        enterBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14.0)
        enterBtn.layer.cornerRadius = btnHeight/2
        enterBtn.layer.masksToBounds = true
        enterBtn.addTarget(self, action: #selector(enterIM), for: .touchUpInside)
        view.addSubview(enterBtn)
    }

    @objc func welcomeIM() {
        let vc = TUIIMIntroductionViewController()
        present(vc, animated: true, completion: nil)
    }

    @objc func enterIM() {
        showIMWindow()
    }

    static var gImWindow: UIWindow?
    func showIMWindow() {
        if TUIEnterIMViewController.gImWindow == nil {
            TUIEnterIMViewController.gImWindow = UIWindow(frame: .zero)
            TUIEnterIMViewController.gImWindow?.windowLevel = .alert - 1
            TUIEnterIMViewController.gImWindow?.backgroundColor = .white

            if #available(iOS 13.0, *) {
                for windowScene in UIApplication.shared.connectedScenes {
                    if let windowScene = windowScene as? UIWindowScene, windowScene.activationState == .foregroundActive {
                        TUIEnterIMViewController.gImWindow?.windowScene = windowScene
                        break
                    }
                }
            }

            TUIEnterIMViewController.gImWindow?.frame = CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: UIScreen.main.bounds.height)
            TUIEnterIMViewController.gImWindow?.rootViewController = getMainController()
            TUIEnterIMViewController.gImWindow?.isHidden = false

            dismissWindowBtn = Observable(UIButton(type: .custom))
            dismissWindowBtn?.value?.frame = CGRect(x: TUISwift.kScale390(15), y: TUISwift.statusBar_Height() + 6, width: 44, height: 32)
            dismissWindowBtn?.value?.setImage(TUISwift.tuiDemoDynamicImage("", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("dismiss_im_window"))), for: .normal)
            dismissWindowBtn?.value?.addTarget(self, action: #selector(dismissIMWindow), for: .touchUpInside)
            TUIEnterIMViewController.gImWindow?.addSubview((dismissWindowBtn?.value)!)
        }

        setupStyleWindow()
        setupStyleConfig()
    }

    func updateIMWindow() {
        if TUIEnterIMViewController.gImWindow != nil {
            TUIEnterIMViewController.gImWindow?.rootViewController = getMainController()
            setupStyleWindow()
            setupStyleConfig()
        }
    }

    @objc func dismissIMWindow() {
        if TUIEnterIMViewController.gImWindow != nil {
            TUIEnterIMViewController.gImWindow?.isHidden = true
            TUIEnterIMViewController.gImWindow = nil
            windowIsClosed = true

            if let originRTCBackImage = originRTCBackImage {
                UINavigationBar.appearance().setBackgroundImage(originRTCBackImage, for: .default)
            }

            if let navigationController = navigationController {
                navigationController.popViewController(animated: true)
            } else {
                dismiss(animated: true, completion: nil)
            }
        }
    }

    func setupStyleWindow() {
        dismissWindowBtn?.value?.isHidden = false
        TUIEnterIMViewController.gImWindow?.bringSubviewToFront((dismissWindowBtn?.value)!)

        if TUIStyleSelectViewController.isClassicEntrance() {
            for item in contactsShowLeftBarButtonItems {
                item.customView?.removeFromSuperview()
            }
            for item in contactsShowRightBarButtonItems {
                item.customView?.removeFromSuperview()
            }
            for item in convShowLeftBarButtonItems {
                item.customView?.removeFromSuperview()
            }
            for item in convShowRightBarButtonItems {
                item.customView?.removeFromSuperview()
            }
            for item in settingShowLeftBarButtonItems {
                item.customView?.removeFromSuperview()
            }
            return
        }

        dismissWindowBtn?.addObserver(dismissWindowBtnObserver, closure: { [weak self] newValue, _ in
            guard let self = self else { return }
            if TUIStyleSelectViewController.isClassicEntrance() {
                return
            }
            if newValue?.isHidden == true {
                self.showConvBarButtonItems(false)
                self.showContactBarButtonItems(false)
                self.showSettingBarButtonItems(false)
            }
        })

        convVC_Mini?.showLeftBarButtonItems.addObserver(convVCMiniShowLeftBarButtonItemsObserver, closure: { [weak self] showLeftBarButtonItems, _ in
            guard let self = self else { return }
            self.convShowLeftBarButtonItems = showLeftBarButtonItems
            if let titleItem = showLeftBarButtonItems.last, !(TUIEnterIMViewController.gImWindow?.subviews.contains(titleItem.customView ?? UIView()) ?? false) {
                titleItem.customView?.frame.origin.x = self.dismissWindowBtn?.value?.frame.origin.x ?? 0
                titleItem.customView?.frame.origin.y = self.dismissWindowBtn?.value?.frame.maxY ?? 0
                TUIEnterIMViewController.gImWindow?.addSubview(titleItem.customView ?? UIView())
            }
            self.convVC_Mini?.showLeftBarButtonItems.value.removeAll()
        })

        contactsVC_Mini?.showLeftBarButtonItems.addObserver(contactsVCMiniShowLeftBarButtonItemsObserver, closure: { [weak self] showLeftBarButtonItems, _ in
            guard let self = self else { return }
            self.contactsShowLeftBarButtonItems = showLeftBarButtonItems
            if let titleItem = showLeftBarButtonItems.last, !(TUIEnterIMViewController.gImWindow?.subviews.contains(titleItem.customView ?? UIView()) ?? false) {
                titleItem.customView?.frame.origin.x = self.dismissWindowBtn?.value?.frame.origin.x ?? 0
                titleItem.customView?.frame.origin.y = self.dismissWindowBtn?.value?.frame.maxY ?? 0
                TUIEnterIMViewController.gImWindow?.addSubview(titleItem.customView ?? UIView())
            }
            self.contactsVC_Mini?.showLeftBarButtonItems.value.removeAll()
        })

        settingVC_Mini?.showLeftBarButtonItems.addObserver(settingVCMiniShowLeftBarButtonItemsObserver, closure: { [weak self] showLeftBarButtonItems, _ in
            guard let self = self else { return }
            self.settingShowLeftBarButtonItems = showLeftBarButtonItems
            if let titleItem = showLeftBarButtonItems.last, !(TUIEnterIMViewController.gImWindow?.subviews.contains(titleItem.customView ?? UIView()) ?? false) {
                titleItem.customView?.frame.origin.x = self.dismissWindowBtn?.value?.frame.origin.x ?? 0
                titleItem.customView?.frame.origin.y = self.dismissWindowBtn?.value?.frame.maxY ?? 0
                TUIEnterIMViewController.gImWindow?.addSubview(titleItem.customView ?? UIView())
            }
            self.settingVC_Mini?.showLeftBarButtonItems.value.removeAll()
        })

        convVC_Mini?.showRightBarButtonItems.addObserver(convVCMiniShowRightBarButtonItemsObserver, closure: { [weak self] showRightBarButtonItems, _ in
            guard let self = self else { return }
            self.convShowRightBarButtonItems = showRightBarButtonItems
            for item in self.convShowRightBarButtonItems {
                if !(TUIEnterIMViewController.gImWindow?.subviews.contains(item.customView ?? UIView()) ?? false) {
                    switch item.tag {
                    case UIBarButtonItemType.edit.rawValue:
                        item.customView?.frame.origin.x = TUISwift.screen_Width() - TUISwift.kScale390(90)
                    case UIBarButtonItemType.more.rawValue:
                        item.customView?.frame.origin.x = TUISwift.screen_Width() - TUISwift.kScale390(40)
                    case UIBarButtonItemType.done.rawValue:
                        item.customView?.frame.origin.x = TUISwift.screen_Width() - TUISwift.kScale390(60)
                    default:
                        break
                    }
                    item.customView?.center.y = self.dismissWindowBtn?.value?.center.y ?? 0
                    TUIEnterIMViewController.gImWindow?.addSubview(item.customView ?? UIView())
                }
            }
            for item in self.convVC_Mini?.rightBarButtonItems ?? [] {
                item.customView?.isHidden = !(showRightBarButtonItems.contains(item))
            }
            self.convVC_Mini?.showRightBarButtonItems.value.removeAll()
        })

        contactsVC_Mini?.showRightBarButtonItems.addObserver(contactsVCMiniShowRightBarButtonItemsObserver, closure: { [weak self] showRightBarButtonItems, _ in
            guard let self = self else { return }
            self.contactsShowRightBarButtonItems = showRightBarButtonItems
            let item = showRightBarButtonItems.first
            if item != nil, !(TUIEnterIMViewController.gImWindow?.subviews.contains(item?.customView ?? UIView()) ?? false) {
                item?.customView?.frame.origin.x = TUISwift.screen_Width() - TUISwift.kScale390(40)
                item?.customView?.center.y = self.dismissWindowBtn?.value?.center.y ?? 0
                TUIEnterIMViewController.gImWindow?.addSubview(item?.customView ?? UIView())
            }
            item?.customView?.isHidden = false
            self.contactsVC_Mini?.showRightBarButtonItems.value.removeAll()
        })

        let vcOffsetY: CGFloat = 120
        convVC_Mini?.conv.addObserver(convVCMiniConvObserver, closure: { [weak self] conv, _ in
            guard let self = self else { return }
            let vc = conv
            vc?.view.frame = CGRect(x: 0, y: vcOffsetY, width: self.view.frame.width, height: self.view.frame.height - vcOffsetY)
        })

        contactsVC_Mini?.contact.addObserver(contactsVCMiniContactObserver, closure: { [weak self] contact, _ in
            guard let self = self else { return }
            let vc = contact
            vc?.view.frame = CGRect(x: 0, y: vcOffsetY, width: self.view.frame.width, height: self.view.frame.height - vcOffsetY)
        })

        settingVC_Mini?.setting.addObserver(settingVCMiniSettingObserver, closure: { [weak self] setting, _ in
            guard let self = self else { return }
            let vc = setting
            vc?.view.frame = CGRect(x: 0, y: vcOffsetY, width: self.view.frame.width, height: self.view.frame.height - vcOffsetY)
        })

        callingVC?.callsVC.addObserver(callingVCCallsVCObserver, closure: { [weak self] callsVC, _ in
            guard let self = self else { return }
            if self.callingVC?.isMimimalist == true {
                callsVC?.view.frame = CGRect(x: 0, y: 40, width: self.view.frame.width, height: self.view.frame.height - 40)
            }
        })

        inConversationVC.addObserver(inConversationVCObserver, closure: { [weak self] inConversationVC, _ in
            guard let self = self else { return }
            if inConversationVC == true {
                self.showConvBarButtonItems(true)
                self.showContactBarButtonItems(false)
                self.showSettingBarButtonItems(false)
            }
        })

        inContactsVC.addObserver(inContactsVCObserver, closure: { [weak self] inContactsVC, _ in
            guard let self = self else { return }
            if inContactsVC == true {
                self.showContactBarButtonItems(true)
                self.showConvBarButtonItems(false)
                self.showSettingBarButtonItems(false)
            }
        })

        inSettingVC.addObserver(inSettingVCObserver, closure: { [weak self] inSettingVC, _ in
            guard let self = self else { return }
            if inSettingVC == true {
                self.showConvBarButtonItems(false)
                self.showContactBarButtonItems(false)
                self.showSettingBarButtonItems(true)
            }
        })

        inCallsRecordVC.addObserver(inCallsRecordVCObserver, closure: { [weak self] inCallsRecordVC, _ in
            guard let self = self else { return }
            if inCallsRecordVC == true {
                self.showConvBarButtonItems(false)
                self.showContactBarButtonItems(false)
                self.showContactBarButtonItems(false)
            }
        })
    }

    func showConvBarButtonItems(_ isShow: Bool) {
        for item in convShowLeftBarButtonItems {
            item.customView?.isHidden = !isShow
        }
        for item in convShowRightBarButtonItems {
            item.customView?.isHidden = !isShow
        }
    }

    func showContactBarButtonItems(_ isShow: Bool) {
        for item in contactsShowLeftBarButtonItems {
            item.customView?.isHidden = !isShow
        }
        for item in contactsShowRightBarButtonItems {
            item.customView?.isHidden = !isShow
        }
    }

    func showSettingBarButtonItems(_ isShow: Bool) {
        for item in settingShowLeftBarButtonItems {
            item.customView?.isHidden = !isShow
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
        tbc = TUITabBarController()
        var items: [TUITabBarItem] = []
        let msgItem = TUITabBarItem()
        msgItem.title = TUISwift.timCommonLocalizableString("TIMAppTabBarItemMessageText")
        msgItem.identity = "msgItem"
        msgItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_msg_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("session_selected")))
        msgItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_msg_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("session_normal")))
        let convVC = ConversationController()
        convVC.viewWillAppear = { [weak self] isAppear in
            guard let self = self else { return }
            self.inConversationVC.value = isAppear
            if (self.inContactsVC.value || self.inSettingVC.value || self.inCallsRecordVC.value) && !isAppear {
                return
            }
            self.dismissWindowBtn?.value?.isHidden = !isAppear
        }
        msgItem.controller = TUINavigationController(rootViewController: convVC)
        msgItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: TUISwift.tController_Background_Color(), dark: TUISwift.tController_Background_Color_Dark())
        msgItem.badgeView = TUIBadgeView()
        msgItem.badgeView?.clearCallback = { [weak self] in
            self?.redpoint_clearUnreadMessage()
        }
        items.append(msgItem)

        if let callsItem = getCallsRecordTabBarItem(false) {
            items.append(callsItem)
        }

        let contactItem = TUITabBarItem()
        contactItem.title = TUISwift.timCommonLocalizableString("TIMAppTabBarItemContactText")
        contactItem.identity = "contactItem"
        contactItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_contact_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("contact_selected")))
        contactItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_contact_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("contact_normal")))
        let contactVC = ContactsController()
        contactVC.viewWillAppear = { [weak self] isAppear in
            guard let self = self else { return }
            self.inContactsVC.value = isAppear
            if (self.inConversationVC.value || self.inSettingVC.value || self.inCallsRecordVC.value) && !isAppear {
                return
            }
            self.dismissWindowBtn?.value?.isHidden = !isAppear
        }
        contactItem.controller = TUINavigationController(rootViewController: contactVC)
        contactItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: TUISwift.tController_Background_Color(), dark: TUISwift.tController_Background_Color_Dark())
        contactItem.badgeView = TUIBadgeView()
        items.append(contactItem)

        let setItem = TUITabBarItem()
        setItem.title = TUISwift.timCommonLocalizableString("TIMAppTabBarItemMeText")
        setItem.identity = "setItem"
        setItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_me_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("myself_selected")))
        setItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_me_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("myself_normal")))
        let setVC = SettingController()
        setVC.showPersonalCell = false
        let appName = TUICore.callService("TUICore_ConfigureService", method: "TUICore_ConfigureService_getAppName", param: nil) as? String
        setVC.showSelectStyleCell = (appName == "RTCube")
        setVC.showChangeThemeCell = true
        setVC.showAboutIMCell = false
        setVC.showLoginOutCell = false
        setVC.viewWillAppearClosure = { [weak self] isAppear in
            guard let self = self else { return }
            self.inSettingVC.value = isAppear
            if (self.inConversationVC.value || self.inContactsVC.value || self.inCallsRecordVC.value) && !isAppear {
                return
            }
            self.dismissWindowBtn?.value?.isHidden = !isAppear
        }
        setVC.changeStyle = { [weak self] in
            self?.updateIMWindow()
        }
        setVC.changeTheme = { [weak self] in
            self?.updateIMWindow()
        }
        setItem.controller = TUINavigationController(rootViewController: setVC)
        setItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: TUISwift.tController_Background_Color(), dark: TUISwift.tController_Background_Color_Dark())
        items.append(setItem)
        tbc?.setTabBarItems(items)

        switch defaultVC {
        case .conversation:
            tbc?.selectedIndex = items.firstIndex { $0.identity == "msgItem" } ?? 0
        case .contact:
            tbc?.selectedIndex = items.firstIndex { $0.identity == "contactItem" } ?? 0
        case .setting:
            tbc?.selectedIndex = items.firstIndex { $0.identity == "setItem" } ?? 0
        }

        return tbc!
    }

    func getMainController_Minimalist() -> UITabBarController {
        tbc = TUITabBarController()
        var items: [TUITabBarItem] = []
        let msgItem = TUITabBarItem()
        msgItem.title = TUISwift.timCommonLocalizableString("TIMAppTabBarItemMessageText_mini")
        msgItem.identity = "msgItem"
        msgItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_msg_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("session_selected")))
        msgItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_msg_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("session_normal")))
        convVC_Mini = ConversationController_Minimalist()
        convVC_Mini?.viewWillAppearClosure = { [weak self] isAppear in
            guard let self = self else { return }
            self.inConversationVC.value = isAppear
            if (self.inContactsVC.value || self.inSettingVC.value || self.inCallsRecordVC.value) && !isAppear {
                return
            }
            self.dismissWindowBtn?.value?.isHidden = !isAppear
        }
        msgItem.controller = TUINavigationController(rootViewController: convVC_Mini!)
        msgItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: .white, dark: TUISwift.tController_Background_Color_Dark())
        msgItem.badgeView = TUIBadgeView()
        msgItem.badgeView?.clearCallback = { [weak self] in
            self?.redpoint_clearUnreadMessage()
        }
        items.append(msgItem)

        if let callsItem = getCallsRecordTabBarItem(true) {
            items.append(callsItem)
        }

        let contactItem = TUITabBarItem()
        contactItem.title = TUISwift.timCommonLocalizableString("TIMAppTabBarItemContactText_mini")
        contactItem.identity = "contactItem"
        contactItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_contact_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("contact_selected")))
        contactItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_contact_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("contact_normal")))
        contactsVC_Mini = ContactsController_Minimalist()
        contactsVC_Mini?.viewWillAppearClosure = { [weak self] isAppear in
            guard let self = self else { return }
            self.inContactsVC.value = isAppear
            if (self.inConversationVC.value || self.inSettingVC.value || self.inCallsRecordVC.value) && !isAppear {
                return
            }
            self.dismissWindowBtn?.value?.isHidden = !isAppear
        }
        contactItem.controller = TUINavigationController(rootViewController: contactsVC_Mini!)
        contactItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: .white, dark: TUISwift.tController_Background_Color_Dark())
        contactItem.badgeView = TUIBadgeView()
        items.append(contactItem)

        let setItem = TUITabBarItem()
        setItem.title = TUISwift.timCommonLocalizableString("TIMAppTabBarItemSettingText_mini")
        setItem.identity = "setItem"
        setItem.selectedImage = TUISwift.tuiDemoDynamicImage("tab_me_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("myself_selected")))
        setItem.normalImage = TUISwift.tuiDemoDynamicImage("tab_me_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("myself_normal")))
        settingVC_Mini = SettingController_Minimalist()
        settingVC_Mini?.showPersonalCell = false
        let appName = TUICore.callService("TUICore_ConfigureService", method: "TUICore_ConfigureService_getAppName", param: nil) as? String
        settingVC_Mini?.showSelectStyleCell = (appName == "RTCube")
        settingVC_Mini?.showChangeThemeCell = true
        settingVC_Mini?.showAboutIMCell = false
        settingVC_Mini?.showLoginOutCell = false
        settingVC_Mini?.viewWillAppearClosure = { [weak self] isAppear in
            guard let self = self else { return }
            self.inSettingVC.value = isAppear
            if (self.inConversationVC.value || self.inContactsVC.value || self.inCallsRecordVC.value) && !isAppear {
                return
            }
            self.dismissWindowBtn?.value?.isHidden = !isAppear
        }
        settingVC_Mini?.changeStyle = { [weak self] in
            self?.updateIMWindow()
        }
        settingVC_Mini?.changeTheme = { [weak self] in
            self?.updateIMWindow()
        }
        setItem.controller = TUINavigationController(rootViewController: settingVC_Mini!)
        setItem.controller?.view.backgroundColor = UIColor.d_color(withColorLight: .white, dark: TUISwift.tController_Background_Color_Dark())
        items.append(setItem)
        tbc?.setTabBarItems(items)

        switch defaultVC {
        case .conversation:
            tbc?.selectedIndex = items.firstIndex(where: { $0.identity == "msgItem" }) ?? 0
        case .contact:
            tbc?.selectedIndex = items.firstIndex(where: { $0.identity == "contactItem" }) ?? 0
        case .setting:
            tbc?.selectedIndex = items.firstIndex(where: { $0.identity == "setItem" }) ?? 0
        }

        tbc?.tabBar.backgroundColor = .white
        tbc?.tabBar.barTintColor = .white
        return tbc!
    }

    private enum AssociatedKeys {
        static var markUnreadMap = {}
    }

    var markUnreadMap: [String: Any] {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.markUnreadMap) as? [String: Any] ?? [:]
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.markUnreadMap, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    func redpoint_clearUnreadMessage() {
        V2TIMManager.sharedInstance().cleanConversationUnreadMessageCount(conversationID: "", cleanTimestamp: 0, cleanSequence: 0, succ: { [weak self] in
            guard let self = self else { return }
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TIMAppMarkAllMessageAsReadSucc"))
            self.onTotalUnreadCountChanged(0)
        }, fail: { [weak self] code, desc in
            guard let self = self else { return }
            TUITool.makeToast(String(format: TUISwift.timCommonLocalizableString("TIMAppMarkAllMessageAsReadErrFormat"), code, desc ?? ""))
            self.onTotalUnreadCountChanged(self.unReadCount)
        })
        let conversations = Array(markUnreadMap.keys)
        if !conversations.isEmpty {
            V2TIMManager.sharedInstance().markConversation(conversationIDList: conversations, markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_UNREAD.rawValue), enableMark: false, succ: nil, fail: nil)
        }
    }

    func onTotalUnreadCountChanged(_ totalUnreadCount: UInt) {
        let total = totalUnreadCount
        let item = tbc?.tabBarItems.first
        item?.badgeView!.title = total > 0 ? (total > 99 ? "99+" : "\(total)") : ""
        unReadCount = UInt(total)
    }

    func redpoint_setupTotalUnreadCount() {
        // Getting total unread count
        V2TIMManager.sharedInstance().getTotalUnreadMessageCount(succ: { [weak self] totalCount in
            self?.onTotalUnreadCountChanged(UInt(totalCount))
        }, fail: { _, _ in })

        // Getting the count of friends application
        contactDataProvider.addObserver(contactDataProviderObserver) { [weak self] newValue, _ in
            guard let self = self else { return }
            self.onFriendApplicationCountChanged(Int(newValue.pendencyCnt))
        }
        contactDataProvider.value.loadFriendApplication()
    }

    func onFriendApplicationCountChanged(_ applicationCount: Int) {
        guard let tab = tbc, tab.tabBarItems.count >= 2 else { return }
        var contactItem: TUITabBarItem?
        for item in tab.tabBarItems {
            if item.identity == "contactItem" {
                contactItem = item
                break
            }
        }
        contactItem?.badgeView?.title = applicationCount == 0 ? "" : "\(applicationCount)"
    }

    func caculateRealResultAboutSDKTotalCount(_ totalCount: UInt, markUnreadCount: Int, markHideUnreadCount: Int) -> Int {
        var unreadCalculationResults = Int(totalCount) + markUnreadCount - markHideUnreadCount
        if unreadCalculationResults < 0 {
            // error protect
            unreadCalculationResults = 0
        }
        return unreadCalculationResults
    }

    // MARK: - NSNotification

    @objc func updateMarkUnreadCount(_ note: Notification) {
        guard let userInfo = note.userInfo else { return }
        let markUnreadCount = userInfo["TUIKitNotification_onConversationMarkUnreadCountChanged_MarkUnreadCount"] as? Int ?? 0
        let markHideUnreadCount = userInfo["TUIKitNotification_onConversationMarkUnreadCountChanged_MarkHideUnreadCount"] as? Int ?? 0
        self.markUnreadCount = UInt(markUnreadCount)
        self.markHideUnreadCount = UInt(markHideUnreadCount)
        if let markUnreadMap = userInfo["TUIKitNotification_onConversationMarkUnreadCountChanged_MarkUnreadMap"] as? [String: Any] {
            self.markUnreadMap = markUnreadMap
        }
        V2TIMManager.sharedInstance().getTotalUnreadMessageCount(succ: { [weak self] totalCount in
            guard let self = self else { return }
            let unreadCalculationResults = self.caculateRealResultAboutSDKTotalCount(UInt(totalCount), markUnreadCount: markUnreadCount, markHideUnreadCount: markHideUnreadCount)
            self.onTotalUnreadCountChanged(UInt(unreadCalculationResults))
        }, fail: { _, _ in })
    }

    func onSetAPPUnreadCount() -> UInt {
        return unReadCount // test
    }

    @objc func onDisplayCallsRecordForClassic(_ notice: Notification) {
        onDisplayCallsRecord(notice, isMinimalist: false)
    }

    @objc func onDisplayCallsRecordForMinimalist(_ notice: Notification) {
        onDisplayCallsRecord(notice, isMinimalist: true)
    }

    func onDisplayCallsRecord(_ notice: Notification, isMinimalist: Bool) {
        guard let tabVC = TUIEnterIMViewController.gImWindow?.rootViewController as? TUITabBarController, let value = notice.object as? NSNumber else { return }

        var items = tabVC.tabBarItems
        items.removeAll { $0.identity == "callItem" }

        let isOn = value.boolValue
        if isOn {
            if let item = getCallsRecordTabBarItem(isMinimalist) {
                items.insert(item, at: 1)
            }
        }
        tabVC.setTabBarItems(items)

        tabVC.layoutBadgeViewIfNeeded()
        setupStyleWindow()
    }

    func getCallsRecordTabBarItem(_ isMinimalist: Bool) -> TUITabBarItem? {
        let showCallsRecord = isMinimalist ? UserDefaults.standard.bool(forKey: kEnableCallsRecord_mini) : UserDefaults.standard.bool(forKey: kEnableCallsRecord)
        callingVC = TUICallingHistoryViewController.createCallingHistoryViewController(isMimimalist: isMinimalist)
        callingVC?.viewWillAppearClosure = { [weak self] isAppear in
            guard let self = self else { return }
            self.inCallsRecordVC.value = isAppear
            if (self.inConversationVC.value || self.inContactsVC.value || self.inSettingVC.value) && !isAppear {
                return
            }
            self.dismissWindowBtn?.value?.isHidden = (isMinimalist ? !isAppear : true)
        }
        if showCallsRecord, let callingVC = callingVC {
            let title = isMinimalist ? TUISwift.timCommonLocalizableString("TIMAppTabBarItemCallsRecordText_mini") : TUISwift.timCommonLocalizableString("TIMAppTabBarItemCallsRecordText_mini")
            let selected = isMinimalist ?
                TUISwift.tuiDynamicImage("", themeModule: TUIThemeModule.demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("tab_calls_selected"))) :
                TUISwift.tuiDemoDynamicImage("tab_calls_selected_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("tab_calls_selected")))
            let normal = isMinimalist ?
                TUISwift.tuiDynamicImage("", themeModule: TUIThemeModule.demo_Minimalist, defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath_Minimalist("tab_calls_normal"))) :
                TUISwift.tuiDemoDynamicImage("tab_calls_normal_img", defaultImage: UIImage.safeImage(TUISwift.tuiDemoImagePath("tab_calls_normal")))
            let callsItem = TUITabBarItem()
            callsItem.title = title
            callsItem.selectedImage = selected
            callsItem.normalImage = normal
            callsItem.controller = TUINavigationController(rootViewController: callingVC)
            callsItem.identity = "callItem"
            return callsItem
        }
        return nil
    }

    // MARK: V2TIMConversationListener

    func onTotalUnreadMessageCountChanged(totalUnreadCount: UInt64) {
        let unreadCalculationResults = caculateRealResultAboutSDKTotalCount(UInt(totalUnreadCount), markUnreadCount: Int(markUnreadCount), markHideUnreadCount: Int(markHideUnreadCount))
        onTotalUnreadCountChanged(UInt(unreadCalculationResults))
    }

    // MARK: TUIStyleSelectControllerDelegate

    func onSelectStyle(_ cellModel: TUIStyleSelectCellModel) {
        if cellModel.styleID == "Minimalist" {
            themeLabel?.isHidden = true
            themeSubLabel?.isHidden = true
            themeVC?.view.isHidden = true
        } else {
            themeLabel?.isHidden = false
            themeSubLabel?.isHidden = false
            themeVC?.view.isHidden = false
        }
    }
}
