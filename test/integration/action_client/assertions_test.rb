require "test_helper"
require "integration_test_case"

module ActionClient
  class AssertionsTest < IntegrationTestCase
    include ActionClient::TestHelpers

    test "integrates with Webmock's assert_requested methods" do
      client = declare_client {
        def all
          get url: "https://example.com/articles"
        end
      }
      stub_request(:get, "https://example.com/articles")

      client.all.submit

      assert_requested client.all, times: 1
    end

    test "integrates with Webmock's assert_not_requested methods" do
      client = declare_client {
        def all
          get url: "https://example.com/articles"
        end

        def destroy
          delete url: "https://example.com/articles/1"
        end
      }
      stub_request(:any, "https://example.com/articles")

      client.all.submit

      assert_requested client.all, times: 1
      assert_not_requested client.destroy, times: 1
    end

    test "falls back to Webmock's assert_requested methods" do
      client = declare_client {
        def all
          get url: "https://example.com/articles"
        end
      }
      stub_request(:get, "https://example.com/articles")

      client.all.submit

      assert_requested :get, "https://example.com/articles", times: 1
    end

    test "falls back to Webmock's assert_not_requested methods" do
      client = declare_client {
        def all
          get url: "https://example.com/articles"
        end

        def destroy
          delete url: "https://example.com/articles/1"
        end
      }
      stub_request(:get, "https://example.com/articles")

      client.all.submit

      assert_not_requested :delete, "https://example.com/articles/1"
    end
  end
end
