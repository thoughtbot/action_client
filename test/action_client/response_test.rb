require "test_helper"

module ActionClient
  class ResponseTest < ActiveSupport::TestCase
    test ".[] inherits behavior of Rack::Response" do
      response = ActionClient::Response[
        "200",
        {"Content-Type" => "text/plain"},
        "body string",
      ]

      status, headers, body = *response

      assert_equal 200, status
      assert_equal "text/plain", headers["Content-Type"]
      assert_equal "body string", body
    end

    test "#to_a returns a Rack triplet" do
      response = ActionClient::Response.new(
        "body string",
        "200",
        {"Content-Type" => "text/plain"}
      )

      status, headers, body = *response

      assert_equal 200, status
      assert_equal "text/plain", headers["Content-Type"]
      assert_equal "body string", body
    end

    test "#initialize sets a body String, without buffering it" do
      response = ActionClient::Response.new("body string")

      assert_equal 200, response.status
      assert_equal "body string", response.body
    end

    test "#initialize sets a body Hash, without buffering it" do
      response = ActionClient::Response.new({response: "body"})

      assert_equal 200, response.status
      assert_equal "body", response.body.fetch(:response)
    end

    test "#initialize sets a body Array, without buffering it" do
      response = ActionClient::Response.new([{response: "body"}])

      assert_equal 200, response.status
      assert_equal [{response: "body"}], response.body
    end
  end
end
