//
//  TUITranslationLanguageRow.swift
//  TUITranslationPlugin
//
//  Created by AI Assistant on 2025/11/26.
//  Copyright © 2025 Tencent. All rights reserved.
//

import SnapKit
import TIMCommon
import UIKit

/// A UIKit component for displaying translation language settings row
/// Converted from Figma design (node-id: 1828-7811)
class TUITranslationLanguageRow: UIView {
    
    // MARK: - Design Tokens
    
    private enum DesignToken {
        enum Spacing {
            static let containerHorizontal: CGFloat = 16
            static let containerVertical: CGFloat = 12
            static let contentSpacing: CGFloat = 16
            static let rightContentSpacing: CGFloat = 8
            static let titleDescriptionSpacing: CGFloat = 4
        }
        
        enum Typography {
            static let titleFont = UIFont.systemFont(ofSize: 16)
            static let descriptionFont = UIFont.systemFont(ofSize: 12)
            static let languageFont = UIFont.systemFont(ofSize: 14)
        }
        
        enum Layout {
            static let containerHeight: CGFloat = 84
            static let arrowImageSize: CGFloat = 16
        }
    }
    
    // MARK: - UI Components
    
    public let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Typography.titleFont
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        label.numberOfLines = 1
        return label
    }()
    
    public let descriptionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Typography.descriptionFont
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.numberOfLines = 0
        return label
    }()
    
    private let languageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = DesignToken.Typography.languageFont
        label.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#000000")
        label.numberOfLines = 1
        return label
    }()
    
    private let arrowImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = TUISwift.timCommonDynamicColor("form_value_color", defaultColor: "#000000").withAlphaComponent(1)
        return imageView
    }()
    
    private let leftContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = DesignToken.Spacing.titleDescriptionSpacing
        return stackView
    }()
    
    private let rightContentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = DesignToken.Spacing.rightContentSpacing
        stackView.alignment = .center
        return stackView
    }()
    
    // MARK: - Properties
    
    var currentLanguage: String = "" {
        didSet {
            languageLabel.text = currentLanguage
        }
    }
    
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        updateForLayoutDirection()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        
        // Setup localized strings
        titleLabel.text = TUISwift.timCommonLocalizableString("TranslateMessage")
        descriptionLabel.text = TUISwift.timCommonLocalizableString("TUITranslationLanguageDescription")
        
        // Setup arrow image
        updateArrowImage()
        
        // Add subviews to stack views
        leftContentStackView.addArrangedSubview(titleLabel)
        leftContentStackView.addArrangedSubview(descriptionLabel)
        
        rightContentStackView.addArrangedSubview(languageLabel)
        rightContentStackView.addArrangedSubview(arrowImageView)
        
        // Add stack views to main view
        addSubview(leftContentStackView)
        addSubview(rightContentStackView)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    private func setupConstraints() {
        leftContentStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(DesignToken.Spacing.containerHorizontal)
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview().offset(DesignToken.Spacing.containerVertical)
            make.bottom.lessThanOrEqualToSuperview().offset(-DesignToken.Spacing.containerVertical)
        }
        
        rightContentStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-DesignToken.Spacing.containerHorizontal)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(leftContentStackView.snp.trailing).offset(DesignToken.Spacing.contentSpacing)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.width.height.equalTo(DesignToken.Layout.arrowImageSize)
        }
        
        snp.makeConstraints { make in
            make.height.equalTo(DesignToken.Layout.containerHeight)
        }
    }
    
    private func updateForLayoutDirection() {
        let isRTL = TUISwift.isRTL()
        
        // Update text alignment
        titleLabel.textAlignment = isRTL ? .right : .left
        descriptionLabel.textAlignment = isRTL ? .right : .left
        languageLabel.textAlignment = isRTL ? .left : .right
        
        // Update stack view alignment
        leftContentStackView.alignment = isRTL ? .trailing : .leading
        
        // Update arrow image
        updateArrowImage()
    }
    
    private func updateArrowImage() {
        let isRTL = TUISwift.isRTL()
        let imageName = isRTL ? "chevron.left" : "chevron.right"
        
        if #available(iOS 13.0, *) {
            arrowImageView.image = UIImage(systemName: imageName)
        } else {
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        onTap?()
    }
    
    // MARK: - Layout
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Update colors for dark mode
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
                titleLabel.textColor = TUISwift.timCommonDynamicColor("form_title_color", defaultColor: "#000000").withAlphaComponent(0.6)
                descriptionLabel.textColor = TUISwift.timCommonDynamicColor("form_subtitle_color", defaultColor: "#000000").withAlphaComponent(0.4)
                languageLabel.textColor = TUISwift.timCommonDynamicColor("form_value_color", defaultColor: "#000000").withAlphaComponent(0.6)
                arrowImageView.tintColor = TUISwift.timCommonDynamicColor("form_value_color", defaultColor: "#000000").withAlphaComponent(0.6)
            }
        }
    }
}
