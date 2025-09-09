Pod::Spec.new do |spec|
  spec.name         = 'TUIEmojiPlugin_Swift'
  spec.module_name  = 'TUIEmojiPlugin'
  spec.version      = '8.7.7201'
  spec.platform     = :ios
  spec.ios.deployment_target = '9.0'
  spec.license      = { :type => 'Proprietary',
      :text => <<-LICENSE
        copyright 2017 tencent Ltd. All rights reserved.
        LICENSE
       }
  spec.homepage     = 'https://cloud.tencent.com/document/product/269/3794'
  spec.documentation_url = 'https://cloud.tencent.com/document/product/269/9147'
  spec.authors      = 'tencent video cloud'
  spec.summary      = 'TUIEmojiPlugin_Swift'
  spec.requires_arc = true

  spec.source = { :http => 'https://im.sdk.cloud.tencent.cn/download/tuikit/8.7.7201/ios/TUIEmojiPlugin_Swift.zip?time=4'}

  spec.dependency 'TUICore'
  spec.dependency 'TIMCommon_Swift','~>8.7.7201'
  spec.dependency 'TUIChat_Swift','~>8.7.7201'
  spec.source_files = 'TUIEmojiPlugin/**/*.{h,m,mm,swift}'
  spec.resource_bundle = {
    "#{spec.module_name}_Privacy" => '**/TUIEmojiPlugin/Resources/PrivacyInfo.xcprivacy'
  }
  
end

# pod trunk push TUIEmojiPlugin.podspec --use-libraries --allow-warnings
