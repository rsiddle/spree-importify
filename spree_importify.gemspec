Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_importify'
  s.version     = '1.0'
  s.summary     = 'Adds advanced product importation facilities to Spree.'
  #s.description = 'Add (optional) gem description here'
  s.required_ruby_version = '>= 1.8.7'

  s.author            = 'Ryan Siddle'
  s.email             = 'ryan@whitestarmedia.co.uk'
  s.homepage          = 'http://www.whitestarmedia.co.uk'

  s.files        = Dir['CHANGELOG', 'README.md', 'LICENSE', 'lib/**/*', 'app/**/*', 'db/**/*', 'public/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.has_rdoc = true

  s.add_dependency('spree_core', '>= 0.60.0')
  s.add_dependency('spree_auth', '>= 0.60.0')
end
