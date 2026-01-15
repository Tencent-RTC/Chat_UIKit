import UIKit
import TIMCommon
import SnapKit

/// Recommend cell for official account (card style)
public class TUIOfficialAccountRecommendCell: UICollectionViewCell {
    
    // MARK: - Constants
    
    private enum Constants {
        static let avatarSize: CGFloat = 56.0
        static let avatarCornerRadius: CGFloat = 28.0
        static let horizontalPadding: CGFloat = 12.0
        static let verticalPadding: CGFloat = 16.0
        static let followButtonHeight: CGFloat = 28.0
        static let verifiedIconSize: CGFloat = 16.0
    }
    
    // MARK: - UI Components
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
        return view
    }()
    
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
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = TUISwift.timCommonDynamicColor("form_title_color", defaultColor: "#000000")
        label.textAlignment = .center
        label.numberOfLines = 1
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
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private lazy var subscriberLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#999999")
        label.textAlignment = .center
        return label
    }()
    
    private lazy var followButton: UIButton = {
        let button = UIButton(type: .custom)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        button.layer.cornerRadius = Constants.followButtonHeight / 2
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(followButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Properties
    
    public var cellData: TUIOfficialAccountCellData? {
        didSet {
            updateUI()
        }
    }
    
    public var onFollowButtonTapped: ((TUIOfficialAccountCellData) -> Void)?
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.addSubview(containerView)
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(verifiedIcon)
        containerView.addSubview(descriptionLabel)
        containerView.addSubview(subscriberLabel)
        containerView.addSubview(followButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.bottom.equalToSuperview().offset(-4)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.verticalPadding)
            make.centerX.equalToSuperview()
            make.size.equalTo(Constants.avatarSize)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(Constants.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Constants.horizontalPadding)
        }
        
        verifiedIcon.snp.makeConstraints { make in
            make.size.equalTo(Constants.verifiedIconSize)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(Constants.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Constants.horizontalPadding)
        }
        
        subscriberLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(Constants.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Constants.horizontalPadding)
        }
        
        followButton.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-Constants.verticalPadding)
            make.centerX.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.7)
            make.height.equalTo(Constants.followButtonHeight)
        }
    }
    
    // MARK: - Update UI
    
    private func updateUI() {
        guard let data = cellData else { return }
        
        // Avatar
        avatarImageView.image = TUISwift.tuiOfficialAccountBundleThemeImage(
            "official_account_placeholder_img",
            defaultImage: "official_account_placeholder"
        )
        
        // Name
        nameLabel.text = data.displayName
        
        // Verified icon
        verifiedIcon.isHidden = !data.isVerified
        
        // Description
        descriptionLabel.text = data.accountDescription ?? ""
        
        // Subscriber count
        let subscriberText = TUISwift.timCommonLocalizableString("TUIKitSubscribers") ?? "subscribers"
        subscriberLabel.text = "\(data.formattedSubscriberCount) \(subscriberText)"
        
        // Follow button
        updateFollowButton()
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
            followButton.backgroundColor = TUISwift.timCommonDynamicColor(
                "primary_color",
                defaultColor: "#147AFF"
            )
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
        subscriberLabel.text = nil
        verifiedIcon.isHidden = true
    }
    
    // MARK: - Size
    
    public static let cellSize = CGSize(width: 140, height: 200)
}
