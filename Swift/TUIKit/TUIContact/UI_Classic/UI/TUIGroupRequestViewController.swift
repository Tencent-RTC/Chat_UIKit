import TIMCommon
import UIKit

class TUIGroupRequestViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TUIProfileCardDelegate {
    var groupInfo: V2TIMGroupInfo?
    private var tableView: UITableView!
    private var addMsgTextView: UITextView!
    private var cardCellData: TUIProfileCardCellData?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView = UITableView(frame: view.bounds, style: .grouped)
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self

        addMsgTextView = UITextView(frame: .zero)
        addMsgTextView.font = UIFont.systemFont(ofSize: 14)
        addMsgTextView.textAlignment = TUISwift.isRTL() ? .right : .left
        if let loginUser = V2TIMManager.sharedInstance().getLoginUser() {
            V2TIMManager.sharedInstance().getUsersInfo([loginUser], succ: { [weak self] infoList in
                guard let self = self, let infoList = infoList else { return }
                if let showName = infoList.first?.showName() {
                    self.addMsgTextView.text = String(format: TUISwift.timCommonLocalizableString("GroupRequestJoinGroupFormat"), showName)
                }
            }, fail: { _, _ in
                // Handle failure
            })
        }

        let data = TUIProfileCardCellData()
        data.name = groupInfo?.groupName ?? ""
        data.identifier = groupInfo?.groupID ?? ""
        data.avatarImage = TUISwift.defaultGroupAvatarImage(byGroupType: groupInfo?.groupType)
        if let faceUrl = groupInfo?.faceURL {
            data.avatarUrl = URL(string: faceUrl) ?? URL(string: "")!
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
            return 120
        case 2:
            return 54
        default:
            return 0
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 1 else { return nil }
        let view = UIView()
        view.backgroundColor = .clear

        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("please_fill_in_verification_information")
        label.textColor = UIColor(red: 136 / 255.0, green: 136 / 255.0, blue: 136 / 255.0, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 14.0)
        label.frame = CGRect(x: 10, y: 0, width: tableView.bounds.size.width - 20, height: 40)
        view.addSubview(label)

        return view
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 1:
            return 40
        case 2:
            return 10
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
            let cell = TUIProfileCardCell(style: .default, reuseIdentifier: "TPersonalCommonCell_ReuseId")
            cell.delegate = self
            if let cardData = cardCellData {
                cell.fill(with: cardData)
            }
            return cell
        case 1:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "AddWord")
            cell.contentView.addSubview(addMsgTextView)
            addMsgTextView.mm_width(TUISwift.screen_Width()).mm_height(120)
            return cell
        case 2:
            let cell = TUIButtonCell(style: .default, reuseIdentifier: "send")
            let cellData = TUIButtonCellData()
            cellData.title = TUISwift.timCommonLocalizableString("Send")
            cellData.style = .white
            cellData.cselector = #selector(onSend)
            cellData.textColor = UIColor(red: 20 / 255.0, green: 122 / 255.0, blue: 255 / 255.0, alpha: 1.0)
            cell.fill(with: cellData)
            return cell
        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    @objc func onSend() {
        TUITool.makeToastActivity()
        V2TIMManager.sharedInstance().joinGroup(groupID: groupInfo?.groupID ?? "", msg: addMsgTextView.text, succ: {
            TUITool.hideToastActivity()
            TUITool.makeToast(TUISwift.timCommonLocalizableString("send_success"), duration: 3.0, idposition: TUICSToastPositionBottom)
        }, fail: { code, desc in
            TUITool.hideToastActivity()
            TUITool.makeToastError(Int(code), msg: desc)
            if code == ERR_SDK_INTERFACE_NOT_SUPPORT.rawValue {
                TUITool.postUnsupportNotification(ofService: TUISwift.timCommonLocalizableString("TUIKitErrorUnsupportIntefaceCommunity"), serviceDesc: TUISwift.timCommonLocalizableString("TUIKitErrorUnsupportIntefaceCommunityDesc"), debugOnly: true)
            }
        })
    }

    func didTap(onAvatar cell: TUIProfileCardCell) {
        let image = TUIAvatarViewController()
        image.avatarData = cell.cardData
        navigationController?.pushViewController(image, animated: true)
    }
}
