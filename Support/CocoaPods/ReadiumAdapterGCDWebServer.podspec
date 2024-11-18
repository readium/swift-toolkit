Pod::Spec.new do |s|

  s.name          = "ReadiumAdapterGCDWebServer"
  s.version       = "2.7.4"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Adapter to use GCDWebServer as an HTTP server in Readium"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :tag => "2.7.4" }
  s.requires_arc  = true
  s.source_files  = "Sources/Adapters/GCDWebServer/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "11.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'R2Shared'
  s.dependency 'ReadiumInternal'
  s.dependency 'ReadiumGCDWebServer', '~> 4.0.0'

end
