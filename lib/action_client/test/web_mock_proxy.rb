module ActionClient
  module Test
    class WebMockProxy
      delegate_missing_to :webmock

      def self.stub_request(request)
        request_method = request.method.downcase.to_sym
        request_body = request.body.read

        webmock = WebMock::API.stub_request(request_method, request.url)

        if request_body.present?
          webmock.with(body: request_body)
        end

        new(webmock, request)
      end

      def initialize(webmock, request)
        @webmock = webmock
        @request = request
      end

      def to_return(*arguments, **options, &block)
        if (mime_type = request.headers["Accept"])
          options[:headers] ||= {}
          options[:headers].with_defaults!(Rack::CONTENT_TYPE => mime_type)
        end

        webmock.to_return(*arguments, **options, &block)

        self
      end

      def to_fixture(locals: {}, status: 200, **options)
        fixture_client = ActionClient::Test::Client.new(request, status)
        fixture_client.process(locals)

        status, headers, body = *fixture_client.response

        options[:status] = status
        options[:body] = body
        options[:headers] ||= {}
        options[:headers].with_defaults!(headers)

        webmock.to_return(options)

        self
      end

      private

      attr_reader :request
      attr_reader :webmock
    end
  end
end
