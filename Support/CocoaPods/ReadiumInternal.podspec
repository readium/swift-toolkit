Pod::Spec.new do |s|

  s.name          = "ReadiumInternal"
  s.version       = "3.0.0-beta.1"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Private utilities used by the Readium modules"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :branch => "develop" }
  s.requires_arc  = true
  s.source_files  = "Sources/Internal/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "13.4"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

end
