require "test_helper"
require "template_test_helpers"

module ActionClient
  class PreviewsControllerTest < ActionDispatch::IntegrationTest
    include TemplateTestHelpers
    include Engine.routes.url_helpers

    class ArticleClient < ActionClient::Base
      def create(title:)
        post url: "https://example.com/articles", locals: { title: title }
      end
    end

    class ArticlesClientPreview < ActionClient::Preview
      def create
        ArticleClient.create(title: "Hello, World")
      end
    end

    setup do
      @routes = Engine.routes
    end

    test "action_client/previews displays information about the request" do
      declare_template "action_client/previews_controller_test/article_client/create.json.erb", <<~ERB
      {"title": "<%= title %>"}
      ERB

      get client_preview_path(ArticlesClientPreview.preview_name, "create")

      assert_select "#url", text: "\nPOST https://example.com/articles\n"
      assert_select "#body", text: JSON.pretty_generate({ title: "Hello, World" })
    end

    test "action_client/previews omits body when a template is not declared" do
      get client_preview_path(ArticlesClientPreview.preview_name, "create")

      assert_select "#body", count: 0
    end
  end
end
