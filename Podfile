# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'V-Labs-Test' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  pod 'RxSwift', '~> 3.0.0.beta.1'
  pod 'RxCocoa', '~> 3.0.0.beta.1'
  pod 'Moya-ObjectMapper/RxSwift'
  pod 'Moya-ObjectMapper'
  pod 'ObjectMapper', '~> 2.2'
  pod 'RxDataSources', '~> 1.0'
  pod 'Kingfisher', '~> 4.0'
end

  post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['SWIFT_VERSION'] = '3.0'
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.10'
        end
  end

  # Pods for V-Labs-Test

  target 'V-Labs-TestTests' do
    inherit! :search_paths
    # Pods for testing
  end

end
