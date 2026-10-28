Pod::Spec.new do |s|
  s.name             = 'storage'
  s.version          = '1.0.0'
  s.summary          = 'Khoa CSDL boc Keychain cho app La ban.'
  s.homepage         = 'https://compass.tsudev.com'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'TsuDev' => 'security@tsudev.com' }
  s.source           = { :path => '.' }
  s.source_files = 'storage/Sources/storage/**/*.swift'
  s.resource_bundles = { 'storage_privacy' => ['storage/Sources/storage/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
