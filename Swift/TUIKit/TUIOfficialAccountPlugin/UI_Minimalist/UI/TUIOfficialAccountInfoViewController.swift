import UIKit
import TIMCommon
import TUICore
import SDWebImage
import SnapKit

/// View controller for displaying official account info/detail
public class TUIOfficialAccountInfoViewController: UIViewController {
    
    // MARK: - Constants
    
    private enum Constants {
        static let avatarSize: CGFloat = 88.0
        static let avatarCornerRadius: CGFloat = 44.0 // Half of avatarSize for circular
        static let horizontalPadding: CGFloat = 16.0
        static let buttonWidth: CGFloat = 157.0
        static let buttonHeight: CGFloat = 98.0
        static let buttonCornerRadius: CGFloat = 12.0
        static let buttonSpacing: CGFloat = 16.0
        static let sectionSpacing: CGFloat = 8.0
    }
    
    // MARK: - Properties
    
    private let presenter: TUIOfficialAccountInfoPresenter
    private var isFromChatPage: Bool = false
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .white
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    // MARK: - Header Section
    
    private lazy var headerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Constants.avatarCornerRadius
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var subscriberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) // Gray color
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Buttons Section
    
    private lazy var buttonsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = Constants.buttonSpacing
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private lazy var followButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 0.976, green: 0.976, blue: 0.976, alpha: 1.0) // #f9f9f9
        button.layer.cornerRadius = Constants.buttonCornerRadius
        button.addTarget(self, action: #selector(followButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var followIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        return imageView
    }()
    
    private lazy var followTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var messageButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = UIColor(red: 0.976, green: 0.976, blue: 0.976, alpha: 1.0) // #f9f9f9
        button.layer.cornerRadius = Constants.buttonCornerRadius
        button.addTarget(self, action: #selector(messageButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var messageIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        let placeholderImage = TUISwift.tuiOfficialAccountBundleThemeImage(
            "official_account_msg_img",
            defaultImage: "official_account_msg"
        )
        imageView.image = placeholderImage
        return imageView
    }()
    
    private lazy var messageTitleLabel: UILabel = {
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("TUIKitSendMessage")
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Separator
    
    private lazy var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0)
        return view
    }()
    
    // MARK: - Info Section
    
    private lazy var infoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15)
        label.textColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
        return label
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator: UIActivityIndicatorView
        if #available(iOS 13.0, *) {
            indicator = UIActivityIndicatorView(style: .medium)
        } else {
            indicator = UIActivityIndicatorView(style: .gray)
        }
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - Initialization
    
    public init(accountID: String, isFromChatPage: Bool = false) {
        self.presenter = TUIOfficialAccountInfoPresenter(accountID: accountID)
        self.isFromChatPage = isFromChatPage
        super.init(nibName: nil, bundle: nil)
    }
    
    public init(accountInfo: TUIOfficialAccountInfo, isFromChatPage: Bool = false) {
        self.presenter = TUIOfficialAccountInfoPresenter(accountID: accountInfo.accountID)
        self.isFromChatPage = isFromChatPage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupPresenter()
        loadData()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = TUISwift.timCommonLocalizableString("TUIKitOfficialChannel")
        view.backgroundColor = .white
        navigationController?.navigationBar.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Header section
        contentView.addSubview(headerContainerView)
        headerContainerView.addSubview(avatarImageView)
        headerContainerView.addSubview(nameLabel)
        headerContainerView.addSubview(subscriberLabel)
        
        // Buttons
        headerContainerView.addSubview(buttonsStackView)
        buttonsStackView.addArrangedSubview(followButton)
        buttonsStackView.addArrangedSubview(messageButton)
        followButton.addSubview(followIconImageView)
        followButton.addSubview(followTitleLabel)
        messageButton.addSubview(messageIconImageView)
        messageButton.addSubview(messageTitleLabel)
        
        // Separator
        contentView.addSubview(separatorView)
        
        // Info section
        contentView.addSubview(infoContainerView)
        infoContainerView.addSubview(descriptionLabel)
        infoContainerView.addSubview(dateLabel)
        
        view.addSubview(loadingIndicator)
    }
    
    private func setupConstraints() {
        // ScrollView - full screen
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        // ContentView
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        // Header container
        headerContainerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        // Avatar - centered, circular
        avatarImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(32)
            make.size.equalTo(Constants.avatarSize)
        }
        
        // Name - below avatar
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        // Subscriber - below name
        subscriberLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        // Buttons container - below subscriber, centered using StackView
        buttonsStackView.snp.makeConstraints { make in
            make.top.equalTo(subscriberLabel.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }
        
        messageButton.isHidden = true
        
        // Follow icon - centered horizontally, vertically centered with title
        followIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(followButton.snp.centerY).offset(-4)
            make.size.equalTo(24)
        }
        
        // Follow title - below icon, centered
        followTitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(followButton.snp.centerY).offset(4)
        }
        
        // Message icon - centered horizontally, vertically centered with title
        messageIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(messageButton.snp.centerY).offset(-4)
            make.size.equalTo(24)
        }
        
        // Message title - below icon, centered
        messageTitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(messageButton.snp.centerY).offset(4)
        }
        
        // Separator
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(headerContainerView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.sectionSpacing)
        }
        
        // Info container
        infoContainerView.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        // Description
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        // Date
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        // Loading indicator
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    private func setupPresenter() {
        presenter.onAccountInfoUpdated = { [weak self] info in
            self?.updateUI(with: info)
        }
        
        presenter.onError = { [weak self] message in
            self?.showError(message)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        loadingIndicator.startAnimating()
        presenter.loadAccountInfo()
    }
    
    // MARK: - UI Update
    
    private func updateUI(with info: TUIOfficialAccountInfo?) {
        loadingIndicator.stopAnimating()
        
        guard let info = info else {
            showEmptyState()
            return
        }
        
        // Avatar - load real avatar from URL
        let placeholderImage = TUISwift.tuiOfficialAccountBundleThemeImage(
            "official_account_placeholder_img",
            defaultImage: "official_account_placeholder"
        )
        if let faceURL = info.faceURL, !faceURL.isEmpty, let url = URL(string: faceURL) {
            avatarImageView.sd_setImage(with: url, placeholderImage: placeholderImage)
        } else {
            avatarImageView.image = placeholderImage
        }
        
        // Name
        nameLabel.text = info.displayName
        
        // Subscriber count - localized format
        let subscribersText = TUISwift.timCommonLocalizableString("TUIKitSubscribers") ?? "subscribers"
        subscriberLabel.text = "\(info.formattedSubscriberCount) \(subscribersText)"
        
        // Description
        descriptionLabel.text = info.accountDescription ?? info.introduction ?? ""
        
        // Date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        dateLabel.text = dateFormatter.string(from: Date())
        
        // Follow button state 
        updateFollowButton(isFollowed: info.isFollowed)
    }
    
    private func updateFollowButton(isFollowed: Bool) {
        if isFollowed {
            
            messageButton.isHidden = false
            buttonsStackView.distribution = .fillEqually
            
            if #available(iOS 13.0, *) {
                followIconImageView.image = UIImage(systemName: "checkmark")
                followTitleLabel.text = TUISwift.timCommonLocalizableString("TUIKitFollowing") ?? "Following"
            }
        } else {
            messageButton.isHidden = true
            buttonsStackView.distribution = .fill
            
            if #available(iOS 13.0, *) {
                followIconImageView.image = UIImage(systemName: "plus")
                followTitleLabel.text = TUISwift.timCommonLocalizableString("TUIKitFollow") ?? "Follow"
            }
        }
        
        updateButtonConstraints(isFollowed: isFollowed)
    }
    
    private func updateButtonConstraints(isFollowed: Bool) {
        followButton.snp.removeConstraints()
        messageButton.snp.removeConstraints()
        
        if isFollowed {
            followButton.snp.makeConstraints { make in
                make.width.equalTo(Constants.buttonWidth)
                make.height.equalTo(Constants.buttonHeight)
            }
            
            messageButton.snp.makeConstraints { make in
                make.width.equalTo(Constants.buttonWidth)
                make.height.equalTo(Constants.buttonHeight)
            }
        } else {
            followButton.snp.makeConstraints { make in
                make.width.equalTo(Constants.buttonWidth)
                make.height.equalTo(Constants.buttonHeight)
            }
        }
    }
    
    private func showEmptyState() {
        descriptionLabel.text = TUISwift.timCommonLocalizableString("TUIKitNoData") ?? "No data available"
    }
    
    // MARK: - Actions
    
    @objc private func followButtonTapped() {
        guard let info = presenter.accountInfo else { return }
        
        followButton.isEnabled = false
        
        if info.isFollowed {
            presenter.unfollowAccount { [weak self] success in
                self?.followButton.isEnabled = true
                if success {
                    self?.updateFollowButton(isFollowed: false)
                }
            }
        } else {
            presenter.followAccount { [weak self] success in
                self?.followButton.isEnabled = true
                if success {
                    self?.updateFollowButton(isFollowed: true)
                }
            }
        }
    }
    
    @objc private func messageButtonTapped() {
        guard let info = presenter.accountInfo else { return }
        
        // If this page was opened from chat page, just go back instead of creating new chat
        if isFromChatPage {
            navigationController?.popViewController(animated: true)
            return
        }
        
        // Navigate to chat with official account
        var param: [String: Any] = [
            "TUICore_TUIChatObjectFactory_ChatViewController_Title": info.displayName,
            "TUICore_TUIChatObjectFactory_ChatViewController_UserID": info.accountID
        ]
        
        // Pass avatar - use current loaded image or URL
        if let avatarImage = avatarImageView.image {
            param["TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage"] = avatarImage
        }
        if let faceURL = info.faceURL, !faceURL.isEmpty {
            param["TUICore_TUIChatObjectFactory_ChatViewController_AvatarUrl"] = faceURL
        }
        
        navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Minimalist", param: param, forResult: nil)
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        loadingIndicator.stopAnimating()
        
        let alert = UIAlertController(
            title: TUISwift.timCommonLocalizableString("TUIKitError") ?? "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: TUISwift.timCommonLocalizableString("TUIKitConfirm") ?? "OK",
            style: .default
        ))
        present(alert, animated: true)
    }
}
