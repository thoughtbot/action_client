module ActionClient
  class Engine < ::Rails::Engine
    config.action_client = ActiveSupport::OrderedOptions.new

    initializer "action_client.dependencies" do |app|
      ActionClient::Base.append_view_path app.paths["app/views"]
    end

    initializer "action_client.middleware" do
      config.action_client.middleware = ActionDispatch::MiddlewareStack.new do |stack|
        stack.use ActionClient::Middleware::ResponseParser
        stack.use Rack::ContentLength
        stack.use Rails::Rack::Logger, [ActionClient::Middleware::Tagger]
      end
    end

    initializer "action_client.routes" do |app|
      unless Rails.env.production?
        app.routes.prepend do
          mount ActionClient::Engine => "/rails/action_client", as: :action_client_engine
        end
      end
    end
  end
end
