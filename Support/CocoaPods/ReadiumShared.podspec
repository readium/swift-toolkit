Pod::Spec.new do |s|
  
  s.name         = "ReadiumShared"
  s.version      = "3.4.0"
  s.license      = "BSD 3-Clause License"
  s.summary      = "Readium Shared"
  s.homepage     = "http://readium.github.io"
  s.author       = { "Readium" => "contact@readium.org" }
  s.source       = { :git => 'https://github.com/readium/swift-toolkit.git', :tag => s.version }
  s.requires_arc = true
  s.resource_bundles = {
    "ReadiumShared" => ["Sources/Shared/Resources/**"],
  }
  s.source_files  = "Sources/Shared/**/*.{m,h,swift}"
  s.swift_version = '5.10'
  s.platform     = :ios
  s.ios.deployment_target = "13.4"
  s.frameworks   = "CoreServices"
  s.libraries =  "xml2"
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
  
  s.dependency 'Minizip', '~> 1.0.0'
  s.dependency 'SwiftSoup', '~> 2.7.0'
  s.dependency 'ReadiumFuzi', '~> 4.0.0'
  s.dependency 'ReadiumZIPFoundation', '~> 3.0.0'
  s.dependency 'ReadiumInternal', '~> 3.4.0'

end
