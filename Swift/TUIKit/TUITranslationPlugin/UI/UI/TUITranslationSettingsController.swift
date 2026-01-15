import SnapKit
import TIMCommon
import UIKit

/// Translation settings main page controller
class TUITranslationSettingsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Section Definition
    
    private enum SettingsSection: Int, CaseIterable {
        case language
        case options
        
        var title: String? {
            switch self {
            case .language:
                return nil
            case .options:
                return nil
            }
        }
    }
    
    private enum SettingsRow {
        case targetLanguage
        case autoTranslate
        case showBilingual
        
        var title: String {
            switch self {
            case .targetLanguage:
                return TUISwift.timCommonLocalizableString("TranslateMessage")
            case .autoTranslate:
                return TUISwift.timCommonLocalizableString("AutoTranslateReceivedMessages")
            case .showBilingual:
                return TUISwift.timCommonLocalizableString("ShowBilingual")
            }
        }
    }
    
    // MARK: - Properties
    
    private var languageCellData: TUICommonTextCellData?
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delaysContentTouches = false
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        tableView.register(TUICommonTextCell.self, forCellReuseIdentifier: "textCell")
        tableView.register(TranslationOptionCell.self, forCellReuseIdentifier: "switchCell")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        return tableView
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLanguageCell()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = TUISwift.timCommonLocalizableString("TranslationSettings")
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func updateLanguageCell() {
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
    }
    
    // MARK: - UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingsSection = SettingsSection(rawValue: section) else {
            return 0
        }
        
        switch settingsSection {
        case .language:
            return 1
        case .options:
            return 2
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let settingsSection = SettingsSection(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch settingsSection {
        case .language:
            return createLanguageCell(for: indexPath)
        case .options:
            return createOptionCell(for: indexPath)
        }
    }
    
    private func createLanguageCell(for indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "languageRowCell")
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        
        let currentLanguage = TUITranslationConfig.shared.targetLanguageName ?? TUISwift.timCommonLocalizableString("TranslateMessage")
        
        // Create UIKit language row view
        let languageRowView = TUITranslationLanguageRow()
        languageRowView.translatesAutoresizingMaskIntoConstraints = false
        languageRowView.titleLabel.text = TUISwift.timCommonLocalizableString("TranslateMessage")
        languageRowView.descriptionLabel.text = TUISwift.timCommonLocalizableString("TUITranslationLanguageDescription")

        languageRowView.currentLanguage = currentLanguage
        languageRowView.onTap = { [weak self] in
            self?.navigateToLanguageSelection()
        }
        
        cell.contentView.addSubview(languageRowView)
        
        languageRowView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        return cell
    }
    
    private func createOptionCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as? TranslationOptionCell else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .none
        cell.switchControl.tag = indexPath.row
        cell.switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        
        switch indexPath.row {
        case 0:
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("AutoTranslateReceivedMessages")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("AutoTranslateDescription")
            cell.switchControl.isOn = TUITranslationConfig.shared.autoTranslateEnabled
        case 1:
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("ShowBilingual")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("ShowBilingualDescription")
            cell.switchControl.isOn = TUITranslationConfig.shared.showBilingualEnabled
        default:
            break
        }
        
        return cell
    }
    
    // MARK: - UITableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let settingsSection = SettingsSection(rawValue: indexPath.section) else {
            return
        }
        
        switch settingsSection {
        case .language:
            navigateToLanguageSelection()
        case .options:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 4
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    // MARK: - Navigation
    
    private func navigateToLanguageSelection() {
        let languageVC = TUITranslationLanguageController()
        languageVC.onSelectedLanguage = { [weak self] languageName in
            self?.languageCellData?.value = languageName
        }
        navigationController?.pushViewController(languageVC, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func switchValueChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 0:
            TUITranslationConfig.shared.autoTranslateEnabled = sender.isOn
            print("Auto Translate: \(sender.isOn)")
        case 1:
            TUITranslationConfig.shared.showBilingualEnabled = sender.isOn
            print("Show Bilingual: \(sender.isOn)")
        default:
            break
        }
    }
}

// MARK: - TranslationOptionCell

/// Custom cell with title, description and switch control
private class TranslationOptionCell: UITableViewCell {
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        return label
    }()
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.numberOfLines = 0
        return label
    }()
    
    let switchControl: UISwitch = {
        let switchControl = UISwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.onTintColor = TUISwift.timCommonDynamicColor("common_switch_on_color", defaultColor: "#147AFF")
        return switchControl
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(switchControl)
        
        switchControl.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(switchControl.snp.leading).offset(-12)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(switchControl.snp.leading).offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
}
