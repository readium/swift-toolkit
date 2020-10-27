Pod::Spec.new do |s|

  s.name         = "ReadiumOPDS"
  s.version       = "2.0.0-alpha.2"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Readium OPDS"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.source        = { :git => "https://github.com/readium/r2-opds-swift.git", :tag => "2.0.0-alpha.2" }
  s.exclude_files = ["**/Info*.plist"]
  s.requires_arc  = true
  s.resources     = ['readium-opds/Resources/**']
  s.source_files  = "readium-opds/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "10.0"
  s.xcconfig      = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'R2Shared'
  s.dependency 'Fuzi'

end
