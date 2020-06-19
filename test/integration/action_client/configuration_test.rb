require "test_helper"
require "integration_test_case"

module ActionClient
  class ConfigurationTestCase < ActionClient::IntegrationTestCase
    test "can read configuration values from a file" do
      declare_config "clients/articles.yml", <<~YAML
        test:
          url: "https://example.com"
      YAML
      client = declare_client "articles_client" do
        default url: configuration.url

        def all
          get path: "articles"
        end
      end

      request = client.all

      assert_equal "https://example.com/articles", request.url
    end

    test "defaults to an empty configuration when a file is not present" do
      client = declare_client "articles_client" do
        default url: configuration.url || "https://example.com"

        def all
          get path: "articles"
        end
      end

      request = client.all

      assert_equal "https://example.com/articles", request.url
    end
  end
end
