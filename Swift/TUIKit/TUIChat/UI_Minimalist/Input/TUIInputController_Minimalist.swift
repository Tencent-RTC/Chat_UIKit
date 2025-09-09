import AVFoundation
import TIMCommon
import UIKit

protocol TUIInputControllerDelegate_Minimalist: NSObjectProtocol {
    func inputController(_ inputController: TUIInputController_Minimalist, didChangeHeight height: CGFloat)
    func inputController(_ inputController: TUIInputController_Minimalist, didSendMessage message: V2TIMMessage)
    func inputControllerDidSelectMoreButton(_ inputController: TUIInputController_Minimalist)
    func inputControllerDidSelectCamera(_ inputController: TUIInputController_Minimalist)
    func inputControllerDidInputAt(_ inputController: TUIInputController_Minimalist)
    func inputController(_ inputController: TUIInputController_Minimalist, didDeleteAt atText: String)
    func inputControllerDidBeginTyping(_ inputController: TUIInputController_Minimalist)
    func inputControllerDidEndTyping(_ inputController: TUIInputController_Minimalist)
    func inputControllerDidTouchAIInterrupt(_ inputController: TUIInputController_Minimalist)
}

extension TUIInputControllerDelegate_Minimalist {
    func inputController(_ inputController: TUIInputController_Minimalist, didChangeHeight height: CGFloat) {}
    func inputController(_ inputController: TUIInputController_Minimalist, didSendMessage message: V2TIMMessage) {}
    func inputControllerDidSelectMoreButton(_ inputController: TUIInputController_Minimalist) {}
    func inputControllerDidSelectCamera(_ inputController: TUIInputController_Minimalist) {}
    func inputControllerDidInputAt(_ inputController: TUIInputController_Minimalist) {}
    func inputController(_ inputController: TUIInputController_Minimalist, didDeleteAt atText: String) {}
    func inputControllerDidBeginTyping(_ inputController: TUIInputController_Minimalist) {}
    func inputControllerDidEndTyping(_ inputController: TUIInputController_Minimalist) {}
    func inputControllerDidTouchAIInterrupt(_ inputController: TUIInputController_Minimalist) {}
}

public class TUIInputController_Minimalist: UIViewController, TUIInputBarDelegate_Minimalist, TUIMenuViewDelegate_Minimalist, TUIFaceVerticalViewDelegate {
    var replyData: TUIReplyPreviewData?
    var referenceData: TUIReferencePreviewData?
    var inputBar: TUIInputBar_Minimalist?
    weak var delegate: TUIInputControllerDelegate_Minimalist?
    var status: InputStatus = .input
    private var keyboardFrame: CGRect = .zero
    private var modifyRootReplyMsgBlock: ((TUIMessageCellData) -> Void)?
    
    // MARK: - AI Conversation Properties
    private var aiStyleEnabled: Bool = false

    lazy var menuView: TUIMenuView_Minimalist? = {
        let menuView = TUIMenuView_Minimalist(frame: CGRect(x: 16, y: inputBar!.mm_maxY, width: self.view.frame.size.width - 32, height: CGFloat(TMenuView_Menu_Height)))
        menuView.delegate = self

        let config = TIMConfig.shared
        var menuList = [TUIMenuCellData]()
        if let groups = config.faceGroups {
            for (index, group) in groups.enumerated() {
                let data = TUIMenuCellData()
                data.path = group.menuPath
                data.isSelected = index == 0
                menuList.append(data)
            }
        }
        menuView.data = menuList

        return menuView
    }()

    lazy var faceSegementScrollView: TUIFaceSegementScrollView? = {
        let scrollView = TUIFaceSegementScrollView(frame: CGRect(x: 0, y: (inputBar?.frame.origin.y ?? 0) + (inputBar?.frame.size.height ?? 0), width: self.view.frame.size.width, height: CGFloat(TFaceView_Height)))
        if let groups = TIMConfig.shared.faceGroups {
            scrollView.setItems(groups, delegate: self)
        }

        return scrollView
    }()

