import TIMCommon
import TUICore
import UIKit

let GroupBtnSpace: CGFloat = 24
let GroupScrollViewHeight: CGFloat = 30

public class TUIConversationListController: UIViewController, UIGestureRecognizerDelegate, TUINotificationProtocol, TUIPopViewDelegate, TUIConversationTableViewDelegate, TUIConversationListDataProviderDelegate {
    public weak var delegate: TUIConversationListControllerListener?
    var isShowBanner: Bool = true
    var isShowConversationGroup: Bool = true
    var viewHeight: CGFloat = 0.0
    var tipsMsgWhenNoConversation: String?
    var disableMoreActionExtension = false
    private var settingDataProvider: TUIConversationListBaseDataProvider?
    private var groupItemList: [TUIConversationGroupItem] = []
    @objc dynamic var actualShowConversationGroup: Bool = false

    private var contentSizeObservation: NSKeyValueObservation?
    private var actualShowConversationGroupObservation: NSKeyValueObservation?

    var dataProvider: TUIConversationListBaseDataProvider? {
        set {
            settingDataProvider = newValue
        }
        get {
            return settingDataProvider
        }
    }

    lazy var tableViewContainer: UIView = {
        let tableViewContainer = UIView()
        tableViewContainer.autoresizesSubviews = true
        return tableViewContainer
    }()

    lazy var tableViewForAll: TUIConversationTableView = {
        let tableViewForAll = TUIConversationTableView()
        tableViewForAll.backgroundColor = self.view.backgroundColor
        tableViewForAll.convDelegate = self
        if let settingDataProvider = self.settingDataProvider {
            tableViewForAll.dataProvider = settingDataProvider
        } else {
            let dataProvider = TUIConversationListDataProvider()
            tableViewForAll.dataProvider = dataProvider
        }
        if let tipsMsgWhenNoConversation = tipsMsgWhenNoConversation {
            tableViewForAll.tipsMsgWhenNoConversation = tipsMsgWhenNoConversation
        } else {
            tableViewForAll.tipsMsgWhenNoConversation = String(format: TUISwift.timCommonLocalizableString("TUIConversationNone"), "")
        }
        tableViewForAll.disableMoreActionExtension = disableMoreActionExtension
        return tableViewForAll
    }()

    lazy var allGroupItem: TUIConversationGroupItem = {
        let allGroupItem = TUIConversationGroupItem()
        allGroupItem.groupName = TUISwift.timCommonLocalizableString("TUIConversationGroupAll")
        return allGroupItem
    }()

    lazy var bannerView: UIView = {
        let bannerView = UIView(frame: CGRect(x: 0, y: TUISwift.statusBar_Height() + TUISwift.navBar_Height(), width: 0, height: 0))
        view.addSubview(bannerView)
        return bannerView
    }()

    lazy var groupBtnContainer: UIView = .init()

    lazy var groupScrollView: UIScrollView = .init()

    lazy var groupAnimationView: UIView = .init()

