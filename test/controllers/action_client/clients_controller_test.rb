require "test_helper"

module ActionClient
  class ClientsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    class ArticlesClient < ActionClient::Base
      def create
      end
    end

    class ArticlesClientPreview < ActionClient::Preview
      def create
      end
    end

    setup do
      @routes = Engine.routes
    end

    test "#index lists available clients" do
      get clients_path

      assert_select(
        %(a[href*="#{client_path(ArticlesClientPreview.preview_name)}"]),
        text: ArticlesClientPreview.preview_name,
      )
    end

    test "#show includes links back to clients#index" do
      get client_path(ArticlesClientPreview.preview_name)

      assert_select(
        %(a[href*="#{clients_path}"]),
        text: ActionClient::Preview.name.pluralize,
      )
    end

    test "#show includes links to available previewed methods" do
      get client_path(ArticlesClientPreview.preview_name)

      assert_select(
        %(a[href*="#{client_preview_path(ArticlesClientPreview.preview_name, "create")}"]),
        text: "create",
      )
    end
  end
end
