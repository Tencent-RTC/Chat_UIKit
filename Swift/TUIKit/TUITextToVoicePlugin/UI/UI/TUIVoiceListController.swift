import ImSDK_Plus
import SnapKit
import TIMCommon
import TUICore
import UIKit

/// Voice list controller for selecting default or custom voices (TUITextToVoicePlugin)
class TUIVoiceListController: UIViewController {
    
    // MARK: - Section Types
    
    private enum Section: Int, CaseIterable {
        case followGlobal = 0
        case defaultVoices
        case customVoices
    }
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.rowHeight = 56
        tableView.register(VoiceItemCell.self, forCellReuseIdentifier: "VoiceItemCell")
        tableView.register(EmptyCustomVoiceCell.self, forCellReuseIdentifier: "EmptyCustomVoiceCell")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        return tableView
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Properties
    
    /// Conversation ID for per-conversation voice selection. If nil, sets global voice.
    var conversationID: String?
    
    private var defaultVoiceList: [TUICustomVoiceItem] = TUITextToVoiceConfig.defaultVoiceList
    private var customVoiceList: [TUICustomVoiceItem] = []
    private var isLoading: Bool = false
    private var hasLoadedCustomVoices: Bool = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadCustomVoiceList()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = TUISwift.timCommonLocalizableString("VoiceSelection")
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        
        view.addSubview(tableView)
        view.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadCustomVoiceList() {
        guard !isLoading else { return }
        
        isLoading = true
        loadingIndicator.startAnimating()
        
        TUITextToVoiceDataProvider.shared.getCustomVoiceList { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
                self.hasLoadedCustomVoices = true
                
                switch result {
                case .success(let voiceList):
                    self.customVoiceList = voiceList
                    self.tableView.reloadData()
                case .failure(let error):
                    print("Failed to load custom voice list: \(error)")
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func selectFollowGlobal() {
        guard let convID = conversationID else { return }
        
        // Remove conversation-level setting to follow global
        TUITextToVoiceConversationConfig.shared.removeVoiceSetting(for: convID)
        tableView.reloadData()
        
        // Notify to refresh profile settings page
        notifyReloadData()
        
        // Show selection feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func selectVoice(_ voice: TUICustomVoiceItem) {
        if let convID = conversationID {
            // Conversation-level setting
            TUITextToVoiceConversationConfig.shared.setVoiceSetting(
                voiceId: voice.voiceId,
                voiceName: voice.name,
                for: convID
            )
        } else {
            // Global setting
            TUITextToVoiceConfig.shared.selectedVoiceId = voice.voiceId
            TUITextToVoiceConfig.shared.selectedVoiceName = voice.name
        }
        tableView.reloadData()
        
        // Notify to refresh profile settings page
        notifyReloadData()
        
        // Show selection feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Notify via TUICore to trigger reload in host controller (e.g., profile settings page)
    private func notifyReloadData() {
        TUICore.notifyEvent(
            "TUICore_TUIVoiceMessageNotify",
            subKey: "TUICore_TUIVoiceMessageNotify_ReloadDataSubKey",
            object: nil,
            param: nil
        )
    }
    
    /// Get currently selected voice ID considering conversation-level override
    private func getSelectedVoiceId() -> String {
        if let convID = conversationID {
            if let setting = TUITextToVoiceConversationConfig.shared.getVoiceSetting(for: convID) {
                return setting.voiceId
            }
            // Following global
            return TUITextToVoiceConfig.shared.selectedVoiceId
        }
        return TUITextToVoiceConfig.shared.selectedVoiceId
    }
    
    /// Check if a voice is currently selected
    private func isVoiceSelected(_ voice: TUICustomVoiceItem) -> Bool {
        if let convID = conversationID {
            // For conversation-level, only show selected if has explicit setting
            if let setting = TUITextToVoiceConversationConfig.shared.getVoiceSetting(for: convID) {
                return setting.voiceId == voice.voiceId
            }
            // Following global, no voice in list should be selected
            return false
        }
        // Global setting
        return TUITextToVoiceConfig.shared.selectedVoiceId == voice.voiceId
    }
    
    private func deleteCustomVoice(_ voice: TUICustomVoiceItem, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: TUISwift.timCommonLocalizableString("DeleteVoice"),
            message: String(format: TUISwift.timCommonLocalizableString("DeleteVoiceConfirmFormat"), voice.name),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Delete"), style: .destructive) { [weak self] _ in
            self?.performDeleteVoice(voice, at: indexPath)
        })
        
        present(alert, animated: true)
    }
    
    private func performDeleteVoice(_ voice: TUICustomVoiceItem, at indexPath: IndexPath) {
        TUITextToVoiceDataProvider.shared.deleteCustomVoice(voiceId: voice.voiceId) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Remove only the item at the specific index to ensure consistency with TableView update
                    guard indexPath.row < self.customVoiceList.count else { return }
                    self.customVoiceList.remove(at: indexPath.row)
                    
                    // If deleted voice was selected, reset to default
                    let selectedVoiceId = self.getSelectedVoiceId()
                    if selectedVoiceId == voice.voiceId {
                        if let firstDefault = self.defaultVoiceList.first {
                            if let convID = self.conversationID {
                                TUITextToVoiceConversationConfig.shared.setVoiceSetting(
                                    voiceId: firstDefault.voiceId,
                                    voiceName: firstDefault.name,
                                    for: convID
                                )
                            } else {
                                TUITextToVoiceConfig.shared.selectedVoiceId = firstDefault.voiceId
                                TUITextToVoiceConfig.shared.selectedVoiceName = firstDefault.name
                            }
                        }
                    }
                    
                
                    if self.customVoiceList.isEmpty {
                        self.tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
                    } else {
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    }
                    
                    // Notify to refresh profile settings page
                    self.notifyReloadData()
                    
                case .failure(let error):
                    let errorAlert = UIAlertController(
                        title: TUISwift.timCommonLocalizableString("DeleteVoiceFailed"),
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default))
                    self.present(errorAlert, animated: true)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension TUIVoiceListController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Only show followGlobal section for conversation-level settings
        if conversationID != nil {
            return Section.allCases.count
        }
        // For global settings, skip followGlobal section
        return Section.allCases.count - 1
    }
    
    /// Map section index to Section type considering conversation mode
    private func sectionType(for section: Int) -> Section? {
        if conversationID != nil {
            return Section(rawValue: section)
        }
        // For global settings, offset by 1 to skip followGlobal
        return Section(rawValue: section + 1)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = sectionType(for: section) else { return 0 }
        
        switch sectionType {
        case .followGlobal:
            return 1
        case .defaultVoices:
            return defaultVoiceList.count
        case .customVoices:
            // Show empty cell when no custom voices and has loaded
            if customVoiceList.isEmpty && hasLoadedCustomVoices {
                return 1
            }
            return customVoiceList.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionType = sectionType(for: indexPath.section) else {
            return UITableViewCell()
        }
        
        switch sectionType {
        case .followGlobal:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceItemCell", for: indexPath) as? VoiceItemCell else {
                return UITableViewCell()
            }
            let isFollowingGlobal = !TUITextToVoiceConversationConfig.shared.hasExplicitVoiceSetting(for: conversationID ?? "")
            let followGlobalItem = TUICustomVoiceItem(
                voiceId: "__follow_global__",
                name: TUITextToVoiceConfig.followGlobalVoiceName,
                isDefault: true
            )
            cell.configure(with: followGlobalItem, isSelected: isFollowingGlobal)
            return cell
            
        case .defaultVoices:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceItemCell", for: indexPath) as? VoiceItemCell else {
                return UITableViewCell()
            }
            let voice = defaultVoiceList[indexPath.row]
            let isSelected = isVoiceSelected(voice)
            cell.configure(with: voice, isSelected: isSelected)
            return cell
            
        case .customVoices:
            // Show empty cell when no custom voices
            if customVoiceList.isEmpty && hasLoadedCustomVoices {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyCustomVoiceCell", for: indexPath) as? EmptyCustomVoiceCell else {
                    return UITableViewCell()
                }
                return cell
            }
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceItemCell", for: indexPath) as? VoiceItemCell else {
                return UITableViewCell()
            }
            let voice = customVoiceList[indexPath.row]
            let isSelected = isVoiceSelected(voice)
            cell.configure(with: voice, isSelected: isSelected)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension TUIVoiceListController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionType = sectionType(for: section) else { return 0.01 }
        
