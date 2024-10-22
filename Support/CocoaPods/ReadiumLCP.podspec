Pod::Spec.new do |s|

  s.name          = "ReadiumLCP"
  s.version       = "3.0.0-alpha.3"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Readium LCP"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :branch => "develop" }
  s.requires_arc  = true
  s.resource_bundles = {
    'ReadiumLCP' => [
      'Sources/LCP/Resources/**',
      'Sources/LCP/**/*.xib',
    ],
  }
  s.source_files  = "Sources/LCP/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "13.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2'}
  
  s.dependency 'ReadiumShared' 
  s.dependency 'ReadiumInternal'
  s.dependency 'ZIPFoundation', '~> 0.9.0'
  s.dependency 'CryptoSwift', '~> 1.8.0'
end