    lazy var groupView: UIView = {
        let groupView = UIView(frame: CGRect(x: 0, y: bannerView.frame.maxY, width: view.frame.width, height: 60))
        view.addSubview(groupView)

        let groupExtensionBtnLeft = groupView.frame.width - GroupScrollViewHeight - TUISwift.kScale375(16)
        groupBtnContainer.frame = CGRect(x: groupExtensionBtnLeft, y: 18, width: GroupScrollViewHeight, height: GroupScrollViewHeight)
        groupView.addSubview(groupBtnContainer)

        TUICore.raiseExtension("TUICore_TUIConversationExtension_ConversationGroupManagerContainer_ClassicExtensionID",
                               parentView: groupBtnContainer,
                               param: ["TUICore_TUIConversationExtension_ConversationGroupManagerContainer_ParentVCKey": self])

        let groupScrollViewWidth = groupBtnContainer.frame.minX - TUISwift.kScale375(16) - TUISwift.kScale375(10)
        let groupScrollBackgrounView = UIView()
        groupView.addSubview(groupScrollBackgrounView)
        groupScrollBackgrounView.frame = CGRect(x: TUISwift.kScale375(16), y: 18, width: groupScrollViewWidth, height: GroupScrollViewHeight)

        groupScrollView.frame = CGRect(x: 0, y: 0, width: groupScrollViewWidth, height: GroupScrollViewHeight)
        groupScrollView.backgroundColor = TUISwift.tuiConversationDynamicColor("conversation_group_bg_color", defaultColor: "#EBECF0")
        groupScrollView.showsHorizontalScrollIndicator = false
        groupScrollView.showsVerticalScrollIndicator = false
        groupScrollView.bounces = false
        groupScrollView.isScrollEnabled = true
        groupScrollView.layer.cornerRadius = GroupScrollViewHeight / 2.0
        groupScrollView.layer.masksToBounds = true
        groupScrollBackgrounView.addSubview(groupScrollView)

        contentSizeObservation = groupScrollView.observe(\.contentSize, options: [.new, .initial]) { [weak self] scrollView, _ in
            guard let self = self else { return }
            let newContentSize = scrollView.contentSize
            let groupScrollViewWidth = self.groupBtnContainer.frame.minX - TUISwift.kScale375(16) - TUISwift.kScale375(10)
            self.groupScrollView.snp.remakeConstraints { make in
                make.leading.equalTo(groupScrollBackgrounView.snp.leading)
                make.height.equalTo(GroupScrollViewHeight)
                make.width.equalTo(min(groupScrollViewWidth, newContentSize.width))
                make.centerY.equalTo(groupScrollBackgrounView)
            }
        }

        groupAnimationView.backgroundColor = TUISwift.tuiConversationDynamicColor("conversation_group_animate_view_color", defaultColor: "#FFFFFF")
        groupAnimationView.layer.cornerRadius = GroupScrollViewHeight / 2.0
        groupAnimationView.layer.masksToBounds = true
        groupAnimationView.layer.borderWidth = 1
        groupAnimationView.layer.borderColor = TUISwift.tuiConversationDynamicColor("conversation_group_bg_color", defaultColor: "#EBECF0").cgColor
        groupScrollView.addSubview(groupAnimationView)

        if TUISwift.isRTL() {
            groupScrollBackgrounView.resetFrameToFitRTL()
            groupBtnContainer.resetFrameToFitRTL()
            groupScrollView.transform = CGAffineTransform(rotationAngle: .pi)
            for subView in groupScrollView.subviews {
                subView.transform = CGAffineTransform(rotationAngle: .pi)
            }
        }

        return groupView
    }()