        switch sectionType {
        case .followGlobal:
            return 8
        case .defaultVoices, .customVoices:
            return 40
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = sectionType(for: section) else { return nil }
        
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        
        switch sectionType {
        case .followGlobal:
            // No header for follow global section
            return nil
        case .defaultVoices:
            label.text = TUISwift.timCommonLocalizableString("DefaultVoices")
        case .customVoices:
            label.text = TUISwift.timCommonLocalizableString("CustomVoices")
        }
        
        headerView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-8)
        }
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let sectionType = sectionType(for: indexPath.section) else { return }
        
        switch sectionType {
        case .followGlobal:
            selectFollowGlobal()
        case .defaultVoices:
            let voice = defaultVoiceList[indexPath.row]
            selectVoice(voice)
        case .customVoices:
            // Ignore tap on empty cell
            if customVoiceList.isEmpty {
                return
            }
            let voice = customVoiceList[indexPath.row]
            selectVoice(voice)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let sectionType = sectionType(for: indexPath.section),
              sectionType == .customVoices,
              !customVoiceList.isEmpty else {
            return nil
        }
        
        let voice = customVoiceList[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: TUISwift.timCommonLocalizableString("Delete")) { [weak self] _, _, completion in
            self?.deleteCustomVoice(voice, at: indexPath)
            completion(true)
        }
        deleteAction.backgroundColor = TUISwift.timCommonDynamicColor("chat_record_error_color", defaultColor: "#FA5251")
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let sectionType = sectionType(for: indexPath.section) else { return false }
        return sectionType == .customVoices && !customVoiceList.isEmpty
    }
}

