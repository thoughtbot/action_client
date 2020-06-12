module ActionClient
  class Base < AbstractController::Base
    include AbstractController::Rendering
    include ActionView::Layouts

    class_attribute :defaults,
      instance_accessor: true,
      default: ActiveSupport::OrderedOptions.new

    class << self
      def inherited(descendant)
        descendant.defaults = defaults.dup
      end

      def default(options)
        options.each do |key, value|
          defaults[key] = value
        end
      end

      def method_missing(method_name, *args)
        if action_methods.include?(method_name.to_s)
          instance = self.new(Rails.configuration.action_client.middleware)

          instance.process(method_name, *args)
        else
          super
        end
      end
    end

    def initialize(middleware)
      super()
      @middleware = middleware.dup
    end

    def build_request(method:, path: nil, url: nil, query: {}, headers: {}, **options)
      if path.present? && url.present?
        raise ArgumentError, "either pass only url:, or only path:"
      end

      if path.present? && defaults.url.blank?
        raise ArgumentError, "path: argument without a default url: declared"
      end

      uri = URI(url || defaults.url)

      if path.present?
        uri = URI(File.join(uri.to_s, path.to_s))
      end

      headers = headers.to_h.with_defaults(defaults.headers.to_h)

      template_path = self.class.controller_path
      template_name = action_name
      prefixes = Array(template_path)

      if lookup_context.any_templates?(template_name, prefixes)
        template = lookup_context.find_template(template_name, prefixes)
        format = template.format || :json
        content_type = Mime[format].to_s
        body = render(template: template.virtual_path, formats: format, **options)
      else
        content_type = headers[Rack::CONTENT_TYPE]
        body = ""
      end

      query_parameters = Rack::Utils.parse_query(uri.query).merge(query)

      payload = CGI.unescapeHTML(body.to_s)

      request = ActionDispatch::Request.new(
        Rack::HTTP_HOST => "#{uri.hostname}:#{uri.port}",
        Rack::PATH_INFO => uri.path,
        Rack::QUERY_STRING => query_parameters.to_query,
        Rack::RACK_INPUT => StringIO.new(payload),
        Rack::RACK_URL_SCHEME => uri.scheme,
        Rack::REQUEST_METHOD => method.to_s.upcase,
      )

      headers.with_defaults(
        "Accept" => content_type,
        Rack::CONTENT_TYPE => content_type,
      ).each do |key, value|
        request.headers[key] = value
      end

      SubmittableRequest.new(@middleware, request.env)
    end

    %i(
      connect
      delete
      get
      head
      options
      patch
      post
      put
      trace
    ).each do |verb|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{verb}(**options)
          build_request(method: #{verb.inspect}, **options)
        end
      RUBY
    end
  end
end
