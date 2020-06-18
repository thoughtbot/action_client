module ActionClient
  class Base < AbstractController::Base
    include AbstractController::Rendering
    include ActionView::Layouts
    include ActiveSupport::Callbacks

    abstract!

    define_callbacks :submit

    class_attribute :defaults,
      instance_accessor: true,
      default: ActiveSupport::OrderedOptions.new

    class_attribute :middleware,
      default: ActionDispatch::MiddlewareStack.new

    class_attribute :config_path,
      instance_accessor: true

    class_attribute :submission_job,
      instance_accessor: true,
      default: ActionClient::SubmissionJob

    attr_reader :response

    class << self
      def inherited(descendant)
        descendant.defaults = defaults.dup
        descendant.middleware = middleware.dup
      end

      def configuration
        configuration_path = config_path.join("clients", client_name + ".yml")

        if configuration_path.exist?
          ActiveSupport::InheritableOptions.new(
            Rails.application.config_for(configuration_path).deep_symbolize_keys
          )
        else
          ActiveSupport::OrderedOptions.new
        end
      end

      def default(options)
        options.each do |key, value|
          default_value = defaults[key]

          defaults[key] = case default_value
          when Hash
            default_value.with_indifferent_access.merge(value)
          else
            value
          end
        end
      end

      def after_submit(method_name = nil, only_status: nil, &block)
        http_status_filter = HttpStatusFilter.new(only_status)

        set_callback :submit, :after do
          if http_status_filter.include?(response.status)
            ActionClient::Callback.call(self, @response, method_name || block)
          end
        end
      end

      def client_name
        controller_path.gsub("_client", "")
      end

      def respond_to?(method, *arguments)
        action_methods.include?(method.to_s) || super
      end

      def method_missing(method_name, *arguments)
        if action_methods.include?(method_name.to_s)
          new(middleware).process(method_name, *arguments)
        else
          super
        end
      end

      def respond_to_missing?(method_name, *arguments)
        action_methods.include?(method_name.to_s) || super
      end
    end

    def initialize(middleware)
      super()
      @middleware = middleware.dup
    end

    def process(action_name, *arguments)
      @action_arguments = arguments
      super
    end

    def id
      action_name
    end

    def build_request(method:, path: nil, url: nil, query: {}, headers: {}, **options, &block)
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

        format = if template.handler.is_a?(ActionView::Template::Handlers::Raw)
          identifier = template.identifier
          extension = File.extname(identifier)
          extension.delete_prefix(".")
        elsif template.respond_to?(:format)
          template.format
        else
          template.formats.first
        end

        mime_type = Mime[format]
        if mime_type.present?
          content_type = mime_type.to_s
        end
        body = render(template: template.virtual_path, **options)
      else
        content_type = headers[Rack::CONTENT_TYPE]
        body = ""
      end

      file_extension = File.extname(uri.path).delete_prefix(".")
      accept = Mime[file_extension].to_s

      query_parameters = Rack::Utils.parse_query(uri.query).merge(query)

      payload = CGI.unescapeHTML(body.to_s)

      request = ActionDispatch::Request.new(
        Rack::HTTP_HOST => "#{uri.hostname}:#{uri.port}",
        Rack::PATH_INFO => uri.path,
        Rack::QUERY_STRING => query_parameters.to_query,
        Rack::RACK_INPUT => StringIO.new(payload),
        Rack::RACK_URL_SCHEME => uri.scheme,
        Rack::REQUEST_METHOD => method.to_s.upcase
      )

      headers.with_defaults(
        "Accept" => [accept, content_type].detect(&:present?),
        Rack::CONTENT_TYPE => content_type
      ).each do |key, value|
        request.headers[key] = value
      end

      SubmittableRequest.new(
        @middleware,
        request.env,
        client: self,
        action_arguments: @action_arguments,
        &block
      )
    end

    def submit(request, after_submit: nil, &block)
      run_callbacks(:submit) do
        status, headers, body = block.call

        @response = ActionClient::Response.new(body, status, headers)
      end

      response.tap do
        ActionClient::Callback.call(self, response, after_submit || -> {})
      end
    end

    %i[
      connect
      delete
      get
      head
      options
      patch
      post
      put
      trace
    ].each do |verb|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{verb}(**options, &block)
          build_request(method: #{verb.inspect}, **options, &block)
        end
      RUBY
    end
  end
end
