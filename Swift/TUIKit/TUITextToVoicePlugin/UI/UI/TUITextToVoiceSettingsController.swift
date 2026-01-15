import SnapKit
import TIMCommon
import UIKit

/// Text-to-Voice settings main page controller (TUITextToVoicePlugin)
class TUITextToVoiceSettingsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Properties
    
    /// Conversation ID for per-conversation settings. If nil, shows global settings.
    var conversationID: String?
    
    private enum Section: Int, CaseIterable {
        case settings = 0
        case voiceSelection
    }
    
    private enum SettingItem: Int, CaseIterable {
        case autoTextToVoice = 0
        case voiceSelection
    }
    
    private enum VoiceSelectionItem: Int, CaseIterable {
        case voiceClone = 0
        case voiceList
    }
    
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
        tableView.register(VoiceMessageOptionCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(VoiceSelectionCell.self, forCellReuseIdentifier: "selectionCell")
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
        // Reload to update selected voice display
        tableView.reloadData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = TUISwift.timCommonLocalizableString("TextToVoiceSettings")
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        view.addSubview(tableView)
    }
    
    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - UITableView DataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        switch sectionType {
        case .settings:
            // Show voice selection in settings section only for conversation-level settings
            return conversationID != nil ? SettingItem.allCases.count : (SettingItem.allCases.count - 1)
        case .voiceSelection:
            return VoiceSelectionItem.allCases.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch sectionType {
        case .settings:
            return configureSettingCell(for: indexPath)
        case .voiceSelection:
            return configureVoiceSelectionCell(for: indexPath)
        }
    }
    
    private func configureSettingCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let item = SettingItem(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        // Voice selection uses selection cell style
        if item == .voiceSelection {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath) as? VoiceSelectionCell else {
                return UITableViewCell()
            }
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("VoiceSelection")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("VoiceSelectionDescription")
            cell.detailLabel.text = getDisplayVoiceName()
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as? VoiceMessageOptionCell else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .none
        cell.switchControl.tag = indexPath.row
        cell.switchControl.removeTarget(nil, action: nil, for: .valueChanged)
        cell.switchControl.addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
        cell.switchControl.isHidden = false
        cell.accessoryType = .none
        
        switch item {
        case .autoTextToVoice:
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("AutoTextToVoice")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("AutoTextToVoiceDescription")
            cell.switchControl.isOn = getSettingValue(for: .autoTextToVoice)
        case .voiceSelection:
            break
        }
        
        return cell
    }
    
    /// Get setting value considering conversation-level override
    private func getSettingValue(for type: TUITextToVoiceSettingType) -> Bool {
        if let convID = conversationID {
            // Conversation-level setting
            if let setting = TUITextToVoiceConversationConfig.shared.getSetting(for: convID, type: type) {
                return setting.boolValue
            }
        }
        // Global setting
        switch type {
        case .autoTextToVoice:
            return TUITextToVoiceConfig.shared.autoTextToVoiceEnabled
        }
    }
    
    /// Get display voice name considering conversation-level override
    private func getDisplayVoiceName() -> String {
        if let convID = conversationID {
            return TUITextToVoiceConversationConfig.shared.getDisplayVoiceName(for: convID)
        }
        return TUITextToVoiceConfig.shared.getSelectedVoiceDisplayName()
    }
    
    private func configureVoiceSelectionCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath) as? VoiceSelectionCell,
              let item = VoiceSelectionItem(rawValue: indexPath.row) else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator
        
        switch item {
        case .voiceClone:
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("VoiceClone")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("VoiceCloneDescription")
            cell.detailLabel.text = ""
        case .voiceList:
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("VoiceSelection")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("VoiceSelectionDescription")
            cell.detailLabel.text = TUITextToVoiceConfig.shared.getSelectedVoiceDisplayName()
        }
        
        return cell
    }
    
    // MARK: - UITableView Delegate
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionType = Section(rawValue: section) else { return 4 }
        switch sectionType {
        case .settings:
            return 4
        case .voiceSelection:
            return 32
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = Section(rawValue: section) else {
            return nil
        }
        
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        if sectionType == .voiceSelection {
            let label = UILabel()
            label.text = TUISwift.timCommonLocalizableString("VoiceSettings")
            label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
            headerView.addSubview(label)
            label.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(16)
                make.bottom.equalToSuperview().offset(-4)
            }
        }
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        
        if sectionType == .settings {
            guard let item = SettingItem(rawValue: indexPath.row) else { return }
            if item == .voiceSelection {
                let voiceListVC = TUIVoiceListController()
                voiceListVC.conversationID = conversationID
                navigationController?.pushViewController(voiceListVC, animated: true)
            }
        } else if sectionType == .voiceSelection {
            guard let item = VoiceSelectionItem(rawValue: indexPath.row) else { return }
            
            switch item {
            case .voiceClone:
                let voiceCloneVC = TUIVoiceCloneController()
                navigationController?.pushViewController(voiceCloneVC, animated: true)
            case .voiceList:
                let voiceListVC = TUIVoiceListController()
                navigationController?.pushViewController(voiceListVC, animated: true)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func switchValueChanged(_ sender: UISwitch) {
        guard let item = SettingItem(rawValue: sender.tag) else { return }
        
        if let convID = conversationID {
            // Conversation-level setting
            let type: TUITextToVoiceSettingType
            switch item {
            case .autoTextToVoice:
                type = .autoTextToVoice
            case .voiceSelection:
                return
            }
            TUITextToVoiceConversationConfig.shared.setSetting(sender.isOn, for: convID, type: type)
        } else {
            // Global setting
            switch item {
            case .autoTextToVoice:
                TUITextToVoiceConfig.shared.autoTextToVoiceEnabled = sender.isOn
            case .voiceSelection:
                break
            }
        }
    }
}

// MARK: - VoiceMessageOptionCell

/// Custom cell with title, description and switch control
private class VoiceMessageOptionCell: UITableViewCell {
    
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

// MARK: - VoiceSelectionCell

/// Custom cell with title, description and detail label
private class VoiceSelectionCell: UITableViewCell {
    
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
    
    let detailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.textAlignment = .right
        return label
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
        contentView.addSubview(detailLabel)
        
        detailLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-8)
            make.width.lessThanOrEqualTo(120)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(detailLabel.snp.leading).offset(-12)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(detailLabel.snp.leading).offset(-12)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
}
