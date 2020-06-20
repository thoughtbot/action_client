require "test_helper"

module ActionClient
  module Middleware
    class ParserTest < ActiveSupport::TestCase
      test "#call infers missing Content-Type based on the request's Accept header" do
        payload = %({"response": true})
        middleware = ActionClient::Middleware::Parser.new(build_app({}))

        *, body = middleware.call({
          "HTTP_ACCEPT" => "application/json",
          Rack::RACK_INPUT => payload.lines
        })

        assert_equal true, body.fetch("response")
      end

      test "#call skips empty Response body Strings" do
        payload = ""
        app = build_app(Rack::CONTENT_TYPE => "text/plain")
        middleware = ActionClient::Middleware::Parser.new app,
          parsers: {"text/plain": ->(*) { raise }}

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal "", body
      end

      test "#call can decode arbitrary content types" do
        payload = "response"
        app = build_app(Rack::CONTENT_TYPE => "text/plain")
        middleware = ActionClient::Middleware::Parser.new app,
          parsers: {"text/plain": ->(body) { body.upcase }}

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal "RESPONSE", body
      end

      test "#call can decode content types with parameter values" do
        payload = "response"
        app = build_app(Rack::CONTENT_TYPE => "text/plain;charset=UTF-8")
        middleware = ActionClient::Middleware::Parser.new(
          app,
          parsers: {
            "text/plain": ->(*) { raise },
            "text/plain;charset=UTF-8": ->(body) { body.upcase }
          }
        )

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal "RESPONSE", body
      end

      test "#call can decode content types with ignored parameter values" do
        payload = "response"
        app = build_app(Rack::CONTENT_TYPE => "text/plain;charset=UTF-8")
        middleware = ActionClient::Middleware::Parser.new(
          app,
          parsers: {
            "text/plain": ->(body) { body.upcase }
          }
        )

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal "RESPONSE", body
      end

      test "#call does not find partial content type matches" do
        payload = "response"
        app = build_app(Rack::CONTENT_TYPE => "application/x-shockwave-flash")
        middleware = ActionClient::Middleware::Parser.new(
          app,
          parsers: {
            "application/x-sh": ->(*) { raise }
          }
        )

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal payload, body
      end

      test "#call can handle errors from an arbitrary content type" do
        app = build_app(Rack::CONTENT_TYPE => "text/plain")
        payload = "response"
        middleware = ActionClient::Middleware::Parser.new(
          app,
          parsers: {
            "text/plain": ->(*) { raise ArgumentError, "whoops" }
          }
        )

        exception = assert_raises(ActionClient::ParseError) {
          middleware.call(Rack::RACK_INPUT => payload.lines)
        }
        assert_includes exception.message, "whoops"
        assert_equal payload, exception.body, payload
        assert_equal "text/plain", exception.content_type
      end

      test "#call decodes application/json to JSON" do
        payload = %({"response": true})
        app = build_app(Rack::CONTENT_TYPE => "application/json")
        middleware = ActionClient::Middleware::Parser.new(app)

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal true, body.fetch("response")
      end

      test "#call decodes application/ld+json to JSON" do
        payload = %({"response": true})
        app = build_app(Rack::CONTENT_TYPE => "application/ld+json")
        middleware = ActionClient::Middleware::Parser.new(app)

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal true, body.fetch("response")
      end

      test "#call parses JSON into HashWithIndifferentAccess instances" do
        app = build_app(Rack::CONTENT_TYPE => "application/json")
        middleware = ActionClient::Middleware::Parser.new(app)
        payload = %([{ "nested": {"response": true} }])

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal true, body.first.dig(:nested, :response)
      end

      test "#call raises ActionClient::ParseError when decoding invalid JSON" do
        payload = "junk"
        app = build_app(Rack::CONTENT_TYPE => "application/json")
        middleware = ActionClient::Middleware::Parser.new(app)

        assert_raises ActionClient::ParseError do
          middleware.call(Rack::RACK_INPUT => payload.lines)
        end
      end

      test "#call decodes application/xml to XML" do
        payload = %(<node id="root"></node>)
        app = build_app(Rack::CONTENT_TYPE => "application/xml")
        middleware = ActionClient::Middleware::Parser.new(app)

        *, document = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal "node", document.root.name
        assert_equal "root", document.root["id"]
      end

      test "#call can resolve synonymous content types" do
        payload = %( <node id="root"></node> )
        app = build_app(Rack::CONTENT_TYPE => "text/xml")
        middleware = ActionClient::Middleware::Parser.new app,
          parsers: {"application/xml": ->(body) { body.strip }}

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal payload.strip, body
      end

      test "#call raises ActionClient::ParseError when decoding invalid XML" do
        payload = "junk"
        app = build_app(Rack::CONTENT_TYPE => "application/xml")
        middleware = ActionClient::Middleware::Parser.new(app)

        assert_raises ActionClient::ParseError do
          middleware.call(Rack::RACK_INPUT => payload.lines)
        end
      end

      test "#call does not decode a body without a matching header" do
        payload = "plain-text"
        app = build_app
        middleware = ActionClient::Middleware::Parser.new(app)

        *, body = middleware.call(Rack::RACK_INPUT => payload.lines)

        assert_equal payload, body
      end

      def build_app(headers = {})
        ->(env) { [200, headers, env[Rack::RACK_INPUT]] }
      end
    end
  end
end
