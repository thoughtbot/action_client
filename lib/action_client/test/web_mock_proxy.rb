module ActionClient
  module Test
    class WebMockProxy < SimpleDelegator
      def self.stub_request(request)
        request_method = request.method.downcase.to_sym

        webmock_chain = WebMock::API.stub_request(request_method, request.url)

        new(
          action_name: request.client.action_name,
          arguments: request.client.action_arguments,
          request: request,
          webmock_chain: webmock_chain
        ).with(request: request)
      end

      def initialize(action_name:, arguments:, request:, webmock_chain:)
        super(webmock_chain)
        @arguments = arguments
        @action_name = action_name
        @request = request
      end

      def with(request: nil, **options, &block)
        if request
          options[:body] = request.body.read
        end

        chain(webmock.with(**options, &block))
      end

      def to_return(*arguments, **options, &block)
        if (mime_type = @request.headers["Accept"])
          options[:headers] ||= {}
          options[:headers].with_defaults!(Rack::CONTENT_TYPE => mime_type)
        end

        chain(webmock.to_return(*arguments, **options, &block))
      end

      def to_fixture(locals: {}, status: 200, **options)
        client = ActionClient::Test::Client.new(@request, status)

        client.process(@request.client.action_name, *@arguments, **locals)

        status, headers, body = *client.response

        options[:status] = status
        options[:body] = body
        options[:headers] ||= {}
        options[:headers].with_defaults!(headers)

        chain(webmock.to_return(options))
      end

      private

      alias webmock __getobj__

      def chain(webmock_chain)
        WebMockProxy.new(
          arguments: @arguments,
          request: @request,
          webmock_chain: webmock_chain,
          action_name: @action_name
        )
      end
    end
  end
end
