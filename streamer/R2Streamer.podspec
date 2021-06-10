Pod::Spec.new do |s|

  s.name         = "R2Streamer"
  s.version      = "2.0.0"
  s.license      = "BSD 3-Clause License"
  s.summary      = "R2 Streamer"
  s.homepage     = "http://readium.github.io"
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.source       = { :git => "https://github.com/readium/r2-streamer-swift.git", :branch => "develop" }
  s.exclude_files = ["**/Info*.plist"]
  s.requires_arc = true
  s.resources    = ['r2-streamer-swift/Resources/**', 'r2-streamer-swift/Assets']
  s.source_files  = "r2-streamer-swift/**/*.{m,h,swift}"
  s.platform     = :ios
  s.ios.deployment_target = "10.0"
  s.libraries =  'z', 'xml2'
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'R2Shared'
  s.dependency 'CryptoSwift', '~> 1.3.8'
  s.dependency 'Fuzi', '~> 3.1.3'
  s.dependency 'GCDWebServer', '~> 3.6.3'
  s.dependency 'Minizip', '~> 1.0.0'

end
