require "test_helper"
require "integration_test_case"

module ActionClient
  class ConfigurationTestCase < ActionClient::IntegrationTestCase
    test "default headers will cascade down the inheritance hierarchy" do
      declare_client "ApplicationClient" do
        default headers: {
          "X-Special": "abc123",
          "Content-Type": "text/plain"
        }
      end
      client = declare_client(inherits: ApplicationClient) {
        default headers: {
          "Content-Type": "application/json"
        }

        def all
          get url: "https://example.com/articles"
        end
      }

      request = client.all

      assert_equal "abc123", request.headers["X-Special"]
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "can read configuration values from a file" do
      declare_config "clients/articles.yml", <<~YAML
        test:
          url: "https://example.com"
      YAML
      client = declare_client("ArticlesClient") {
        default url: configuration.url

        def all
          get path: "articles"
        end
      }

      request = client.all

      assert_equal "https://example.com/articles", request.url
    end

    test "defaults to an empty configuration when a file is not present" do
      client = declare_client("ArticlesClient") {
        default url: configuration.url || "https://example.com"

        def all
          get path: "articles"
        end
      }

      request = client.all

      assert_equal "https://example.com/articles", request.url
    end

    test "declares defaults from configuration when inherited" do
      declare_config "clients/articles.yml", <<~YAML
        test:
          headers:
            X-Special-Key: "abc123"
          url: "https://example.com"
      YAML
      declare_client("ApplicationClient", inherits: ActionClient::Base)
      class ::ArticlesClient < ApplicationClient
        def all
          get path: "articles"
        end
      end

      request = ArticlesClient.all

      assert_equal "https://example.com/articles", request.url
      assert_equal "abc123", request.headers["X-Special-Key"]
    ensure
      Object.send :remove_const, "ArticlesClient"
    end
  end
end
