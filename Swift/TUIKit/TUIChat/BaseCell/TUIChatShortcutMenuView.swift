import UIKit

@objc public class TUIChatShortcutMenuCellData: NSObject {
    public var text: String
    public var cselector: Selector
    public var target: AnyObject

    public var textColor: UIColor
    public var backgroundColor: UIColor
    public var textFont: UIFont
    public var borderColor: UIColor
    public var borderWidth: CGFloat
    public var cornerRadius: CGFloat

    public init(text: String, cselector: Selector, target: AnyObject) {
        self.text = text
        self.cselector = cselector
        self.target = target
        self.textColor = UIColor.tui_color(withHex: "#8F959E")
        self.textFont = UIFont.systemFont(ofSize: 14)
        self.backgroundColor = UIColor.tui_color(withHex: "#F6F7F9")
        self.cornerRadius = 16
        self.borderColor = UIColor.tui_color(withHex: "#C5CBD4")
        self.borderWidth = 1.0
    }

    public func calcSize() -> CGSize {
        return calcMenuCellButtonSize(title: text)
    }

    private func calcMenuCellButtonSize(title: String) -> CGSize {
        let margin: CGFloat = 28
        let rect = title.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 32),
                                      options: [.usesLineFragmentOrigin, .usesFontLeading],
                                      attributes: [NSAttributedString.Key.font: textFont],
                                      context: nil)
        return CGSize(width: rect.size.width + margin, height: 32)
    }
}

public class TUIChatShortcutMenuCell: UICollectionViewCell {
    public var button: UIButton
    public var cellData: TUIChatShortcutMenuCellData?

    override init(frame: CGRect) {
        self.button = UIButton()
        super.init(frame: frame)
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func fill(withData cellData: TUIChatShortcutMenuCellData) {
        self.cellData = cellData
        button.setTitle(cellData.text, for: .normal)
        button.addTarget(cellData.target, action: cellData.cselector, for: .touchUpInside)

        button.layer.cornerRadius = cellData.cornerRadius
        button.titleLabel?.font = cellData.textFont
        button.backgroundColor = cellData.backgroundColor
        button.setTitleColor(cellData.textColor, for: .normal)
        button.layer.borderWidth = cellData.borderWidth
        button.layer.borderColor = cellData.borderColor.cgColor

        updateConstraints()
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    override public func updateConstraints() {
        super.updateConstraints()

        guard let size = cellData?.calcSize() else { return }
        button.snp.makeConstraints { make in
            make.leading.equalTo(12)
            make.centerY.equalTo(self.snp.centerY)
            make.width.equalTo(size.width)
            make.height.equalTo(size.height)
        }
    }
}

public class TUIChatShortcutMenuView: UIView, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public var viewHeight: CGFloat = 0
    public var itemHorizontalSpacing: CGFloat = 0

    private var dataSource: [TUIChatShortcutMenuCellData]

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isScrollEnabled = true
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(TUIChatShortcutMenuCell.self, forCellWithReuseIdentifier: "menuCell")
        return collectionView
    }()

    public init(dataSource: [TUIChatShortcutMenuCellData]) {
        self.dataSource = dataSource
        super.init(frame: .zero)
        backgroundColor = UIColor.tui_color(withHex: "#EBF0F6")
        addSubview(collectionView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateFrame() {
        snp.remakeConstraints { make in
            make.left.top.right.equalToSuperview()
            make.height.equalTo(viewHeight > 0 ? viewHeight : 46)
        }
        collectionView.snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        layoutIfNeeded()
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource & Delegate

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataSource.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "menuCell", for: indexPath) as? TUIChatShortcutMenuCell {
            let cellData = dataSource[indexPath.row]
            cell.fill(withData: cellData)
            return cell
        }
        return UICollectionViewCell()
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellData = dataSource[indexPath.row]
        return CGSize(width: cellData.calcSize().width + 12, height: cellData.calcSize().height)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }

    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
}