// MARK: - VoiceItemCell

private class VoiceItemCell: UITableViewCell {
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        return label
    }()
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = TUISwift.timCommonDynamicColor("common_switch_on_color", defaultColor: "#147AFF")
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var customBadge: UILabel = {
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("CustomVoiceBadge")
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        label.backgroundColor = TUISwift.timCommonDynamicColor("common_switch_on_color", defaultColor: "#147AFF")
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()
    
    private lazy var voiceIdLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.isHidden = true
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
        contentView.addSubview(nameLabel)
        contentView.addSubview(customBadge)
        contentView.addSubview(voiceIdLabel)
        contentView.addSubview(checkmarkImageView)
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }
        
        customBadge.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.width.equalTo(44)
            make.height.equalTo(18)
        }
        
        voiceIdLabel.snp.makeConstraints { make in
            make.leading.equalTo(customBadge.snp.trailing).offset(6)
            make.trailing.lessThanOrEqualTo(checkmarkImageView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        checkmarkImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(20)
        }
    }
    
    func configure(with voice: TUICustomVoiceItem, isSelected: Bool) {
        nameLabel.text = voice.name
        if voice.isDefault {
            customBadge.isHidden = true
            voiceIdLabel.isHidden = true
        } else {
            customBadge.isHidden = false
            voiceIdLabel.isHidden = false
            voiceIdLabel.text = voice.voiceId
        }
        checkmarkImageView.isHidden = !isSelected
    }
}

// MARK: - EmptyCustomVoiceCell

private class EmptyCustomVoiceCell: UITableViewCell {
    
    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("NoCustomVoices")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.textAlignment = .center
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
        selectionStyle = .none
        contentView.addSubview(emptyLabel)
        
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