    private var _replyPreviewBar: TUIReplyPreviewBar_Minimalist?
    var replyPreviewBar: TUIReplyPreviewBar_Minimalist {
        get {
            if _replyPreviewBar == nil {
                _replyPreviewBar = TUIReplyPreviewBar_Minimalist()
                _replyPreviewBar?.onClose = { [weak self] in
                    guard let self else { return }
                    self.exitReplyAndReference(nil)
                }
            }
            return _replyPreviewBar!
        }
        set {
            _replyPreviewBar = newValue
        }
    }

    private var _referencePreviewBar: TUIReferencePreviewBar_Minimalist?
    var referencePreviewBar: TUIReferencePreviewBar_Minimalist {
        get {
            if _referencePreviewBar == nil {
                _referencePreviewBar = TUIReferencePreviewBar_Minimalist()
                _referencePreviewBar?.onClose = { [weak self] in
                    guard let self else { return }
                    self.exitReplyAndReference(nil)
                }
            }
            return _referencePreviewBar!
        }
        set {
            _referencePreviewBar = newValue
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(inputMessageStatusChanged(_:)), name: Notification.Name("kTUINotifyMessageStatusChanged"), object: nil)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        for gesture in view.window?.gestureRecognizers ?? [] {
            print("gesture = \(gesture)")
            gesture.delaysTouchesBegan = false
            print("delaysTouchesBegan = \(gesture.delaysTouchesBegan ? "YES" : "NO")")
            print("delaysTouchesEnded = \(gesture.delaysTouchesEnded ? "YES" : "NO")")
        }
        navigationController?.interactivePopGestureRecognizer?.delaysTouchesBegan = false
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    private func setupViews() {
        view.backgroundColor = TUISwift.rgba(255, g: 255, b: 255, a: 1)
        status = .input

        inputBar = TUIInputBar_Minimalist(frame: CGRect(x: 0, y: replyPreviewBar.frame.maxY, width: view.frame.size.width, height: CGFloat(TTextView_Height)))
        inputBar?.delegate = self
        view.addSubview(inputBar!)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let inputContainerBottom = getInputContainerBottom()
        delegate?.inputController(self, didChangeHeight: inputContainerBottom + TUISwift.bottom_SafeHeight())
        if status == .inputKeyboard {
            status = .input
        }
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        if status == .inputFace {
            hideFaceAnimation()
        } else {
            // hideFaceAnimation(false)
            // hideMoreAnimation(false)
        }
        status = .inputKeyboard
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let inputContainerBottom = getInputContainerBottom()
            delegate?.inputController(self, didChangeHeight: keyboardFrame.size.height + inputContainerBottom)
            self.keyboardFrame = keyboardFrame
        }
    }

