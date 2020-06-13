require "test_helper"

module ActionClient
  class ResponseTest < ActiveSupport::TestCase
    test ".[] inherits behavior of Rack::Response" do
      response = ActionClient::Response[
        "200",
        {"Accept" => "text/plain"},
        "body string",
      ]

      status, headers, body = *response

      assert_equal 200, status
      assert_equal "text/plain", headers["Accept"]
      assert_equal "body string", body
    end

    test "#initialize sets a body String, without buffering it" do
      response = ActionClient::Response.new("body string")

      status, headers, body = *response

      assert_equal 200, status
      assert_equal "body string", body
    end

    test "#initialize sets a body Hash, without buffering it" do
      response = ActionClient::Response.new({response: "body"})

      status, headers, body = *response

      assert_equal 200, status
      assert_equal "body", body.fetch(:response)
    end

    test "#initialize sets a body Array, without buffering it" do
      response = ActionClient::Response.new([{response: "body"}])

      status, headers, body = *response

      assert_equal 200, status
      assert_equal [{response: "body"}], body
    end
  end
end
