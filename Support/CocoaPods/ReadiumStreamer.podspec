Pod::Spec.new do |s|

  s.name          = "R2Streamer"
  s.version       = "2.3.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "R2 Streamer"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :branch => "develop" }
  s.requires_arc  = true
  s.resource_bundles = {
    'ReadiumStreamer' => [
      'Sources/Streamer/Resources/**',
      'Sources/Streamer/Assets',
    ],
  }
  s.source_files  = "Sources/Streamer/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "10.0"
  s.libraries     =  'z', 'xml2'
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'R2Shared'
  s.dependency 'CryptoSwift', '~> 1.3.8'
  s.dependency 'Fuzi', '~> 3.1.3'
  s.dependency 'GCDWebServer', '~> 3.6.3'
  s.dependency 'Minizip', '~> 1.0.0'

end