    func currentTableView() -> TUIConversationTableView? {
        for view in tableViewContainer.subviews {
            if view.isKind(of: TUIConversationTableView.self) {
                return view as? TUIConversationTableView
            }
        }
        return nil
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.isShowBanner = true
        self.isShowConversationGroup = true
        NotificationCenter.default.addObserver(self, selector: #selector(onThemeChanged), name: NSNotification.Name("TUIDidApplyingThemeChangedNotfication"), object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.isShowBanner = true
        self.isShowConversationGroup = true
        NotificationCenter.default.addObserver(self, selector: #selector(onThemeChanged), name: NSNotification.Name("TUIDidApplyingThemeChangedNotfication"), object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        TUICore.unRegisterEvent(byObject: self)
        contentSizeObservation = nil
        actualShowConversationGroupObservation = nil
    }

    @objc func onThemeChanged() {
        groupAnimationView.layer.borderColor = TUISwift.tuiConversationDynamicColor("conversation_group_bg_color", defaultColor: "#EBECF0").cgColor
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupViews()
        TUICore.registerEvent("TUICore_TUIConversationGroupNotify", subKey: "", object: self)
        TUICore.registerEvent("TUICore_TUIConversationMarkNotify", subKey: "", object: self)
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        currentTableView()?.reloadData()
    }

    func setupNavigation() {
        let moreButton = UIButton(type: .custom)
        let image = TUISwift.timCommonDynamicImage("nav_more_img", defaultImage: UIImage.safeImage(TUISwift.timCommonImagePath("more")))
        moreButton.setImage(image, for: .normal)
        moreButton.addTarget(self, action: #selector(rightBarButtonClick(_:)), for: .touchUpInside)
        moreButton.imageView!.contentMode = .scaleAspectFit
        moreButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        moreButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let moreItem = UIBarButtonItem(customView: moreButton)
        navigationController?.navigationItem.rightBarButtonItem = moreItem

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    @objc func rightBarButtonClick(_ rightBarButton: UIButton) {
        var menus = [TUIPopCellData]()
        let friend = TUIPopCellData()
        friend.image = TUISwift.timCommonDynamicImage("pop_icon_new_chat_img", defaultImage: UIImage.safeImage(TUISwift.timCommonImagePath("new_chat")))
        friend.title = TUISwift.timCommonLocalizableString("ChatsNewChatText")
        menus.append(friend)

        let group = TUIPopCellData()
        group.image = TUISwift.tuiConversationDynamicImage("pop_icon_new_group_img", defaultImage: UIImage.safeImage("new_groupchat"))
        group.title = TUISwift.timCommonLocalizableString("ChatsNewGroupText")
        menus.append(group)

        let height = Int(TUIPopCell.getHeight()) * menus.count + Int(TUISwift.tuiPopView_Arrow_Size().height)
        let orginY = TUISwift.statusBar_Height() + TUISwift.navBar_Height()
        var orginX = TUISwift.screen_Width() - 155
        if TUISwift.isRTL() {
            orginX = 10
        }
        let popView = TUIPopView(frame: CGRect(x: orginX, y: orginY, width: 145, height: CGFloat(height)))
        let frameInNaviView = navigationController?.view.convert(rightBarButton.frame, from: rightBarButton.superview)
        popView.arrowPoint = CGPoint(x: frameInNaviView!.origin.x + frameInNaviView!.size.width * 0.5, y: orginY)
        popView.delegate = self
        popView.setData(menus)
        popView.showInWindow(view.window!)
    }

    func setupViews() {
        view.backgroundColor = TUIConversationConfig.shared.listBackgroundColor ??
            TUISwift.tuiConversationDynamicColor("conversation_bg_color", defaultColor: "#FFFFFF")
        viewHeight = view.frame.height

        if isShowBanner {
            let size = CGSize(width: view.bounds.size.width, height: 60)
            bannerView.frame.size = size
            var param: [String: Any] = [:]
            param["TUICore_TUIConversationExtension_ConversationListBanner_BannerSize"] = NSCoder.string(for: size)
            param["TUICore_TUIConversationExtension_ConversationListBanner_ModalVC"] = self

            let result = TUICore.raiseExtension("TUICore_TUIConversationExtension_ConversationListBanner_ClassicExtensionID", parentView: bannerView, param: param)
            if !result {
                bannerView.frame.size.height = 0
            }
        }

        view.addSubview(tableViewContainer)
        tableViewContainer.addSubview(tableViewForAll)

        if isShowConversationGroup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let extensionList = TUICore.getExtensionList("TUICore_TUIConversationExtension_ConversationGroupListBanner_ClassicExtensionID", param: nil)
                self.actualShowConversationGroupObservation = self.observe(\.actualShowConversationGroup, options: [.new]) { [weak self] _, change in
                    guard let self = self else { return }
                    if let showConversationGroup = change.newValue, showConversationGroup {
                        self.tableViewContainer.frame = CGRect(x: 0, y: self.groupView.frame.maxY, width: self.view.frame.width, height: self.viewHeight - self.groupView.frame.maxY)

                        self.groupItemList = []
                        self.addGroup(self.allGroupItem)

                        for info in extensionList {
                            if let groupItem = info.data?["TUICore_TUIConversationExtension_ConversationGroupListBanner_GroupItemKey"] as? TUIConversationGroupItem {
                                self.addGroup(groupItem)
                            }
                        }
                        self.onSelectGroup(self.allGroupItem)
                    } else {
                        self.tableViewContainer.frame = CGRect(x: 0, y: self.bannerView.frame.maxY, width: self.view.frame.width, height: self.viewHeight - self.bannerView.frame.maxY)
                        self.tableViewForAll.frame = self.tableViewContainer.bounds
                    }
                }

                self.actualShowConversationGroup = !extensionList.isEmpty
            }
        } else {
            tableViewContainer.frame = CGRect(x: 0, y: bannerView.frame.maxY, width: view.frame.width, height: viewHeight - bannerView.frame.maxY)
            tableViewForAll.frame = tableViewContainer.bounds
        }
    }

    func createGroupBtn(groupItem: TUIConversationGroupItem, positionX: CGFloat) {
        let groupBtn = UIButton(type: .custom)
        groupBtn.backgroundColor = .clear
        groupBtn.setAttributedTitle(getGroupBtnAttributedString(groupItem: groupItem), for: .normal)
        groupBtn.setTitleColor(TUISwift.tuiConversationDynamicColor("conversation_group_btn_unselect_color", defaultColor: "#666666"), for: .normal)
        groupBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        groupBtn.addTarget(self, action: #selector(onGroupBtnClick(_:)), for: .touchUpInside)
        groupBtn.sizeToFit()
        groupBtn.mm_x = positionX
        groupBtn.mm_w = groupBtn.mm_w + GroupBtnSpace
        groupBtn.mm_h = GroupScrollViewHeight
        groupItem.groupBtn = groupBtn
        if TUISwift.isRTL() {
            groupBtn.transform = CGAffineTransform(rotationAngle: .pi)
        }
    }

    func updateGroupBtn(groupItem: TUIConversationGroupItem) {
        groupItem.groupBtn.setAttributedTitle(getGroupBtnAttributedString(groupItem: groupItem), for: .normal)
        if TUISwift.isRTL() {
            groupItem.groupBtn.mm_w = groupItem.groupBtn.mm_w
            groupItem.groupBtn.mm_h = GroupScrollViewHeight
        } else {
            groupItem.groupBtn.sizeToFit()
            groupItem.groupBtn.mm_w = groupItem.groupBtn.mm_w + GroupBtnSpace
            groupItem.groupBtn.mm_h = GroupScrollViewHeight
        }
    }

    @objc func onGroupBtnClick(_ btn: UIButton) {
        for groupItem in groupItemList {
            if groupItem.groupBtn == btn {
                onSelectGroup(groupItem)
                return
            }
        }
    }

    func reloadGroupList(_ reloadGroupItemList: [TUIConversationGroupItem]) {
        var currentSelectGroup = ""
        for groupItem in groupItemList {
            if groupItem.groupBtn.isSelected {
                currentSelectGroup = groupItem.groupName ?? ""
            }
            groupItem.groupBtn.removeFromSuperview()
        }
        groupItemList.removeAll()
        groupScrollView.contentSize = CGSize.zero

        addGroup(allGroupItem)
        for groupItem in reloadGroupItemList {
            addGroup(groupItem)
            if groupItem.groupName == currentSelectGroup {
                groupItem.groupBtn.isSelected = true
                groupAnimationView.frame = groupItem.groupBtn.frame
            }
        }
        if TUISwift.isRTL() {
            for subView in groupScrollView.subviews {
                subView.transform = CGAffineTransform(rotationAngle: .pi)
            }
        }
    }

    func addGroup(_ addGroupItem: TUIConversationGroupItem) {
        createGroupBtn(groupItem: addGroupItem, positionX: groupScrollView.contentSize.width)
        groupItemList.append(addGroupItem)
        groupScrollView.addSubview(addGroupItem.groupBtn)
        groupScrollView.contentSize = CGSize(width: (groupScrollView.contentSize.width) + addGroupItem.groupBtn.mm_w, height: GroupScrollViewHeight)
    }

    func insertGroup(_ insertGroupItem: TUIConversationGroupItem, atIndex index: Int) {
        if index < groupItemList.count {
            for i in 0..<(groupItemList.count) {
                if i == index {
                    createGroupBtn(groupItem: insertGroupItem, positionX: groupItemList[i].groupBtn.mm_x)
                    groupScrollView.addSubview(insertGroupItem.groupBtn)
                }
                if i >= index {
                    groupItemList[i].groupBtn.mm_x += insertGroupItem.groupBtn.mm_w
                    if groupItemList[i].groupBtn.isSelected {
                        groupAnimationView.frame = groupItemList[i].groupBtn.frame
                    }
                }
            }
            groupItemList.insert(insertGroupItem, at: index)
            groupScrollView.contentSize = CGSize(width: (groupScrollView.contentSize.width) + insertGroupItem.groupBtn.mm_w, height: GroupScrollViewHeight)
        } else {
            addGroup(insertGroupItem)
        }
    }

    func updateGroup(_ updateGroupItem: TUIConversationGroupItem) {
        var offsetX: CGFloat = 0
        for i in 0..<(groupItemList.count) {
            if offsetX != 0 {
                groupItemList[i].groupBtn.mm_x += offsetX
            }
            if groupItemList[i].groupName == updateGroupItem.groupName {
                groupItemList[i].unreadCount = updateGroupItem.unreadCount
                let oldBtnWidth = groupItemList[i].groupBtn.mm_w
                updateGroupBtn(groupItem: groupItemList[i])
                let newBtnWidth = groupItemList[i].groupBtn.mm_w
                offsetX = newBtnWidth - oldBtnWidth
            }
            if groupItemList[i].groupBtn.isSelected {
                groupAnimationView.frame = groupItemList[i].groupBtn.frame
            }
        }
        groupScrollView.contentSize = CGSize(width: (groupScrollView.contentSize.width) + offsetX, height: GroupScrollViewHeight)
    }

    func renameGroup(oldName: String, newName: String) {
        var offsetX: CGFloat = 0
        for i in 0..<(groupItemList.count) {
            if offsetX != 0 {
                groupItemList[i].groupBtn.mm_x += offsetX
            }
            if groupItemList[i].groupName == oldName {
                groupItemList[i].groupName = newName
                let oldBtnWidth = groupItemList[i].groupBtn.mm_w
                updateGroupBtn(groupItem: groupItemList[i])
                let newBtnWidth = groupItemList[i].groupBtn.mm_w
                offsetX = newBtnWidth - oldBtnWidth
            }
            if groupItemList[i].groupBtn.isSelected {
                groupAnimationView.frame = groupItemList[i].groupBtn.frame
            }
        }
        groupScrollView.contentSize = CGSize(width: (groupScrollView.contentSize.width) + offsetX, height: GroupScrollViewHeight)
    }

    func deleteGroup(_ deleteGroupItem: TUIConversationGroupItem) {
        var offsetX: CGFloat = 0
        var removeIndex = 0
        var isSelectedGroup = false
        for i in 0..<(groupItemList.count) {
            if offsetX != 0 {
                groupItemList[i].groupBtn.mm_x += offsetX
            }
            if groupItemList[i].groupName == deleteGroupItem.groupName {
                groupItemList[i].groupBtn.removeFromSuperview()
                offsetX = -(groupItemList[i].groupBtn.mm_w)
                removeIndex = i
                isSelectedGroup = groupItemList[i].groupBtn.isSelected
            }
            if groupItemList[i].groupBtn.isSelected {
                groupAnimationView.frame = groupItemList[i].groupBtn.frame
            }
        }
        groupItemList.remove(at: removeIndex)
        groupScrollView.contentSize = CGSize(width: (groupScrollView.contentSize.width) + offsetX, height: GroupScrollViewHeight)
        if isSelectedGroup {
            onSelectGroup(groupItemList.first ?? TUIConversationGroupItem())
        }
    }

    func onSelectGroup(_ selectGroupItem: TUIConversationGroupItem) {
        for i in 0..<(groupItemList.count) {
            if groupItemList[i].groupName == selectGroupItem.groupName {
                groupItemList[i].groupBtn.isSelected = true

                UIView.animate(withDuration: 0.1) {
                    self.groupAnimationView.frame = self.groupItemList[i].groupBtn.frame
                }
                for view in tableViewContainer.subviews {
                    view.removeFromSuperview()
                }
                if selectGroupItem.groupName == TUISwift.timCommonLocalizableString("TUIConversationGroupAll") {
                    tableViewForAll.frame = tableViewContainer.bounds
                    tableViewContainer.addSubview(tableViewForAll)
                } else {
                    let _ = TUICore.raiseExtension("TUICore_TUIConversationExtension_ConversationListContainer_ClassicExtensionID", parentView: tableViewContainer, param: ["TUICore_TUIConversationExtension_ConversationListContainer_GroupNameKey": selectGroupItem.groupName])
                    currentTableView()?.convDelegate = self
                }
            } else {
                groupItemList[i].groupBtn.isSelected = false
            }
            updateGroupBtn(groupItem: groupItemList[i])
        }
    }

    func getGroupBtnAttributedString(groupItem: TUIConversationGroupItem) -> NSAttributedString {
        let content = NSMutableString(string: "")
        let contentName = NSMutableString(string: groupItem.groupName ?? "")
        let contentNum = NSMutableString(string: "")
        let attributeString: NSMutableAttributedString
        let unreadCount = groupItem.unreadCount
        if unreadCount > 0 {
            contentNum.append(unreadCount > 99 ? "99+" : "\(unreadCount)")
        }
        if TUISwift.isRTL() {
            content.append("\u{200E}")
            content.append(contentNum as String)
            content.append(" ")
            content.append("\u{202B}")
            content.append(contentName as String)
            attributeString = NSMutableAttributedString(string: content as String)
        } else {
            content.append(contentName as String)
            content.append(" ")
            content.append(contentNum as String)
            attributeString = NSMutableAttributedString(string: content as String)
        }

        attributeString.setAttributes([
            .foregroundColor: TUISwift.tuiConversationDynamicColor("conversation_group_btn_select_color", defaultColor: "#147AFF"),
            .font: UIFont.systemFont(ofSize: 12),
            .baselineOffset: 1
        ], range: content.range(of: contentNum as String))
        if groupItem.groupBtn.isSelected {
            attributeString.setAttributes([
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: TUISwift.tuiConversationDynamicColor("conversation_group_btn_select_color", defaultColor: "#147AFF")
            ], range: content.range(of: contentName as String))
        } else {
            attributeString.setAttributes([
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: TUISwift.tuiConversationDynamicColor("conversation_group_btn_unselect_color", defaultColor: "#666666")
            ], range: content.range(of: contentName as String))
        }
        return attributeString
    }

    public func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIConversationGroupNotify" || key == "TUICore_TUIConversationMarkNotify" {
            if !actualShowConversationGroup {
                actualShowConversationGroup = true
            }
        }
        if key == "TUICore_TUIConversationGroupNotify" {
            if let groupListReloadKey = param?["TUICore_TUIConversationGroupNotify_GroupListReloadKey"] as? [TUIConversationGroupItem] {
                reloadGroupList(groupListReloadKey)
            } else if let groupAddKey = param?["TUICore_TUIConversationGroupNotify_GroupAddKey"] as? TUIConversationGroupItem {
                addGroup(groupAddKey)
            } else if let groupUpdateKey = param?["TUICore_TUIConversationGroupNotify_GroupUpdateKey"] as? TUIConversationGroupItem {
                updateGroup(groupUpdateKey)
            } else if let groupRenameKey = param?["TUICore_TUIConversationGroupNotify_GroupRenameKey"] as? [String: Any] {
                if let oldName = groupRenameKey.keys.first,
                   let newName = groupRenameKey.values.first
                {
                    renameGroup(oldName: oldName, newName: newName as? String ?? "")
                }
            } else if let groupDeleteKey = param?["TUICore_TUIConversationGroupNotify_GroupDeleteKey"] as? TUIConversationGroupItem {
                deleteGroup(groupDeleteKey)
            }
        } else if key == "TUICore_TUIConversationMarkNotify" {
            if let markAddKey = param?["TUICore_TUIConversationGroupNotify_MarkAddKey"] as? TUIConversationGroupItem {
                insertGroup(markAddKey, atIndex: markAddKey.groupIndex)
            } else if let markUpdateKey = param?["TUICore_TUIConversationGroupNotify_MarkUpdateKey"] as? TUIConversationGroupItem {
                updateGroup(markUpdateKey)
            }
        }
    }

    func tableViewDidScroll(_ offsetY: CGFloat) {
        if bannerView.isHidden || !isShowBanner {
            return
        }
        if let currentTableView = currentTableView() {
            var safeAreaInsets = UIEdgeInsets.zero
            if #available(iOS 11.0, *) {
                safeAreaInsets = currentTableView.adjustedContentInset
            }
            let contentSizeHeight = currentTableView.contentSize.height + safeAreaInsets.top + safeAreaInsets.bottom
            if contentSizeHeight > currentTableView.mm_h && currentTableView.contentOffset.y + currentTableView.mm_h > contentSizeHeight {
                return
            }
        }
        var offsetYCache = offsetY
        if offsetYCache > bannerView.mm_h {
            offsetYCache = bannerView.mm_h
        }
        if offsetYCache < 0 {
            offsetYCache = 0
        }
        bannerView.mm_top(TUISwift.statusBar_Height() + TUISwift.navBar_Height() - offsetYCache)
        if actualShowConversationGroup {
            groupView.mm_top(bannerView.mm_maxY)
            tableViewContainer.mm_top(groupView.mm_maxY).mm_height(view.mm_h - (groupView.mm_maxY))
        } else {
            tableViewContainer.mm_top(bannerView.mm_maxY).mm_height(view.mm_h - (bannerView.mm_maxY))
        }
    }

