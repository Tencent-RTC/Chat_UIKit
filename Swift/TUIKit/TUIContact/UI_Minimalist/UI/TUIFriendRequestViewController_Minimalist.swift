//  TUIFriendRequestViewController_Minimalist.swift
//  TUIContact

import TIMCommon
import UIKit

class TUIFriendRequestViewController_Minimalist: UIViewController, UITableViewDataSource, UITableViewDelegate, TUIContactProfileCardDelegate, TUIFloatSubViewControllerProtocol {
    var floatDataSourceChanged: (([Any]) -> Void)?
    
    var profile: V2TIMUserFullInfo?
    var tableView: UITableView!
    var addWordTextView: UITextView!
    var nickTextField: UITextField!
    var keyboardShown = false
    var cardCellData: TUICommonContactProfileCardCellData?
    var singleSwitchData: TUICommonContactSwitchCellData?
    var titleView: TUINaviBarIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView = UITableView(frame: .zero, style: .plain)
        view.addSubview(tableView)
        tableView.frame = view.frame
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorInset = UIEdgeInsets.zero
        tableView.separatorStyle = .none
        tableView.backgroundColor = .white
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        addWordTextView = UITextView(frame: .zero)
        addWordTextView.font = UIFont.systemFont(ofSize: 14)
        addWordTextView.backgroundColor = UIColor.tui_color(withHex: "#F9F9F9")
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.firstLineHeadIndent = TUISwift.kScale390(12.5)
        paragraphStyle.alignment = TUISwift.isRTL() ? .right : .left

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: TUISwift.kScale390(16)),
            .paragraphStyle: paragraphStyle
        ]
        if let selfUserID: String = V2TIMManager.sharedInstance().getLoginUser() {
//           V2TIMManager.sharedInstance().getUsersInfo([selfUserID]) { (infoList: [V2TIMUserFullInfo]?) in
//                if let userInfo = infoList?.first {
//                    let text = String(format: TUISwift.timCommonLocalizableString("FriendRequestFormat"), userInfo.nickName ?? userInfo.userID)
//                    self.addWordTextView.attributedText = NSAttributedString(string: text, attributes: attributes)
//                }
//            } fail: { _, _ in
//                // Handle failure
//            }
        }

        nickTextField = UITextField(frame: .zero)
        nickTextField.textAlignment = TUISwift.isRTL() ? .left : .right

        titleView = TUINaviBarIndicatorView()
        titleView.setTitle(TUISwift.timCommonLocalizableString("FriendRequestFillInfo"))
        navigationItem.titleView = titleView
        navigationItem.title = ""

        let data = TUICommonContactProfileCardCellData()
        data.name = profile?.showName()
        data.genderString = profile?.showGender()
        data.identifier = profile?.userID
        data.signature = profile?.showSignature()
        data.avatarImage = TUISwift.defaultAvatarImage()
        data.avatarUrl = URL(string: profile?.faceURL ?? "")
        data.showSignature = true
        cardCellData = data

        singleSwitchData = TUICommonContactSwitchCellData()
        singleSwitchData?.title = TUISwift.timCommonLocalizableString("FriendOneWay")

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil) { [weak self] notification in
            guard let self = self, !self.keyboardShown else { return }
            self.keyboardShown = true
            self.adjustContentOffsetDuringKeyboardAppear(true, with: notification)
        }

        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil) { [weak self] notification in
            guard let self = self, self.keyboardShown else { return }
            self.keyboardShown = false
            self.adjustContentOffsetDuringKeyboardAppear(false, with: notification)
        }
    }

    // MARK: - Keyboard

    func adjustContentOffsetDuringKeyboardAppear(_ appear: Bool, with notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
              let keyboardEndFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }

        let keyboardHeight = keyboardEndFrame.height
        var contentSize = tableView.contentSize
        contentSize.height += appear ? -keyboardHeight : keyboardHeight

        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: UInt(curveValue))) {
            self.tableView.contentSize = contentSize
            self.view.layoutIfNeeded()
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return cardCellData?.height(ofWidth: TUISwift.screen_Width()) ?? 0
        }
        if indexPath.section == 1 {
            return 120
        }
        return 44
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.textColor = UIColor.tui_color(withHex: "#000000")
        label.font = UIFont.systemFont(ofSize: 14.0)
        if section == 1 {
            label.text = "  " + TUISwift.timCommonLocalizableString("please_fill_in_verification_information")
        } else if section == 2 {
            label.text = "  " + TUISwift.timCommonLocalizableString("please_fill_in_remarks_group_info")
        }
        return label
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 38
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = TUICommonContactProfileCardCell(style: .default, reuseIdentifier: "TPersonalCommonCell_ReuseId")
            cell.delegate = self
            if let cardCellData = cardCellData {
                cell.fill(with: cardCellData)
            }
            return cell
        } else if indexPath.section == 1 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "AddWord")
            cell.contentView.addSubview(addWordTextView)
            addWordTextView.frame = CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: 120)
            return cell
        } else if indexPath.section == 2 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "NickName")
            cell.textLabel?.text = TUISwift.timCommonLocalizableString("Alia")
            cell.contentView.addSubview(nickTextField)

            let separator = UIView()
            separator.backgroundColor = .groupTableViewBackground
            cell.contentView.addSubview(separator)
            separator.frame = CGRect(x: 0, y: cell.contentView.frame.height - 1, width: tableView.frame.width, height: 1)

            nickTextField.frame = CGRect(x: cell.contentView.frame.width / 2, y: 0, width: cell.contentView.frame.width / 2 - 20, height: cell.contentView.frame.height)
            nickTextField.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]

            return cell
        } else if indexPath.section == 3 {
            let cell = TUIContactButtonCell_Minimalist(style: .default, reuseIdentifier: "send")
            let data = TUIContactButtonCellData_Minimalist()
            data.style = .blue
            data.title = TUISwift.timCommonLocalizableString("Send")
            data.cselector = #selector(onSend)
            data.textColor = TUISwift.timCommonDynamicColor("primary_theme_color", defaultColor: "147AFF")
            cell.fill(with: data)

            return cell
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    @objc func onSend() {
        view.endEditing(true)
        TUITool.makeToastActivity()

        let application = V2TIMFriendAddApplication()
        application.addWording = addWordTextView.text
        application.friendRemark = nickTextField.text
        application.userID = profile?.userID ?? ""
        application.addSource = "iOS"
        application.addType = (singleSwitchData?.isOn == true ? .FRIEND_TYPE_SINGLE : .FRIEND_TYPE_BOTH)

        V2TIMManager.sharedInstance().addFriend(application: application) { result in
            guard let result = result else { return }
            var msg: String?
            var isSuccessFlag = false
            if result.resultCode == ERR_SUCC.rawValue {
                msg = TUISwift.timCommonLocalizableString("FriendAddResultSuccess")
                isSuccessFlag = true
            } else if result.resultCode == ERR_SVR_FRIENDSHIP_INVALID_PARAMETERS.rawValue, result.resultInfo == "Err_SNS_FriendAdd_Friend_Exist" {
                msg = TUISwift.timCommonLocalizableString("FriendAddResultExists")
            } else {
                if result.resultCode == ERR_SVR_FRIENDSHIP_ALLOW_TYPE_NEED_CONFIRM.rawValue {
                    isSuccessFlag = true
                }
                msg = TUITool.convertIMError(result.resultCode, msg: result.resultInfo)
            }

            if msg?.isEmpty ?? true {
                msg = "\(result.resultCode)"
            }

            TUITool.hideToastActivity()
            self.showHud(isSuccessFlag, msgText: msg ?? "")
        } fail: { code, desc in
            TUITool.hideToastActivity()
            TUITool.makeToastError(Int(code), msg: desc)
        }
    }

    func showHud(_ isSuccess: Bool, msgText: String) {
        let hudView = UIView(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height()))
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
        descLabel.numberOfLines = 0
        descLabel.sizeToFit()

        icon.snp.remakeConstraints { make in
            make.leading.equalTo(TUISwift.kScale390(12))
            make.top.equalTo(TUISwift.kScale390(10))
            make.width.height.equalTo(TUISwift.kScale390(16))
        }
        descLabel.snp.remakeConstraints { make in
            make.leading.equalTo(icon.snp.trailing).offset(TUISwift.kScale390(8))
            make.top.equalTo(TUISwift.kScale390(10))
            make.bottom.equalTo(msgView).offset(-TUISwift.kScale390(10))
            make.trailing.equalTo(msgView)
        }
        msgView.snp.remakeConstraints { make in
            make.center.equalTo(hudView)
            make.width.lessThanOrEqualTo(hudView)
        }

        TUITool.applicationKeywindow()?.tui_showToast(hudView, duration: 3.0, position: TUICSToastPositionCenter, completion: nil)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }

    func didTapOnAvatar(cell: TUICommonContactProfileCardCell) {
        let image = TUIContactAvatarViewController_Minimalist()
        image.avatarData = cell.cardData as! TUICommonContactProfileCardCellData_Minimalist
        navigationController?.pushViewController(image, animated: true)
    }
}
