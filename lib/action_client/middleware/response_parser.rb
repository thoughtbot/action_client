module ActionClient
  module Middleware
    class ResponseParser
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body_proxy = @app.call(env)
        body = body_proxy.each(&:yield_self).sum
        content_type = headers[Rack::CONTENT_TYPE].to_s

        if body.present?
          if content_type.starts_with?("application/json")
            body = JSON.parse(body)
          elsif content_type.starts_with?("application/xml")
            body = Nokogiri::XML(body)
          else
            body
          end
        end

        [status, headers, body]
      end
    end
  end
end
