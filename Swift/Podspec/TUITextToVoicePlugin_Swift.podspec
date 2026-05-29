Pod::Spec.new do |spec|
  spec.name         = 'TUITextToVoicePlugin_Swift'
  spec.module_name  = 'TUITextToVoicePlugin'
  spec.version      = '9.0.7652'
  spec.platform     = :ios
  spec.ios.deployment_target = '13.0'
  spec.license      = { :type => 'Proprietary',
      :text => <<-LICENSE
        copyright 2017 tencent Ltd. All rights reserved.
        LICENSE
       }
  spec.homepage     = 'https://cloud.tencent.com/document/product/269/3794'
  spec.documentation_url = 'https://cloud.tencent.com/document/product/269/9147'
  spec.authors      = 'tencent video cloud'
  spec.summary      = 'TUITextToVoicePlugin_Swift'
  spec.dependency 'TUICore'
  spec.dependency 'TIMCommon_Swift'
  spec.dependency 'TUIChat_Swift'
  
  spec.requires_arc = true

  spec.source = { :http => 'https://im.sdk.cloud.tencent.cn/download/tuikit/9.0.7652/ios/TUITextToVoicePlugin_Swift.zip'}
  spec.source_files = '**/*.{h,m,mm,c,swift}'
  spec.resource = ['Resources/*.bundle']
  spec.resource_bundle = {
    "#{spec.module_name}_Privacy" => 'Resources/PrivacyInfo.xcprivacy'
  }
end
