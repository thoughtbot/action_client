module ActionClient
  class Engine < ::Rails::Engine
    config.action_client = ActiveSupport::InheritableOptions.new(
      enable_previews: !Rails.env.production?,
      previews_path: "test/clients/previews"
    )

    initializer "action_client.dependencies" do |app|
      ActionClient::Base.append_view_path app.paths["app/views"]
      ActionClient::Base.config_path = Pathname(app.paths["config"].first)
    end

    initializer "action_client.middleware" do
      ActionClient::Base.middleware = ActionDispatch::MiddlewareStack.new do |stack|
        stack.use ActionClient::Middleware::Parser, config.action_client
        stack.use Rack::ContentLength
      end
    end

    initializer "action_client.logging" do
      ActionClient::LogSubscriber.attach_to :action_client
    end

    initializer "action_client.routes" do |app|
      if config.action_client.enable_previews
        ActionClient::Preview.previews_path = config.action_client.previews_path

        app.routes.prepend do
          mount ActionClient::Engine => "/rails/action_client", :as => :action_client_engine
        end
      end
    end
  end
end
