import TIMCommon
import TUICore
import UIKit

public let gConversationCell_ReuseId: String = "TConversationCell"

protocol TUIConversationTableViewDelegate: NSObjectProtocol {
    func tableViewDidScroll(_ offsetY: CGFloat)
    func tableViewDidSelectCell(_ data: TUIConversationCellData)
    func tableViewDidShowAlert(_ ac: UIAlertController)
}

open class TUIConversationTableView: UITableView, UITableViewDelegate, UITableViewDataSource, TUIConversationListDataProviderDelegate {
    weak var convDelegate: TUIConversationTableViewDelegate?
    var _dataProvider: TUIConversationListBaseDataProvider?
    public var unreadCountChanged: ((Int, Int) -> Void)?
    public var tipsMsgWhenNoConversation: String?
    var disableMoreActionExtension = false
    
    private var hideMarkReadAction = false
    private var hideDeleteAction = false
    private var hideHideAction = false
    private var customizedItems: [UIAlertAction] = []
    
    lazy var tipsView: UIImageView = {
        let tipsView = UIImageView()
        tipsView.image = TUISwift.tuiConversationDynamicImage("no_conversation_img", defaultImage: UIImage.safeImage(TUISwift.tuiConversationImagePath("no_conversation")))
        tipsView.isHidden = true
        return tipsView
    }()
    
    lazy var tipsLabel: UILabel = {
        let tipsLabel = UILabel()
        tipsLabel.textColor = TUISwift.timCommonDynamicColor("nodata_tips_color", defaultColor: "#999999")
        tipsLabel.font = UIFont.systemFont(ofSize: 14.0)
        tipsLabel.textAlignment = .center
        tipsLabel.isHidden = true
        return tipsLabel
    }()
    
