import TIMCommon
import TUIChat
import TUICore
import UIKit

class TUIVoiceToTextView: UIView {
    private var text: String?
    private var tips: String?
    private var bgColor: UIColor?
    
    private var loadingView: UIImageView = .init()
    private var textView: TUITextView = .init()
    private var retryView: UIImageView = .init()
    
    private var cellData: TUIMessageCellData!
    
    convenience init(data: TUIMessageCellData) {
        self.init(frame: CGRect.zero)
        self.cellData = data
        
        let shouldShow = TUIVoiceToTextDataProvider.shouldShowConvertedText(data.innerMessage ?? V2TIMMessage())
        if shouldShow {
            setupViews()
            setupGesture()
            refreshWithData(data)
        } else {
            if !cellData.bottomContainerSize.equalTo(.zero) {
                notifyConversionChanged()
            }
            self.isHidden = true
            stopLoading()
            cellData.bottomContainerSize = .zero
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupGesture()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func refreshWithData(_ cellData: TUIMessageCellData) {
        text = TUIVoiceToTextDataProvider.getConvertedText(cellData.innerMessage ?? V2TIMMessage())
        let status = TUIVoiceToTextDataProvider.getConvertedTextStatus(cellData.innerMessage ?? V2TIMMessage())
        
        let size = calcSizeOfStatus(status)
        if !cellData.bottomContainerSize.equalTo(size) {
            notifyConversionChanged()
        }
        cellData.bottomContainerSize = size
        frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        
        switch status {
        case .loading:
            startLoading()
        case .shown:
            stopLoading()
            updateConversionViewByText(text ?? "", translationViewStatus: .shown)
        case .securityStrike:
            stopLoading()
            updateConversionViewByText(text ?? "", translationViewStatus: .securityStrike)
        default:
            break
        }
        
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }
    
    private func calcSizeOfStatus(_ status: TUIVoiceToTextViewStatus) -> CGSize {
        let minTextWidth: CGFloat = 164
        let maxTextWidth: CGFloat = TUISwift.screen_Width() * 0.68
        let actualTextWidth: CGFloat = 80 - 20
        let oneLineTextHeight: CGFloat = 22
        let commonMargins: CGFloat = 11 * 2
        
        if status == .loading {
            return CGSize(width: 80, height: oneLineTextHeight + commonMargins)
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let rtlText = rtlString(text ?? "")
        var textRect = rtlText.boundingRect(with: CGSize(width: actualTextWidth, height: .greatestFiniteMagnitude),
                                            options: .usesLineFragmentOrigin,
                                            attributes: [.font: UIFont.systemFont(ofSize: 16),
                                                         .paragraphStyle: paragraphStyle],
                                            context: nil)
        
        if textRect.height < 30 {
            return CGSize(width: max(textRect.width, minTextWidth) + commonMargins,
                          height: max(textRect.height, oneLineTextHeight) + commonMargins)
        }
        
        textRect = rtlText.boundingRect(with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
                                        options: .usesLineFragmentOrigin,
                                        attributes: [.font: UIFont.systemFont(ofSize: 16),
                                                     .paragraphStyle: paragraphStyle],
                                        context: nil)
        
        let result = CGSize(width: max(textRect.width, minTextWidth) + commonMargins,
                            height: max(textRect.height, oneLineTextHeight) + commonMargins)
        return CGSize(width: ceil(result.width), height: ceil(result.height))
    }
    
    // MARK: - UI

    private func setupViews() {
        backgroundColor = bgColor ?? TUISwift.tuiVoice(toTextDynamicColor: "convert_voice_text_view_bg_color", defaultColor: "#F2F7FF")
        layer.cornerRadius = 10.0
        
        loadingView.frame = CGRect(x: 0, y: 0, width: 15, height: 15)
        loadingView.image = TUISwift.tuiVoice(toTextBundleThemeImage: "convert_voice_text_view_icon_loading_img", defaultImage: "convert_voice_text_loading")
        loadingView.isHidden = true
        addSubview(loadingView)
        
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.textAlignment = TUISwift.isRTL() ? .right : .left
        textView.semanticContentAttribute = TUISwift.isRTL() ? .forceRightToLeft : .forceLeftToRight
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.disableHighlightLink()
        textView.textColor = TUISwift.tuiVoice(toTextDynamicColor: "convert_voice_text_view_text_color", defaultColor: "#000000")
        addSubview(textView)
        textView.isHidden = true
        textView.isUserInteractionEnabled = false
        
        retryView.image = UIImage.safeImage(TUISwift.tuiChatImagePath("msg_error"))
        retryView.isHidden = true
        addSubview(retryView)
    }
    
    private func setupGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPressed(_:)))
        addGestureRecognizer(longPress)
    }
    
