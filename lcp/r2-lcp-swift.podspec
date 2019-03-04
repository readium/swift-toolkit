#
#  Be sure to run `pod spec lint r2-streamer-swift.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.version      = "1.0.4"
  s.name         = "ReadiumLCP"
  s.summary      = "Readium LCP"
  s.description  = <<-DESC
            Shared Readium LCP
                   DESC
  s.homepage     = "http://readium.github.io"
  s.license      = "BSD 3-Clause License"
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.platform     = :ios
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/readium/r2-lcp-swift.git", :branch => "develop" }
  s.source_files  = "**/*.{m,mm,h,swift}"
  s.exclude_files = ["**/Info*.plist","**/Carthage/*"]
  s.preserve_paths      = 'ReadiumLCP.framework'
  s.vendored_frameworks = 'ReadiumLCP.framework'
  s.xcconfig            = { 'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_ROOT)/ReadiumLCP/**"' ,
  'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2'}

  s.dependency 'R2Shared'
  s.dependency 'R2LCPClient'

  s.dependency 'ZIPFoundation'
  s.dependency 'SQLite.swift'
  s.dependency 'CryptoSwift'

end
