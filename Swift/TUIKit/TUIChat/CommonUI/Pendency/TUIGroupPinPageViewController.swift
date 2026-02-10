import ImSDK_Plus
import TIMCommon
import UIKit

class TUIGroupPinPageViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var tableview: UITableView!
    var customArrowView: UIView!
    var groupPinList: [V2TIMMessage]? = []
    var onClickRemove: ((V2TIMMessage) -> Void)?
    var onClickCellView: ((V2TIMMessage) -> Void)?
    var canRemove: Bool = false
    var bottomShadow: UIView!

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        setupViews()
        addSingleTapGesture()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // Disable implicit animations during setup
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Add bottomShadow first (bottom layer)
        bottomShadow = UIView()
        bottomShadow.backgroundColor = UIColor(white: 0, alpha: 0.5)
        bottomShadow.isUserInteractionEnabled = false
        bottomShadow.frame = .zero
        bottomShadow.alpha = 0
        view.addSubview(bottomShadow)
        
        tableview = UITableView()
        tableview.contentInset = UIEdgeInsets.zero
        tableview.delegate = self
        tableview.dataSource = self
        tableview.separatorStyle = .none
        tableview.showsVerticalScrollIndicator = false
        tableview.showsHorizontalScrollIndicator = false
        tableview.backgroundColor = TUISwift.tuiChatDynamicColor("chat_pop_group_pin_back_color", defaultColor: "#F9F9F9")
        tableview.clipsToBounds = true
        tableview.frame = .zero
        tableview.alpha = 0
        view.addSubview(tableview)
        view.bringSubviewToFront(tableview)

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 0))
        tableview.tableHeaderView = headerView

        customArrowView = UIView(frame: .zero)
        customArrowView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_pop_group_pin_back_color", defaultColor: "#F9F9F9")
        customArrowView.clipsToBounds = true
        customArrowView.alpha = 0
        view.addSubview(customArrowView)
        view.bringSubviewToFront(customArrowView)
        
        let arrowBackgroundView = UIView(frame: .zero)
        arrowBackgroundView.backgroundColor = .clear
        arrowBackgroundView.layer.cornerRadius = 5
        customArrowView.addSubview(arrowBackgroundView)
        
        let arrow = UIImageView(frame: .zero)
        arrow.image = TUISwift.tuiChatBundleThemeImage("chat_pop_group_pin_up_arrow_img", defaultImage: "chat_up_arrow_icon")
        arrowBackgroundView.addSubview(arrow)
        arrowBackgroundView.snp.makeConstraints { make in
            make.center.equalTo(customArrowView)
            make.size.equalTo(CGSize(width: 20, height: 20))
        }
        arrow.snp.makeConstraints { make in
            make.center.equalTo(arrowBackgroundView)
            make.size.equalTo(CGSize(width: 20, height: 20))
        }
        
        CATransaction.commit()
    }

    private func addSingleTapGesture() {
        view.isUserInteractionEnabled = true
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTap(_:)))
        view.addGestureRecognizer(singleTap)
    }

    @objc private func singleTap(_ tap: UITapGestureRecognizer?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.tableview.frame = CGRect(x: 0, y: self.tableview.frame.origin.y, width: self.view.frame.size.width, height: 0)
            self.tableview.alpha = 0
            self.customArrowView.frame = CGRect(x: 0, y: self.tableview.frame.maxY, width: self.view.frame.size.width, height: 0)
            self.customArrowView.alpha = 0
            self.bottomShadow.alpha = 0
        }) { finished in
            if finished {
                self.dismiss(animated: false, completion: nil)
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupPinList?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "cell"
        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as? TUIGroupPinCell
        if cell == nil {
            cell = TUIGroupPinCell(style: .default, reuseIdentifier: cellIdentifier)
        }
        cell!.backgroundColor = .systemGroupedBackground

        guard let msg = groupPinList?[indexPath.row] else { return UITableViewCell() }
        let cellData = TUIMessageDataProvider.convertToCellData(from: msg)
        cell!.fill(withData: cellData)
        cell!.cellView.removeButton.isHidden = !canRemove
        cell!.cellView.onClickRemove = { [weak self] originMessage in
            guard let self else { return }
            self.onClickRemove?(originMessage)
        }
        cell!.cellView.onClickCellView = { [weak self] originMessage in
            guard let self else { return }
            self.onClickCellView?(originMessage)
            self.singleTap(nil)
        }
        cell!.selectionStyle = .none
        return cell!
    }

    // MARK: - UITableViewDelegate

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 62
    }
}
