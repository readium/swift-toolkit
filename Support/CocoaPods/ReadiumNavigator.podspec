Pod::Spec.new do |s|

  s.name          = "ReadiumNavigator"
  s.version       = "3.4.0"
  s.license       = "BSD 3-Clause License"
  s.summary       = "Readium Navigator"
  s.homepage      = "http://readium.github.io"
  s.author        = { "Readium" => "contact@readium.org" }
  s.source        = { :git => "https://github.com/readium/swift-toolkit.git", :tag => s.version }
  s.requires_arc  = true
  s.resource_bundles = {
    'ReadiumNavigator' => [
      'Sources/Navigator/Resources/**',
      'Sources/Navigator/EPUB/Assets',
    ],
  }
  s.source_files  = "Sources/Navigator/**/*.{m,h,swift}"
  s.swift_version = '5.10'
  s.platform      = :ios
  s.ios.deployment_target = "13.4"

  s.dependency 'ReadiumShared', '~> 3.4.0'
  s.dependency 'ReadiumInternal', '~> 3.4.0'
  s.dependency 'DifferenceKit', '~> 1.0'
  s.dependency 'SwiftSoup', '~> 2.7.0'

end
