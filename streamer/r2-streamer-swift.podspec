#
#  Be sure to run `pod spec lint r2-streamer-swift.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name          = "R2Streamer"
  s.version      = "1.0.6"
  s.summary      = "R2 Streamer"
  s.description  = <<-DESC
             R2 Streamer
                   DESC
  s.homepage     = "http://readium.github.io"
  s.license      = "BSD 3-Clause License"
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.platform     = :ios
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/readium/r2-streamer-swift.git", :branch => "develop" }
  s.source_files  = "**/*.{m,h,swift}"
  s.exclude_files = ["**/Info*.plist","**/Carthage/*"]
  s.preserve_paths      = 'R2Streamer.framework'
  s.vendored_frameworks = 'R2Streamer.framework'
  s.xcconfig            = { 'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_ROOT)/R2Streamer/**"' ,
  'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2'}

  s.libraries =  'z'

  s.dependency 'R2Shared'
  s.dependency 'AEXML'
  s.dependency 'Fuzi'
  s.dependency 'CryptoSwift'
  s.dependency 'GCDWebServer'
  s.dependency 'Minizip'

end
