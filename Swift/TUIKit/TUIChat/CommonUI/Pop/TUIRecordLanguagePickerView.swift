import UIKit
import TIMCommon
import SnapKit

/// A lightweight bottom-sheet language picker used by the record-transcription
/// translation flow. It is added on top of the record overlay (which lives in
/// the key window), so it does not require a presenting view controller.
public final class TUIRecordLanguagePickerView: UIView {
    // MARK: - Layout

    private enum Layout {
        static let sheetCornerRadius: CGFloat = 16
        static let rowHeight: CGFloat = 52
        static let titleHeight: CGFloat = 52
        static let maxSheetHeightRatio: CGFloat = 0.6
        static let animationDuration: TimeInterval = 0.25
        static let separatorHeight: CGFloat = 1 / UIScreen.main.scale
        static let separatorAlpha: CGFloat = 0.3
        static let titleHorizontalPadding: CGFloat = 16
    }

    // MARK: - Public

    public var onSelected: ((TUIVoiceRecordLanguage) -> Void)?

    // MARK: - Private State

    private let languages: [TUIVoiceRecordLanguage]
    private let selectedCode: String?

    private let dimmingView = UIView()
    private let sheetView = UIView()
    private let tableView = UITableView()
    private var sheetBottomConstraint: Constraint?

    // MARK: - Init

    public init(languages: [TUIVoiceRecordLanguage], selectedCode: String?) {
        self.languages = languages
        self.selectedCode = selectedCode
        super.init(frame: .zero)
        setupSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupSubviews() {
        setupDimmingView()
        setupSheetView()
        setupTitle()
        setupTableView()
    }

    private func setupDimmingView() {
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimmingView.alpha = 0
        addSubview(dimmingView)
        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDimmingTap))
        dimmingView.addGestureRecognizer(tap)
    }

    private func setupSheetView() {
        sheetView.backgroundColor = .systemBackground
        sheetView.layer.cornerRadius = Layout.sheetCornerRadius
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.clipsToBounds = true
        addSubview(sheetView)

        let rowsHeight = CGFloat(languages.count) * Layout.rowHeight + Layout.titleHeight
        let maxHeight = UIScreen.main.bounds.height * Layout.maxSheetHeightRatio
        let sheetHeight = min(rowsHeight, maxHeight)

        sheetView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(sheetHeight)
            sheetBottomConstraint = make.top.equalTo(self.snp.bottom).constraint
        }
    }

    private func setupTitle() {
        let titleLabel = UILabel()
        titleLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputSelectLanguage")
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        sheetView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(Layout.titleHorizontalPadding)
            make.trailing.equalToSuperview().offset(-Layout.titleHorizontalPadding)
            make.height.equalTo(Layout.titleHeight)
        }

        let separator = UIView()
        separator.backgroundColor = UIColor.separator.withAlphaComponent(Layout.separatorAlpha)
        sheetView.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Layout.separatorHeight)
        }
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = Layout.rowHeight
        tableView.separatorInset = .zero
        tableView.tableFooterView = UIView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TUIRecordLanguageCell")
        sheetView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Layout.titleHeight)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - Show / Dismiss

    public func show(in parentView: UIView) {
        frame = parentView.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        parentView.addSubview(self)
        layoutIfNeeded()

        sheetBottomConstraint?.update(offset: -sheetView.bounds.height)
        UIView.animate(withDuration: Layout.animationDuration) {
            self.dimmingView.alpha = 1
            self.layoutIfNeeded()
        }
    }

    private func dismiss(completion: (() -> Void)? = nil) {
        sheetBottomConstraint?.update(offset: 0)
        UIView.animate(withDuration: Layout.animationDuration, animations: {
            self.dimmingView.alpha = 0
            self.layoutIfNeeded()
        }, completion: { _ in
            self.removeFromSuperview()
            completion?()
        })
    }

    @objc private func handleDimmingTap() {
        dismiss()
    }
}

// MARK: - UITableViewDataSource & Delegate

extension TUIRecordLanguagePickerView: UITableViewDataSource, UITableViewDelegate {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TUIRecordLanguageCell", for: indexPath)
        let language = languages[indexPath.row]
        cell.textLabel?.text = language.name
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        cell.accessoryType = (language.code == selectedCode) ? .checkmark : .none
        cell.selectionStyle = .default
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let language = languages[indexPath.row]
        dismiss { [weak self] in
            self?.onSelected?(language)
        }
    }
}
