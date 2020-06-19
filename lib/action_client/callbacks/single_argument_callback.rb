module ActionClient
  module Callbacks
    SingleArgumentCallback = Struct.new(:status, :headers, :body) {
      def call(block)
        modified_body = block.call(body).tap do |response|
          if response.nil?
            raise ActionClient::AfterSubmitError, <<~ERROR
              Callbacks declared with a single argument must return
              a single body value, but this invocation returns nil
            ERROR
          end
        end

        [status, headers, modified_body]
      end
    }
  end
end
