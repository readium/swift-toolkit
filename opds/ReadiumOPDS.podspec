Pod::Spec.new do |s|

  s.name         = "ReadiumOPDS"
  s.version      = "1.0.4"
  s.summary      = "Readium OPDS"
  s.homepage     = "http://readium.github.io"
  s.license      = "BSD 3-Clause License"
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.platform     = :ios
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/readium/r2-opds-swift.git", :branch => "develop" }
  s.source_files  = "**/*.{m,h,swift}"
  s.exclude_files = ["**/Info*.plist","**/Carthage/*"]
  s.xcconfig            = { 'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_ROOT)/ReadiumOPDS/**"' ,
  'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2'}
  s.swift_version  = "4.2"

  s.dependency 'R2Shared'
  s.dependency 'Fuzi'

end
