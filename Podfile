platform :osx, '11.0'
use_frameworks!

target 'Clipy' do

  # Application
  pod 'PINCache'
  pod 'Sauce'
  pod 'Sparkle'
  pod 'RealmSwift'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git'
  pod 'KeyHolder'
  pod 'Magnet'
  pod 'RxScreeen'
  pod 'AEXML'
  pod 'LetsMove'
  pod 'SwiftHEXColors'
  # Utility
  pod 'BartyCrouch'
  pod 'SwiftLint'
  pod 'SwiftGen'

  target 'ClipyTests' do
    inherit! :search_paths

    pod 'Quick'
    pod 'Nimble'

  end

end

post_install do |installer|
  swift_5_0_lib = "#{installer.sandbox.root}/../#{`xcrun --show-sdk-platform-path`.strip}/../usr/lib/swift-5.0/macosx"
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
    end
    if ['Nimble', 'Quick'].include?(target.name)
      target.build_configurations.each do |config|
        paths = config.build_settings['LIBRARY_SEARCH_PATHS'] || ['$(inherited)']
        xctest_lib = '$(DEVELOPER_DIR)/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.0/$(PLATFORM_NAME)'
        paths << xctest_lib unless paths.include?(xctest_lib)
        config.build_settings['LIBRARY_SEARCH_PATHS'] = paths
      end
    end
  end
end
