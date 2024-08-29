Pod::Spec.new do |s|

  s.name          = "ReadiumAdapterLCPSQLite"
  s.version       = "3.0.0-alpha.2"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Adapter to use SQLite.swift for the Readium LCP repositories"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :tag => "3.0.0-alpha.2" }
  s.requires_arc  = true
  s.source_files  = "Sources/Adapters/LCPSQLite/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "13.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'ReadiumLCP'
  s.dependency 'ReadiumShared'
  s.dependency 'SQLite.swift', '~> 0.15.0'

end
