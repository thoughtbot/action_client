require "test_helper"
require "integration_test_case"

module ActionClient
  class InstrumentationTest < ActionClient::IntegrationTestCase
    test "instruments submit.action_client during submission" do
      client = declare_client {
        def all(**query)
          get url: "https://example.com/articles", query: query
        end
      }
      stub_request(:get, "https://example.com/articles?page=1")
      assertions = proc do |name, start, finish, id, payload|
        assert_predicate finish - start, :positive?
        assert_kind_of client, payload[:client]
        assert_equal "GET", payload[:request].request_method
        assert_equal "all", payload[:action_name]
        assert_equal [{page: 1}], payload[:action_arguments]
      end

      ActiveSupport::Notifications.subscribed(assertions, "submit.action_client") do
        client.all(page: 1).submit
      end
    end

    test "instruments http_request.action_client during submission" do
      client = declare_client {
        def all
          get url: "https://example.com/articles"
        end
      }
      stub_request(:get, "https://example.com/articles")
      assertions = proc do |name, start, finish, id, payload|
        assert_predicate finish - start, :positive?
        assert_equal "GET", payload[:method]
        assert_equal URI("https://example.com/articles"), payload[:uri]
        assert_includes payload, :http_request
      end

      ActiveSupport::Notifications.subscribed(assertions, "http_request.action_client") do
        client.all.submit
      end
    end

    test "instruments parse.action_client during submission" do
      client = declare_client {
        def all
          get url: "https://example.com/articles"
        end
      }
      stub_request(:get, "https://example.com/articles").and_return(
        headers: {"Content-Type": "application/json"},
        body: %({"status": "success"})
      )
      assertions = proc do |name, start, finish, id, payload|
        assert_predicate finish - start, :positive?
        assert_equal "application/json", payload[:content_type]
        assert_equal %({"status": "success"}), payload[:body]
      end

      ActiveSupport::Notifications.subscribed(assertions, "parse.action_client") do
        client.all.submit
      end
    end
  end
end
