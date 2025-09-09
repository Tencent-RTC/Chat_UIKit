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

public class ConversationController: UIViewController, V2TIMSDKListener, TUIPopViewDelegate {
    private var titleView: TUINaviBarIndicatorView?
    private var titleViewTitle: String?
    private var conv: TUIConversationListController?
    var viewWillAppear: ((Bool) -> Void)?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
       V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewWillAppear?(true)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewWillAppear?(false)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()

        conv = TUIConversationListController()
        if let conv = conv {
            addChild(conv)
            view.addSubview(conv.view)
        }
    }

    private func setupNavigation() {
        let moreButton = UIButton(type: .custom)
        moreButton.setImage(TUISwift.tuiCoreDynamicImage("nav_more_img", defaultImage: UIImage.safeImage(TUISwift.tuiCoreImagePath("more"))), for: .normal)
        moreButton.addTarget(self, action: #selector(rightBarButtonClick(_:)), for: .touchUpInside)
        moreButton.imageView?.contentMode = .scaleAspectFit
        moreButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        moreButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let moreItem = UIBarButtonItem(customView: moreButton)
        navigationItem.rightBarButtonItem = moreItem

        titleView = TUINaviBarIndicatorView()
        titleView?.setTitle(titleViewTitle?.isEmpty == false ? titleViewTitle! : TUISwift.timCommonLocalizableString("TIMAppMainTitle"))
        navigationItem.titleView = titleView
        navigationItem.title = ""
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

    // MARK: - TUIPopViewDelegate

    public func popView(_ popView: TUIPopView, didSelectRowAt index: Int) {
        if index == 0 {
            conv?.startConversation(.C2C)
        } else {
            conv?.startConversation(.GROUP)
        }
    }

    @objc(pushToChatViewController:userID:) func pushToChatViewController(groupID: String?, userID: String?) {
        guard let topVc = navigationController?.topViewController else { return }
        var isSameTarget = false
        var isInChat = false
        if let topVc = topVc as? TUIBaseChatViewController {
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
        if let chatVC = getChatViewController(conversationData) {
            navigationController?.pushViewController(chatVC, animated: true)
        }
    }

    private func getChatViewController(_ model: TUIChatConversationModel) -> TUIBaseChatViewController? {
        var chat: TUIBaseChatViewController?
        if let userID = model.userID, !userID.isEmpty {
            chat = TUIC2CChatViewController()
        } else if let groupID = model.groupID, !groupID.isEmpty {
            chat = TUIGroupChatViewController()
        }
        chat?.conversationData = model
        return chat
    }

    // MARK: - V2TIMSDKListener

    public func onConnecting() {
        titleViewTitle = TUISwift.timCommonLocalizableString("TIMAppMainConnectingTitle")
        titleView?.setTitle(titleViewTitle ?? "")
        titleView?.startAnimating()
    }

    public func onConnectSuccess() {
        titleViewTitle = TUISwift.timCommonLocalizableString("TIMAppMainTitle")
        titleView?.setTitle(titleViewTitle ?? "")
        titleView?.stopAnimating()
    }

    public func onConnectFailed(_ code: Int32, err: String?) {
        titleViewTitle = TUISwift.timCommonLocalizableString("TIMAppMainDisconnectTitle")
        titleView?.setTitle(titleViewTitle ?? "")
        titleView?.stopAnimating()
    }
}
