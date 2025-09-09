//
//  ConversationViewController.m
//  TUIKitDemo
//
//  Created by kennethmiao on 2018/10/10.
//  Copyright © 2018 Tencent. All rights reserved.
//

import TIMCommon
import TUIChat
import TUIConversation
import TUICore
import UIKit

enum UIBarButtonItemType: Int {
    case edit
    case more
    case done
}

public class ConversationController_Minimalist: UIViewController, TUIConversationListControllerListener, V2TIMSDKListener, TUIPopViewDelegate {
    private let titleView = TUINaviBarIndicatorView()
    private var titleViewTitle: String?
    
    private var moreItem: UIBarButtonItem?
    private var editItem: UIBarButtonItem?
    private var doneItem: UIBarButtonItem?
    
    var conv: Observable<TUIConversationListController_Minimalist?> = Observable(TUIConversationListController_Minimalist())
    var showLeftBarButtonItems: Observable<[UIBarButtonItem]> = Observable([])
    var showRightBarButtonItems: Observable<[UIBarButtonItem]> = Observable([])
    var rightBarButtonItems = [UIBarButtonItem]()
    private var leftSpaceWidth: CGFloat = TUISwift.kScale390(13)
    public var getUnReadCount: (() -> UInt)?
    public var clearUnreadMessage: (() -> Void)?
    var viewWillAppearClosure: ((Bool) -> Void)?
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
    }
    
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        
        conv.value?.delegate = self
        if let conv = conv.value {
            addChild(conv)
            view.addSubview(conv.view)
        }
    }
    
    private func navBackColor() -> UIColor {
        return .white
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.shadowColor = nil
            appearance.backgroundEffect = nil
            appearance.backgroundColor = navBackColor()
            if let navigationBar = navigationController?.navigationBar {
                navigationBar.backgroundColor = navBackColor()
                navigationBar.barTintColor = navBackColor()
                navigationBar.shadowImage = UIImage()
                navigationBar.standardAppearance = appearance
                navigationBar.scrollEdgeAppearance = appearance
            }
        } else {
            if let navigationBar = navigationController?.navigationBar {
                navigationBar.backgroundColor = navBackColor()
                navigationBar.barTintColor = navBackColor()
                navigationBar.shadowImage = UIImage()
            }
        }
        viewWillAppearClosure?(true)
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewWillAppearClosure?(false)
    }
    
    private func setupNavigation() {
        titleView.label.font = UIFont.boldSystemFont(ofSize: 34)
        titleView.maxLabelLength = TUISwift.screen_Width()
        titleView.setTitle(titleViewTitle?.isEmpty == false ? titleViewTitle! : TUISwift.timCommonLocalizableString("TIMAppChat"))
        titleView.label.textColor = TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000")
        
        let leftTitleItem = UIBarButtonItem(customView: titleView)
        let leftSpaceItem = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        leftSpaceItem.width = leftSpaceWidth
        showLeftBarButtonItems.value = [leftSpaceItem, leftTitleItem]
        
        navigationItem.title = ""
        navigationItem.leftBarButtonItems = showLeftBarButtonItems.value
        
        let editButton = UIButton(type: .custom)
        editButton.setTitle(TUISwift.timCommonLocalizableString("Edit"), for: .normal)
        editButton.setTitleColor(.systemBlue, for: .normal)
        editButton.addTarget(self, action: #selector(editBarButtonClick(_:)), for: .touchUpInside)
        editButton.imageView?.contentMode = .scaleAspectFit
        editButton.frame = CGRect(x: 0, y: 0, width: 40, height: 26)
        
        let moreButton = UIButton(type: .custom)
        moreButton.setImage(UIImage.safeImage(TUISwift.tuiConversationImagePath_Minimalist("nav_add")), for: .normal)
        moreButton.addTarget(self, action: #selector(rightBarButtonClick(_:)), for: .touchUpInside)
        moreButton.imageView?.contentMode = .scaleAspectFit
        moreButton.frame = CGRect(x: 0, y: 0, width: 26, height: 26)
        
        let doneButton = UIButton(type: .custom)
        doneButton.setTitle(TUISwift.timCommonLocalizableString("TUIKitDone"), for: .normal)
        doneButton.setTitleColor(.systemBlue, for: .normal)
        doneButton.addTarget(self, action: #selector(doneBarButtonClick(_:)), for: .touchUpInside)
        doneButton.frame = CGRect(x: 0, y: 0, width: 40, height: 26)
        
        editItem = UIBarButtonItem(customView: editButton)
        editItem?.tag = UIBarButtonItemType.edit.rawValue
        moreItem = UIBarButtonItem(customView: moreButton)
        moreItem?.tag = UIBarButtonItemType.more.rawValue
        doneItem = UIBarButtonItem(customView: doneButton)
        doneItem?.tag = UIBarButtonItemType.done.rawValue
        rightBarButtonItems = [editItem!, moreItem!, doneItem!]
        
        showRightBarButtonItems.value = [moreItem!, editItem!]
        navigationItem.rightBarButtonItems = showRightBarButtonItems.value
    }
    
    @objc private func rightBarButtonClick(_ rightBarButton: UIButton) {
        var menus = [TUIPopCellData]()
        let friend = TUIPopCellData()
        friend.image = TUISwift.tuiConversationDynamicImage("pop_icon_new_chat_img", defaultImage: UIImage.safeImage(TUISwift.tuiConversationImagePath("new_chat")))
        friend.title = TUISwift.timCommonLocalizableString("ChatsNewChatText")
        menus.append(friend)
        
        let group = TUIPopCellData()
        group.image = TUISwift.tuiConversationDynamicImage("pop_icon_new_group_img", defaultImage: UIImage.safeImage(TUISwift.tuiConversationImagePath("new_groupchat")))
        group.title = TUISwift.timCommonLocalizableString("ChatsNewGroupText")
        menus.append(group)
        
        let height = TUIPopCell.getHeight() * CGFloat(menus.count) + TUISwift.tuiPopView_Arrow_Size().height
        let orginY = TUISwift.statusBar_Height() + TUISwift.navBar_Height()
        var orginX = TUISwift.screen_Width() - 155
        if TUISwift.isRTL() {
            orginX = 10
        }
        let popView = TUIPopView(frame: CGRect(x: orginX, y: orginY, width: 145, height: height))
        if let frameInNaviView = navigationController?.view.convert(rightBarButton.frame, from: rightBarButton.superview) {
            popView.arrowPoint = CGPoint(x: frameInNaviView.origin.x + frameInNaviView.size.width * 0.5, y: orginY)
        }
        popView.delegate = self
        popView.setData(menus)
        if let window = view.window {
            popView.showInWindow(window)
        }
    }
    
    @objc private func doneBarButtonClick(_ doneBarButton: UIBarButtonItem) {
        conv.value?.openMultiChooseBoard(false)
        showRightBarButtonItems.value = [moreItem!, editItem!]
        navigationItem.rightBarButtonItems = showRightBarButtonItems.value
    }
    
    @objc private func editBarButtonClick(_ editBarButton: UIButton) {
        conv.value?.openMultiChooseBoard(true)
        conv.value?.enableMultiSelectedMode(true)
        showRightBarButtonItems.value = [doneItem!]
        navigationItem.rightBarButtonItems = showRightBarButtonItems.value
        
        if let getUnReadCount = getUnReadCount, getUnReadCount() <= 0 {
            conv.value?.multiChooseView.readButton.isEnabled = false
        }
    }
    
    // MARK: - TUIPopViewDelegate

    public func popView(_ popView: TUIPopView, didSelectRowAt index: Int) {
        if index == 0 {
            conv.value?.startConversation(.C2C)
        } else {
            conv.value?.startConversation(.GROUP)
        }
    }
    
    @objc(pushToChatViewController:userID:) func pushToChatViewController(groupID: String?, userID: String?) {
        guard let topVc = navigationController?.topViewController else { return }
        var isSameTarget = false
        var isInChat = false
        if let topVc = topVc as? TUIBaseChatViewController_Minimalist {
            let cellData = topVc.conversationData
            isSameTarget = (cellData?.groupID == groupID) || (cellData?.userID == userID)
            isInChat = true
        }
        if isInChat && isSameTarget {
            return
        }
        
        if isInChat && !isSameTarget {
            navigationController?.popViewController(animated: false)
        }
        
        let conversationData = TUIChatConversationModel()
        conversationData.userID = userID ?? ""
        conversationData.groupID = groupID ?? ""
        if let chatVC = getChatViewController(model: conversationData) {
            navigationController?.pushViewController(chatVC, animated: true)
        }
    }
    
    private func getChatViewController(model: TUIChatConversationModel) -> TUIBaseChatViewController_Minimalist? {
        var chat: TUIBaseChatViewController_Minimalist?
        let userID = model.userID
        let groupID = model.groupID
        if let userID = userID, !userID.isEmpty {
            chat = TUIC2CChatViewController_Minimalist()
        } else if let groupID = groupID, !groupID.isEmpty {
            chat = TUIGroupChatViewController_Minimalist()
        }
        chat?.conversationData = model
        return chat
    }
    
    // MARK: - TUIConversationListControllerListener

    public func onClearAllConversationUnreadCount() {
        clearUnreadMessage?()
    }
    
    public func onCloseConversationMultiChooseBoard() {
        showRightBarButtonItems.value = [moreItem!, editItem!]
        navigationItem.rightBarButtonItems = showRightBarButtonItems.value
    }
    
    // MARK: - V2TIMSDKListener

    public func onConnecting() {
        titleViewTitle = TUISwift.timCommonLocalizableString("TIMAppMainConnectingTitle")
        titleView.setTitle(titleViewTitle ?? "")
        titleView.startAnimating()
    }
    
    public func onConnectSuccess() {
        titleViewTitle = TUISwift.timCommonLocalizableString("TIMAppChat")
        titleView.setTitle(titleViewTitle ?? "")
        titleView.stopAnimating()
    }
    
    public func onConnectFailed(_ code: Int32, err: String?) {
        titleViewTitle = TUISwift.timCommonLocalizableString("TIMAppChatDisconnectTitle")
        titleView.setTitle(titleViewTitle ?? "")
        titleView.stopAnimating()
    }
}
