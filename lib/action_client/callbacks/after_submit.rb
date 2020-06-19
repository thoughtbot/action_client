module ActionClient
  module Callbacks
    class AfterSubmit
      def initialize(app, matching_status_codes = nil, &block)
        @app = app
        @http_status_filter = HttpStatusFilter.new(matching_status_codes)
        @block = block
      end

      def call(env)
        status_code, headers, body = app.call(env)

        if http_status_filter.include?(status_code)
          callback = callback_factory.new(status_code, headers, body)

          callback.call(block)
        else
          [status_code, headers, body]
        end
      end

      private

      attr_reader :app, :block, :http_status_filter

      def callback_factory
        if block.arity == 1
          SingleArgumentCallback
        else
          TripleArgumentCallback
        end
      end
    end
  end
end
