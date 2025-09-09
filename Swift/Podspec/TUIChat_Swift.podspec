Pod::Spec.new do |spec|
  spec.name         = 'TUIChat_Swift'
  spec.module_name  = 'TUIChat'
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
  spec.summary      = 'TUIChat_Swift'
  spec.xcconfig     = { 'VALID_ARCHS' => 'armv7 arm64 x86_64', }
  spec.libraries    = 'stdc++'

  spec.requires_arc = true

  spec.source = { :http => 'https://im.sdk.cloud.tencent.cn/download/tuikit/8.7.7201/ios/TUIChat_Swift.zip?time=1'}

  spec.default_subspec = 'ALL'

  spec.subspec 'CommonModel' do |commonModel|
    commonModel.source_files = '**/TUIChat/CommonModel/*.{h,m,mm,swift}'
    commonModel.dependency 'TXIMSDK_Plus_iOS_XCFramework'
    commonModel.dependency 'TUICore'
    commonModel.dependency 'TIMCommon_Swift','~> 8.7.7201'
    commonModel.dependency 'SDWebImage'
    commonModel.dependency 'SnapKit'
  end

  spec.subspec 'BaseCellData' do |baseCellData|
       baseCellData.subspec 'Base' do |base|
            base.source_files = '**/TUIChat/BaseCellData/Base/*.{h,m,mm,swift}'
            base.dependency "TUIChat_Swift/CommonModel"
       end
      baseCellData.subspec 'Chat' do |chat|
            chat.source_files = '**/TUIChat/BaseCellData/Chat/*.{h,m,mm,swift}'
            chat.dependency "TUIChat_Swift/BaseCellData/Base"
      end
      baseCellData.subspec 'Custom' do |custom|
            custom.source_files = '**/TUIChat/BaseCellData/Custom/*.{h,m,mm,swift}'
            custom.dependency "TUIChat_Swift/BaseCellData/Chat"
      end
      baseCellData.subspec 'Reply' do |reply|
            reply.source_files = '**/TUIChat/BaseCellData/Reply/*.{h,m,mm,swift}'
            reply.dependency "TUIChat_Swift/BaseCellData/Custom"
      end
  end
  
  spec.subspec 'BaseCell' do |baseCell|
      baseCell.source_files = '**/TUIChat/BaseCell/*.{h,m,mm,swift}'
      baseCell.dependency "TUIChat_Swift/BaseCellData"
  end

  spec.subspec 'BaseDataProvider' do |baseDataProvider|
      baseDataProvider.subspec 'Base' do |base|
            base.source_files = '**/TUIChat/BaseDataProvider/Base/*.{h,m,mm,swift}'
            base.dependency "TUIChat_Swift/BaseCellData"
      end
      baseDataProvider.subspec 'Impl' do |impl|
            impl.source_files = '**/TUIChat/BaseDataProvider/Impl/*.{h,m,mm,swift}'
            impl.dependency "TUIChat_Swift/BaseCellData"
            impl.dependency "TUIChat_Swift/BaseDataProvider/Base"
      end
  end

  spec.subspec 'CommonUI' do |commonUI|
    commonUI.subspec 'Camera' do |camera|
      camera.source_files = '**/TUIChat/CommonUI/Camera/*.{h,m,mm,swift}'
      camera.dependency "TUIChat_Swift/BaseDataProvider"
      camera.dependency "TUIChat_Swift/BaseCell"
    end
    commonUI.subspec 'Pendency' do |pendency|
      pendency.source_files = '**/TUIChat/CommonUI/Pendency/*.{h,m,mm,swift}'
      pendency.dependency "TUIChat_Swift/BaseDataProvider"
      pendency.dependency "TUIChat_Swift/BaseCell"
    end
    commonUI.subspec 'Pop' do |pop|
      pop.source_files = '**/TUIChat/CommonUI/Pop/*.{h,m,mm,swift}'
      pop.dependency "TUIChat_Swift/BaseDataProvider"
      pop.dependency "TUIChat_Swift/BaseCell"
    end
  end

  spec.subspec 'UI_Classic' do |uiClassic|
    uiClassic.subspec 'Cell' do |cell|
        cell.subspec 'Base' do |base|
          base.source_files = '**/TUIChat/UI_Classic/Cell/Base/*.{h,m,mm,swift}'
          base.dependency "TUIChat_Swift/CommonUI"
        end
        cell.subspec 'Chat' do |chat|
          chat.source_files = '**/TUIChat/UI_Classic/Cell/Chat/*.{h,m,mm,swift}'
          chat.dependency "TUIChat_Swift/UI_Classic/Cell/Base"
        end
        cell.subspec 'Custom' do |custom|
          custom.source_files = '**/TUIChat/UI_Classic/Cell/Custom/*.{h,m,mm,swift}'
          custom.dependency "TUIChat_Swift/UI_Classic/Cell/Chat"
        end
        cell.subspec 'Reply' do |reply|
          reply.source_files = '**/TUIChat/UI_Classic/Cell/Reply/*.{h,m,mm,swift}'
          reply.dependency "TUIChat_Swift/UI_Classic/Cell/Custom"
        end
    end
    uiClassic.subspec 'Input' do |input|
      input.source_files = '**/TUIChat/UI_Classic/Input/*.{h,m,mm,swift}'
      input.dependency "TUIChat_Swift/UI_Classic/Cell"
    end
    uiClassic.subspec 'Chat' do |chat|
      chat.source_files = '**/TUIChat/UI_Classic/Chat/*.{h,m,mm,swift}'
      chat.dependency "TUIChat_Swift/UI_Classic/Input"
    end
    uiClassic.subspec 'Service' do |service|
      service.source_files = '**/TUIChat/UI_Classic/Service/*.{h,m,mm,swift}'
      service.dependency "TUIChat_Swift/UI_Classic/Chat"
    end
    uiClassic.subspec 'Config' do |config|
      config.source_files = '**/TUIChat/UI_Classic/Config/*.{h,m,mm,swift}'
      config.dependency "TUIChat_Swift/UI_Classic/Chat"
    end
    uiClassic.resource = [
      '**/TUIChat/Resources/*.bundle'
    ]
  end

  spec.subspec 'UI_Minimalist' do |uiMinimalist|
    uiMinimalist.subspec 'Cell' do |cell|
        cell.subspec 'Base' do |base|
          base.source_files = '**/TUIChat/UI_Minimalist/Cell/Base/*.{h,m,mm,swift}'
          base.dependency "TUIChat_Swift/CommonUI"
        end
        cell.subspec 'Chat' do |chat|
          chat.source_files = '**/TUIChat/UI_Minimalist/Cell/Chat/*.{h,m,mm,swift}'
          chat.dependency "TUIChat_Swift/UI_Minimalist/Cell/Base"
        end
        cell.subspec 'Custom' do |custom|
          custom.source_files = '**/TUIChat/UI_Minimalist/Cell/Custom/*.{h,m,mm,swift}'
          custom.dependency "TUIChat_Swift/UI_Minimalist/Cell/Chat"
        end
        cell.subspec 'Reply' do |reply|
          reply.source_files = '**/TUIChat/UI_Minimalist/Cell/Reply/*.{h,m,mm,swift}'
          reply.dependency "TUIChat_Swift/UI_Minimalist/Cell/Custom"
        end
    end
    uiMinimalist.subspec 'Input' do |input|
      input.source_files = '**/TUIChat/UI_Minimalist/Input/*.{h,m,mm,swift}'
      input.dependency "TUIChat_Swift/UI_Minimalist/Cell"
    end
    uiMinimalist.subspec 'Chat' do |chat|
      chat.source_files = '**/TUIChat/UI_Minimalist/Chat/*.{h,m,mm,swift}'
      chat.dependency "TUIChat_Swift/UI_Minimalist/Input"
    end
    uiMinimalist.subspec 'Service' do |service|
      service.source_files = '**/TUIChat/UI_Minimalist/Service/*.{h,m,mm,swift}'
      service.dependency "TUIChat_Swift/UI_Minimalist/Chat"
    end
    uiMinimalist.subspec 'Config' do |config|
      config.source_files = '**/TUIChat/UI_Minimalist/Config/*.{h,m,mm,swift}'
      config.dependency "TUIChat_Swift/UI_Minimalist/Chat"
    end
    uiMinimalist.resource = [
      '**/TUIChat/Resources/*.bundle'
    ]
  end

  spec.subspec 'ALL' do |all|
    all.dependency "TUIChat_Swift/UI_Classic"
    all.dependency "TUIChat_Swift/UI_Minimalist"
  end

  spec.resource_bundle = {
    "#{spec.module_name}_Privacy" => '**/TUIChat/Resources/PrivacyInfo.xcprivacy'
  }
end

# pod trunk push TUIChat.podspec --use-libraries --allow-warnings
