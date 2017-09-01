#
#  Be sure to run `pod spec lint eCite.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

 s.name          = "R2Shared"
  s.version      = "0.1.0"
  s.summary      = "Readium2"
  s.description  = <<-DESC
            Shared readium2
                   DESC
  s.homepage     = "http://readium.github.io"
  s.license      = "BSD 3-Clause License"
  s.author       = { "Alexandre Camilleri" => "alexandre.camilleri@edrlab.org" }
  s.platform     = :ios
  s.ios.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/readium/r2-shared-swift.git", :tag => "#{s.version}" }
  s.source_files  = "r2-shared-swift/**/*"
  s.dependency 'ObjectMapper', '~> 2.2'

end
