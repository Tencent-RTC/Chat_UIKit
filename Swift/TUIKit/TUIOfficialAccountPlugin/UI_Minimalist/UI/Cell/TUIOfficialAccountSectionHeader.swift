import UIKit
import TIMCommon
import SnapKit

/// Section header for official account list
public class TUIOfficialAccountSectionHeader: UITableViewHeaderFooterView {
    
    // MARK: - Constants
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 16.0
        static let verticalPadding: CGFloat = 12.0
    }
    
    // MARK: - UI Components
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        return label
    }()
    
    // MARK: - Properties
    
    public var title: String? {
        didSet {
            titleLabel.text = title
        }
    }
    
    // MARK: - Initialization
    
    public override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        
        contentView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.horizontalPadding)
            make.trailing.equalToSuperview().offset(-Constants.horizontalPadding)
            make.centerY.equalToSuperview()
        }
    }
    
    // MARK: - Height
    
    public static let headerHeight: CGFloat = 36.0
}
