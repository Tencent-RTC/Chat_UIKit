Pod::Spec.new do |spec|
  spec.name         = 'TIMCommon_Swift'
  spec.module_name  = 'TIMCommon'
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
  spec.summary      = 'TIMCommon_Swift'
  spec.xcconfig     = { 'VALID_ARCHS' => 'armv7 arm64 x86_64', }

  spec.requires_arc = true

  spec.source = { :http => 'https://im.sdk.cloud.tencent.cn/download/tuikit/8.7.7201/ios/TIMCommon_Swift.zip?time=6'}

  spec.subspec 'CommonModel' do |commonModel|
        commonModel.source_files = ['**/TIMCommon/CommonModel/*.{h,m,mm,swift}', '**/TIMCommon/CommonModel/TUIAttributedLabel/**/*.{h,m,mm,swift}']
        commonModel.dependency 'TXIMSDK_Plus_iOS_XCFramework'
        commonModel.dependency 'TUICore'
        commonModel.dependency 'SDWebImage'
        commonModel.dependency 'SnapKit'
  end
  
  spec.subspec 'BaseCellData' do |baseCellData|
       baseCellData.source_files = '**/TIMCommon/BaseCellData/*.{h,m,mm,swift}'
       baseCellData.dependency "TIMCommon_Swift/CommonModel"
  end
  
  spec.subspec 'BaseCell' do |baseCell|
       baseCell.source_files = '**/TIMCommon/BaseCell/*.{h,m,mm,swift}'
       baseCell.dependency "TIMCommon_Swift/BaseCellData"
  end
  
  spec.subspec 'UI_Classic' do |uiClassic|
       uiClassic.source_files = '**/TIMCommon/UI_Classic/*.{h,m,mm,swift}'
       uiClassic.dependency "TIMCommon_Swift/BaseCell"
       uiClassic.resource = ['**/TIMCommon/Resources/*.bundle']
  end

  spec.subspec 'UI_Minimalist' do |uiMinimalist|
       uiMinimalist.source_files = '**/TIMCommon/UI_Minimalist/*.{h,m,mm,swift}'
       uiMinimalist.dependency "TIMCommon_Swift/BaseCell"
       uiMinimalist.resource = ['**/TIMCommon/Resources/*.bundle']
  end
  
  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  spec.user_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }
  spec.resource_bundle = {
    "#{spec.module_name}_Privacy" => '**/TIMCommon/Resources/PrivacyInfo.xcprivacy'
  }
end

# pod trunk push TUICore.podspec --use-libraries --allow-warnings
