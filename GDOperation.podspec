#
# Be sure to run `pod lib lint GDOperation.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'GDOperation'
  s.version          = '0.1.0'
  s.summary          = 'Collaborative Rich Text on iOS.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
?? NSAttributedString ??????, ? JSON ????, ?????????????
                       DESC

  s.homepage         = 'https://github.com/goodow/GDOperation'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Larry Tin' => 'dev@goodow.com' }
  s.source           = { :git => 'https://github.com/goodow/GDOperation.git', :tag => "v#{s.version.to_s}" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.subspec 'Core' do |sp|
    sp.dependency 'Protobuf', '~> 3.0'
    sp.dependency 'GDChannel', '~> 0.8'

    sp.requires_arc = ['GDOperation/Classes/**/*']
    sp.source_files = 'GDOperation/Classes/*', 'GDOperation/Classes/AttributedString/**/*', 'GDOperation/Generated/**/*'

    sp.resource_bundle = { 'GDOperation' => 'protos/*.proto' }
  end

  s.subspec 'YYText' do |sp|
    sp.dependency 'GDOperation/Core'
    sp.dependency 'YYText', '~> 1.0'
    sp.source_files = 'GDOperation/Classes/YYText/**/*'
  end

  s.subspec 'Firebase' do |sp|
    sp.dependency 'GDOperation/YYText'
    sp.dependency 'Firebase/Database'
    sp.source_files = 'GDOperation/Classes/Firebase/**/*'
  end
end