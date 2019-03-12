Pod::Spec.new do |s|

  s.name         = "R2Shared"
  s.version      = "1.2.7"
  s.summary      = "R2 Shared"
  s.homepage     = "http://readium.github.io"
  s.license      = "BSD 3-Clause License"
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.platform     = :ios
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/readium/r2-shared-swift.git", :branch => "develop" }
  s.source_files  = "r2-shared-swift/**/*.{m,h,swift}"
  s.exclude_files = ["**/Info*.plist"]
  s.xcconfig            = { 'FRAMEWORK_SEARCH_PATHS' => '"$(PODS_ROOT)/R2Shared/**"' }
  s.swift_version  = "4.2"

end
