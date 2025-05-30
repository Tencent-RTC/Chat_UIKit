//  Created by Tencent on 2023/06/09.
//  Copyright © 2023 Tencent. All rights reserved.

import UIKit
import TIMCommon

/**
 * 【Module name】The interface that displays the received friend request (TUINewFriendViewController)
 * 【Function description】Responsible for pulling friend application information and displaying it in the interface.
 *  Through this interface, you can view the friend requests you have received, and perform the operations of agreeing/rejecting the application.
 */
class TUINewFriendViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var cellClickBlock: ((TUICommonPendencyCell) -> Void)?

    private let tableView = UITableView()
    private let moreBtn = UIButton(type: .system)
    private let viewModel = TUINewFriendViewDataProvider()
    private var dataListObservation: NSKeyValueObservation?
    
    private lazy var noDataTipsLabel: UILabel = {
        let label = UILabel()
        label.textColor = TUISwift.timCommonDynamicColor("nodata_tips_color", defaultColor: "#999999")
        label.font = UIFont.systemFont(ofSize: 14.0)
        label.textAlignment = .center
        label.text = TUISwift.timCommonLocalizableString("TUIKitContactNoNewApplicationRequest")
        return label
    }()
    
    deinit {
        dataListObservation = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let titleLabel = UILabel()
        titleLabel.text = TUISwift.timCommonLocalizableString("TUIKitContactsNewFriends")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17.0)
        titleLabel.textColor = TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000")
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel

        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")

        tableView.frame = view.bounds
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TUICommonPendencyCell.self, forCellReuseIdentifier: "PendencyCell")
        tableView.allowsMultipleSelectionDuringEditing = false
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 94, bottom: 0, right: 0)
        tableView.backgroundColor = view.backgroundColor

        moreBtn.frame.size.height = 20
        tableView.tableFooterView = moreBtn
        moreBtn.isHidden = true

        dataListObservation = viewModel.observe(\.dataList, options: [.new, .initial]) { [weak self] (data, change) in
            guard let self = self, let _ = change.newValue else { return }
            self.tableView.reloadData()
        }

        noDataTipsLabel.frame = CGRect(x: 10, y: 60, width: view.bounds.size.width - 20, height: 40)
        tableView.addSubview(noDataTipsLabel)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }

    private func loadData() {
        viewModel.loadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        noDataTipsLabel.isHidden = (viewModel.dataList.count != 0)
        return viewModel.dataList.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 20
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PendencyCell", for: indexPath) as? TUICommonPendencyCell else {
            return UITableViewCell()
        }
        let data = viewModel.dataList[indexPath.row]
        data.cselector = #selector(cellClick(_:))
        data.cbuttonSelector = #selector(btnClick(_:))
        data.cRejectButtonSelector = #selector(rejectBtnClick(_:))
        cell.selectionStyle = .none
        cell.fill(with: data)
        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            tableView.beginUpdates()
            let data = viewModel.dataList[indexPath.row]
            viewModel.removeData(data)
            tableView.deleteRows(at: [indexPath], with: .fade)
            tableView.endUpdates()
        }
    }

    @objc private func btnClick(_ cell: TUICommonPendencyCell) {
        if let pendencyData = cell.pendencyData {
            viewModel.agreeData(pendencyData)
        }
        tableView.reloadData()
    }

    @objc private func rejectBtnClick(_ cell: TUICommonPendencyCell) {
        if let pendencyData = cell.pendencyData {
            viewModel.rejectData(pendencyData)
        }
        tableView.reloadData()
    }

    @objc private func cellClick(_ cell: TUICommonPendencyCell) {
        cellClickBlock?(cell)
    }
}
