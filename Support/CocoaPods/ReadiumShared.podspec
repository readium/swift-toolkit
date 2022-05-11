Pod::Spec.new do |s|
  
  s.name         = 'R2Shared'
  s.version      = '2.3.0'
  s.license      = 'BSD 3-Clause License'
  s.summary      = 'R2 Shared'
  s.homepage     = 'http://readium.github.io'
  s.author       = { "Readium" => "contact@readium.org" }
  s.source       = { :git => 'https://github.com/readium/swift-toolkit.git', :branch => "develop" }
  s.exclude_files = ["Sources/Shared/Toolkit/Archive/ZIPFoundation.swift"]
  s.requires_arc = true
  s.resources    = ['Sources/Shared/Resources/**']
  s.source_files  = "Sources/Shared/**/*.{m,h,swift}"
  s.platform     = :ios
  s.ios.deployment_target = "10.0"
  s.frameworks   = 'CoreServices'
  s.libraries =  'xml2'
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
  
  s.dependency 'Fuzi', '~> 3.1.3'
  s.dependency 'Minizip', '~> 1.0.0'
  s.dependency 'SwiftSoup', '~> 2.3'

end