    func tableViewDidSelectCell(_ data: TUIConversationCellData) {
        if data.isLocalConversationFoldList {
            TUIConversationListDataProvider.cacheConversationFoldListSettings_FoldItemIsUnread(false)
            let foldVC = TUIFoldListViewController()
            navigationController?.pushViewController(foldVC, animated: true)
            foldVC.dismissCallback = { [weak self] foldStr, sortArr, needRemoveFromCacheMapArray in
                guard let self = self else { return }
                data.foldSubTitle = foldStr
                data.subTitle = data.foldSubTitle
                data.isMarkAsUnread = false
                if sortArr.count <= 0 {
                    data.orderKey = 0
                    if self.dataProvider?.conversationList.contains(data) ?? false {
                        self.dataProvider?.hideConversation(data)
                    }
                }
                for removeId in needRemoveFromCacheMapArray {
                    if let _ = self.dataProvider?.markFoldMap.keys.contains(removeId) {
                        self.dataProvider?.markFoldMap.removeValue(forKey: removeId)
                    }
                }
                TUIConversationListDataProvider.cacheConversationFoldListSettings_FoldItemIsUnread(false)
                self.currentTableView()?.reloadData()
            }
            return
        }
        if let delegate = delegate, delegate.conversationListController(self, didSelectConversation: data) {
        } else {
            let param: [String: Any] = [
                "TUICore_TUIChatObjectFactory_ChatViewController_Title": data.title ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_UserID": data.userID ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_GroupID": data.groupID ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage": data.avatarImage ?? UIImage(),
                "TUICore_TUIChatObjectFactory_ChatViewController_AvatarUrl": data.faceUrl ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_ConversationID": data.conversationID ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_AtTipsStr": data.atTipsStr ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_AtMsgSeqs": data.atMsgSeqs ?? [],
                "TUICore_TUIChatObjectFactory_ChatViewController_Draft": data.draftText ?? ""
            ]
            navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Classic", param: param, forResult: nil)
        }
    }

