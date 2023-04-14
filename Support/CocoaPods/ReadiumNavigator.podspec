Pod::Spec.new do |s|

  s.name          = "R2Navigator"
  s.version       = "2.5.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "R2 Navigator"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :tag => "2.5.0" }
  s.requires_arc  = true
  s.resource_bundles = {
    'ReadiumNavigator' => [
      'Sources/Navigator/Resources/**',
      'Sources/Navigator/EPUB/Assets',
    ],
  }
  s.source_files  = "Sources/Navigator/**/*.{m,h,swift}"
  s.platform      = :ios
  s.ios.deployment_target = "10.0"
  s.dependency 'R2Shared'
  s.dependency 'ReadiumInternal'
  s.dependency 'DifferenceKit', '~> 1.0'
  s.dependency 'SwiftSoup', '~> 2.0'

end
