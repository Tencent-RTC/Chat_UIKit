// TUIGroupRequestViewController_Minimalist.swift
// TUIContact

import TIMCommon
import UIKit

class TUIGroupRequestViewController_Minimalist: UIViewController, UITableViewDataSource, UITableViewDelegate, TUIProfileCardDelegate, TUIFloatSubViewControllerProtocol {
    var floatDataSourceChanged: (([Any]) -> Void)?

    func didTap(onAvatar cell: TUIProfileCardCell) {
        // to do
    }

    var groupInfo: V2TIMGroupInfo!
    private var tableView: UITableView!
    private var addMsgTextView: UITextView!
    private var cardCellData: TUIProfileCardCellData_Minimalist?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: .zero, style: .grouped)
        view.addSubview(tableView)
        tableView.frame = view.bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none

        addMsgTextView = UITextView(frame: .zero)
        addMsgTextView.font = UIFont.systemFont(ofSize: 14)
        addMsgTextView.textAlignment = TUISwift.isRTL() ? .right : .left
        addMsgTextView.backgroundColor = UIColor.tui_color(withHex: "#F9F9F9")

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.firstLineHeadIndent = TUISwift.kScale390(12.5)
        paragraphStyle.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: TUISwift.kScale390(16)),
            .paragraphStyle: paragraphStyle
        ]

        if let loginUser = V2TIMManager.sharedInstance().getLoginUser() {
            V2TIMManager.sharedInstance().getUsersInfo([loginUser], succ: { [weak self] infoList in
                guard let self = self, let infoList = infoList else { return }
                if let showName = infoList.first?.showName() {
                    let text = String(format: TUISwift.timCommonLocalizableString("GroupRequestJoinGroupFormat"), showName)
                    self.addMsgTextView.attributedText = NSAttributedString(string: text, attributes: attributes)
                }
            }, fail: { _, _ in
                // Handle failure
            })
        }

        let data = TUIProfileCardCellData_Minimalist()
        data.name = groupInfo.groupName ?? ""
        data.identifier = groupInfo.groupID ?? ""
        data.signature = String(format: "%@: %@", TUISwift.timCommonLocalizableString("TUIKitCreatGroupType"), groupInfo.groupType ?? "Public")
        data.showSignature = true
        data.avatarImage = TUISwift.defaultGroupAvatarImage(byGroupType: groupInfo.groupType ?? "Public")
        if let faceURL = groupInfo.faceURL {
            data.avatarUrl = URL(string: faceURL)!
        }
        cardCellData = data

        title = TUISwift.timCommonLocalizableString("GroupJoin")

        TUITool.addUnsupportNotification(inVC: self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            return cardCellData?.height(ofWidth: TUISwift.screen_Width()) ?? 0
        case 1:
            return TUISwift.kScale390(123)
        case 2:
            return TUISwift.kScale390(42)
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear

        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("please_fill_in_verification_information")
        label.textColor = UIColor.tui_color(withHex: "#000000")
        label.font = UIFont.systemFont(ofSize: 14.0)

        label.frame = CGRect(x: TUISwift.kScale390(16), y: TUISwift.kScale390(12), width: tableView.bounds.size.width - 20, height: TUISwift.kScale390(28))
        view.addSubview(label)

        return section == 1 ? view : nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return TUISwift.kScale390(10)
        case 1:
            return TUISwift.kScale390(40)
        case 2:
            return TUISwift.kScale390(20)
        default:
            return 0
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = TUIProfileCardCell_Minimalist(style: .default, reuseIdentifier: "TPersonalCommonCell_ReuseId")
            cell.delegate = self
            if let cardCellData = cardCellData {
                cell.fill(with: cardCellData)
            }
            return cell
        case 1:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "AddWord")
            cell.contentView.addSubview(addMsgTextView)
            addMsgTextView.mm_width(TUISwift.screen_Width()).mm_height(TUISwift.kScale390(123))
            return cell
        case 2:
            let cell = TUIGroupButtonCell_Minimalist(style: .default, reuseIdentifier: "send")
            let cellData = TUIGroupButtonCellData_Minimalist()
            cellData.title = TUISwift.timCommonLocalizableString("Send")
            cellData.style = .blue
            cellData.cselector = #selector(onSend)
            cellData.textColor = UIColor.tui_color(withHex: "#147AFF")
            cell.fill(with: cellData)
            return cell
        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        addMsgTextView.endEditing(true)
    }

    @objc func onSend() {
        TUITool.makeToastActivity()
        if let groupInfo = groupInfo, let groupID = groupInfo.groupID {
            V2TIMManager.sharedInstance().joinGroup(groupID: groupID, msg: addMsgTextView.text, succ: {
                TUITool.hideToastActivity()
                self.showHud(isSuccess: true, msgText: TUISwift.timCommonLocalizableString("send_success"))
            }, fail: { code, desc in
                TUITool.hideToastActivity()
                let msg = TUITool.convertIMError(Int(code), msg: desc) ?? ""
                self.showHud(isSuccess: false, msgText: msg)
                if code == ERR_SDK_INTERFACE_NOT_SUPPORT.rawValue {
                    TUITool.postUnsupportNotification(ofService: TUISwift.timCommonLocalizableString("TUIKitErrorUnsupportIntefaceCommunity"), serviceDesc: TUISwift.timCommonLocalizableString("TUIKitErrorUnsupportIntefaceCommunityDesc"), debugOnly: true)
                }
            })
        }
    }

    func didTapOnAvatar(_ cell: TUIProfileCardCell_Minimalist) {
        let image = TUIAvatarViewController()
        image.avatarData = cell.cardData ?? TUIProfileCardCellData()
        navigationController?.pushViewController(image, animated: true)
    }

    func showHud(isSuccess: Bool, msgText: String) {
        let hudView = UIView()
        hudView.frame = CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height())
        hudView.backgroundColor = UIColor.tui_color(withHex: "#000000", alpha: 0.6)

        let msgView = UIView()
        hudView.addSubview(msgView)
        msgView.layer.masksToBounds = true
        msgView.layer.cornerRadius = TUISwift.kScale390(10)
        msgView.backgroundColor = UIColor.tui_color(withHex: "FFFFFF")

        let icon = UIImageView()
        msgView.addSubview(icon)
        icon.image = isSuccess ? UIImage.safeImage(TUISwift.tuiContactImagePath_Minimalist("contact_add_success")) : UIImage.safeImage(TUISwift.tuiContactImagePath_Minimalist("contact_add_failed"))

        let descLabel = UILabel()
        msgView.addSubview(descLabel)
        descLabel.font = UIFont.systemFont(ofSize: TUISwift.kScale390(14))
        descLabel.text = msgText
        descLabel.sizeToFit()

        icon.frame = CGRect(x: TUISwift.kScale390(12), y: TUISwift.kScale390(10), width: TUISwift.kScale390(16), height: TUISwift.kScale390(16))
        descLabel.frame = CGRect(x: icon.frame.origin.x + icon.frame.size.width + TUISwift.kScale390(8), y: TUISwift.kScale390(8), width: descLabel.frame.size.width, height: TUISwift.kScale390(20))
        msgView.frame = CGRect(x: 0, y: 0, width: descLabel.frame.origin.x + descLabel.frame.size.width + TUISwift.kScale390(12), height: TUISwift.kScale390(36))
        msgView.center = hudView.center

        TUITool.applicationKeywindow()?.tui_showToast(hudView, duration: 3.0, position: TUICSToastPositionCenter, completion: { _ in
            // Completion handler
        })
    }
}
