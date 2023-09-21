Pod::Spec.new do |s|

  s.name          = "ReadiumOPDS"
  s.version       = "2.6.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Readium OPDS"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :tag => "2.6.0" }
  s.requires_arc  = true
  s.resource_bundles = {
    'ReadiumOPDS' => ['Sources/OPDS/Resources/**'],
  }
  s.source_files  = "Sources/OPDS/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "11.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'R2Shared'
  s.dependency 'ReadiumInternal'
  s.dependency 'Fuzi', '~> 3.0'

end
