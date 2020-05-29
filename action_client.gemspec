$:.push File.expand_path("lib", __dir__)

# Maintain your gem's version:
require "action_client/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "action_client"
  spec.version     = ActionClient::VERSION
  spec.authors     = ["Sean Doyle"]
  spec.email       = ["sean.p.doyle24@gmail.com"]
  spec.homepage    = "https://github.com/seanpdoyle/action_client"
  spec.summary     = "HTTP Clients, the Rails way"
  spec.description = "Write HTTP clients in the style of Controllers and Mailers"
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", ">= 4.2.0"
end
