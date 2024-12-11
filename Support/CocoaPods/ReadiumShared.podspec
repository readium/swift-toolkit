Pod::Spec.new do |s|
  
  s.name         = "ReadiumShared"
  s.version      = "3.0.0-beta.1"
  s.license      = "BSD 3-Clause License"
  s.summary      = "Readium Shared"
  s.homepage     = "http://readium.github.io"
  s.author       = { "Readium" => "contact@readium.org" }
  s.source       = { :git => 'https://github.com/readium/swift-toolkit.git', :branch => "develop" }
  s.requires_arc = true
  s.source_files  = "Sources/Shared/**/*.{m,h,swift}"
  s.platform     = :ios
  s.ios.deployment_target = "13.0"
  s.frameworks   = "CoreServices"
  s.libraries =  "xml2"
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
  
  s.dependency 'SwiftSoup', '~> 2.7.0'
  s.dependency 'ReadiumFuzi', '~> 4.0.0'
  s.dependency 'ReadiumInternal'

end
