import AssetsLibrary
import AVFoundation
import MobileCoreServices
import Photos
import TIMCommon
import TUICore
import UIKit

public class TUIBaseChatViewController: UIViewController, TUIBaseMessageControllerDelegate, TUIInputControllerDelegate, UIImagePickerControllerDelegate, UIDocumentPickerDelegate, UINavigationControllerDelegate, TUIMessageMultiChooseViewDelegate, TUIChatBaseDataProviderDelegate, TUINotificationProtocol, TUIJoinGroupMessageCellDelegate, V2TIMConversationListener, TUINavigationControllerDelegate, TUIChatMediaDataListener, TIMInputViewMoreActionProtocol {
    var kTUIInputNormalFont: UIFont {
        UIFont.systemFont(ofSize: 16)
    }

    var kTUIInputNormalTextColor: UIColor {
        TUISwift.tuiChatDynamicColor("chat_input_text_color", defaultColor: "#000000")
    }

    public var highlightKeyword: String?
    public var locateMessage: V2TIMMessage?
    public var messageController: TUIBaseMessageController?
    public var needScrollToBottom: Bool = false
    public var unreadView: TUIUnReadView?
    public var bottomContainerView: UIView = .init()
    public var inputController: TUIInputController!
    var moreMenus: [TUIInputMoreCellData]? {
        didSet {
            inputController.moreView.setData(moreMenus ?? [])
        }
    }

    private var dataProvider: TUIChatDataProvider!
    private var firstAppear: Bool = false
    private var responseKeyboard: Bool = false
    private var isPageAppears: Bool = false

    private var titleView: TUINaviBarIndicatorView?
    private var multiChooseView: TUIMessageMultiChooseView?
    private var backgroudView: UIImageView!

    private var otherSideTypingObservation: NSKeyValueObservation?
    private var faceUrlObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?

    static var gCustomTopView: UIView?
    static var gTopExtensionView: UIView?
    static var gGroupPinTopView: UIView?
    static var gCustomTopViewRect: CGRect?

    public static var customTopView: UIView? {
        get {
            return gCustomTopView
        } set {
            gCustomTopView = newValue
            gCustomTopViewRect = newValue?.frame ?? .zero
            gCustomTopView?.clipsToBounds = true
        }
    }

    public static var groupPinTopView: UIView? {
        get {
            return gGroupPinTopView
        } set {
            gGroupPinTopView = newValue
        }
    }

    public static func topAreaBottomView() -> UIView? {
        return gGroupPinTopView ?? gCustomTopView ?? gTopExtensionView ?? nil
    }

    private var _mediaProvider: TUIChatMediaDataProvider?
    var mediaProvider: TUIChatMediaDataProvider? {
        get {
            if _mediaProvider == nil {
                _mediaProvider = TUIChatMediaDataProvider()
                _mediaProvider?.listener = self
                _mediaProvider?.presentViewController = self
            }
            return _mediaProvider
        }
        set {}
    }
    
    // AI interrupt message properties
    var lastSendInterruptMessageTime: TimeInterval = 0
    var receivingChatbotMessage: TUIMessageCellData?

    public var conversationData: TUIChatConversationModel? {
        didSet {
            guard let conversationData = conversationData else { return }

            let userID = conversationData.userID ?? ""
            let param: [String: Any] = ["TUICore_TUIChatExtension_GetChatConversationModelParams_UserID": userID]
            let extensionList = TUICore.getExtensionList("TUICore_TUIChatExtension_GetChatConversationModelParams", param: param)

            if let extention = extensionList.first, let data = extention.data {
                conversationData.msgNeedReadReceipt = (data["TUICore_TUIChatExtension_GetChatConversationModelParams_MsgNeedReadReceipt"] as? Bool) ?? false
                conversationData.enableVideoCall = (data["TUICore_TUIChatExtension_GetChatConversationModelParams_EnableVideoCall"] as? Bool) ?? false
                conversationData.enableAudioCall = (data["TUICore_TUIChatExtension_GetChatConversationModelParams_EnableAudioCall"] as? Bool) ?? false
                conversationData.enableWelcomeCustomMessage = (data["TUICore_TUIChatExtension_GetChatConversationModelParams_EnableWelcomeCustomMessage"] as? Bool) ?? false
            }
        }
    }

    // MARK: - Init

