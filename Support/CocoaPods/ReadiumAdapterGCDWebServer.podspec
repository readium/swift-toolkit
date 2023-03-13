Pod::Spec.new do |s|

  s.name          = "ReadiumAdapterGCDWebServer"
  s.version       = "2.4.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Adapter to use GCDWebServer as an HTTP server in Readium"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :branch => "develop" }
  s.requires_arc  = true
  s.source_files  = "Sources/Adapters/GCDWebServer/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "10.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'R2Shared'
  s.dependency 'GCDWebServer', '~> 3.0'

end
