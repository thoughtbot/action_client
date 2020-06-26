module ActionClient
  module Test
    class Client < AbstractController::Base
      include AbstractController::Rendering
      include ActionView::Layouts

      attr_reader :request
      attr_reader :response

      def initialize(request, status)
        @request = request
        @response = ActionClient::Response.new
        @status = status
      end

      def controller_path
        request.client.controller_path
      end

      def process(action_name, *arguments, **options)
        status_code = Rack::Utils.status_code(@status)
        template = ActionClient::Template.find(
          request.client,
          renderer: self,
          variants: [
            status_code,
            Rack::Utils::SYMBOL_TO_STATUS_CODE.invert[status_code]
          ]
        )

        request_options = arguments.extract_options!

        locals = options.with_defaults(request_options).with_defaults(
          arguments: arguments,
          options: request_options
        )

        content_type = request.content_type.presence || template.content_type

        response.status = Rack::Utils.status_code(@status)
        response.headers[Rack::CONTENT_TYPE] = content_type
        response.body = template.render(locals: locals)

        self
      end
    end
  end
end
