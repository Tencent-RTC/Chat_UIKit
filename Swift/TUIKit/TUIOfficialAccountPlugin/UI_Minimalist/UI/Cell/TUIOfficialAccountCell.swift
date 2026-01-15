import UIKit
import TIMCommon
import SDWebImage
import SnapKit

/// Cell for displaying official account in list
public class TUIOfficialAccountCell: UITableViewCell {
    
    // MARK: - Constants
    
    private enum Constants {
        static let avatarSize: CGFloat = 48.0
        static let horizontalPadding: CGFloat = 16.0
        static let verticalPadding: CGFloat = 12.0
        static let avatarCornerRadius: CGFloat = 24.0
        static let contentSpacing: CGFloat = 12.0
        static let verifiedIconSize: CGFloat = 16.0
        static let followButtonMinWidth: CGFloat = 73.0
        static let followButtonMaxWidth: CGFloat = 90.0
        static let followButtonHeight: CGFloat = 32.0
        static let followButtonCornerRadius: CGFloat = 10.0
    }
    
    // MARK: - UI Components
    
    private lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = Constants.avatarCornerRadius
        imageView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = TUISwift.timCommonDynamicColor("form_title_color", defaultColor: "#000000")
        return label
    }()
    
    private lazy var verifiedIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var followButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.layer.cornerRadius = Constants.followButtonCornerRadius
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 16, bottom: 5, right: 16)
        button.setTitle(TUISwift.timCommonLocalizableString("TUIKitFollow") ?? "Follow", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 28.0 / 255.0, green: 102.0 / 255.0, blue: 229.0 / 255.0, alpha: 1.0)
        button.addTarget(self, action: #selector(followButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var unreadBadge: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.backgroundColor = .red
        label.textAlignment = .center
        label.layer.cornerRadius = 9
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.textAlignment = .right
        return label
    }()
    
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = TUISwift.timCommonDynamicColor("separator_color", defaultColor: "#EEEEEE")
        return view
    }()
    
    // MARK: - Properties
    
    public var cellData: TUIOfficialAccountCellData? {
        didSet {
            updateUI()
        }
    }
    
    /// Whether to show as subscribed style (no follow button, show last message)
    public var showAsSubscribed: Bool = false {
        didSet {
            updateUI()
        }
    }
    
    public var onFollowButtonTapped: ((TUIOfficialAccountCellData) -> Void)?
    
    // MARK: - Initialization
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(verifiedIcon)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(followButton)
        contentView.addSubview(unreadBadge)
        contentView.addSubview(timeLabel)
        contentView.addSubview(separatorLine)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.horizontalPadding)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.avatarSize)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(Constants.contentSpacing)
            make.top.equalToSuperview().offset(Constants.verticalPadding + 4)
        }
        
        verifiedIcon.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(4)
            make.centerY.equalTo(nameLabel)
            make.size.equalTo(Constants.verifiedIconSize)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Constants.horizontalPadding)
            make.centerY.equalTo(nameLabel)
            make.width.lessThanOrEqualTo(60)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(Constants.contentSpacing)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.equalTo(followButton.snp.leading).offset(-8)
        }
        
        followButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-Constants.horizontalPadding)
            make.centerY.equalTo(descriptionLabel)
            make.width.greaterThanOrEqualTo(Constants.followButtonMinWidth)
            make.width.lessThanOrEqualTo(Constants.followButtonMaxWidth)
            make.height.equalTo(Constants.followButtonHeight)
        }
        
        unreadBadge.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView).offset(-4)
            make.trailing.equalTo(avatarImageView).offset(4)
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(18)
        }
        
        separatorLine.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(Constants.contentSpacing)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(0.5)
        }
    }
    
    // MARK: - Update UI
    
    private func updateUI() {
        guard let data = cellData else { return }
        
        // Avatar - load real avatar from URL, use built-in placeholder
        let placeholderImage = TUISwift.tuiOfficialAccountBundleThemeImage(
            "official_account_placeholder_img",
            defaultImage: "official_account_placeholder"
        )
        if let faceURL = data.faceURL, !faceURL.isEmpty, let url = URL(string: faceURL) {
            avatarImageView.sd_setImage(with: url, placeholderImage: placeholderImage)
        } else {
            avatarImageView.image = placeholderImage
        }
        
        // Name
        nameLabel.text = data.displayName
        
        // Verified icon
        verifiedIcon.isHidden = !data.isVerified
        if data.isVerified {
            verifiedIcon.image = TUISwift.tuiOfficialAccountBundleThemeImage(
                "official_account_verified_img",
                defaultImage: "official_account_verified"
            )
        }
        
        // Description - show last message for subscribed accounts, otherwise show description
        if showAsSubscribed {
            // For subscribed accounts (created/followed), show last message
            if let lastMessage = data.lastMessage, !lastMessage.isEmpty {
                descriptionLabel.text = lastMessage
            } else {
                descriptionLabel.text = data.accountDescription ?? ""
            }
            // Hide follow button for subscribed accounts
            followButton.isHidden = true
            // Show time for subscribed accounts
            timeLabel.isHidden = false
            timeLabel.text = data.formattedLastMessageTime
        } else {
            // For recommended accounts, show subscriber count
            let subscriberText = TUISwift.timCommonLocalizableString("TUIKitSubscribers") ?? "subscribers"
            descriptionLabel.text = "\(data.formattedSubscriberCount) \(subscriberText)"
            // Show follow button for recommended accounts
            followButton.isHidden = false
            updateFollowButton()
            // Hide time for recommended accounts
            timeLabel.isHidden = true
        }
        
        // Unread badge
        if data.unreadCount > 0 && showAsSubscribed {
            unreadBadge.isHidden = false
            if data.unreadCount > 99 {
                unreadBadge.text = "99+"
            } else {
                unreadBadge.text = "\(data.unreadCount)"
            }
        } else {
            unreadBadge.isHidden = true
        }
    }
    
    private func updateFollowButton() {
        guard let data = cellData else { return }
        
        if data.isFollowed {
            followButton.setTitle(
                TUISwift.timCommonLocalizableString("TUIKitFollowing") ?? "Following",
                for: .normal
            )
            followButton.setTitleColor(
                TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#666666"),
                for: .normal
            )
            followButton.backgroundColor = TUISwift.timCommonDynamicColor(
                "form_bg_color",
                defaultColor: "#EEEEEE"
            )
            followButton.layer.borderWidth = 1
            followButton.layer.borderColor = TUISwift.timCommonDynamicColor(
                "separator_color",
                defaultColor: "#DDDDDD"
            ).cgColor
        } else {
            followButton.setTitle(
                TUISwift.timCommonLocalizableString("TUIKitFollow") ?? "Follow",
                for: .normal
            )
            followButton.setTitleColor(.white, for: .normal)
            followButton.backgroundColor = UIColor(red: 28.0 / 255.0, green: 102.0 / 255.0, blue: 229.0 / 255.0, alpha: 1.0)
            followButton.layer.borderWidth = 0
        }
    }
    
    // MARK: - Actions
    
    @objc private func followButtonTapped() {
        guard let data = cellData else { return }
        onFollowButtonTapped?(data)
    }
    
    // MARK: - Reuse
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.image = nil
        nameLabel.text = nil
        descriptionLabel.text = nil
        timeLabel.text = nil
        verifiedIcon.isHidden = true
        unreadBadge.isHidden = true
        followButton.isHidden = false
        showAsSubscribed = false
    }
}
