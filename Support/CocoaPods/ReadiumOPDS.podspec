Pod::Spec.new do |s|

  s.name          = "ReadiumOPDS"
  s.version       = "3.4.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Readium OPDS"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :tag => s.version }
  s.requires_arc  = true
  s.source_files  = "Sources/OPDS/**/*.{m,h,swift}"
  s.swift_version = '5.10'
  s.platform      = :ios
  s.ios.deployment_target = "13.4"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'ReadiumShared', '~> 3.4.0'
  s.dependency 'ReadiumInternal', '~> 3.4.0'
  s.dependency 'ReadiumFuzi', '~> 4.0.0'

end
