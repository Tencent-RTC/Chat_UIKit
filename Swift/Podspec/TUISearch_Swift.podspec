Pod::Spec.new do |spec|
  spec.name         = 'TUISearch_Swift'
  spec.module_name  = 'TUISearch'
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
  spec.summary      = 'TUISearch_Swift'
  spec.xcconfig     = { 'VALID_ARCHS' => 'armv7 arm64 x86_64', }

  spec.requires_arc = true

  spec.source = { :http => 'https://im.sdk.cloud.tencent.cn/download/tuikit/8.7.7201/ios/TUISearch_Swift.zip?time=3'}

  spec.default_subspec = 'ALL'

  spec.subspec 'BaseCell' do |baseCell|
    baseCell.subspec 'CellData' do |cellData|
      cellData.source_files = '**/TUISearch/BaseCell/CellData/*.{h,m,mm,swift}'
      cellData.dependency 'TXIMSDK_Plus_iOS_XCFramework'
      cellData.dependency 'TUICore'
      cellData.dependency 'TIMCommon_Swift','~> 8.7.7201'
    end
    baseCell.subspec 'CellUI' do |cellUI|
      cellUI.source_files = '**/TUISearch/BaseCell/CellUI/*.{h,m,mm,swift}'
      cellUI.dependency "TUISearch_Swift/BaseCell/CellData"
    end
  end

  spec.subspec 'BaseDataProvider' do |baseDataProvider|
    baseDataProvider.source_files = '**/TUISearch/BaseDataProvider/*.{h,m,mm,swift}'
    baseDataProvider.dependency "TUISearch_Swift/BaseCell"
  end

  spec.subspec 'UI_Classic' do |uiClassic|
    uiClassic.subspec 'UI' do |ui|
      ui.source_files = '**/TUISearch/UI_Classic/UI/*.{h,m,mm,swift}'
      ui.dependency "TUISearch_Swift/BaseDataProvider"
    end
    uiClassic.subspec 'Service' do |service|
      service.source_files = '**/TUISearch/UI_Classic/Service/*.{h,m,mm,swift}'
      service.dependency "TUISearch_Swift/UI_Classic/UI"
    end
    uiClassic.resource = ['**/TUISearch/Resources/*.bundle']
  end

  spec.subspec 'UI_Minimalist' do |uiMinimalist|
    uiMinimalist.subspec 'Cell' do |cell|
        cell.subspec 'CellUI' do |cellUI|
        cellUI.source_files = '**/TUISearch/UI_Minimalist/Cell/CellUI/*.{h,m,mm,swift}'
        cellUI.dependency "TUISearch_Swift/BaseDataProvider"
        end
    end
    uiMinimalist.subspec 'UI' do |ui|
      ui.source_files = '**/TUISearch/UI_Minimalist/UI/*.{h,m,mm,swift}'
      ui.dependency "TUISearch_Swift/UI_Minimalist/Cell"
    end
    uiMinimalist.subspec 'Service' do |service|
      service.source_files = '**/TUISearch/UI_Minimalist/Service/*.{h,m,mm,swift}'
      service.dependency "TUISearch_Swift/UI_Minimalist/UI"
    end
    uiMinimalist.resource = ['**/TUISearch/Resources/*.bundle']
  end

  spec.subspec 'ALL' do |all|
    all.dependency "TUISearch_Swift/UI_Classic"
    all.dependency "TUISearch_Swift/UI_Minimalist"
  end
  
  spec.resource_bundle = {
    "#{spec.module_name}_Privacy" => '**/TUISearch/Resources/PrivacyInfo.xcprivacy'
  }

end

# pod trunk push TUISearch.podspec --use-libraries --allow-warnings
