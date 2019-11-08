Pod::Spec.new do |s|
  
  s.name         = 'R2Shared'
  s.version      = '1.4.0'
  s.license      = 'BSD 3-Clause License'
  s.summary      = 'R2 Shared'
  s.homepage     = 'http://readium.github.io'
  s.author       = { "Aferdita Muriqi" => "aferdita.muriqi@gmail.com" }
  s.source       = { :git => 'https://github.com/readium/r2-shared-swift.git', :tag => '1.4.0' }
  s.exclude_files = ["**/Info*.plist"]
  s.requires_arc = true
  s.resources    = ['r2-shared-swift/Resources/**']
  s.source_files  = "r2-shared-swift/**/*.{m,h,swift}"
  s.platform     = :ios
  s.ios.deployment_target = "10.0"
  s.frameworks   = 'MobileCoreServices'
  
end
