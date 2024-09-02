Pod::Spec.new do |s|

  s.name          = "ReadiumStreamer"
  s.version       = "3.0.0-alpha.2"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Readium Streamer"
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
  s.ios.deployment_target = "13.0"
  s.libraries     =  'z', 'xml2'
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'ReadiumShared'
  s.dependency 'ReadiumInternal'
  s.dependency 'CryptoSwift', '~> 1.8.0'
  s.dependency 'Fuzi', '~> 3.1.0'
  s.dependency 'Minizip', '~> 1.0.0'

end
