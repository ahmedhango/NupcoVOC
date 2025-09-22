Pod::Spec.new do |s|
  s.name         = "NupcoVOC"
  s.version      = "1.0.0"
  s.summary      = "Nupco VOC bridge — native-only integration (JS displays only)."
  s.license      = { :type => "MIT" }
  s.homepage     = "https://github.com/your-org/NupcoVOC"
  s.author       = { "Ahmed Aly" => "dev@example.com" }
  s.platform     = :ios, "12.0"
  s.source       = { :git => "https://github.com/your-org/NupcoVOC.git", :tag => s.version }
  s.source_files = "ios/**/*.{h,m}"
  s.requires_arc = true
  s.dependency   "React-Core"
  s.framework    = "WebKit"
end
