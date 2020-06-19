require "test_helper"

module ActionClient
  module Middleware
    class ResponseParserTest < ActiveSupport::TestCase
      test "#call decodes application/json to JSON" do
        payload = %({"response": true})
        app = proc do |env|
          [
            200,
            {Rack::CONTENT_TYPE => "application/json"},
            env[Rack::RACK_INPUT]
          ]
        end
        middleware = ActionClient::Middleware::ResponseParser.new(app)

        *, body = middleware.call({
          Rack::RACK_INPUT => payload.lines
        })

        assert_equal({"response" => true}, body)
      end

      test "#call decodes application/xml to XML" do
        payload = %(<node id="root"></node>)
        app = proc do |env|
          [
            200,
            {Rack::CONTENT_TYPE => "application/xml"},
            env[Rack::RACK_INPUT]
          ]
        end
        middleware = ActionClient::Middleware::ResponseParser.new(app)

        *, document = middleware.call({
          Rack::RACK_INPUT => payload.lines
        })

        assert_equal "node", document.root.name
        assert_equal "root", document.root["id"]
      end

      test "#call does not decodes a body without a matching header" do
        payload = "plain-text"
        app = proc do |env|
          [
            200,
            {},
            env[Rack::RACK_INPUT]
          ]
        end
        middleware = ActionClient::Middleware::ResponseParser.new(app)

        *, body = middleware.call({
          Rack::RACK_INPUT => payload.lines
        })

        assert_equal payload, body
      end
    end
  end
end