    override class var requiresConstraintBasedLayout: Bool {
        return true
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        
        if let text = text, !text.isEmpty {
            retryView.snp.remakeConstraints { make in
                if cellData.direction == .outgoing {
                    make.leading.equalToSuperview().offset(-27)
                } else {
                    make.trailing.equalToSuperview().offset(27)
                }
                make.centerY.equalToSuperview()
                make.width.height.equalTo(20)
            }
            
            textView.snp.remakeConstraints { make in
                make.leading.equalTo(10)
                make.trailing.equalTo(-10)
                make.top.bottom.equalTo(10)
            }
        } else {
            loadingView.snp.remakeConstraints { make in
                make.height.width.equalTo(15)
                make.leading.equalTo(10)
                make.centerY.equalToSuperview()
            }
        }
    }
    
    private func updateConversionViewByText(_ text: String, translationViewStatus status: TUIVoiceToTextViewStatus) {
        let isConverted = text.count > 0
        
        var textColor = TUISwift.tuiVoice(toTextDynamicColor: "convert_voice_text_view_text_color", defaultColor: "#000000")
        var bgColor = TUISwift.tuiVoice(toTextDynamicColor: "convert_voice_text_view_bg_color", defaultColor: "#F2F7FF")
        if status == .securityStrike {
            bgColor = UIColor.tui_color(withHex: "#FA5151", alpha: 0.16) ?? UIColor()
            textColor = TUISwift.tuiVoice(toTextDynamicColor: "", defaultColor: "#DA2222")
        }
        self.bgColor = bgColor
        backgroundColor = bgColor
        textView.textColor = textColor
        if isConverted {
            textView.text = text
        }
        textView.isHidden = !isConverted
        retryView.isHidden = !(status == .securityStrike)
    }
    
    // MARK: - Public

    func startLoading() {
        guard loadingView.isHidden else { return }
        
        loadingView.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
            rotate.toValue = Double.pi * 2.0
            rotate.duration = 1
            rotate.repeatCount = .greatestFiniteMagnitude
            self.loadingView.layer.add(rotate, forKey: "rotationAnimation")
        }
    }
    
    func stopLoading() {
        guard !loadingView.isHidden else { return }
        loadingView.isHidden = true
        loadingView.layer.removeAllAnimations()
    }
    
    // MARK: - Event response

    @objc private func onLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        
        let popMenu = TUIChatPopMenu()
        
        let status = TUIVoiceToTextDataProvider.getConvertedTextStatus(cellData.innerMessage ?? V2TIMMessage())
        let hasRiskContent = (status == .securityStrike)
        
        let copyAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Copy"), image: TUISwift.tuiVoice(toTextBundleThemeImage: "convert_voice_text_view_pop_menu_copy_img", defaultImage: "icon_copy"), weight: 1) { [weak self] in
            self?.onCopy(self?.text ?? "")
        }
        popMenu.addAction(copyAction)
        
        let forwardAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Forward"),
                                                 image: TUISwift.tuiVoice(toTextBundleThemeImage: "convert_voice_text_view_pop_menu_forward_img", defaultImage: "icon_forward"),
                                                 weight: 2)
        { [weak self] in
            self?.onForward(self?.text ?? "")
        }
        if !hasRiskContent {
            popMenu.addAction(forwardAction)
        }
        
        let hideAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Hide"),
                                              image: TUISwift.tuiVoice(toTextBundleThemeImage: "convert_voice_text_view_pop_menu_hide_img", defaultImage: "icon_hide"),
                                              weight: 3)
        { [weak self] in
            self?.onHide()
        }
        popMenu.addAction(hideAction)
        
        if let keyWindow = TUITool.applicationKeywindow() {
            let frame = keyWindow.convert(self.frame, from: superview)
            popMenu.setArrawPosition(CGPoint(x: frame.origin.x + frame.size.width * 0.5, y: frame.origin.y + 66), adjustHeight: 0)
            popMenu.showInView(keyWindow)
        }
    }
    
    private func onCopy(_ text: String) {
        guard text.count > 0 else { return }
        UIPasteboard.general.string = text
        TUITool.makeToast(TUISwift.timCommonLocalizableString("Copied"))
    }
    
    private func onForward(_ text: String) {
        notifyConversionForward(text)
    }
    
    private func onHide() {
        cellData.bottomContainerSize = .zero
        TUIVoiceToTextDataProvider.saveConvertedResult(cellData.innerMessage ?? V2TIMMessage(), text: "", status: TUIVoiceToTextViewStatus.hidden)
        removeFromSuperview()
        notifyConversionViewHidden()
    }
    
    // MARK: - Notify

    private func notifyConversionViewShown() {
        notifyConversionChanged()
    }
    
    private func notifyConversionViewHidden() {
        notifyConversionChanged()
    }
    
    private func notifyConversionForward(_ text: String) {
        let param = ["TUICore_TUIPluginNotify_WillForwardTextSubKey_Text": text]
        TUICore.notifyEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_WillForwardTextSubKey", object: nil, param: param)
    }
    
    private func notifyConversionChanged() {
        let param = ["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData,
                     "TUICore_TUIPluginNotify_DidChangePluginViewSubKey_VC": self]
        TUICore.notifyEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey", object: nil, param: param as [AnyHashable: Any])
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.setNeedsUpdateConstraints()
            self.updateConstraintsIfNeeded()
            self.layoutIfNeeded()
        }
    }
}
