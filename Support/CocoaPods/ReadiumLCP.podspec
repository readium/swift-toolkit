Pod::Spec.new do |s|

  s.name          = "ReadiumLCP"
  s.version       = "2.3.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Readium LCP"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :branch => "develop" }
  s.requires_arc  = true
  s.resources     = [
    'Sources/LCP/Resources/**',
    'Sources/LCP/**/*.xib'
  ]
  s.source_files  = "Sources/LCP/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "10.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2'}
  
  s.dependency 'R2Shared' 

  s.dependency 'ZIPFoundation', '<= 0.9.11' # 0.9.12 requires iOS 12+
  s.dependency 'SQLite.swift', '~> 0.12.2'
  s.dependency 'CryptoSwift', '~> 1.3.8'
end
