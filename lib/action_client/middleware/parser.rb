module ActionClient
  module Middleware
    class Parser
      JsonParser = proc do |body|
        JSON.parse(body, object_class: HashWithIndifferentAccess)
      end
      XmlParser = proc do |body|
        Nokogiri::XML.parse(body).tap do |document|
          document.validate

          document.errors.each do |error|
            if error.is_a?(Nokogiri::XML::SyntaxError)
              raise error
            end
          end
        end
      end

      class_attribute :parsers, default: {
        "application/json" => JsonParser,
        "application/ld+json" => JsonParser,
        "application/xml" => XmlParser
      }.with_indifferent_access.freeze

      def initialize(app, configuration = {})
        @app = app
        @parsers = self.class.parsers.merge(configuration.fetch(:parsers, {}))
      end

      def call(env)
        request = ActionDispatch::Request.new(env)
        status, headers, body_proxy = @app.call(env)
        body = body_proxy.each(&:yield_self).join
        content_type = headers.fetch(
          Rack::CONTENT_TYPE,
          request.headers["Accept"]
        ).to_s

        if body.present?
          parser = fetch_parser_for_content_type(content_type)

          begin
            [status, headers, parser.call(body)]
          rescue => error
            raise ActionClient::ParseError.new(error, body, content_type)
          end
        else
          [status, headers, body]
        end
      end

      private

      attr_reader :parsers

      def fetch_parser_for_content_type(content_type)
        parsers.fetch(content_type) do
          normalized_parsers.fetch(normalize(content_type))
        end
      rescue *lookup_errors
        if has_parameters?(content_type)
          fetch_parser_for_content_type(before_parameters(content_type))
        else
          :itself.to_proc
        end
      end

      def lookup_errors
        if defined? Mime::Type::InvalidMimeType
          [Mime::Type::InvalidMimeType, KeyError]
        else
          [KeyError]
        end
      end

      def normalized_parsers
        parsers.transform_keys { |content_type| normalize(content_type) }
      end

      def normalize(content_type)
        Mime::Type.lookup(content_type).to_s
      end

      def has_parameters?(content_type)
        content_type.include?(";")
      end

      def before_parameters(content_type)
        before, _ = content_type.partition(";")

        before
      end
    end
  end
end
