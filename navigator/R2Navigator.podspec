Pod::Spec.new do |s|

  s.name          = "R2Navigator"
  s.version       = "2.1.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "R2 Navigator"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/r2-navigator-swift.git", :branch => "develop" }
  s.exclude_files = ["**/Info*.plist"]
  s.requires_arc  = true
  s.resources     = ['r2-navigator-swift/Resources/**', 'r2-navigator-swift/EPUB/Assets']
  s.source_files  = "r2-navigator-swift/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "10.0"
  s.dependency 'R2Shared'
  s.dependency 'DifferenceKit'
  s.dependency 'SwiftSoup', '~> 2.3'

end
