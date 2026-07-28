Pod::Spec.new do |s|
  s.name             = 'bgeo_background_geolocation'
  s.version          = '0.1.1'
  s.summary          = 'Reliable background geolocation for Flutter (BGeo engine).'
  s.description      = 'Thin Flutter bridge over the closed-source BGeoCore engine (motion-aware tracking, offline HTTP queue, geofences).'
  s.homepage         = 'https://bgeo.dev'
  # Dual: bridge sources MIT, vendored BGeoCore.xcframework proprietary (LICENSE).
  s.license          = { :type => 'Commercial', :file => '../LICENSE' }
  s.author           = { 'BGeo' => 'dmitry.chistik@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{h,m}'
  s.public_header_files = 'Classes/BGeoFlutterPlugin.h'
  s.vendored_frameworks = 'BGeoCore.xcframework'
  s.platform         = :ios, '15.5'
  s.dependency 'Flutter'
  s.static_framework = true
  # System frameworks used by the vendored engine (AudioToolbox = debug cues).
  s.frameworks = 'CoreLocation', 'CoreMotion', 'UIKit', 'AudioToolbox'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
