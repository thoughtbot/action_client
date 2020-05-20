require "test_helper"

module ActionClient
  module Applications
    module Net
      class HttpClientTest < ActiveSupport::TestCase
        test "#submit sends a POST request" do
          uri = URI("https://www.example.com/articles")
          stub_request(:any, Regexp.new(uri.hostname)).and_return(
            body: %({"responded": true}),
            status: 201,
          )
          payload = %({"requested": true})
          adapter = ActionClient::Applications::Net::HttpClient.new
          request = ActionDispatch::Request.new(
            Rack::RACK_URL_SCHEME => uri.scheme,
            Rack::HTTP_HOST => uri.hostname,
            Rack::REQUEST_METHOD => "POST",
            Rack::PATH_INFO => uri.path,
            Rack::RACK_INPUT => StringIO.new(payload),
            "CONTENT_TYPE" => "application/json",
          )

          code, _, body = adapter.call(request.env)

          assert_equal %({"responded": true}), body.each(&:yield_self).sum
          assert_equal 201, code
          assert_requested :post, uri, {
            body: %({"requested": true}),
            headers: {
              "Content-Type" => "application/json",
            },
          }
        end
      end
    end
  end
end
