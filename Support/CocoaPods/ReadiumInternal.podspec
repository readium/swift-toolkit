Pod::Spec.new do |s|

  s.name          = "ReadiumInternal"
  s.version       = "2.6.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Private utilities used by the Readium modules"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :tag => "2.6.0" }
  s.requires_arc  = true
  s.source_files  = "Sources/Internal/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "11.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

end
