Pod::Spec.new do |spec|
  spec.name         = 'TUIConversation_Swift'
  spec.module_name  = 'TUIConversation'
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
  spec.summary      = 'TUIConversation_Swift'
  spec.xcconfig     = { 'VALID_ARCHS' => 'armv7 arm64 x86_64', }

  spec.requires_arc = true
  
  spec.source = { :http => 'https://im.sdk.cloud.tencent.cn/download/tuikit/8.7.7201/ios/TUIConversation_Swift.zip?time=3'}

  spec.default_subspec = 'ALL'

  spec.subspec 'CommonModel' do |commonModel|
    commonModel.source_files = '**/TUIConversation/CommonModel/*.{h,m,mm,swift}'
    commonModel.dependency 'TXIMSDK_Plus_iOS_XCFramework'
    commonModel.dependency 'TUICore'
    commonModel.dependency 'TIMCommon_Swift','~> 8.7.7201'
    commonModel.dependency 'SnapKit'
  end

  spec.subspec 'BaseCell' do |baseCell|
    baseCell.subspec 'CellData' do |cellData|
      cellData.source_files = '**/TUIConversation/BaseCell/CellData/*.{h,m,mm,swift}'
      cellData.dependency "TUIConversation_Swift/CommonModel"
    end
    baseCell.subspec 'CellUI' do |cellUI|
      cellUI.source_files = '**/TUIConversation/BaseCell/CellUI/*.{h,m,mm,swift}'
      cellUI.dependency "TUIConversation_Swift/BaseCell/CellData"
    end
  end

  spec.subspec 'BaseDataProvider' do |baseDataProvider|
    baseDataProvider.source_files = '**/TUIConversation/BaseDataProvider/*.{h,m,mm,swift}'
    baseDataProvider.dependency "TUIConversation_Swift/BaseCell"
  end

  spec.subspec 'UI_Classic' do |uiClassic|
    uiClassic.subspec 'DataProvider' do |dataProvider|
      dataProvider.source_files = '**/TUIConversation/UI_Classic/DataProvider/*.{h,m,mm,swift}'
      dataProvider.dependency "TUIConversation_Swift/BaseDataProvider"
    end
    uiClassic.subspec 'UI' do |ui|
      ui.source_files = '**/TUIConversation/UI_Classic/UI/*.{h,m,mm,swift}'
      ui.dependency "TUIConversation_Swift/UI_Classic/DataProvider"
    end
    uiClassic.subspec 'Service' do |service|
      service.source_files = '**/TUIConversation/UI_Classic/Service/*.{h,m,mm,swift}'
      service.dependency "TUIConversation_Swift/UI_Classic/UI"
    end
    uiClassic.subspec 'Header' do |header|
      header.source_files = '**/TUIConversation/UI_Classic/Header/*.{h,m,mm,swift}'
      header.dependency "TUIConversation_Swift/UI_Classic/Service"
    end
    uiClassic.resource = ['**/TUIConversation/Resources/*.bundle']
  end

  spec.subspec 'UI_Minimalist' do |uiMinimalist|
    uiMinimalist.subspec 'Cell' do |cell|
      cell.subspec 'CellData' do |cellData|
        cellData.source_files = '**/TUIConversation/UI_Minimalist/Cell/CellData/*.{h,m,mm,swift}'
        cellData.dependency "TUIConversation_Swift/BaseDataProvider"
      end
      cell.subspec 'CellUI' do |cellUI|
        cellUI.source_files = '**/TUIConversation/UI_Minimalist/Cell/CellUI/*.{h,m,mm,swift}'
        cellUI.dependency "TUIConversation_Swift/UI_Minimalist/Cell/CellData"
      end
    end
    uiMinimalist.subspec 'DataProvider' do |dataProvider|
      dataProvider.source_files = '**/TUIConversation/UI_Minimalist/DataProvider/*.{h,m,mm,swift}'
      dataProvider.dependency "TUIConversation_Swift/UI_Minimalist/Cell"
    end
    uiMinimalist.subspec 'UI' do |ui|
      ui.source_files = '**/TUIConversation/UI_Minimalist/UI/*.{h,m,mm,swift}'
      ui.dependency "TUIConversation_Swift/UI_Minimalist/DataProvider"
    end
    uiMinimalist.subspec 'Service' do |service|
      service.source_files = '**/TUIConversation/UI_Minimalist/Service/*.{h,m,mm,swift}'
      service.dependency "TUIConversation_Swift/UI_Minimalist/UI"
    end
    uiMinimalist.subspec 'Header' do |header|
      header.source_files = '**/TUIConversation/UI_Minimalist/Header/*.{h,m,mm,swift}'
      header.dependency "TUIConversation_Swift/UI_Minimalist/Service"
    end
    uiMinimalist.resource = ['**/TUIConversation/Resources/*.bundle']
  end

  spec.subspec 'ALL' do |all|
    all.dependency "TUIConversation_Swift/UI_Classic"
    all.dependency "TUIConversation_Swift/UI_Minimalist"
  end

  spec.resource_bundle = {
    "#{spec.module_name}_Privacy" => '**/TUIConversation/Resources/PrivacyInfo.xcprivacy'
  }
  
end

# pod trunk push TUIConversation.podspec --use-libraries --allow-warnings
