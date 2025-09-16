Pod::Spec.new do |s|
  s.name         = "NupcoVOC"
  s.version      = "0.1.0"
  s.summary      = "Pure native WebView opener for React Native (iOS/Android)"
  s.license      = { :type => "MIT" }
  s.author       = { "Ahmed" => "ahmedmahmoud04829@gmail.com" }
  s.homepage     = "https://github.com/ahmedhango/NupcoVOC"
  s.source       = { :git => "https://github.com/ahmedhango/NupcoVOC.git", :tag => s.version.to_s }
  s.platforms    = { :ios => "12.0" }
  s.source_files = "ios/**/*.{h,m,mm}"
  s.dependency "React-Core"
end


