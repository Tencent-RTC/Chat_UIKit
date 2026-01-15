import AVFoundation
import ImSDK_Plus
import SnapKit
import TIMCommon
import UIKit

/// Voice clone controller for recording and cloning custom voice
class TUIVoiceCloneController: UIViewController {
    
    // MARK: - Constants
    
    private enum Layout {
        static let recordButtonSize: CGFloat = 100
        static let waveformHeight: CGFloat = 60
        static let minRecordDuration: TimeInterval = 3.0
        static let maxRecordDuration: TimeInterval = 30.0
    }
    
    private enum Colors {
        static var primaryBlue: UIColor {
            TUISwift.timCommonDynamicColor("common_switch_on_color", defaultColor: "#147AFF")
        }
        static var errorRed: UIColor {
            TUISwift.timCommonDynamicColor("chat_record_error_color", defaultColor: "#FA5251")
        }
        static var grayBackground: UIColor {
            TUISwift.timCommonDynamicColor("chat_record_btn_bg_color", defaultColor: "#DFE4ED")
        }
        static var grayText: UIColor {
            TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        }
    }
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private lazy var instructionLabel: UILabel = {
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("VoiceCloneInstruction")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = Colors.grayText
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var sampleTextLabel: UILabel = {
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("VoiceCloneSampleText")
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var waveformContainer: UIView = {
        let view = UIView()
        view.backgroundColor = Colors.grayBackground
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private var waveformBars: [UIView] = []
    
    private lazy var timerLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        label.textAlignment = .center
        return label
    }()
    
    private lazy var recordButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = Colors.primaryBlue
        button.layer.cornerRadius = Layout.recordButtonSize / 2
        button.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var recordHintLabel: UILabel = {
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("VoiceCloneTapToRecord")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = Colors.grayText
        label.textAlignment = .center
        return label
    }()
    
    private lazy var voiceNameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = TUISwift.timCommonLocalizableString("VoiceCloneNamePlaceholder")
        textField.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textField.borderStyle = .roundedRect
        textField.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        textField.delegate = self
        return textField
    }()
    
    private lazy var submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(TUISwift.timCommonLocalizableString("VoiceCloneSubmit"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        button.backgroundColor = Colors.primaryBlue.withAlphaComponent(0.5)
        button.layer.cornerRadius = 8
        button.isEnabled = false
        button.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var waveformTimer: Timer?
    private var recordingDuration: TimeInterval = 0
    private var recordedFilePath: String?
    private var isRecording: Bool = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupWaveformBars()
        setupAudioSession()
        setupKeyboardObservers()
        setupTapGesture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRecording()
    }
    
    deinit {
        stopRecording()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = TUISwift.timCommonLocalizableString("VoiceClone")
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(instructionLabel)
        contentView.addSubview(sampleTextLabel)
        contentView.addSubview(waveformContainer)
        contentView.addSubview(timerLabel)
        contentView.addSubview(recordButton)
        contentView.addSubview(recordHintLabel)
        contentView.addSubview(voiceNameTextField)
        contentView.addSubview(submitButton)
        
        submitButton.addSubview(activityIndicator)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(view)
        }
        
        instructionLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
        }
        
        sampleTextLabel.snp.makeConstraints { make in
            make.top.equalTo(instructionLabel.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
        }
        
        waveformContainer.snp.makeConstraints { make in
            make.top.equalTo(sampleTextLabel.snp.bottom).offset(32)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.height.equalTo(Layout.waveformHeight)
        }
        
        timerLabel.snp.makeConstraints { make in
            make.top.equalTo(waveformContainer.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        
        recordButton.snp.makeConstraints { make in
            make.top.equalTo(timerLabel.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(Layout.recordButtonSize)
        }
        
        recordHintLabel.snp.makeConstraints { make in
            make.top.equalTo(recordButton.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
        }
        
        voiceNameTextField.snp.makeConstraints { make in
            make.top.equalTo(recordHintLabel.snp.bottom).offset(32)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.height.equalTo(44)
        }
        
        submitButton.snp.makeConstraints { make in
            make.top.equalTo(voiceNameTextField.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.height.equalTo(48)
            make.bottom.equalToSuperview().offset(-32)
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    private func setupWaveformBars() {
        let barCount = 30
        let barWidth: CGFloat = 3
        let barSpacing: CGFloat = 4
        
        // Calculate total width and center offset
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        
        for i in 0..<barCount {
            let bar = UIView()
            bar.backgroundColor = Colors.primaryBlue.withAlphaComponent(0.6)
            bar.layer.cornerRadius = barWidth / 2
            waveformContainer.addSubview(bar)
            waveformBars.append(bar)
            
            bar.snp.makeConstraints { make in
                make.width.equalTo(barWidth)
                make.centerY.equalToSuperview()
                make.height.equalTo(6)
                make.centerX.equalToSuperview().offset(-totalWidth / 2 + CGFloat(i) * (barWidth + barSpacing) + barWidth / 2)
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let bottomInset = keyboardHeight - view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = bottomInset + 20
            self.scrollView.scrollIndicatorInsets.bottom = bottomInset
        }
        
        // Scroll to make text field visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let textFieldFrame = self.voiceNameTextField.convert(self.voiceNameTextField.bounds, to: self.scrollView)
            let targetRect = CGRect(
                x: 0,
                y: textFieldFrame.origin.y - 20,
                width: textFieldFrame.width,
                height: textFieldFrame.height + 100
            )
            self.scrollView.scrollRectToVisible(targetRect, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = 0
            self.scrollView.scrollIndicatorInsets.bottom = 0
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Actions
    
    @objc private func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    @objc private func submitButtonTapped() {
        guard let filePath = recordedFilePath else { return }
        
        submitButton.isEnabled = false
        submitButton.setTitle("", for: .normal)
        activityIndicator.startAnimating()
        
        let voiceName = voiceNameTextField.text?.isEmpty == false ? voiceNameTextField.text! : TUISwift.timCommonLocalizableString("VoiceCloneDefaultName")
        
        // Upload file first
        TUITextToVoiceDataProvider.shared.uploadVoiceFile(filePath: filePath) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let url):
                // Clone voice with uploaded URL
                self.cloneVoice(url: url, voiceName: voiceName)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.handleCloneError(error)
                }
            }
        }
    }
    
    private func cloneVoice(url: String, voiceName: String) {
        TUITextToVoiceDataProvider.shared.cloneVoice(audioUrl: url, voiceName: voiceName) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.submitButton.setTitle(TUISwift.timCommonLocalizableString("VoiceCloneSubmit"), for: .normal)
                
                switch result {
                case .success(let voiceId):
                    self.handleCloneSuccess(voiceId: voiceId, voiceName: voiceName)
                case .failure(let error):
                    self.handleCloneError(error)
                }
            }
        }
    }
    
    private func handleCloneSuccess(voiceId: String, voiceName: String) {
        // Save selected voice
        TUITextToVoiceConfig.shared.selectedVoiceId = voiceId
        TUITextToVoiceConfig.shared.selectedVoiceName = voiceName
        
        let alert = UIAlertController(
            title: TUISwift.timCommonLocalizableString("VoiceCloneSuccess"),
            message: TUISwift.timCommonLocalizableString("VoiceCloneSuccessMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func handleCloneError(_ error: Error) {
        submitButton.isEnabled = true
        submitButton.setTitle(TUISwift.timCommonLocalizableString("VoiceCloneSubmit"), for: .normal)
        
        let alert = UIAlertController(
            title: TUISwift.timCommonLocalizableString("VoiceCloneFailed"),
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Recording
    
    private func startRecording() {
        // Check microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.beginRecording()
                } else {
                    self?.showPermissionAlert()
                }
            }
        }
    }
    
    private func beginRecording() {
        let fileName = "voice_clone_\(Date().timeIntervalSince1970).wav"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilePath = documentsPath.appendingPathComponent(fileName)
        recordedFilePath = audioFilePath.path
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilePath, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingDuration = 0
            updateRecordingUI(isRecording: true)
            
            // Start timers
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateRecordingTime()
            }
            
            waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateWaveform()
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        waveformTimer?.invalidate()
        waveformTimer = nil
        
        isRecording = false
        updateRecordingUI(isRecording: false)
        
        // Check if recording is long enough
        if recordingDuration >= Layout.minRecordDuration {
            submitButton.isEnabled = true
            submitButton.backgroundColor = Colors.primaryBlue
        } else if recordingDuration > 0 {
            showTooShortAlert()
            recordedFilePath = nil
        }
    }
    
    private func updateRecordingTime() {
        recordingDuration += 1
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
        
        // Auto stop at max duration
        if recordingDuration >= Layout.maxRecordDuration {
            stopRecording()
        }
    }
    
    private func updateWaveform() {
        audioRecorder?.updateMeters()
        let power = audioRecorder?.averagePower(forChannel: 0) ?? -60
        let normalizedPower = CGFloat(max(0, (power + 60) / 60))
        
        // Animate waveform bars
        for (_, bar) in waveformBars.enumerated() {
            let randomFactor = CGFloat.random(in: 0.5...1.5)
            let height = max(CGFloat(6), normalizedPower * 40 * randomFactor)
            
            UIView.animate(withDuration: 0.1) {
                bar.snp.updateConstraints { make in
                    make.height.equalTo(height)
                }
                self.waveformContainer.layoutIfNeeded()
            }
        }
    }
    
    private func updateRecordingUI(isRecording: Bool) {
        if isRecording {
            recordButton.backgroundColor = Colors.errorRed
            recordButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
            recordHintLabel.text = TUISwift.timCommonLocalizableString("VoiceCloneTapToStop")
        } else {
            recordButton.backgroundColor = Colors.primaryBlue
            recordButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
            recordHintLabel.text = recordingDuration >= Layout.minRecordDuration ? TUISwift.timCommonLocalizableString("VoiceCloneRecordingComplete") : TUISwift.timCommonLocalizableString("VoiceCloneTapToRecord")
            
            // Reset waveform bars
            for bar in waveformBars {
                bar.snp.updateConstraints { make in
                    make.height.equalTo(6)
                }
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: TUISwift.timCommonLocalizableString("VoiceCloneMicPermissionRequired"),
            message: TUISwift.timCommonLocalizableString("VoiceCloneMicPermissionMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("VoiceCloneGoToSettings"), style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }
    
    private func showTooShortAlert() {
        let alert = UIAlertController(
            title: TUISwift.timCommonLocalizableString("VoiceCloneRecordTooShort"),
            message: TUISwift.timCommonLocalizableString("VoiceCloneRecordTooShortMessage"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension TUIVoiceCloneController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
