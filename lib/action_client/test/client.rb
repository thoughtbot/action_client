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

      def process(action_name, *arguments, **locals)
        status_code = Rack::Utils.status_code(@status)
        variants = [
          status_code,
          Rack::Utils::SYMBOL_TO_STATUS_CODE.invert[status_code]
        ]

        prefixes = Array(controller_path)
        template = lookup_context.find_template(
          action_name,
          prefixes,
          false,
          [],
          variants: variants
        )
        format = (
          if template.respond_to?(:format)
            template.format
          else
            template.formats.first
          end
        )
        request_options = arguments.extract_options!
        body = render(
          template: template.virtual_path,
          variants: variants,
          locals: locals.with_defaults(request_options).with_defaults(
            arguments: arguments,
            options: request_options
          )
        )

        content_type = request.content_type.presence || (
          if template.handler.is_a?(ActionView::Template::Handlers::Raw)
            nil
          elsif (mime_type = Mime[format])
            mime_type.to_s
          end
        )

        response.status = Rack::Utils.status_code(@status)
        response.headers[Rack::CONTENT_TYPE] = content_type
        response.body = CGI.unescapeHTML(body.to_s.strip)

        self
      end
    end
  end
end
