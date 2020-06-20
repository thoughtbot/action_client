module ActionClient
  class Engine < ::Rails::Engine
    config.action_client = ActiveSupport::OrderedOptions.new

    initializer "action_client.dependencies" do |app|
      ActionClient::Base.append_view_path app.paths["app/views"]
      ActionClient::Base.config_path = Pathname(app.paths["config"].first)
    end

    initializer "action_client.middleware" do
      ActionClient::Base.middleware = ActionDispatch::MiddlewareStack.new do |stack|
        stack.use ActionClient::Middleware::Parser, config.action_client
        stack.use Rack::ContentLength
        stack.use Rails::Rack::Logger, [ActionClient::Middleware::Tagger]
      end
    end

    initializer "action_client.routes" do |app|
      unless Rails.env.production?
        app.routes.prepend do
          mount ActionClient::Engine => "/rails/action_client", :as => :action_client_engine
        end
      end
    end
  end
end