    func tableViewDidShowAlert(_ ac: UIAlertController) {
        present(ac, animated: true, completion: nil)
    }

    public func popView(_ popView: TUIPopView, didSelectRowAt index: Int) {
        if index == 0 {
            startConversation(.C2C)
        } else {
            startConversation(.GROUP)
        }
    }

    public func startConversation(_ type: V2TIMConversationType) {
        let selectContactCompletion: ([TUICommonContactSelectCellData]) -> Void = { [weak self] array in
            guard let self = self else { return }
            if type == .C2C {
                let param: [String: Any] = [
                    "TUICore_TUIChatObjectFactory_ChatViewController_Title": array.first?.title ?? "",
                    "TUICore_TUIChatObjectFactory_ChatViewController_UserID": array.first?.identifier ?? "",
                    "TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage": array.first?.avatarImage ?? UIImage(),
                    "TUICore_TUIChatObjectFactory_ChatViewController_AvatarUrl": array.first?.avatarUrl?.absoluteString ?? ""
                ]
                self.navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Classic", param: param, forResult: nil)

                var tempArray = self.navigationController?.viewControllers ?? []
                tempArray.remove(at: tempArray.count - 2)
                self.navigationController?.viewControllers = tempArray
            } else {
                guard let loginUser = V2TIMManager.sharedInstance().getLoginUser() else { return }
                V2TIMManager.sharedInstance().getUsersInfo([loginUser]) { [weak self] infoList in
                    guard let self = self, let infoList = infoList else { return }
                    var showName = loginUser
                    if let nickName = infoList.first?.nickName, nickName.count > 0 {
                        showName = nickName
                    }
                    var groupName = NSMutableString(string: showName)
                    for item in array {
                        groupName.appendFormat("、%@", item.title)
                    }
                    if groupName.length > 10 {
                        groupName = NSMutableString(string: String(groupName.substring(to: 10)))
                    }
                    let createGroupCompletion: (Bool, V2TIMGroupInfo?) -> Void = { _, info in
                        let param: [String: Any] = [
                            "TUICore_TUIChatObjectFactory_ChatViewController_Title": info?.groupName ?? "",
                            "TUICore_TUIChatObjectFactory_ChatViewController_GroupID": info?.groupID ?? "",
                            "TUICore_TUIChatObjectFactory_ChatViewController_AvatarUrl": info?.faceURL ?? ""
                        ]
                        self.navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Classic", param: param, forResult: nil)

                        var tempArray = self.navigationController?.viewControllers ?? []
                        for vc in tempArray {
                            if let cls1 = NSClassFromString("TUIContact.TUIGroupCreateController"),
                               vc.isKind(of: cls1)
                            {
                                tempArray.remove(at: tempArray.firstIndex(of: vc) ?? 0)
                            } else if let cls2 = NSClassFromString("TUIContact.TUIContactSelectController"),
                                      vc.isKind(of: cls2)
                            {
                                tempArray.remove(at: tempArray.firstIndex(of: vc) ?? 0)
                            }
                        }
                        self.navigationController?.viewControllers = tempArray
                    }
                    let param: [String: Any] = [
                        "TUICore_TUIContactObjectFactory_GetGroupCreateControllerMethod_TitleKey": array.first?.title ?? "",
                        "TUICore_TUIContactObjectFactory_GetGroupCreateControllerMethod_GroupNameKey": groupName as String,
                        "TUICore_TUIContactObjectFactory_GetGroupCreateControllerMethod_GroupTypeKey": "Work",
                        "TUICore_TUIContactObjectFactory_GetGroupCreateControllerMethod_CompletionKey": createGroupCompletion,
                        "TUICore_TUIContactObjectFactory_GetGroupCreateControllerMethod_ContactListKey": array
                    ]
                    let groupVC = TUICore.createObject("TUICore_TUIContactObjectFactory", key: "TUICore_TUIContactObjectFactory_GetGroupCreateControllerMethod", param: param) as? UIViewController
                    self.navigationController?.pushViewController(groupVC ?? UIViewController(), animated: true)
                } fail: { _, _ in
                    // Handle error
                }
            }
        }
        let param: [String: Any] = [
            "TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_TitleKey": TUISwift.timCommonLocalizableString("ChatsSelectContact"),
            "TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_MaxSelectCount": type == .C2C ? 1 : INT_MAX,
            "TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_CompletionKey": selectContactCompletion
        ]
        let vc = TUICore.createObject("TUICore_TUIContactObjectFactory", key: "TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod", param: param) as? UIViewController
        navigationController?.pushViewController(vc ?? UIViewController(), animated: true)
    }