    public init() {
        super.init(nibName: nil, bundle: nil)
        createCachePath()
        TUIAIDenoiseSignatureManager.sharedInstance.updateSignature()
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTopViewsAndMessagePage), name: Notification.Name("TUICore_TUIChatExtension_ChatViewTopArea_ChangedNotification"), object: nil)
        TUIChatMediaSendingManager.shared.addCurrentVC(self)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        TUICore.unRegisterEvent(byObject: self)
        NotificationCenter.default.removeObserver(self)
        otherSideTypingObservation = nil
        faceUrlObservation = nil
        titleObservation = nil
    }

    // MARK: - Lift cycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupTopViews()

        // data provider
        dataProvider = TUIChatDataProvider()
        dataProvider.delegate = self

        firstAppear = true
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#FFFFFF")
        edgesForExtendedLayout = []

        configBackgroundView()

        // setup UI
        setupNavigator()
        setupMessageController()
        setupInputMoreMenu()
        setupInputController()
        setupShortcutView()

        let userInfo = ["TUIKitNotification_onMessageVCBottomMarginChanged_Margin": 0]
        NotificationCenter.default.post(name: NSNotification.Name("TUIKitNotification_onMessageVCBottomMarginChanged"), object: nil, userInfo: userInfo)

        setupBottomContainerView()

        configNotify()
    }

    override public func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            saveDraft()
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configTopViewsInWillAppear()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        responseKeyboard = true
        isPageAppears = true
        if firstAppear == true {
            loadDraft()
            firstAppear = false
        }
        if needScrollToBottom {
            messageController?.scrollToBottom(true)
            needScrollToBottom = false
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isPageAppears = false
        responseKeyboard = false
        openMultiChooseBoard(isOpen: false)
        messageController?.enableMultiSelectedMode(false)
    }

    override public func viewDidLayoutSubviews() {
        layoutBottomContainerView()
    }

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if conversationData?.isLimitedPortraitOrientation ?? false {
            return .portrait
        } else {
            return .allButUpsideDown
        }
    }

    // MARK: - Setup views and data

    func createCachePath() {
        let fileManager = FileManager.default

        let paths = [
            TUISwift.tuiKit_Image_Path(),
            TUISwift.tuiKit_Video_Path(),
            TUISwift.tuiKit_Voice_Path(),
            TUISwift.tuiKit_File_Path(),
            TUISwift.tuiKit_DB_Path()
        ]

        for path in paths {
            do {
                if !fileManager.fileExists(atPath: path) {
                    try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                }
            } catch {
                print("Failed to create directory at path: \(path). Error: \(error)")
            }
        }
    }

    func setupTopViews() {
        if let gTopExtensionView = TUIBaseChatViewController.gTopExtensionView {
            gTopExtensionView.removeFromSuperview()
        } else {
            TUIBaseChatViewController.gTopExtensionView = UIView()
            TUIBaseChatViewController.gTopExtensionView!.clipsToBounds = true
        }

        if let gGroupPinTopView = TUIBaseChatViewController.gGroupPinTopView {
            gGroupPinTopView.removeFromSuperview()
        } else {
            TUIBaseChatViewController.gGroupPinTopView = UIView()
            TUIBaseChatViewController.gGroupPinTopView?.clipsToBounds = true
        }

        if TUIBaseChatViewController.gTopExtensionView != nil {
            setupTopExtensionView()
        }

        if let gCustomTopView = TUIBaseChatViewController.gCustomTopView,
           let gCustomTopViewRect = TUIBaseChatViewController.gCustomTopViewRect
        {
            setupCustomTopView()
            gCustomTopView.frame = CGRect(x: 0, y: TUIBaseChatViewController.gTopExtensionView?.frame.maxY ?? 0, width: gCustomTopViewRect.size.width, height: gCustomTopViewRect.size.height)
        }

        if let gGroupPinTopView = TUIBaseChatViewController.gGroupPinTopView,
           let groupID = conversationData?.groupID, !groupID.isEmpty
        {
            setupGroupPinTopView()
            gGroupPinTopView.frame = CGRect(x: 0, y: TUIBaseChatViewController.gCustomTopView?.frame.maxY ?? 0, width: gGroupPinTopView.frame.size.width, height: gGroupPinTopView.frame.size.height)
        }
    }

    func setupGroupPinTopView() {
        guard let groupPinTopView = TUIBaseChatViewController.gGroupPinTopView else { return }
        if groupPinTopView.superview != view {
            view.addSubview(groupPinTopView)
        }
        groupPinTopView.backgroundColor = UIColor.clear
        groupPinTopView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 0)
    }

    func setupTopExtensionView() {
        if let topExtensionView = TUIBaseChatViewController.gTopExtensionView {
            if topExtensionView.superview != view {
                view.addSubview(topExtensionView)
            }
            topExtensionView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 0)
            var param: [String: Any] = [:]
            if let userID = conversationData?.userID, userID.count > 0 {
                param["TUICore_TUIChatExtension_ChatViewTopArea_ChatID"] = userID
                param["TUICore_TUIChatExtension_ChatViewTopArea_IsGroup"] = "0"
            } else if let groupID = conversationData?.groupID, groupID.count > 0 {
                param["TUICore_TUIChatExtension_ChatViewTopArea_IsGroup"] = "1"
                param["TUICore_TUIChatExtension_ChatViewTopArea_ChatID"] = groupID
            }

            TUICore.raiseExtension("TUICore_TUIChatExtension_ChatViewTopArea_ClassicExtensionID", parentView: topExtensionView, param: param)
        }
    }

    func configBackgroundView() {
        backgroudView = UIImageView()
        backgroudView.backgroundColor = TUIChatConfig.shared.backgroudColor ?? TUISwift.tuiChatDynamicColor("chat_controller_bg_color", defaultColor: "#FFFFFF")
        let conversationID = getConversationID()
        let imgUrl = getBackgroundImageUrl(byConversationID: conversationID)

        if TUIChatConfig.shared.backgroudImage != nil {
            backgroudView.backgroundColor = .clear
            backgroudView.image = TUIChatConfig.shared.backgroudImage
        } else if imgUrl != nil {
            backgroudView.sd_setImage(with: URL(string: imgUrl!), placeholderImage: nil)
        }

        let textViewHeight = TUIChatConfig.shared.enableMainPageInputBar ? TTextView_Height : 0
        backgroudView.frame = CGRect(x: 0, y: view.frame.origin.y, width: view.frame.size.width, height: view.frame.size.height - CGFloat(textViewHeight) - TUISwift.bottom_SafeHeight())

        view.insertSubview(backgroudView, at: 0)
    }

    func configNotify() {
        V2TIMManager.sharedInstance().addConversationListener(listener: self)
        TUICore.registerEvent("TUICore_TUIConversationNotify", subKey: "TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey", object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(onFriendInfoChanged(_:)), name: NSNotification.Name("FriendInfoChangedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive(_:)), name: NSNotification.Name("UIApplicationWillResignActiveNotification"), object: nil)

        TUICore.registerEvent("TUICore_TUIContactNotify", subKey: "TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey", object: self)
        TUICore.registerEvent("TUICore_TUIChatNotify", subKey: "TUICore_TUIChatNotify_SendMessageSubKey", object: self)
    }

    @objc func appWillResignActive(_ noti: Notification) {
        saveDraft()
    }

    func setupNavigator() {
        guard let conversationData = conversationData else { return }

        if let naviController = navigationController as? TUINavigationController {
            naviController.uiNaviDelegate = self
            let backimg = TUISwift.timCommonDynamicImage("nav_back_img", defaultImage: UIImage.safeImage(TUISwift.timCommonImagePath("nav_back")))
            naviController.navigationItemBackArrowImage = backimg.rtlImageFlippedForRightToLeftLayoutDirection()
        }
        titleView = TUINaviBarIndicatorView()
        navigationItem.titleView = titleView
        navigationItem.title = ""

        titleObservation = conversationData.observe(\.title, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let title = change.newValue, title != nil else { return }
            self.titleView?.setTitle(title!)
        }

        otherSideTypingObservation = conversationData.observe(\.otherSideTyping, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newValue = change.newValue else { return }
            if !newValue {
                checkTitle(force: true)
            } else {
                let typingText = TUISwift.timCommonLocalizableString("TUIKitTyping") + "..."
                self.titleView?.setTitle(typingText)
            }
        }

        checkTitle(force: false)
        TUIChatDataProvider.getTotalUnreadMessageCount { [weak self] totalCount in
            guard let self else { return }
            self.onChangeUnReadCount(Int(totalCount))
        } fail: { _, _ in }

        unreadView = TUIUnReadView()

        let itemSize = CGSize(width: 25, height: 25)
        var rightBarButtonList = [UIBarButtonItem]()
        var param = [String: Any]()
        
        // Check if this is an AI conversation and add AI clear button
        if conversationData.isAIConversation() {
            let button = UIButton(frame: CGRect(x: 0, y: 0, width: itemSize.width, height: itemSize.height))
            let clearIcon = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("chat_ai_clear_icon"))
            button.setImage(clearIcon, for: .normal)
            button.widthAnchor.constraint(equalToConstant: itemSize.width).isActive = true
            button.heightAnchor.constraint(equalToConstant: itemSize.height).isActive = true
            button.addTarget(self, action: #selector(rightBarAIClearButtonClick(_:)), for: .touchUpInside)
            let rightItem = UIBarButtonItem(customView: button)
            navigationItem.rightBarButtonItems = [rightItem]
            return
        }
        
        if let userID = conversationData.userID, !userID.isEmpty {
            param["TUICore_TUIChatExtension_NavigationMoreItem_UserID"] = userID
        } else if let groupID = conversationData.groupID, !groupID.isEmpty {
            param["TUICore_TUIChatExtension_NavigationMoreItem_GroupID"] = groupID
        }
        param["TUICore_TUIChatExtension_NavigationMoreItem_ItemSize"] = itemSize
        param["TUICore_TUIChatExtension_NavigationMoreItem_FilterVideoCall"] = !TUIChatConfig.shared.enableVideoCall
        param["TUICore_TUIChatExtension_NavigationMoreItem_FilterAudioCall"] = !TUIChatConfig.shared.enableAudioCall

        let extensionList: [TUIExtensionInfo]? = TUICore.getExtensionList("TUICore_TUIChatExtension_NavigationMoreItem_ClassicExtensionID", param: param)
        var maxWeightInfo = TUIExtensionInfo()
        maxWeightInfo.weight = Int.min
        if let extensionList = extensionList {
            for info in extensionList {
                if maxWeightInfo.weight < info.weight {
                    maxWeightInfo = info
                }
                if let icon = maxWeightInfo.icon, let _ = maxWeightInfo.onClicked {
                    let button = UIButton(frame: CGRect(x: 0, y: 0, width: itemSize.width, height: itemSize.height))
                    button.widthAnchor.constraint(equalToConstant: itemSize.width).isActive = true
                    button.heightAnchor.constraint(equalToConstant: itemSize.height).isActive = true
                    button.tui_extValueObj = maxWeightInfo
                    button.addTarget(self, action: #selector(rightBarButtonClick(_:)), for: .touchUpInside)
                    button.setImage(icon, for: .normal)
                    let rightItem = UIBarButtonItem(customView: button)
                    rightBarButtonList.append(rightItem)
                }
            }
        }

        if rightBarButtonList.count > 0 {
            navigationItem.rightBarButtonItems = rightBarButtonList.reversed()
        }
    }

    @objc func rightBarButtonClick(_ button: UIButton) {
        inputController.reset()

        guard let info = button.tui_extValueObj as? TUIExtensionInfo, let onClicked = info.onClicked else {
            return
        }

        var param: [String: Any] = [:]
        if let userID = conversationData?.userID, userID.count > 0 {
            param["TUICore_TUIChatExtension_NavigationMoreItem_UserID"] = userID
        } else if let groupID = conversationData?.groupID, groupID.count > 0 {
            param["TUICore_TUIChatExtension_NavigationMoreItem_GroupID"] = groupID
        }

        if let navigationController = navigationController {
            param["TUICore_TUIChatExtension_NavigationMoreItem_PushVC"] = navigationController
        }

        onClicked(param)
    }

    @objc func rightBarAIClearButtonClick(_ button: UIButton) {
        inputController.reset()
        // Check if AI is currently typing
        if let aiIsTyping = inputController.inputBar?.aiIsTyping, aiIsTyping {
            showHudMsgText(TUISwift.timCommonLocalizableString("TUIKitAITyping"))
            return
        }
        
        guard let userID = conversationData?.userID, !userID.isEmpty else {
            return
        }
        
        let alertController = UIAlertController(
            title: nil,
            message: TUISwift.timCommonLocalizableString("TUIKitClearAllChatHistoryTips"),
            preferredStyle: .alert
        )
        
        let confirmAction = UIAlertAction(
            title: TUISwift.timCommonLocalizableString("Confirm"),
            style: .destructive
        ) { [weak self] _ in
            guard let self = self else { return }
            
            V2TIMManager.sharedInstance().clearC2CHistoryMessage(userID:userID) {
                // Success
                TUICore.notifyEvent(
                    "TUICore_TUIConversationNotify",
                    subKey: "TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey",
                    object: self,
                    param: nil
                )
                TUITool.makeToast(TUISwift.timCommonLocalizableString("Done"))
            } fail: { code, desc in
                // Failure
                TUITool.makeToastError(Int(code), msg: desc)
            }
        }
        
        let cancelAction = UIAlertAction(
            title: TUISwift.timCommonLocalizableString("Cancel"),
            style: .cancel,
            handler: nil
        )
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }

    func setupCustomTopView() {
        guard let customTopView = TUIBaseChatViewController.gCustomTopView, customTopView.superview == self.view else { return }
        view.addSubview(customTopView)
    }

    func setupBottomContainerView() {
        view.addSubview(bottomContainerView)

        let viewHeight = conversationData?.shortcutViewHeight ?? 0
        if let shortcutMenuItems = conversationData?.shortcutMenuItems, shortcutMenuItems.count > 0 {
            let view = TUIChatShortcutMenuView(dataSource: shortcutMenuItems)
            view.viewHeight = viewHeight
            view.itemHorizontalSpacing = 0.0
            if let backgroundColor = conversationData?.shortcutViewBackgroundColor {
                view.backgroundColor = backgroundColor
            }
            bottomContainerView.addSubview(view)
            view.updateFrame()
        } else {
            notifyBottomContainerReady()
        }
    }

    func notifyBottomContainerReady() {
        TUICore.registerEvent("TUICore_TUIPluginNotify",
                              subKey: "TUICore_TUIPluginNotify_PluginViewDidAddToSuperview",
                              object: self)

        let userID = conversationData?.userID ?? ""
        let params: [String: Any] = [
            "TUICore_TUIChatExtension_ChatVCBottomContainer_UserID": userID,
            "TUICore_TUIChatExtension_ChatVCBottomContainer_VC": self
        ]

        TUICore.raiseExtension("TUICore_TUIChatExtension_ChatVCBottomContainer_ClassicExtensionID",
                               parentView: bottomContainerView,
                               param: params)
    }

    func layoutBottomContainerView() {
        if bottomContainerView.mm_y == (messageController?.view.frame.maxY ?? 0) {
            return
        }
        if let data = conversationData,
           let shortcutMenuItems = data.shortcutMenuItems, shortcutMenuItems.count > 0,
           let messageController = messageController
        {
            let height = data.shortcutViewHeight > 0 ? data.shortcutViewHeight : 46
            messageController.view.frame.size.height -= height
            bottomContainerView.frame = CGRect(x: 0, y: messageController.view.frame.maxY, width: messageController.view.frame.width, height: height)
        }
    }

    func setupInputController() {
        inputController = TUIInputController()
        inputController.delegate = self
        inputController.view.frame = CGRect(x: 0, y: view.frame.size.height - CGFloat(TTextView_Height) - TUISwift.bottom_SafeHeight(), width: view.frame.size.width, height: CGFloat(TTextView_Height) + TUISwift.bottom_SafeHeight())
        inputController.view.autoresizingMask = .flexibleTopMargin
        addChild(inputController)
        view.addSubview(inputController.view)
        inputController.view.isHidden = !TUIChatConfig.shared.enableMainPageInputBar
        
        // AI conversation style setup
        if let data = conversationData, data.isAIConversation() {
            inputController.enableAIStyle(true)
            
            // Check if there's existing AI typing message
            if let conversationID = data.conversationID {
                let currentAITypingMessage = TUIAIPlaceholderTypingMessageManager.shared.getAIPlaceholderTypingMessage(forConversation: conversationID)
                if currentAITypingMessage != nil {
                    setAIStartTyping()
                }
            }
            
            // Setup streaming message callback
            messageController?.steamCellFinishedBlock = { [weak self] finished, cellData in
                guard let self = self else { return }
                if !finished {
                    self.setAIStartTyping()
                    self.receivingChatbotMessage = cellData
                } else {
                    self.setAIFinishTyping()
                    // Clear the receiving chatbot message
                    self.receivingChatbotMessage = nil
                    
                }
            }
        }
        
        if let data = conversationData {
            moreMenus = dataProvider.getMoreMenuCellDataArray(groupID: data.groupID ?? "", userID: data.userID ?? "", conversationModel: data, actionController: self)
        }
    }

    func setupShortcutView() {
        if let data = conversationData,
           let dataSource = TUIChatConfig.shared.shortcutViewDataSource,
           let items = dataSource.items?(of: data), !items.isEmpty
        {
            data.shortcutMenuItems = items
            if let viewBackgroundColor = dataSource.backgroundColor?(of: data) {
                data.shortcutViewBackgroundColor = viewBackgroundColor
            }
            if let viewCustomHeight = dataSource.height?(of: data) {
                data.shortcutViewHeight = viewCustomHeight
            }
        }
    }

    func setupInputMoreMenu() {
        guard let conversationData = conversationData else { return }
        guard let dataSource = TUIChatConfig.shared.inputBarDataSource else { return }
        let tag = dataSource.shouldHideItems(of: conversationData)
        conversationData.enableFile = !(tag.contains(TUIChatInputBarMoreMenuItem.file))
        conversationData.enablePoll = !(tag.contains(TUIChatInputBarMoreMenuItem.poll))
        conversationData.enableRoom = !(tag.contains(TUIChatInputBarMoreMenuItem.room))
        conversationData.enableAlbum = !(tag.contains(TUIChatInputBarMoreMenuItem.album))
        conversationData.enableAudioCall = !(tag.contains(TUIChatInputBarMoreMenuItem.audioCall))
        conversationData.enableVideoCall = !(tag.contains(TUIChatInputBarMoreMenuItem.videoCall))
        conversationData.enableGroupNote = !(tag.contains(TUIChatInputBarMoreMenuItem.groupNote))
        conversationData.enableTakePhoto = !(tag.contains(TUIChatInputBarMoreMenuItem.takePhoto))
        conversationData.enableRecordVideo = !(tag.contains(TUIChatInputBarMoreMenuItem.recordVideo))
        conversationData.enableWelcomeCustomMessage = !(tag.contains(TUIChatInputBarMoreMenuItem.customMessage))

        if let items = dataSource.shouldAddNewItemsToMoreMenu(of: conversationData) {
            conversationData.customizedNewItemsInMoreMenu = items
        }
    }

    func setupMessageController() {
        guard let conversationData = conversationData else { return }
        let vc = TUIMessageController()
        vc.highlightKeyword = highlightKeyword
        vc.locateMessage = locateMessage
        vc.isMsgNeedReadReceipt = conversationData.msgNeedReadReceipt && TUIChatConfig.shared.msgNeedReadReceipt
        messageController = vc
        messageController!.delegate = self
        messageController!.setConversation(conversationData: conversationData)

        let textViewHeight = TUIChatConfig.shared.enableMainPageInputBar ? TTextView_Height : 0
        let height = view.frame.size.height - CGFloat(textViewHeight) - TUISwift.bottom_SafeHeight() - topMarginByCustomView()
        messageController!.view.frame = CGRect(x: 0, y: topMarginByCustomView(), width: view.frame.size.width,
                                               height: height)

        addChild(messageController!)
        view.addSubview(messageController!.view)
        messageController!.didMove(toParent: self)
    }

    func configTopViewsInWillAppear() {
        if let customTopView = TUIBaseChatViewController.gCustomTopView, customTopView.superview != view {
            if customTopView.frame == .zero,
               let topExtensionView = TUIBaseChatViewController.gTopExtensionView,
               let customTopViewRect = TUIBaseChatViewController.gCustomTopViewRect
            {
                customTopView.frame = CGRect(
                    x: 0, y: topExtensionView.frame.maxY, width: customTopViewRect.width,
                    height: customTopViewRect.height
                )
            }
            view.addSubview(customTopView)
        }

        if let topExtensionView = TUIBaseChatViewController.gTopExtensionView, topExtensionView.superview != view {
            view.addSubview(topExtensionView)
        }

        if let groupID = conversationData?.groupID, !groupID.isEmpty {
            if let groupPinTopView = TUIBaseChatViewController.gGroupPinTopView, groupPinTopView.superview != view {
                view.addSubview(groupPinTopView)
            }
        }

        reloadTopViewsAndMessagePage()
    }

    func loadDraft() {
        guard let draft = conversationData?.draftText, !draft.isEmpty else { return }
        do {
            if let data = draft.data(using: .utf8), let jsonDict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                let draftContent = jsonDict["content"] as? String ?? ""
                var locations: [[NSValue: NSAttributedString]]? = nil
                let formatEmojiString = draftContent.getAdvancedFormatEmojiString(withFont: kTUIInputNormalFont, textColor: kTUIInputNormalTextColor, emojiLocations: &locations)
                inputController.inputBar?.addDraftToInputBar(formatEmojiString)

                if let messageRootID = jsonDict["messageRootID"] as? String,
                   let reply = jsonDict["messageReply"] as? [String: Any],
                   reply.keys.contains("messageID"),
                   reply.keys.contains("messageAbstract"),
                   reply.keys.contains("messageSender"),
                   reply.keys.contains("messageType"),
                   reply.keys.contains("version")
                {
                    if let version = reply["version"] as? Int, version <= kDraftMessageReplyVersion {
                        if !messageRootID.isEmpty {
                            let replyPreviewData = TUIReplyPreviewData()
                            replyPreviewData.msgID = reply["messageID"] as? String ?? ""
                            replyPreviewData.msgAbstract = reply["messageAbstract"] as? String ?? ""
                            replyPreviewData.sender = reply["messageSender"] as? String ?? ""
                            replyPreviewData.type = reply["messageType"] as? V2TIMElemType ?? V2TIMElemType.ELEM_TYPE_NONE
                            replyPreviewData.messageRootID = messageRootID
                            inputController.showReplyPreview(replyPreviewData)
                        } else {
                            let referencePreviewData = TUIReferencePreviewData()
                            referencePreviewData.msgID = reply["messageID"] as? String ?? ""
                            referencePreviewData.msgAbstract = reply["messageAbstract"] as? String ?? ""
                            referencePreviewData.sender = reply["messageSender"] as? String ?? ""
                            referencePreviewData.type = reply["messageType"] as? V2TIMElemType ?? V2TIMElemType.ELEM_TYPE_NONE
                            inputController.showReferencePreview(referencePreviewData)
                        }
                    }
                }
            }
        } catch {
            var locations: [[NSValue: NSAttributedString]]? = nil
            let formatEmojiString = draft.getAdvancedFormatEmojiString(withFont: kTUIInputNormalFont, textColor: kTUIInputNormalTextColor, emojiLocations: &locations)
            inputController.inputBar?.addDraftToInputBar(formatEmojiString)
        }
    }

    func saveDraft() {
        guard let conversationData = conversationData else { return }
        var content = inputController.inputBar?.inputTextView.textStorage.tui_getPlainString()

        var previewData: TUIReplyPreviewData? = nil
        if let referenceData = inputController.referenceData {
            previewData = referenceData
        } else if let replyData = inputController.replyData {
            previewData = replyData
        }

        if let previewData = previewData {
            let contentValue = content ?? ""
            let messageID = previewData.msgID ?? ""
            let messageAbstract = (previewData.msgAbstract ?? "").getInternationalStringWithFaceContent()
            let messageSender = previewData.sender ?? ""
            let messageType = previewData.type.rawValue
            let messageTime = previewData.originMessage?.timestamp?.timeIntervalSince1970 ?? 0
            let messageSequence = previewData.originMessage?.seq ?? 0

            let dict: [String: Any] = [
                "content": contentValue,
                "messageReply": [
                    "messageID": messageID,
                    "messageAbstract": messageAbstract,
                    "messageSender": messageSender,
                    "messageType": messageType,
                    "messageTime": messageTime, // Compatible for web
                    "messageSequence": messageSequence, // Compatible for web
                    "version": kDraftMessageReplyVersion
                ]
            ]

            var mutableDict = dict
            if let rootID = previewData.messageRootID, !rootID.isEmpty {
                mutableDict["messageRootID"] = rootID
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: mutableDict, options: [])
                content = String(data: data, encoding: .utf8)
            } catch {
                print("Error serializing dictionary: \(error)")
            }
        }

        if let conversationID = conversationData.conversationID, let text = content {
            TUIChatDataProvider.saveDraft(withConversationID: conversationID, text: text)
        }
    }

    @objc func reloadTopViewsAndMessagePage() {
        TUIBaseChatViewController.gCustomTopView?.frame = CGRect(x: 0, y: TUIBaseChatViewController.gTopExtensionView?.frame.maxY ?? 0, width: TUIBaseChatViewController.gCustomTopView?.frame.width ?? 0, height: TUIBaseChatViewController.gCustomTopView?.frame.height ?? 0)

        if let groupPinTopView = TUIBaseChatViewController.gGroupPinTopView {
            groupPinTopView.frame = CGRect(x: 0, y: TUIBaseChatViewController.gCustomTopView?.frame.maxY ?? 0, width: groupPinTopView.frame.width, height: groupPinTopView.frame.height)
        }

        let topMarginByCustomView = topMarginByCustomView()
        if messageController?.view.mm_y != topMarginByCustomView {
            let textViewHeight = TUIChatConfig.shared.enableMainPageInputBar ? TTextView_Height : 0
            messageController?.view.frame = CGRect(x: 0, y: topMarginByCustomView, width: view.mm_w,
                                                   height: view.mm_h - CGFloat(textViewHeight) - TUISwift.bottom_SafeHeight() - topMarginByCustomView)

            messageController?.scrollToBottom(true)
        }
    }

    private func topMarginByCustomView() -> CGFloat {
        let customTopViewHeight = TUIBaseChatViewController.gCustomTopView?.superview != nil ? (TUIBaseChatViewController.gCustomTopView?.frame.height ?? 0) : 0
        let topExtensionHeight = TUIBaseChatViewController.gTopExtensionView?.superview != nil ? (TUIBaseChatViewController.gTopExtensionView?.frame.height ?? 0) : 0
        let groupPinTopViewHeight = TUIBaseChatViewController.groupPinTopView?.superview != nil ? (TUIBaseChatViewController.groupPinTopView?.frame.height ?? 0) : 0

        return customTopViewHeight + topExtensionHeight + groupPinTopViewHeight
    }

    // MARK: - Event

    public func sendMessage(_ message: V2TIMMessage) {
        messageController?.sendMessage(message)
    }

    public func sendMessage(_ message: V2TIMMessage, placeHolderCellData: TUIMessageCellData?) {
        messageController?.sendMessage(message, placeHolderCellData: placeHolderCellData)
    }

    func onChangeUnReadCount(_ totalCount: Int) {
        /**
         * The reason for the asynchrony here: The current chat page receives messages continuously and frequently, it may not be marked as read, and unread changes
         * will also be received at this time. In theory, the unreads at this time will not include the current session.
         */
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.unreadView?.setNum(totalCount)
        }
    }

    func checkTitle(force: Bool) {
        guard let conversationData = conversationData else { return }
        if force || (conversationData.title?.isEmpty ?? true) {
            if let userID = conversationData.userID, !userID.isEmpty {
                if conversationData.title?.isEmpty ?? true {
                    conversationData.title = userID
                }
                TUIChatDataProvider.getFriendInfo(withUserId: userID, succ: { [weak self] friendInfoResult in
                    guard let self else { return }
                    let isFriend = (friendInfoResult.relation.rawValue & V2TIMFriendRelationType.FRIEND_RELATION_TYPE_IN_MY_FRIEND_LIST.rawValue) == 1
                    let friendInfo: V2TIMFriendInfo? = friendInfoResult.friendInfo
                    let friendRemark = friendInfo?.friendRemark ?? ""

                    if isFriend, friendRemark.count > 0 {
                        self.conversationData?.title = friendRemark
                    } else {
                        TUIChatDataProvider.getUserInfo(withUserId: userID, succ: { userInfo in
                            if let nickName = userInfo.nickName, !nickName.isEmpty {
                                self.conversationData?.title = userInfo.nickName
                            }
                        }, fail: { _, _ in })
                    }
                }, fail: { _, _ in })
            } else if let groupID = conversationData.groupID, !groupID.isEmpty {
                TUIChatDataProvider.getGroupInfo(withGroupID: groupID) { [weak self] groupResult in
                    guard let self else { return }
                    if let info = groupResult.info, let groupName = info.groupName,
                       groupName.count > 0, conversationData.enableRoom
                    {
                        self.conversationData?.title = groupName
                    }
                    if groupResult.info?.groupType == "Room" {
                        navigationItem.rightBarButtonItem = nil
                    }
                } fail: { _, _ in }
            }
        }
    }

    @objc func onInfoViewTapped() {
        inputController.reset()
        guard let conversationData = conversationData else { return }
        if let userID = conversationData.userID, !userID.isEmpty {
            getUserOrFriendProfileVCWithUserID(userID, succBlock: { [weak self] vc in
                guard let self = self else { return }
                self.navigationController?.pushViewController(vc, animated: true)
            }, failBlock: { code, desc in
                TUITool.makeToastError(Int(code), msg: desc ?? "")
            })
        } else {
            if let groupID = conversationData.groupID {
                let param = ["TUICore_TUIContactObjectFactory_GetGroupInfoVC_GroupID": groupID]
                navigationController?.push("TUICore_TUIContactObjectFactory_GetGroupInfoVC_Classic", param: param, forResult: nil)
            }
        }
    }

    func getUserOrFriendProfileVCWithUserID(_ userID: String, succBlock: @escaping (UIViewController) -> Void, failBlock: @escaping (Int32, String?) -> Void) {
        let param: [String: Any] = [
            "TUICore_TUIContactService_etUserOrFriendProfileVCMethod_UserIDKey": userID,
            "TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_SuccKey": succBlock,
            "TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_FailKey": failBlock
        ]

        TUICore.createObject("TUICore_TUIContactObjectFactory", key: "TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod", param: param)
    }

    // MARK: - TUICore Notify

    public func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIConversationNotify" && subKey == "TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey" {
            messageController?.clearUImsg()
        } else if key == "TUICore_TUIContactNotify" && subKey == "TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey" {
            if let conversationID = param?["TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey_ConversationID"] as? String, !conversationID.isEmpty {
                updateBackgroundImageUrl(byConversationID: conversationID)
            }
        }  else if key == "TUICore_TUIPluginNotify" && subKey == "TUICore_TUIPluginNotify_PluginViewDidAddToSuperview" {
            if let height = param?["TUICore_TUIPluginNotify_PluginViewDidAddToSuperviewSubKey_PluginViewHeight"] as? Float, let messageController = messageController {
                messageController.view.frame = CGRect(
                    x: 0,
                    y: topMarginByCustomView(),
                    width: view.frame.size.width,
                    height: messageController.view.frame.height - CGFloat(height)
                )
                messageController.view.setNeedsLayout()
                messageController.view.layoutIfNeeded()

                DispatchQueue.main.async {
                    self.bottomContainerView.frame = CGRect(
                        x: 0,
                        y: self.messageController?.view.frame.maxY ?? 0,
                        width: self.messageController?.view.frame.width ?? 0,
                        height: CGFloat(height)
                    )
                }

                let userInfo: [String: Any] = ["TUIKitNotification_onMessageVCBottomMarginChanged_Margin": height]
                NotificationCenter.default.post(name: Notification.Name("TUIKitNotification_onMessageVCBottomMarginChanged"), object: nil, userInfo: userInfo)
            }
        }
        else if key == "TUICore_TUIChatNotify" && subKey == "TUICore_TUIChatNotify_SendMessageSubKey" {
            let code = param?["TUICore_TUIChatNotify_SendMessageSubKey_Code"] as? Int ?? -1
            // let desc = param?["TUICore_TUIChatNotify_SendMessageSubKey_Desc"] as? String
            let isAIConversation = conversationData?.isAIConversation() ?? false
            
            if code == 0 && isAIConversation {
                // Create AI placeholder message immediately when user sends message
                if(inputController.inputBar?.aiIsTyping == true) {
                    self.messageController?.createAITypingMessage()
                }
            }
        }
    }

    func updateBackgroundImageUrl(byConversationID conversationID: String) {
        if getConversationID() == conversationID {
            backgroudView?.backgroundColor = .clear
            if let imgUrl = getBackgroundImageUrl(byConversationID: conversationID) {
                backgroudView?.sd_setImage(with: URL(string: imgUrl), placeholderImage: nil)
            } else {
                backgroudView?.image = nil
            }
        }
    }

    func getBackgroundImageUrl(byConversationID targerConversationID: String) -> String? {
        guard !targerConversationID.isEmpty else { return nil }
        let dict = UserDefaults.standard.dictionary(forKey: "conversation_backgroundImage_map") ?? [:]
        let conversationID_UserID = "\(targerConversationID)_\(TUILogin.getUserID() ?? "")"
        guard dict is [String: String] && dict.keys.contains(conversationID_UserID) else { return nil }
        return dict[conversationID_UserID] as? String
    }

    func getConversationID() -> String {
        guard let conversationData = conversationData else { return "" }

        var conversationID = ""
        if let conversationIDValue = conversationData.conversationID, !conversationIDValue.isEmpty {
            conversationID = conversationIDValue
        } else if let userID = conversationData.userID, !userID.isEmpty {
            conversationID = "c2c_\(userID)"
        } else if let groupID = conversationData.groupID, !groupID.isEmpty {
            conversationID = "group_\(groupID)"
        }
        return conversationID
    }

    // MARK: - TUIInputControllerDelegate

    func inputController(_ inputController: TUIInputController, didChangeHeight height: CGFloat) {
        guard responseKeyboard, let messageController = messageController else { return }

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            var msgFrame = messageController.view.frame
            let calHeight = self.view.frame.height - height - self.topMarginByCustomView() - self.bottomContainerView.frame.height
            msgFrame.size.height = max(0, calHeight)
            messageController.view.frame = msgFrame

            if self.bottomContainerView.frame.height > 0 {
                var containerFrame = self.bottomContainerView.frame
                containerFrame.origin.y = msgFrame.origin.y + msgFrame.size.height
                self.bottomContainerView.frame = containerFrame

                var inputFrame = self.inputController.view.frame
                inputFrame.origin.y = self.bottomContainerView.frame.maxY
                inputFrame.size.height = height
                self.inputController.view.frame = inputFrame
            } else {
                var inputFrame = self.inputController.view.frame
                inputFrame.origin.y = msgFrame.origin.y + msgFrame.size.height
                inputFrame.size.height = height
                self.inputController.view.frame = inputFrame
            }

            messageController.scrollToBottom(false)
        }, completion: nil)
    }

    func inputController(_ inputController: TUIInputController, didSendMessage message: V2TIMMessage) {
        // Handle AI conversation message sending
        if let data = conversationData, data.isAIConversation() {
            if inputController.inputBar?.aiIsTyping == true {
                showHudMsgText(TUISwift.timCommonLocalizableString("TUIKitAITyping"))
                return
            }
            inputController.setAITyping(true)
            messageController?.sendMessage(message)
            
        } else {
            messageController?.sendMessage(message)
        }
    }

    func inputController(_ inputController: TUIInputController, didSelectMoreCell cell: TUIInputMoreCell) {
        cell.disableDefaultSelectAction = false
        if cell.disableDefaultSelectAction {
            return
        }

        guard let data = cell.data, let onClicked = data.onClicked else {
            return
        }

        var param: [String: Any] = [:]
        if let userID = conversationData?.userID, !userID.isEmpty {
            param["TUICore_TUIChatExtension_InputViewMoreItem_UserID"] = userID
        } else if let groupID = conversationData?.groupID, !groupID.isEmpty {
            param["TUICore_TUIChatExtension_InputViewMoreItem_GroupID"] = groupID
        }

        if let navigationController = navigationController {
            param["TUICore_TUIChatExtension_InputViewMoreItem_PushVC"] = navigationController
            param["TUICore_TUIChatExtension_InputViewMoreItem_VC"] = self
        }

        onClicked(param)
    }

    func inputControllerDidClickMore(_ inputController: TUIInputController) {
        if let data = conversationData {
            moreMenus = dataProvider.getMoreMenuCellDataArray(
                groupID: data.groupID ?? "",
                userID: data.userID ?? "",
                conversationModel: data,
                actionController: self
            )
        }
    }

    func inputControllerDidInputAt(_ inputController: TUIInputController) {
        // Override by GroupChatVC
    }

    func inputController(_ inputController: TUIInputController, didDeleteAt atText: String) {
        // Override by GroupChatVC
    }

    func inputControllerDidBeginTyping(_ inputController: TUIInputController) {
        // Override by C2CChatVC
    }

    func inputControllerDidEndTyping(_ inputController: TUIInputController) {
        // Override by C2CChatVC
    }

    // MARK: - TUIBaseMessageControllerDelegate

    func didTap(_ controller: TUIBaseMessageController) {
        inputController.reset()
    }

    func willShowMenu(_ controller: TUIBaseMessageController, inCell cell: TUIMessageCell) -> Bool {
        if let isFirstResponder = inputController.inputBar?.inputTextView.isFirstResponder, isFirstResponder == true {
            inputController.inputBar?.inputTextView.overrideNextResponder = cell
            return true
        }
        return false
    }

    func onNewMessage(_ controller: TUIBaseMessageController?, message: V2TIMMessage) -> TUIMessageCellData? {
        return nil
    }

    func onShowMessageData(_ controller: TUIBaseMessageController?, data: TUIMessageCellData) -> TUIMessageCell? {
        return nil
    }

    func willDisplayCell(_ controller: TUIBaseMessageController, cell: TUIMessageCell, withData cellData: TUIMessageCellData) {
        if let joinCell = cell as? TUIJoinGroupMessageCell {
            joinCell.joinGroupDelegate = self
        }
    }

    func onSelectMessageAvatar(_ controller: TUIBaseMessageController, cell: TUIMessageCell) {
        var userID: String?
        guard let messageData = cell.messageData, let msg = messageData.innerMessage else { return }

        if let groupID = msg.groupID, !groupID.isEmpty {
            userID = msg.sender
        } else {
            if messageData.isUseMsgReceiverAvatar {
                if msg.isSelf {
                    userID = msg.userID
                } else {
                    userID = V2TIMManager.sharedInstance().getLoginUser()
                }
            } else {
                userID = msg.sender
            }
        }

        guard let validUserID = userID else {
            return
        }

        // Get extensions first
        var param: [String: Any] = [:]
        if let userID = conversationData?.userID, !userID.isEmpty {
            param["TUICore_TUIChatExtension_ClickAvatar_UserID"] = userID
        } else if let groupID = conversationData?.groupID, !groupID.isEmpty {
            param["TUICore_TUIChatExtension_ClickAvatar_GroupID"] = groupID
        }
        if let navigationController = navigationController {
            param["TUICore_TUIChatExtension_ClickAvatar_PushVC"] = navigationController
        }

        let extensionList = TUICore.getExtensionList("TUICore_TUIChatExtension_ClickAvatar_ClassicExtensionID", param: param)
        if !extensionList.isEmpty {
            var maxWeightInfo: TUIExtensionInfo? = nil
            for info in extensionList {
                if maxWeightInfo == nil || maxWeightInfo!.weight < info.weight {
                    maxWeightInfo = info
                }
            }

            if let maxWeightInfo = maxWeightInfo, let onClicked = maxWeightInfo.onClicked {
                onClicked(param)
            }
        } else {
            getUserOrFriendProfileVCWithUserID(validUserID, succBlock: { [weak self] vc in
                self?.navigationController?.pushViewController(vc, animated: true)
            }, failBlock: { _, _ in })
        }

        inputController.reset()
    }

    func onLongSelectMessageAvatar(_ controller: TUIBaseMessageController, cell: TUIMessageCell) {}

    func onSelectMessageContent(_ controller: TUIBaseMessageController?, cell: TUIMessageCell) {
        cell.disableDefaultSelectAction = false
        if cell.disableDefaultSelectAction {
            return
        }
    }

    func onSelectMessageMenu(_ controller: TUIBaseMessageController, menuType: NSInteger, withData data: TUIMessageCellData?) {
        onSelectMessageMenu(menuType: menuType, withData: data)
    }

    func didHideMenu(_ controller: TUIBaseMessageController) {
        inputController.inputBar?.inputTextView.overrideNextResponder = nil
    }

    func onReEditMessage(_ controller: TUIBaseMessageController, data: TUIMessageCellData?) {
        if let message = data?.innerMessage, message.elemType == V2TIMElemType.ELEM_TYPE_TEXT, let textElem = message.textElem {
            inputController.inputBar?.inputTextView.text = textElem.text
            inputController.inputBar?.inputTextView.becomeFirstResponder()
        }
    }

    func getTopMarginByCustomView() -> CGFloat {
        return topMarginByCustomView()
    }

    // MARK: - TUIChatBaseDataProviderDelegate

    func dataProvider(_ dataProvider: TUIChatBaseDataProvider, mergeForwardTitleWithMyName name: String) -> String {
        return forwardTitleWithMyName(name)
    }

    func dataProvider(_ dataProvider: TUIChatBaseDataProvider, mergeForwardMsgAbstactForMessage message: V2TIMMessage) -> String {
        return ""
    }

    func dataProvider(_ dataProvider: TUIChatBaseDataProvider, sendMessage message: V2TIMMessage) {
        messageController?.sendMessage(message)
    }

    func onSelectPhotoMoreCellData() {
        mediaProvider?.selectPhoto()
    }

    func onTakePictureMoreCellData() {
        mediaProvider?.takePicture()
    }

    func onTakeVideoMoreCellData() {
        mediaProvider?.takeVideo()
    }

    func onMultimediaRecordMoreCellData() {
//        mediaProvider.multimediaRecord()
    }

    func onSelectFileMoreCellData() {
        mediaProvider?.selectFile()
    }

    // MARK: - TUINavigationControllerDelegate

    public func navigationControllerDidClickLeftButton(_ controller: TUINavigationController) {
        if controller.currentShowVC == self {
            messageController?.readReport()
        }
    }

    public func navigationControllerDidSideSlideReturn(_ controller: TUINavigationController, from fromViewController: UIViewController) {
        if fromViewController == self {
            messageController?.readReport()
        }
    }

    // MARK: - Message menu

    func onSelectMessageMenu(menuType: Int, withData data: TUIMessageCellData?) {
        if menuType == 0 {
            openMultiChooseBoard(isOpen: true)
        } else if menuType == 1, let data = data {
            let uiMsgs = [TUIMessageCellData](arrayLiteral: data)
            prepareForwardMessages(uiMsgs)
        }
    }

    func openMultiChooseBoard(isOpen: Bool) {
        view.endEditing(true)

        multiChooseView?.removeFromSuperview()

        if isOpen {
            multiChooseView = TUIMessageMultiChooseView()
            multiChooseView!.frame = UIScreen.main.bounds
            multiChooseView!.delegate = self
            multiChooseView!.titleLabel?.text = conversationData?.title ?? ""

            if #available(iOS 12.0, *) {
                if #available(iOS 13.0, *) {
                    TUITool.applicationKeywindow()?.addSubview(multiChooseView!)
                } else {
                    let view = navigationController?.view ?? self.view
                    view?.addSubview(multiChooseView!)
                }
            } else {
                TUITool.applicationKeywindow()?.addSubview(multiChooseView!)
            }
        } else {
            messageController?.enableMultiSelectedMode(false)
        }
    }

    // MARK: - TUIMessageMultiChooseViewDelegate

    func onCancelClicked(_ multiChooseView: TUIMessageMultiChooseView) {
        openMultiChooseBoard(isOpen: false)
        messageController?.enableMultiSelectedMode(false)
    }

    func onRelayClicked(_ multiChooseView: TUIMessageMultiChooseView) {
        if let uiMsgs = messageController?.multiSelectedResult(TUIMultiResultOption.all) {
            prepareForwardMessages(uiMsgs)
        }
    }

    func onDeleteClicked(_ multiChooseView: TUIMessageMultiChooseView) {
        guard let uiMsgs = messageController?.multiSelectedResult(.all), !uiMsgs.isEmpty else {
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitRelayNoMessageTips"))
            return
        }
        messageController?.deleteMessages(uiMsgs)
        openMultiChooseBoard(isOpen: false)
        messageController?.enableMultiSelectedMode(false)
    }

    public func prepareForwardMessages(_ uiMsgs: [TUIMessageCellData]) {
        guard !uiMsgs.isEmpty else {
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitRelayNoMessageTips"))
            return
        }
        var hasSendFailedMsg = false
        var canForwardMsg = true
        for data in uiMsgs {
            if data.status != .success {
                hasSendFailedMsg = true
            }
            canForwardMsg = canForwardMsg && data.canForward()
            if hasSendFailedMsg && !canForwardMsg {
                break
            }
        }
        if hasSendFailedMsg {
            let vc = UIAlertController(title: TUISwift.timCommonLocalizableString("TUIKitRelayUnsupportForward"), message: nil, preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default, handler: nil))
            present(vc, animated: true, completion: nil)
            return
        }
        if !canForwardMsg {
            let vc = UIAlertController(title: TUISwift.timCommonLocalizableString("TUIKitRelayPluginNotAllowed"), message: nil, preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default, handler: nil))
            present(vc, animated: true, completion: nil)
            return
        }

        let tipsVc = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        tipsVc.tuitheme_addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitRelayOneByOneForward"), style: .default, handler: { [weak self] _ in
            guard let self else { return }
            if uiMsgs.count <= 30 {
                self.selectTarget(false, toForwardMessage: uiMsgs, orForwardText: nil)
                return
            }
            let vc = UIAlertController(title: TUISwift.timCommonLocalizableString("TUIKitRelayOneByOnyOverLimit"), message: nil, preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .default, handler: nil))
            vc.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitRelayCombineForwad"), style: .default, handler: { _ in
                self.selectTarget(true, toForwardMessage: uiMsgs, orForwardText: nil)
            }))
            self.present(vc, animated: true, completion: nil)
        }))
        tipsVc.tuitheme_addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitRelayCombineForwad"), style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.selectTarget(true, toForwardMessage: uiMsgs, orForwardText: nil)
        }))
        tipsVc.tuitheme_addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .default, handler: nil))
        present(tipsVc, animated: true, completion: nil)
    }

    private func selectTarget(_ mergeForward: Bool, toForwardMessage uiMsgs: [TUIMessageCellData]?, orForwardText forwardText: String?) {
        let nav = UINavigationController()
        nav.modalPresentationStyle = .fullScreen

        present("TUICore_TUIConversationObjectFactory_ConversationSelectVC_Classic", param: nil, embbedIn: nav, forResult: { [weak self] param in
            guard let self else { return }
            guard let selectList = param["TUICore_TUIConversationObjectFactory_ConversationSelectVC_ResultList"] as? [NSDictionary], !selectList.isEmpty else { return }
            var targetList = [TUIChatConversationModel]()
            for selectItem in selectList {
                let model = TUIChatConversationModel()
                model.title = selectItem["TUICore_TUIConversationObjectFactory_ConversationSelectVC_ResultList_Title"] as? String ?? ""
                model.userID = selectItem["TUICore_TUIConversationObjectFactory_ConversationSelectVC_ResultList_UserID"] as? String ?? ""
                model.groupID = selectItem["TUICore_TUIConversationObjectFactory_ConversationSelectVC_ResultList_GroupID"] as? String ?? ""
                model.conversationID = selectItem["TUICore_TUIConversationObjectFactory_ConversationSelectVC_ResultList_ConversationID"] as? String ?? ""
                targetList.append(model)
            }
            if let msgs = uiMsgs, msgs.count > 0 {
                self.forwardMessages(msgs, toTargets: targetList, merge: mergeForward)
            } else if let text = forwardText, !text.isEmpty {
                self.forwardText(text, toConversations: targetList)
            }
        })
    }

    private func forwardMessages(_ uiMsgs: [TUIMessageCellData], toTargets targets: [TUIChatConversationModel], merge: Bool) {
        guard !uiMsgs.isEmpty, !targets.isEmpty else { return }
        dataProvider.getForwardMessage(withCellDatas: uiMsgs, toTargets: targets, merge: merge, resultBlock: { [weak self] targetConversation, msgs in
            guard let self else { return }

            let convCellData = targetConversation
            let timeInterval = (convCellData.groupID?.count ?? 0) > 0 ? 0.09 : 0.05

            // Forward to current chat.
            if convCellData.conversationID == self.conversationData?.conversationID {
                let semaphore = DispatchSemaphore(value: 0)
                let queue = DispatchQueue.global(qos: .default)
                queue.async {
                    for imMsg in msgs {
                        DispatchQueue.main.async {
                            self.messageController?.sendMessage(imMsg)
                            semaphore.signal()
                        }
                        semaphore.wait()
                        Thread.sleep(forTimeInterval: timeInterval)
                    }
                }
                return
            }

            // Forward to other chats.

            let appendParams = TUISendMessageAppendParams()
            appendParams.isSendPushInfo = true
            appendParams.isOnlineUserOnly = false
            appendParams.priority = .PRIORITY_NORMAL

            for message in msgs {
                message.needReadReceipt = (self.conversationData?.msgNeedReadReceipt ?? false) && TUIChatConfig.shared.msgNeedReadReceipt
                _ = TUIMessageDataProvider.sendMessage(message, toConversation: convCellData, appendParams: appendParams, Progress: nil, SuccBlock: {
                    // Messages sent to other chats need to broadcast the message sending status, which is convenient to refresh the message status after entering the corresponding chat
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TUIKitNotification_onMessageStatusChanged"), object: message)
                }, FailBlock: { _, _ in
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TUIKitNotification_onMessageStatusChanged"), object: message)
                })
                Thread.sleep(forTimeInterval: timeInterval)
            }
        }, fail: { _, desc in
            assertionFailure(desc ?? "")
        })
    }

    public func forwardTitleWithMyName(_ nameStr: String) -> String {
        return ""
    }

    // MARK: Message reply

    public func onRelyMessage(_ controller: TUIBaseMessageController, data: TUIMessageCellData?) {
        inputController.exitReplyAndReference { [weak self] in
            guard let self, let data = data else { return }

            let desc = self.replyReferenceMessageDesc(data)

            let replyData = TUIReplyPreviewData()
            replyData.msgID = data.msgID
            replyData.msgAbstract = desc
            replyData.sender = data.senderName
            if let elemType = data.innerMessage?.elemType {
                replyData.type = elemType
            }
            replyData.originMessage = data.innerMessage

            var cloudResultDic = [AnyHashable: Any]()
            if let cloudCustomData = data.innerMessage?.cloudCustomData as Data?,
               let originDic = TUITool.jsonData2Dictionary(cloudCustomData)
            {
                cloudResultDic.merge(originDic) { current, _ in current }
            }

            if let messageParentReply = cloudResultDic["messageReply"] as? [String: Any],
               let messageRootID = messageParentReply["messageRootID"] as? String, !messageRootID.isEmpty
            {
                replyData.messageRootID = messageRootID
            } else if let originMessageID = replyData.originMessage?.msgID, !originMessageID.isEmpty {
                replyData.messageRootID = originMessageID
            }

            self.inputController.showReplyPreview(replyData)
        }
    }

    private func replyReferenceMessageDesc(_ data: TUIMessageCellData) -> String {
        var desc = ""
        switch data.innerMessage?.elemType {
        case .ELEM_TYPE_FILE:
            if let fileElem = data.innerMessage?.fileElem {
                desc = fileElem.filename ?? ""
            }
        case .ELEM_TYPE_MERGER:
            if let mergerElem = data.innerMessage?.mergerElem {
                desc = mergerElem.title ?? ""
            }
        case .ELEM_TYPE_CUSTOM:
            if let msg = data.innerMessage {
                desc = TUIMessageDataProvider.getDisplayString(message: msg) ?? ""
            }
        case .ELEM_TYPE_TEXT:
            if let textElem = data.innerMessage?.textElem {
                desc = textElem.text ?? ""
            }
        default:
            break
        }
        return desc
    }

    // MARK: Message quote

    public func onReferenceMessage(_ controller: TUIBaseMessageController, data: TUIMessageCellData?) {
        inputController.exitReplyAndReference { [weak self] in
            guard let self, let data = data else { return }
            let desc = self.replyReferenceMessageDesc(data)
            let referenceData = TUIReferencePreviewData()
            referenceData.msgID = data.msgID
            referenceData.msgAbstract = desc
            referenceData.sender = data.senderName
            if let elemType = data.innerMessage?.elemType {
                referenceData.type = elemType
            }
            referenceData.originMessage = data.innerMessage
            self.inputController.showReferencePreview(referenceData)
        }
    }

    // MARK: Forward translation

    public func onForwardText(_ controller: TUIBaseMessageController, text: String) {
        guard !text.isEmpty else { return }
        selectTarget(false, toForwardMessage: nil, orForwardText: text)
    }

    public func forwardText(_ text: String, toConversations conversations: [TUIChatConversationModel]) {
        let appendParams = TUISendMessageAppendParams()
        appendParams.isSendPushInfo = true
        appendParams.isOnlineUserOnly = false
        appendParams.priority = .PRIORITY_NORMAL
        for conversation in conversations {
            if let message = V2TIMManager.sharedInstance().createTextMessage(text: text) {
                DispatchQueue.main.async {
                    if conversation.conversationID == self.conversationData?.conversationID {
                        self.messageController?.sendMessage(message)
                    } else {
                        message.needReadReceipt = self.conversationData?.msgNeedReadReceipt ?? false && TUIChatConfig.shared.msgNeedReadReceipt
                        _ = TUIMessageDataProvider.sendMessage(message, toConversation: conversation, appendParams: appendParams, Progress: nil, SuccBlock: {
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TUIKitNotification_onMessageStatusChanged"), object: message)
                        }, FailBlock: { _, _ in
                            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TUIKitNotification_onMessageStatusChanged"), object: message)
                        })
                    }
                }
            }
        }
    }

    // MARK: - TUIJoinGroupMessageCellDelegate

    func didTapOnRestNameLabel(_ cell: TUIJoinGroupMessageCell, withIndex index: Int) {
        if let userId = cell.joinData?.userIDList?[index] as? String {
            getUserOrFriendProfileVCWithUserID(userId, succBlock: { [weak self] vc in
                guard let self = self else { return }
                self.navigationController?.pushViewController(vc, animated: true)
            }, failBlock: { code, desc in
                TUITool.makeToastError(Int(code), msg: desc ?? "")
            })
        }
    }

    // MARK: - V2TIMConversationListener

    public func onConversationChanged(conversationList: [V2TIMConversation]) {
        guard let conversationData = conversationData else { return }
        for conv in conversationList {
            if conv.conversationID == conversationData.conversationID {
                if !conversationData.otherSideTyping {
                    conversationData.title = conv.showName
                }
                break
            }
        }
    }

    // MARK: - FriendInfoChangedNotification

    @objc func onFriendInfoChanged(_ notice: Notification) {
        checkTitle(force: true)
    }

    // MARK: TUIChatMediaDataListener

    public func onProvideImage(_ imageUrl: String) {
        let message = V2TIMManager.sharedInstance().createImageMessage(imagePath: imageUrl)!
        sendMessage(message)
    }

    public func onProvideImageError(_ errorMessage: String) {
        TUITool.makeToast(errorMessage)
    }

    public func onProvidePlaceholderVideoSnapshot(_ snapshotUrl: String, snapImage: UIImage, completion: ((Bool, TUIMessageCellData) -> Void)?) {
        let videoCellData = TUIVideoMessageCellData.placeholderCellData(snapshotUrl: snapshotUrl, thumbImage: snapImage)
        messageController?.sendPlaceHolderUIMessage(videoCellData)
        completion?(true, videoCellData)
    }

    public func onProvideVideo(_ videoUrl: String, snapshot: String, duration: Int, placeHolderCellData: TUIMessageCellData?) {
        if let url = URL(string: videoUrl) {
            if let message = V2TIMManager.sharedInstance().createVideoMessage(videoFilePath: videoUrl, type: url.pathExtension, duration: Int32(duration), snapshotPath: snapshot) {
                sendMessage(message, placeHolderCellData: placeHolderCellData)
            }
        }
    }

    public func onProvideVideoError(_ errorMessage: String) {
        TUITool.makeToast(errorMessage)
    }

    public func onProvideFile(_ fileUrl: String, filename: String, fileSize: Int) {
        let message = V2TIMManager.sharedInstance().createFileMessage(filePath: fileUrl, fileName: filename)!
        sendMessage(message)
    }

    public func onProvideFileError(_ errorMessage: String) {
        TUITool.makeToast(errorMessage)
    }
    
    // MARK: - AI Conversation Methods
    
    
    /// Handle AI interrupt action
    func inputControllerDidTouchAIInterrupt(_ inputController: TUIInputController) {
        // Send interrupt message
        sendChatbotInterruptMessage()
    }
        
    func setAIStartTyping() {
        if let data = conversationData, data.isAIConversation() {
            inputController?.setAITyping(true)
        }
    }
    
    func setAIFinishTyping() {
        if let data = conversationData, data.isAIConversation() {
            inputController?.setAITyping(false)
        }
    }
    
    func generateMessageKey(_ messageData: TUIMessageCellData) -> String {
        guard let message = messageData.innerMessage else {
            return ""
        }
        
        let msgSeq = message.seq
        let random = message.random
        let timestamp = message.timestamp?.timeIntervalSince1970 ?? 0
        
        return String(format: "%llu_%llu_%.0f", msgSeq, random, timestamp)
    }
    
    func buildChatbotInterruptMessage(_ messageData: TUIMessageCellData) -> V2TIMMessage? {
        guard messageData.innerMessage != nil else {
            return nil
        }
        
        // Build interrupt message content
        let interruptMessageContent: [String: Any] = [
            "chatbotPlugin": 2,
            "src": 22,
            "msgKey": generateMessageKey(messageData)
        ]
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: interruptMessageContent, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to create interrupt message JSON")
            return nil
        }
        
        // Create custom message
        let message = V2TIMManager.sharedInstance().createCustomMessage(data: jsonData)
        message?.isExcludedFromLastMessage = true
        message?.isExcludedFromUnreadCount = true
        return message
    }
    
    func sendChatbotInterruptMessage() {
        // Check send interval (1 second minimum)
        let currentTime = Date().timeIntervalSince1970
        let sendInterruptMessageInterval: TimeInterval = 1.0
        
        if lastSendInterruptMessageTime != 0 &&
           currentTime - lastSendInterruptMessageTime < sendInterruptMessageInterval {
            return
        }
        
        lastSendInterruptMessageTime = currentTime
        
        guard let messageData = receivingChatbotMessage else {
            print("No receiving chatbot message found")
            self.setAIFinishTyping();
            return
        }
        
        guard let message = buildChatbotInterruptMessage(messageData) else {
            print("Failed to build interrupt message")
            self.setAIFinishTyping();
            return
        }
        
        // Determine conversation type
        var groupID: String?
        var userID: String?
        
        if let groupId = conversationData?.groupID, !groupId.isEmpty {
            groupID = groupId
        } else {
            userID = conversationData?.userID
        }
        
        // Send interrupt message
        V2TIMManager.sharedInstance().sendMessage(message: message, receiver: userID, groupID: groupID, priority: .PRIORITY_DEFAULT, onlineUserOnly: true, offlinePushInfo: nil, progress: nil) {
            print("sendChatbotInterruptMessage success")

        }   fail: {  [weak self] code, desc in
            guard let self = self else { return }
            print("sendChatbotInterruptMessage failed \(code) \(desc ?? "")")
            self.setAIFinishTyping();
        };

    
    }
    
    // MARK: - HUD Methods
    
    /// HUD container properties
    private var hudContainerView: UIView?
    private var hudBackgroundView: UIView?
    private var hudLabel: UILabel?
    
    /// Show HUD message with text
    /// - Parameter msgText: The message text to display
    func showHudMsgText(_ msgText: String?) {
        hideHud()
        
        guard let msgText = msgText, !msgText.isEmpty else {
            return
        }
        
        // Create container view
        hudContainerView = UIView()
        hudContainerView?.backgroundColor = UIColor.clear
        hudContainerView?.alpha = 0.0
        view.addSubview(hudContainerView!)
        
        // Create background view with design specs
        hudBackgroundView = UIView()
        hudBackgroundView?.backgroundColor = UIColor(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0) // #EBF3FF
        hudBackgroundView?.layer.cornerRadius = 6.0
        hudBackgroundView?.layer.masksToBounds = false
        
        // Add shadow effects as per design
        hudBackgroundView?.layer.shadowColor = UIColor.black.cgColor
        hudBackgroundView?.layer.shadowOffset = CGSize(width: 0, height: 8)
        hudBackgroundView?.layer.shadowRadius = 13
        hudBackgroundView?.layer.shadowOpacity = 0.06
        
        // Additional shadow layers for multiple shadow effect
        let shadowLayer1 = CALayer()
        shadowLayer1.shadowColor = UIColor.black.cgColor
        shadowLayer1.shadowOffset = CGSize(width: 0, height: 12)
        shadowLayer1.shadowRadius = 13
        shadowLayer1.shadowOpacity = 0.06
        hudBackgroundView?.layer.insertSublayer(shadowLayer1, at: 0)
        
        let shadowLayer2 = CALayer()
        shadowLayer2.shadowColor = UIColor.black.cgColor
        shadowLayer2.shadowOffset = CGSize(width: 0, height: 1)
        shadowLayer2.shadowRadius = 2.5
        shadowLayer2.shadowOpacity = 0.06
        hudBackgroundView?.layer.insertSublayer(shadowLayer2, at: 0)
        
        hudContainerView?.addSubview(hudBackgroundView!)
        
        // Create label with design specs
        hudLabel = UILabel()
        hudLabel?.text = msgText
        hudLabel?.textColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.9) // rgba(0, 0, 0, 0.9)
        hudLabel?.font = UIFont(name: "PingFangSC-Medium", size: 14.0) ?? UIFont.systemFont(ofSize: 14.0, weight: .medium)
        hudLabel?.textAlignment = .center
        hudLabel?.numberOfLines = 0
        hudLabel?.lineBreakMode = .byWordWrapping
        hudBackgroundView?.addSubview(hudLabel!)
        
        // Layout constraints
        hudContainerView?.translatesAutoresizingMaskIntoConstraints = false
        hudBackgroundView?.translatesAutoresizingMaskIntoConstraints = false
        hudLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        // Container view constraints (center in parent view)
        NSLayoutConstraint.activate([
            hudContainerView!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hudContainerView!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hudContainerView!.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            hudContainerView!.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
        
        // Background view constraints (hug content)
        NSLayoutConstraint.activate([
            hudBackgroundView!.topAnchor.constraint(equalTo: hudContainerView!.topAnchor),
            hudBackgroundView!.leadingAnchor.constraint(equalTo: hudContainerView!.leadingAnchor),
            hudBackgroundView!.trailingAnchor.constraint(equalTo: hudContainerView!.trailingAnchor),
            hudBackgroundView!.bottomAnchor.constraint(equalTo: hudContainerView!.bottomAnchor)
        ])
        
        // Label constraints (8px 20px padding as per design)
        NSLayoutConstraint.activate([
            hudLabel!.topAnchor.constraint(equalTo: hudBackgroundView!.topAnchor, constant: 8),
            hudLabel!.leadingAnchor.constraint(equalTo: hudBackgroundView!.leadingAnchor, constant: 20),
            hudLabel!.trailingAnchor.constraint(equalTo: hudBackgroundView!.trailingAnchor, constant: -20),
            hudLabel!.bottomAnchor.constraint(equalTo: hudBackgroundView!.bottomAnchor, constant: -8)
        ])
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            self.hudContainerView?.alpha = 1.0
        }
        
        // Auto hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideHud()
        }
    }
    
    /// Hide the HUD
    func hideHud() {
        guard let hudContainerView = hudContainerView else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            hudContainerView.alpha = 0.0
        }) { _ in
            hudContainerView.removeFromSuperview()
            self.hudContainerView = nil
            self.hudBackgroundView = nil
            self.hudLabel = nil
        }
    }
}
