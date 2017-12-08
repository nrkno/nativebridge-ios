Pod::Spec.new do |s|
  s.name             = 'nativebridge-ios'
  s.version          = '0.1.0'
  s.summary          = 'The native part of a communication bridge between WKWebView and your app.'
  s.description      = <<-DESC
When used together with its javascript counterpart, 'nativebridge', this framework enables two way communication between
your app and a WKWebView.
                       DESC

  s.homepage         = 'https://github.com/nrkno/nativebridge-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'NRK Medieutvikling' => 'mobil-tilbakemelding@nrk.no' }
  s.source           = { :git => 'https://github.com/nrkno/nativebridge-ios.git', :tag => s.version.to_s }
  s.module_name      = 'NativeBridge'

  s.ios.deployment_target = '9.0'
  s.source_files = 'nativebridge-ios/Classes/**/*'
  s.ios.framework = 'WebKit'
end