    public func getConversationDisplayString(_ conversation: V2TIMConversation) -> String? {
        if let delegate = delegate {
            return delegate.getConversationDisplayString(conversation)
        }
        guard let msg = conversation.lastMessage, let customElem = msg.customElem, let data = customElem.data else {
            return nil
        }
        guard let param = TUITool.jsonData2Dictionary(data) as? [String: Any] else {
            return nil
        }
        guard let businessID = param["businessID"] as? String else {
            return nil
        }
        if businessID == "text_link" || (param["text"] as? String)?.count ?? 0 > 0 && (param["link"] as? String)?.count ?? 0 > 0 {
            guard let desc = param["text"] as? String else {
                return nil
            }
            if msg.status == V2TIMMessageStatus.MSG_STATUS_LOCAL_REVOKED {
                if msg.hasRiskContent {
                    return TUISwift.timCommonLocalizableString("TUIKitMessageTipsRecallRiskContent")
                } else if let info = msg.revokerInfo, let userName = info.nickName {
                    return String(format: TUISwift.timCommonLocalizableString("TUIKitMessageTipsRecallMessageFormat"), userName)
                } else if msg.isSelf {
                    return TUISwift.timCommonLocalizableString("TUIKitMessageTipsYouRecallMessage")
                } else if let userID = msg.userID, !userID.isEmpty {
                    return TUISwift.timCommonLocalizableString("TUIKitMessageTipsOthersRecallMessage")
                } else if let groupID = msg.groupID, !groupID.isEmpty {
                    let userName = (msg.nameCard ?? msg.nickName ?? msg.sender) ?? ""
                    return String(format: TUISwift.timCommonLocalizableString("TUIKitMessageTipsRecallMessageFormat"), userName)
                }
            }
            return desc
        }
        return nil
    }

    func adaptivePresentationStyle(for presentationController: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