    override public init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        setupTableView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTableView()
    }
    
    private func setupTableView() {
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = TUISwift.tuiConversationDynamicColor("conversation_bg_color", defaultColor: "#FFFFFF")
        tableFooterView = UIView()
        contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        register(TUIConversationCell.self, forCellReuseIdentifier: gConversationCell_ReuseId)
        estimatedRowHeight = CGFloat(TConversationCell_Height)
        rowHeight = CGFloat(TConversationCell_Height)
        delaysContentTouches = false
        separatorColor = TUISwift.timCommonDynamicColor("separator_color", defaultColor: "#DBDBDB")
        delegate = self
        dataSource = self
        addSubview(tipsView)
        addSubview(tipsLabel)
        disableMoreActionExtension = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(onFriendInfoChanged(_:)), name: NSNotification.Name("FriendInfoChangedNotification"), object: nil)
    }
    
    @objc private func onFriendInfoChanged(_ notice: Notification) {
        guard let friendInfo = notice.object as? V2TIMFriendInfo else { return }
        for cellData in dataProvider.conversationList {
            if cellData.userID == friendInfo.userID {
                if let userFullInfo = friendInfo.userFullInfo {
                    cellData.title = friendInfo.friendRemark ?? userFullInfo.nickName ?? friendInfo.userID
                    reloadData()
                    break
                }
            }
        }
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        tipsView.mm_width(128).mm_height(109).mm__centerX(mm_centerX).mm__centerY(mm_centerY - 60)
        tipsLabel.mm_width(300).mm_height(20).mm__centerX(mm_centerX).mm_top(tipsView.mm_maxY + 18)
    }
    
    private func updateTipsViewStatus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.dataProvider.conversationList.count == 0 {
                self.tipsView.isHidden = false
                self.tipsLabel.isHidden = false
                self.tipsLabel.text = self.tipsMsgWhenNoConversation
            } else {
                self.tipsView.isHidden = true
                self.tipsLabel.isHidden = true
            }
        }
    }
    
    public var dataProvider: TUIConversationListBaseDataProvider {
        get {
            return _dataProvider ?? TUIConversationListBaseDataProvider()
        }
        set {
            _dataProvider = newValue
            _dataProvider?.delegate = self
            _dataProvider?.loadNexPageConversations()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: TUIConversationListDataProviderDelegate

    public func insertConversations(at indexPaths: [IndexPath]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.insertConversations(at: indexPaths)
            }
            return
        }
        
        // Validate section and row consistency before insert to avoid crash
        let currentSectionCount = numberOfSections
        let currentRowCount = currentSectionCount > 0 ? numberOfRows(inSection: 0) : 0
        let expectedRowCount = currentRowCount + indexPaths.count
        let actualRowCount = dataProvider.conversationList.count
        
        // Check: only 1 section expected, and row count matches
        if currentSectionCount != 1 || expectedRowCount != actualRowCount {
            reloadData()
            return
        }
        
        UIView.performWithoutAnimation {
            self.insertRows(at: indexPaths, with: .none)
        }
    }

    public func reloadConversations(at indexPaths: [IndexPath]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.reloadConversations(at: indexPaths)
            }
            return
        }
        if isEditing {
            isEditing = false
        }
        UIView.performWithoutAnimation {
            self.reloadRows(at: indexPaths, with: .none)
        }
    }
    
    public func deleteConversation(at indexPaths: [IndexPath]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.deleteConversation(at: indexPaths)
            }
            return
        }
        deleteRows(at: indexPaths, with: .none)
    }
    
    public func reloadAllConversations() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.reloadAllConversations()
            }
            return
        }
        reloadData()
    }
    
    public func updateMarkUnreadCount(_ markUnreadCount: Int, markHideUnreadCount: Int) {
        if let unreadCountChanged = unreadCountChanged {
            unreadCountChanged(markUnreadCount, markHideUnreadCount)
        }
    }
    
    func parseActionHiddenTagAndCustomizedItems(_ cellData: TUIConversationCellData) {
        guard let dataSource = TUIConversationConfig.shared.moreMenuDataSource else { return }
        let flag = dataSource.conversationShouldHideItemsInMoreMenu(cellData)
        hideDeleteAction = ((flag.rawValue & TUIConversationItemInMoreMenu.Delete.rawValue) != 0)
        hideMarkReadAction = ((flag.rawValue & TUIConversationItemInMoreMenu.MarkRead.rawValue) != 0)
        hideHideAction = ((flag.rawValue & TUIConversationItemInMoreMenu.Hide.rawValue) != 0)
        
        if let items = dataSource.conversationShouldAddNewItemsToMoreMenu(cellData) as? [UIAlertAction], items.count > 0 {
            customizedItems = items
        }
    }
    
    // MARK: - Table view data source

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        dataProvider.loadNexPageConversations()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        convDelegate?.tableViewDidScroll(offsetY)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        updateTipsViewStatus()
        return dataProvider.conversationList.count
    }
    
    public func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    open func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let cellData = dataProvider.conversationList[indexPath.row]
        var rowActions: [UITableViewRowAction] = []
        parseActionHiddenTagAndCustomizedItems(cellData)
        
        if cellData.isLocalConversationFoldList {
            let markHideAction = UITableViewRowAction(style: .default, title: TUISwift.timCommonLocalizableString("MarkHide")) { _, _ in
                self.dataProvider.markConversationHide(cellData)
                if cellData.isLocalConversationFoldList {
                    TUIConversationListDataProvider.cacheConversationFoldListSettings_HideFoldItem(true)
                }
            }
            markHideAction.backgroundColor = TUISwift.rgb(242, g: 147, b: 64)
            if !hideHideAction {
                rowActions.append(markHideAction)
            }
            return rowActions
        }
        
        let deleteAction = UITableViewRowAction(style: .destructive, title: TUISwift.timCommonLocalizableString("Delete")) { _, _ in
            let cancelBtnInfo = TUISecondConfirmBtnInfo()
            cancelBtnInfo.title = TUISwift.timCommonLocalizableString("Cancel")
            cancelBtnInfo.click = { [weak self] in
                guard let self = self else { return }
                self.isEditing = false
            }
            let confirmBtnInfo = TUISecondConfirmBtnInfo()
            confirmBtnInfo.title = TUISwift.timCommonLocalizableString("Delete")
            confirmBtnInfo.click = { [weak self] in
                guard let self = self else { return }
                self.dataProvider.removeConversation(cellData)
                self.isEditing = false
            }
            TUISecondConfirm.show(title: TUISwift.timCommonLocalizableString("TUIKitConversationTipsDelete"), cancelBtnInfo: cancelBtnInfo, confirmBtnInfo: confirmBtnInfo)
        }
        deleteAction.backgroundColor = TUISwift.rgb(242, g: 77, b: 76)
        if !hideDeleteAction {
            rowActions.append(deleteAction)
        }
        
        let markAsReadAction = UITableViewRowAction(style: .default, title: cellData.isMarkAsUnread || cellData.unreadCount > 0 ? TUISwift.timCommonLocalizableString("MarkAsRead") : TUISwift.timCommonLocalizableString("MarkAsUnRead")) { _, _ in
            if cellData.isMarkAsUnread || cellData.unreadCount > 0 {
                self.dataProvider.markConversationAsRead(cellData)
                if cellData.isLocalConversationFoldList {
                    TUIConversationListDataProvider.cacheConversationFoldListSettings_FoldItemIsUnread(false)
                }
            } else {
                self.dataProvider.markConversationAsUnRead(cellData)
                if cellData.isLocalConversationFoldList {
                    TUIConversationListDataProvider.cacheConversationFoldListSettings_FoldItemIsUnread(true)
                }
            }
        }
        markAsReadAction.backgroundColor = TUISwift.rgb(20, g: 122, b: 255)
        if !hideMarkReadAction {
            rowActions.append(markAsReadAction)
        }
        
        let moreExtensionList = TUICore.getExtensionList("TUICore_TUIConversationExtension_ConversationCellMoreAction_ClassicExtensionID", param: [
            "TUICore_TUIConversationExtension_ConversationCellAction_ConversationIDKey": cellData.conversationID ?? "",
            "TUICore_TUIConversationExtension_ConversationCellAction_MarkListKey": cellData.conversationMarkList ?? [],
            "TUICore_TUIConversationExtension_ConversationCellAction_GroupListKey": cellData.conversationGroupList ?? []
        ])
        if disableMoreActionExtension || moreExtensionList.count == 0 {
            let markAsHideAction = UITableViewRowAction(style: .destructive, title: TUISwift.timCommonLocalizableString("MarkHide")) { _, _ in
                self.dataProvider.markConversationHide(cellData)
                if cellData.isLocalConversationFoldList {
                    TUIConversationListDataProvider.cacheConversationFoldListSettings_HideFoldItem(true)
                }
            }
            markAsHideAction.backgroundColor = TUISwift.rgb(242, g: 147, b: 64)
            if !hideHideAction {
                rowActions.append(markAsHideAction)
            }
        } else {
            let moreAction = UITableViewRowAction(style: .destructive, title: TUISwift.timCommonLocalizableString("More")) { [weak self] _, _ in
                guard let self = self else { return }
                self.isEditing = false
                showMoreAction(cellData, extensionList: moreExtensionList)
            }
            moreAction.backgroundColor = TUISwift.rgb(242, g: 147, b: 64)
            rowActions.append(moreAction)
        }
        return rowActions
    }
    
    @available(iOS 11.0, *)
    open func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let cellData = dataProvider.conversationList[indexPath.row]
        
        parseActionHiddenTagAndCustomizedItems(cellData)
        
        var arrayM: [UIContextualAction] = []
        
        if cellData.isLocalConversationFoldList && !hideHideAction {
            let markHideAction = UIContextualAction(style: .normal, title: TUISwift.timCommonLocalizableString("MarkHide")) { [weak self] _, _, completionHandler in
                guard let self = self else { return }
                self.dataProvider.markConversationHide(cellData)
                if cellData.isLocalConversationFoldList {
                    TUIConversationListDataProvider.cacheConversationFoldListSettings_HideFoldItem(true)
                }
                completionHandler(true)
            }
            markHideAction.backgroundColor = TUISwift.rgb(242, g: 147, b: 64)
            let configuration = UISwipeActionsConfiguration(actions: [markHideAction])
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }
        
        if !hideDeleteAction {
            let deleteAction = UIContextualAction(style: .normal, title: TUISwift.timCommonLocalizableString("Delete")) { _, _, completionHandler in
                let cancelBtnInfo = TUISecondConfirmBtnInfo()
                cancelBtnInfo.title = TUISwift.timCommonLocalizableString("Cancel")
                cancelBtnInfo.click = { [weak self] in
                    guard let self = self else { return }
                    self.isEditing = false
                }
                let confirmBtnInfo = TUISecondConfirmBtnInfo()
                confirmBtnInfo.title = TUISwift.timCommonLocalizableString("Delete")
                confirmBtnInfo.click = { [weak self] in
                    guard let self = self else { return }
                    self.dataProvider.removeConversation(cellData)
                    self.isEditing = false
                }
                TUISecondConfirm.show(title: TUISwift.timCommonLocalizableString("TUIKitConversationTipsDelete"), cancelBtnInfo: cancelBtnInfo, confirmBtnInfo: confirmBtnInfo)
                completionHandler(true)
            }
            deleteAction.backgroundColor = TUISwift.rgb(242, g: 77, b: 76)
            arrayM.append(deleteAction)
        }
        
        if !hideMarkReadAction {
            let markAsReadAction = UIContextualAction(style: .normal, title: cellData.isMarkAsUnread || cellData.unreadCount > 0 ? TUISwift.timCommonLocalizableString("MarkAsRead") : TUISwift.timCommonLocalizableString("MarkAsUnRead")) { [weak self] _, _, completionHandler in
                guard let self = self else { return }
                if cellData.isMarkAsUnread || cellData.unreadCount > 0 {
                    self.dataProvider.markConversationAsRead(cellData)
                    if cellData.isLocalConversationFoldList {
                        TUIConversationListDataProvider.cacheConversationFoldListSettings_FoldItemIsUnread(false)
                    }
                } else {
                    self.dataProvider.markConversationAsUnRead(cellData)
                    if cellData.isLocalConversationFoldList {
                        TUIConversationListDataProvider.cacheConversationFoldListSettings_FoldItemIsUnread(true)
                    }
                }
                completionHandler(true)
            }
            markAsReadAction.backgroundColor = TUISwift.rgb(20, g: 122, b: 255)
            arrayM.append(markAsReadAction)
        }
        
        let moreExtensionList: [Any] = TUICore.getExtensionList(
            "TUICore_TUIConversationExtension_ConversationCellMoreAction_ClassicExtensionID",
            param: [
                "TUICore_TUIConversationExtension_ConversationCellAction_ConversationIDKey": cellData.conversationID ?? "",
                "TUICore_TUIConversationExtension_ConversationCellAction_MarkListKey": cellData.conversationMarkList ?? [],
                "TUICore_TUIConversationExtension_ConversationCellAction_GroupListKey": cellData.conversationGroupList ?? []
            ]
        )
        if disableMoreActionExtension || moreExtensionList.count == 0 {
            let markAsHideAction = UIContextualAction(style: .normal, title: TUISwift.timCommonLocalizableString("MarkHide")) { [weak self] _, _, _ in
                guard let self = self else { return }
                self.dataProvider.markConversationHide(cellData)
                if cellData.isLocalConversationFoldList {
                    TUIConversationListDataProvider.cacheConversationFoldListSettings_HideFoldItem(true)
                }
            }
            markAsHideAction.backgroundColor = TUISwift.rgb(242, g: 147, b: 64)
            if !hideHideAction {
                arrayM.append(markAsHideAction)
            }
        } else {
            let moreAction = UIContextualAction(style: .normal, title: TUISwift.timCommonLocalizableString("More")) { [weak self] _, _, completionHandler in
                guard let self = self else { return }
                self.isEditing = false
                showMoreAction(cellData, extensionList: moreExtensionList)
                completionHandler(true)
            }
            moreAction.backgroundColor = TUISwift.rgb(242, g: 147, b: 64)
            arrayM.append(moreAction)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: arrayM)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    // MARK: action

    private func showMoreAction(_ cellData: TUIConversationCellData, extensionList: [Any]) {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for action in customizedItems {
            ac.addAction(action)
        }
        if !hideHideAction {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("MarkHide"), style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.dataProvider.markConversationHide(cellData)
                if cellData.isLocalConversationFoldList {
                    TUIConversationListDataProvider.cacheConversationFoldListSettings_HideFoldItem(true)
                }
            })
        }
        addCustomAction(ac, cellData: cellData)
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        convDelegate?.tableViewDidShowAlert(ac)
    }
    
    func addCustomAction(_ ac: UIAlertController, cellData: TUIConversationCellData) {
        let extensionList = TUICore.getExtensionList("TUICore_TUIConversationExtension_ConversationCellMoreAction_ClassicExtensionID", param: [
            "TUICore_TUIConversationExtension_ConversationCellAction_ConversationIDKey": cellData.conversationID ?? "",
            "TUICore_TUIConversationExtension_ConversationCellAction_MarkListKey": cellData.conversationMarkList ?? [],
            "TUICore_TUIConversationExtension_ConversationCellAction_GroupListKey": cellData.conversationGroupList ?? []
        ])
        for info in extensionList {
            let action = UIAlertAction(title: info.text, style: .default) { _ in
                info.onClicked?([:])
            }
            ac.addAction(action)
        }
    }
    
    // MARK: - Table view delegate

    public func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < dataProvider.conversationList.count else { return UITableViewCell() }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: gConversationCell_ReuseId, for: indexPath) as? TUIConversationCell else { return UITableViewCell() }
        if indexPath.row < dataProvider.conversationList.count {
            let data = dataProvider.conversationList[indexPath.row]
            tableViewFillCell(cell, withData: data)
            let extensionList = TUICore.getExtensionList("TUICore_TUIConversationExtension_ConversationCellUpperRightCorner_ClassicExtensionID", param: [
                "TUICore_TUIConversationExtension_ConversationCellUpperRightCorner_GroupListKey": data.conversationGroupList ?? [],
                "TUICore_TUIConversationExtension_ConversationCellUpperRightCorner_MarkListKey": data.conversationMarkList ?? []
            ])
            if !extensionList.isEmpty {
                if let info = extensionList.first {
                    if let text = info.text {
                        cell.timeLabel.text = text
                    } else if let icon = info.icon {
                        let textAttachment = NSTextAttachment()
                        textAttachment.image = icon
                        let imageStr = NSAttributedString(attachment: textAttachment)
                        cell.timeLabel.attributedText = imageStr
                    }
                }
            }
        }
        return cell
    }
    
    open func tableViewFillCell(_ cell: TUIConversationCell, withData data: TUIConversationCellData) {
        cell.fill(with: data)
    }
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let data = dataProvider.conversationList[indexPath.row]
        tableViewDidSelectCell(data)
    }
    
    open func tableViewDidSelectCell(_ data: TUIConversationCellData) {
        convDelegate?.tableViewDidSelectCell(data)
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let needLastLineFromZeroToMax = false
        if cell.responds(to: #selector(setter: UITableViewCell.separatorInset)) {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 75, bottom: 0, right: 0)
            if needLastLineFromZeroToMax && indexPath.row == (dataProvider.conversationList.count) - 1 {
                cell.separatorInset = .zero
            }
        }
        if needLastLineFromZeroToMax && cell.responds(to: #selector(setter: UITableViewCell.preservesSuperviewLayoutMargins)) {
            cell.preservesSuperviewLayoutMargins = false
        }
        if needLastLineFromZeroToMax && cell.responds(to: #selector(setter: UITableViewCell.layoutMargins)) {
            cell.layoutMargins = .zero
        }
    }
}
