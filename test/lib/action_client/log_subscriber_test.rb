require "test_helper"
require "integration_test_case"
require "active_support/log_subscriber/test_helper"

module ActionClient
  class LogSubscriberTest < ActionClient::IntegrationTestCase
    include ActiveSupport::LogSubscriber::TestHelper

    def setup
      super
      ActionClient::LogSubscriber.attach_to :action_client
    end

    test "submit.action_client logs lifecycle events" do
      client = declare_client("ArticlesClient") {
        def all
          get url: "https://example.com/articles"
        end
      }
      stub_request(:get, "https://example.com/articles").to_return(
        body: %({"status": "success"}),
        headers: {"Content-Type": "application/json"}
      )

      client.all.submit
      wait

      assert_logged(:info, "ArticlesClient#all - GET https://example.com/articles")
    end

    def assert_logged(level, message)
      lines = @logger.logged(level)

      messages_in_logs = lines.any? { |line| line.include?(message) }

      assert messages_in_logs, <<~FAIL
        Expected #{level} logs to include:

        #{message.indent(2)}

        but was

        #{lines.map { |line| line.indent(2) }.join("\n")}

      FAIL
    end
  end
end
