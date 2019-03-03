#
#  Be sure to run `pod spec lint r2-navigator-swift.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

 s.name          = "R2Navigator"
  s.version      = "1.0.5"
  s.summary      = "R2 Navigator"
  s.description  = <<-DESC
            Shared R2 Navigator
                   DESC
  s.homepage     = "http://readium.github.io"
  s.license      = "BSD 3-Clause License"
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.platform     = :ios
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/readium/r2-navigator-swift.git", :branch => "develop" }
  s.source_files  = "r2-navigator-swift/**/*"

end