    private func hideFaceAnimation() {
        faceSegementScrollView?.isHidden = false
        faceSegementScrollView?.alpha = 1.0
        menuView?.isHidden = false
        menuView?.alpha = 1.0
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.faceSegementScrollView?.alpha = 0.0
            self.menuView?.alpha = 0.0
        } completion: { _ in
            self.faceSegementScrollView?.isHidden = true
            self.faceSegementScrollView?.alpha = 1.0
            self.menuView?.isHidden = true
            self.menuView?.alpha = 1.0
            self.menuView?.removeFromSuperview()
            self.faceSegementScrollView?.removeFromSuperview()
            self.view.backgroundColor = TUISwift.rgba(255, g: 255, b: 255, a: 1)
        }
    }

    private func showFaceAnimation() {
        view.addSubview(faceSegementScrollView ?? UIView())
        view.addSubview(menuView ?? UIView())
        faceSegementScrollView?.updateRecentView()
        faceSegementScrollView?.setAllFloatCtrlViewAllowSendSwitch(inputBar?.inputTextView.text?.count ?? 0 > 0)
        faceSegementScrollView?.onScrollCallback = { [weak self] indexPage in
            guard let self else { return }
            self.menuView?.scrollTo(indexPage)
        }
        inputBar?.inputBarTextChanged = { [weak self] textview in
            guard let self else { return }
            if textview.text?.count ?? 0 > 0 {
                self.faceSegementScrollView?.setAllFloatCtrlViewAllowSendSwitch(true)
            } else {
                self.faceSegementScrollView?.setAllFloatCtrlViewAllowSendSwitch(false)
            }
        }

        faceSegementScrollView?.isHidden = false
        var frame = menuView?.frame ?? .zero
        frame.origin.y = view.window?.frame.size.height ?? 0
        menuView?.frame = frame
        menuView?.isHidden = false
        frame = faceSegementScrollView?.frame ?? .zero
        frame.origin.y = (menuView?.frame.origin.y ?? 0) + (menuView?.frame.size.height ?? 0)
        faceSegementScrollView?.frame = frame

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            var newFrame = self.menuView?.frame ?? .zero
            newFrame.origin.y = self.inputBar?.frame.maxY ?? 0
            self.menuView?.frame = newFrame

            newFrame = self.faceSegementScrollView?.frame ?? .zero
            newFrame.origin.y = (self.menuView?.frame.origin.y ?? 0) + (self.menuView?.frame.size.height ?? 0)
            self.faceSegementScrollView?.frame = newFrame
            self.view.backgroundColor = TUISwift.tuiChatDynamicColor("chat_input_controller_bg_color", defaultColor: "#EBF0F6")
        }
    }

    @objc func inputBarDidTouchCamera(_ textView: TUIInputBar_Minimalist) {
        inputBar?.inputTextView.resignFirstResponder()
        hideFaceAnimation()
        status = .inputCamera
        let inputContainerBottom = getInputContainerBottom()
        delegate?.inputController(self, didChangeHeight: inputContainerBottom + TUISwift.bottom_SafeHeight())
        delegate?.inputControllerDidSelectCamera(self)
    }

    @objc func inputBarDidTouchMore(_ textView: TUIInputBar_Minimalist) {
        delegate?.inputControllerDidSelectMoreButton(self)
    }

    @objc func inputBarDidTouchFace(_ textView: TUIInputBar_Minimalist) {
        guard let groups = TIMConfig.shared.faceGroups, groups.count > 0 else {
            return
        }

        inputBar?.inputTextView.resignFirstResponder()
        status = .inputFace
        let inputContainerBottom = getInputContainerBottom()
        delegate?.inputController(self, didChangeHeight: inputContainerBottom + (faceSegementScrollView?.frame.size.height ?? 0) + (menuView?.frame.size.height ?? 0))
        showFaceAnimation()
    }

    @objc func inputBarDidTouchKeyboard(_ textView: TUIInputBar_Minimalist) {
        if status == .inputFace {
            hideFaceAnimation()
        }
        status = .inputKeyboard
        inputBar?.inputTextView.becomeFirstResponder()
    }

    @objc func inputBarDidChangeInputHeight(_ textView: TUIInputBar_Minimalist, offset: CGFloat) {
        if status == .inputFace {
            showFaceAnimation()
        }

        delegate?.inputController(self, didChangeHeight: view.frame.size.height + offset)
        if _referencePreviewBar != nil {
            var referencePreviewBarFrame = _referencePreviewBar!.frame
            referencePreviewBarFrame.origin.y += offset
            _referencePreviewBar!.frame = referencePreviewBarFrame
        }
    }

    @objc func inputBarDidSendText(_ textView: TUIInputBar_Minimalist, text: String) {
        let content = text.getInternationalStringWithFaceContent()
        let message = V2TIMManager.sharedInstance().createTextMessage(text: content)!
        appendReplyDataIfNeeded(message)
        appendReferenceDataIfNeeded(message)
        delegate?.inputController(self, didSendMessage: message)
    }

    @objc func inputMessageStatusChanged(_ noti: Notification) {
        if let userInfo = noti.userInfo as? [String: Any],
           let msg = userInfo["msg"] as? TUIMessageCellData,
           let statusNumber = userInfo["status"] as? NSNumber,
           let status = TMsgStatus(rawValue: UInt(statusNumber.intValue))
        {
            if status == .success {
                DispatchQueue.main.async {
                    if self.modifyRootReplyMsgBlock != nil {
                        self.modifyRootReplyMsgBlock!(msg)
                        self.modifyRootReplyMsgBlock = nil
                    }
                }
            }
        }
    }

    private func appendReplyDataIfNeeded(_ message: V2TIMMessage) {
        guard let replyData = replyData else { return }

        let parentMsg = replyData.originMessage
        var simpleReply: [String: Any] = [
            "messageID": replyData.msgID ?? "",
            "messageAbstract": (replyData.msgAbstract ?? "").getInternationalStringWithFaceContent(),
            "messageSender": replyData.sender ?? "",
            "messageType": replyData.type.rawValue,
            "messageTime": replyData.originMessage?.timestamp?.timeIntervalSince1970 ?? 0,
            "messageSequence": replyData.originMessage?.seq ?? 0,
            "version": kMessageReplyVersion
        ]

        var cloudResultDic: [String: Any] = [:]
        if let cloudCustomData = parentMsg?.cloudCustomData,
           let originDic = TUITool.jsonData2Dictionary(cloudCustomData) as? [String: Any]
        {
            cloudResultDic.merge(originDic) { _, new in new }
            cloudResultDic.removeValue(forKey: "messageReplies")
            cloudResultDic.removeValue(forKey: "messageReact")
        }

        let messageReply = cloudResultDic["messageReply"] as? [String: Any]
        var messageRootID = messageReply?["messageRootID"] as? String ?? ""
        if let replyRootID = replyData.messageRootID, !replyRootID.isEmpty {
            messageRootID = replyRootID
        }
        if messageRootID.isEmpty {
            if let parentMsgID = parentMsg?.msgID, !parentMsgID.isEmpty {
                messageRootID = parentMsgID
            }
        }

        simpleReply["messageRootID"] = messageRootID
        cloudResultDic["messageReply"] = simpleReply

        if let data = TUITool.dictionary2JsonData(cloudResultDic) {
            message.cloudCustomData = data
        } else {
            assertionFailure("convert reply dict to data failed")
        }
        exitReplyAndReference(nil)

        modifyRootReplyMsgBlock = { [weak self] cellData in
            guard let self else { return }
            self.modifyRootReplyMsgByID(messageRootID, currentMsg: cellData)
            self.modifyRootReplyMsgBlock = nil
        }
    }

    private func modifyRootReplyMsgByID(_ messageRootID: String, currentMsg: TUIMessageCellData) {
        guard let msg = currentMsg.innerMessage else { return }
        var messageAbstract = ""
        if let textElem = msg.textElem {
            messageAbstract = textElem.text?.getInternationalStringWithFaceContent() ?? ""
        }
        let simpleCurrentContent: [String: Any] = [
            "messageID": msg.msgID ?? "",
            "messageAbstract": messageAbstract,
            "messageSender": msg.sender ?? "",
            "messageType": msg.elemType.rawValue,
            "messageTime": msg.timestamp?.timeIntervalSince1970 ?? "",
            "messageSequence": msg.seq,
            "version": kMessageReplyVersion
        ]
        TUIChatDataProvider.findMessages([messageRootID]) { _, _, msgs in
            if msgs.count > 0 {
                let rootMsg = msgs.first!
                TUIChatModifyMessageHelper.shared.modifyMessage(rootMsg, simpleCurrentContent: simpleCurrentContent)
            }
        }
    }

    private func appendReferenceDataIfNeeded(_ message: V2TIMMessage) {
        guard let referenceData = referenceData else { return }
        let dict: [String: Any] = [
            "messageReply": [
                "messageID": referenceData.msgID ?? "",
                "messageAbstract": (referenceData.msgAbstract ?? "").getInternationalStringWithFaceContent(),
                "messageSender": referenceData.sender ?? "",
                "messageType": referenceData.type.rawValue,
                "messageTime": referenceData.originMessage?.timestamp?.timeIntervalSince1970 ?? 0,
                "messageSequence": referenceData.originMessage?.seq ?? 0,
                "version": kMessageReplyVersion
            ]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
            message.cloudCustomData = data
        }
        exitReplyAndReference(nil)
    }

    func inputBarDidSendVoice(_ textView: TUIInputBar_Minimalist, path: String) {
        let url = URL(fileURLWithPath: path)
        let audioAsset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(audioAsset.duration)
        let formatDuration = duration > 59 ? 60 : Int(duration) + 1
        if let message = V2TIMManager.sharedInstance().createSoundMessage(audioFilePath: path, duration: Int32(formatDuration)) {
            delegate?.inputController(self, didSendMessage: message)
        }
    }

    func inputBarDidInputAt(_ textView: TUIInputBar_Minimalist) {
        delegate?.inputControllerDidInputAt(self)
    }

    func inputBarDidDeleteAt(_ textView: TUIInputBar_Minimalist, text: String) {
        delegate?.inputController(self, didDeleteAt: text)
    }

    func inputBarDidDeleteBackward(_ textView: TUIInputBar_Minimalist) {
        if textView.inputTextView.text?.count == 0 {
            exitReplyAndReference(nil)
        }
    }

    func inputTextViewShouldBeginTyping(_ textView: UITextView) {
        delegate?.inputControllerDidBeginTyping(self)
    }

    func inputTextViewShouldEndTyping(_ textView: UITextView) {
        delegate?.inputControllerDidEndTyping(self)
    }

    func reset() {
        if status == .input {
            return
        } else if status == .inputFace {
            hideFaceAnimation()
        }
        status = .input
        inputBar?.inputTextView.resignFirstResponder()
        let inputContainerBottom = getInputContainerBottom()
        delegate?.inputController(self, didChangeHeight: inputContainerBottom + TUISwift.bottom_SafeHeight())
    }

    func showReferencePreview(_ data: TUIReferencePreviewData) {
        referenceData = data
        referencePreviewBar.removeFromSuperview()
        view.addSubview(referencePreviewBar)
        inputBar?.lineView.isHidden = true

        referencePreviewBar.previewReferenceData = data

        inputBar?.mm_y = 0

        referencePreviewBar.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: CGFloat(TMenuView_Menu_Height))
        referencePreviewBar.mm_y = inputBar?.frame.maxY ?? 0

        delegate?.inputController(self, didChangeHeight: (inputBar?.frame.maxY ?? 0) + TUISwift.bottom_SafeHeight() + CGFloat(TMenuView_Menu_Height))

        if status == .inputKeyboard {
            let keyboradHeight = keyboardFrame.size.height
            delegate?.inputController(self, didChangeHeight: referencePreviewBar.frame.maxY + keyboradHeight)
        } else if status == .inputFace {
            inputBar?.changeToKeyboard()
        } else {
            inputBar?.inputTextView.becomeFirstResponder()
        }
    }

    func showReplyPreview(_ data: TUIReplyPreviewData) {
        replyData = data
        replyPreviewBar.removeFromSuperview()
        view.addSubview(replyPreviewBar)
        inputBar?.lineView.isHidden = true

        replyPreviewBar.previewData = data

        replyPreviewBar.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: CGFloat(TMenuView_Menu_Height))
        inputBar?.mm_y = replyPreviewBar.frame.maxY

        delegate?.inputController(self, didChangeHeight: (inputBar?.frame.maxY ?? 0) + TUISwift.bottom_SafeHeight())

        if status == .inputKeyboard {
            let keyboradHeight = keyboardFrame.size.height
            delegate?.inputController(self, didChangeHeight: (inputBar?.frame.maxY ?? 0) + keyboradHeight)
        } else if status == .inputFace {
            inputBar?.changeToKeyboard()
        } else {
            inputBar?.inputTextView.becomeFirstResponder()
        }
    }

    func exitReplyAndReference(_ finishedCallback: (() -> Void)?) {
        if replyData == nil && referenceData == nil {
            finishedCallback?()
            return
        }
        replyData = nil
        referenceData = nil
        UIView.animate(withDuration: 0.25) { [self] in
            self.replyPreviewBar.isHidden = true
            self.referencePreviewBar.isHidden = true
            self.inputBar?.mm_y = 0

            if self.status == .inputKeyboard {
                let keyboradHeight = self.keyboardFrame.size.height
                delegate?.inputController(self, didChangeHeight: (self.inputBar?.frame.maxY ?? 0) + keyboradHeight)
            } else {
                delegate?.inputController(self, didChangeHeight: (self.inputBar?.frame.maxY ?? 0) + TUISwift.bottom_SafeHeight())
            }
        } completion: { _ in
            self.replyPreviewBar.removeFromSuperview()
            self.referencePreviewBar.removeFromSuperview()
            self._replyPreviewBar = nil
            self._referencePreviewBar = nil
            self.hideFaceAnimation()
            self.inputBar?.lineView.isHidden = false
            finishedCallback?()
        }
    }

    // MARK: - TUIMenuViewDelegate

    func menuViewDidSelectItemsAtIndex(_ menuView: TUIMenuView_Minimalist, _ index: Int) {
        faceSegementScrollView?.setPageIndex(index)
    }

    func menuViewDidSendMessage(_ menuView: TUIMenuView_Minimalist) {
        guard let text = inputBar?.getInput(), !text.isEmpty else { return }
        let content = text.getInternationalStringWithFaceContent()
        inputBar?.clearInput()
        if let message = V2TIMManager.sharedInstance().createTextMessage(text: content) {
            appendReplyDataIfNeeded(message)
            appendReferenceDataIfNeeded(message)
            delegate?.inputController(self, didSendMessage: message)
        }
    }

    // MARK: - TUIFaceVerticalViewDelegate

    public func faceVerticalView(_ faceView: TUIFaceVerticalView, scrollToFaceGroupIndex index: Int) {
        menuView?.scrollTo(index)
    }

    public func faceVerticalView(_ faceView: TUIFaceVerticalView, didSelectItemAtIndexPath indexPath: IndexPath) {
        let group = faceView.faceGroups[indexPath.section]
        if let face = group.faces?[indexPath.row] as? TUIFaceCellData {
            if group.isNeedAddInInputBar {
                inputBar?.addEmoji(face)
                updateRecentMenuQueue(face.name ?? "")
            } else {
                let message = V2TIMManager.sharedInstance().createFaceMessage(index: Int32(group.groupIndex), data: face.name?.data(using: .utf8) ?? Data())!
                delegate?.inputController(self, didSendMessage: message)
            }
        }
    }

    public func faceVerticalViewClickSendMessageBtn() {
        menuViewDidSendMessage(menuView ?? TUIMenuView_Minimalist())
    }

    private func updateRecentMenuQueue(_ faceName: String) {
        guard let service = TIMCommonMediator.shared.getObject(for: TUIEmojiMeditorProtocol.self) else { return }
        service.updateRecentMenuQueue(faceName)
    }

    private func getInputContainerBottom() -> CGFloat {
        var inputHeight = inputBar?.frame.maxY ?? 0
        if _referencePreviewBar != nil {
            inputHeight = referencePreviewBar.frame.maxY
        }
        return inputHeight
    }

    func faceViewDidBackDelete(_ faceView: TUIFaceView) {
        inputBar?.backDelete()
    }
    
    // MARK: - AI Conversation Methods
    
    /// Enable or disable AI conversation style
    public func enableAIStyle(_ enable: Bool) {
        aiStyleEnabled = enable
        
        if enable {
            inputBar?.setInputBarStyle(.ai)
            inputBar?.setAIState(.default) // Default state
        } else {
            inputBar?.setInputBarStyle(.default)
        }
    }
    
    /// Set AI state
    public func setAIState(_ state: TUIInputBarAIState_Minimalist) {
        if aiStyleEnabled {
            inputBar?.setAIState(state)
        }
    }
    
    /// Set AI typing status
    public func setAITyping(_ typing: Bool) {
        if aiStyleEnabled {
            inputBar?.setAITyping(typing)
        }
    }
    
    // MARK: - TUIInputBarDelegate_Minimalist - AI Methods
    
    func inputBarDidTouchAIInterrupt(_ textView: TUIInputBar_Minimalist) {
        // Handle AI interrupt logic
        delegate?.inputControllerDidTouchAIInterrupt(self)
    }
}
