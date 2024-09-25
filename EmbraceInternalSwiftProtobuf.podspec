Pod::Spec.new do |s|
  s.name = 'EmbraceInternalSwiftProtobuf'
  s.version = '1.28.1'
  s.license = { :type => 'Apache 2.0', :file => 'LICENSE.txt' }
  s.summary = 'Swift Protobuf Runtime Library'
  s.homepage = 'https://github.com/apple/swift-protobuf'
  s.author = 'Apple Inc.'
  s.source = { :git => 'https://github.com/apple/swift-protobuf.git', :tag => s.version }

  s.requires_arc = true
  s.ios.deployment_target = '11.0'

  s.cocoapods_version = '>= 1.7.0'

  s.source_files = 'Sources/SwiftProtobuf/**/*.swift'
  s.resource_bundle = {'SwiftProtobuf' => ['Sources/SwiftProtobuf/PrivacyInfo.xcprivacy']}

  s.swift_versions = ['5.0']
end
