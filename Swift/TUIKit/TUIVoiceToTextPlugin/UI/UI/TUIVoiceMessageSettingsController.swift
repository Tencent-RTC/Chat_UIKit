import Foundation
import SnapKit
import TIMCommon
import TUICore
import UIKit

/// Unified voice message settings page controller (TUIVoiceToTextPlugin)
/// Provides global settings for:
/// - Auto play voice messages (VoiceToText)
/// - Auto voice-to-text conversion (VoiceToText)
/// - Auto text-to-voice conversion (TextToVoice - via TUICore extension)
/// - Voice selection (TextToVoice - via TUICore extension)
/// - Voice clone (TextToVoice - via TUICore extension)
class TUIVoiceMessageSettingsController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - Section Types
    
    private enum Section: Int, CaseIterable {
        case voiceToText = 0      // Voice message settings (auto play, auto voice-to-text)
        case textToVoice          // TTS settings (auto text-to-voice)
        case voiceSelection       // Voice clone and selection
    }
    
    // MARK: - Setting Items
    
    private enum VoiceToTextItem: Int, CaseIterable {
        case autoPlayVoice = 0
        case autoVoiceToText
    }
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        tableView.register(VoiceSettingSwitchCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(VoiceSettingSelectionCell.self, forCellReuseIdentifier: "selectionCell")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        return tableView
    }()
    
    // MARK: - Properties
    
    /// Conversation ID for per-conversation settings. If nil, shows global settings.
    var conversationID: String?
    
    /// TTS settings items fetched from TUITextToVoicePlugin via TUICore
    private var ttsSettingsItems: [[String: Any]] = []
    
    /// Voice selection items fetched from TUITextToVoicePlugin via TUICore
    private var voiceSelectionItems: [[String: Any]] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchTTSSettings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh TTS settings and reload table
        fetchTTSSettings()
        tableView.reloadData()
    }
    
    private func setupUI() {
        title = TUISwift.timCommonLocalizableString("VoiceMessageSettings")
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    /// Fetch TTS settings from TUITextToVoicePlugin via TUICore service
    private func fetchTTSSettings() {
        // Call TUITextToVoicePlugin service to get settings items
        let param: [String: Any] = conversationID != nil ? ["conversationID": conversationID!] : [:]
        
        if let result = TUICore.callService(
            "TUICore_TUITextToVoiceService",
            method: "TUICore_TUITextToVoiceService_GetGlobalSettingsMethod",
            param: param
        ) as? [String: Any] {
            ttsSettingsItems = result["settingsItems"] as? [[String: Any]] ?? []
            voiceSelectionItems = result["voiceSelectionItems"] as? [[String: Any]] ?? []
        } else {
            ttsSettingsItems = []
            voiceSelectionItems = []
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // If no TTS plugin, only show voiceToText section
        if ttsSettingsItems.isEmpty && voiceSelectionItems.isEmpty {
            return 1
        }
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .voiceToText:
            return VoiceToTextItem.allCases.count
        case .textToVoice:
            return ttsSettingsItems.count
        case .voiceSelection:
            return voiceSelectionItems.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch sectionType {
        case .voiceToText:
            return configureVoiceToTextCell(for: indexPath)
        case .textToVoice:
            return configureTTSSettingCell(for: indexPath)
        case .voiceSelection:
            return configureVoiceSelectionCell(for: indexPath)
        }
    }
    
    // MARK: - Cell Configuration
    
    private func configureVoiceToTextCell(for indexPath: IndexPath) -> UITableViewCell {
        guard let item = VoiceToTextItem(rawValue: indexPath.row),
              let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as? VoiceSettingSwitchCell
        else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .none
        cell.switchControl.tag = indexPath.row
        cell.switchControl.removeTarget(nil, action: nil, for: .valueChanged)
        cell.switchControl.addTarget(self, action: #selector(voiceToTextSwitchChanged(_:)), for: .valueChanged)
        
        switch item {
        case .autoPlayVoice:
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("AutoPlayVoice")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("AutoPlayVoiceDescription")
            cell.switchControl.isOn = getVoiceToTextSettingValue(for: .autoPlayVoice)
        case .autoVoiceToText:
            cell.titleLabel.text = TUISwift.timCommonLocalizableString("AutoVoiceToText")
            cell.descriptionLabel.text = TUISwift.timCommonLocalizableString("AutoVoiceToTextDescription")
            cell.switchControl.isOn = getVoiceToTextSettingValue(for: .autoVoiceToText)
        }
        
        return cell
    }
    
    private func configureTTSSettingCell(for indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < ttsSettingsItems.count else { return UITableViewCell() }
        
        let itemData = ttsSettingsItems[indexPath.row]
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as? VoiceSettingSwitchCell else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .none
        cell.titleLabel.text = itemData["title"] as? String ?? ""
        cell.descriptionLabel.text = itemData["description"] as? String ?? ""
        cell.switchControl.isOn = itemData["isOn"] as? Bool ?? false
        cell.switchControl.tag = indexPath.row + 1000 // Offset to distinguish from voiceToText items
        cell.switchControl.removeTarget(nil, action: nil, for: .valueChanged)
        cell.switchControl.addTarget(self, action: #selector(ttsSwitchChanged(_:)), for: .valueChanged)
        
        return cell
    }
    
    private func configureVoiceSelectionCell(for indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < voiceSelectionItems.count else { return UITableViewCell() }
        
        let itemData = voiceSelectionItems[indexPath.row]
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "selectionCell", for: indexPath) as? VoiceSettingSelectionCell else {
            return UITableViewCell()
        }
        
        cell.selectionStyle = .default
        cell.accessoryType = .disclosureIndicator
        cell.titleLabel.text = itemData["title"] as? String ?? ""
        cell.descriptionLabel.text = itemData["description"] as? String ?? ""
        cell.detailLabel.text = itemData["detailText"] as? String ?? ""
        
        return cell
    }
    
    // MARK: - Section Headers
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionType = Section(rawValue: section) else { return 4 }
        switch sectionType {
        case .voiceToText:
            return 4
        case .textToVoice:
            return ttsSettingsItems.isEmpty ? 0.01 : 32
        case .voiceSelection:
            return voiceSelectionItems.isEmpty ? 0.01 : 32
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        var headerTitle: String?
        switch sectionType {
        case .voiceToText:
            headerTitle = nil
        case .textToVoice:
            headerTitle = ttsSettingsItems.isEmpty ? nil : TUISwift.timCommonLocalizableString("TextToVoiceSettings")
        case .voiceSelection:
            headerTitle = voiceSelectionItems.isEmpty ? nil : TUISwift.timCommonLocalizableString("VoiceSettings")
        }
        
        if let title = headerTitle {
            let label = UILabel()
            label.text = title
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
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        
        if sectionType == .voiceSelection, indexPath.row < voiceSelectionItems.count {
            let itemData = voiceSelectionItems[indexPath.row]
            
            // Call TUITextToVoicePlugin to handle navigation
            var param: [String: Any] = [
                "itemType": itemData["itemType"] as? String ?? "",
                "navigationController": navigationController as Any
            ]
            if let convID = conversationID {
                param["conversationID"] = convID
            }
            
            TUICore.callService(
                "TUICore_TUITextToVoiceService",
                method: "TUICore_TUITextToVoiceService_NavigateToSettingMethod",
                param: param
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func getVoiceToTextSettingValue(for type: TUIVoiceMessageSettingType) -> Bool {
        if let convID = conversationID {
            if let setting = TUIVoiceMessageConversationConfig.shared.getSetting(for: convID, type: type) {
                return setting.boolValue
            }
        }
        switch type {
        case .autoPlayVoice:
            return TUIVoiceToTextConfig.shared.autoPlayVoiceEnabled
        case .autoVoiceToText:
            return TUIVoiceToTextConfig.shared.autoVoiceToTextEnabled
        }
    }
    
    @objc private func voiceToTextSwitchChanged(_ sender: UISwitch) {
        guard let item = VoiceToTextItem(rawValue: sender.tag) else { return }
        
        if let convID = conversationID {
            let type: TUIVoiceMessageSettingType
            switch item {
            case .autoPlayVoice:
                type = .autoPlayVoice
            case .autoVoiceToText:
                type = .autoVoiceToText
            }
            TUIVoiceMessageConversationConfig.shared.setSetting(sender.isOn, for: convID, type: type)
        } else {
            switch item {
            case .autoPlayVoice:
                TUIVoiceToTextConfig.shared.autoPlayVoiceEnabled = sender.isOn
            case .autoVoiceToText:
                TUIVoiceToTextConfig.shared.autoVoiceToTextEnabled = sender.isOn
            }
        }
    }
    
    @objc private func ttsSwitchChanged(_ sender: UISwitch) {
        let index = sender.tag - 1000
        guard index >= 0, index < ttsSettingsItems.count else { return }
        
        let itemData = ttsSettingsItems[index]
        
        // Call TUITextToVoicePlugin to update setting
        var param: [String: Any] = [
            "settingType": itemData["settingType"] as? String ?? "",
            "value": sender.isOn
        ]
        if let convID = conversationID {
            param["conversationID"] = convID
        }
        
        TUICore.callService(
            "TUICore_TUITextToVoiceService",
            method: "TUICore_TUITextToVoiceService_UpdateSettingMethod",
            param: param
        )
    }
}

// MARK: - VoiceSettingSwitchCell

private class VoiceSettingSwitchCell: UITableViewCell {
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        return label
    }()
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.numberOfLines = 0
        return label
    }()
    
    let switchControl: UISwitch = {
        let sw = UISwitch()
        sw.onTintColor = TUISwift.timCommonDynamicColor("common_switch_on_color", defaultColor: "#147AFF")
        return sw
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        
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

// MARK: - VoiceSettingSelectionCell

private class VoiceSettingSelectionCell: UITableViewCell {
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        return label
    }()
    
    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.numberOfLines = 0
        return label
    }()
    
    let detailLabel: UILabel = {
        let label = UILabel()
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
        backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        
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
