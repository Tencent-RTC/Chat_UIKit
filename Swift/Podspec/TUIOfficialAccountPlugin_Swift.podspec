Pod::Spec.new do |spec|
  spec.name         = 'TUIOfficialAccountPlugin_Swift'
  spec.module_name  = 'TUIOfficialAccountPlugin'
  spec.version      = '8.9.7511'
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
  spec.summary      = 'TUIOfficialAccountPlugin_Swift'
  spec.dependency 'TUICore'
  spec.dependency 'TIMCommon_Swift'
  spec.dependency 'TUIChat_Swift'
  
  spec.requires_arc = true
  spec.source = { :http => 'https://im.sdk.cloud.tencent.cn/download/tuikit/8.9.7511/ios/TUIOfficialAccountPlugin_Swift.zip?time=4'}
  spec.dependency 'TUICore'
  spec.dependency 'TIMCommon_Swift','~>8.9.7511'
  spec.dependency 'TUIChat_Swift','~>8.9.7511'
  spec.source_files = 'TUIOfficialAccountPlugin/**/*.{h,m,mm,swift}'
  spec.resource_bundle = {
    "#{spec.module_name}_Privacy" => '**/TUIOfficialAccountPlugin/Resources/PrivacyInfo.xcprivacy'
  }

end
