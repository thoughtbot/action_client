module ActionClient
  module Callbacks
    TripleArgumentCallback = Struct.new(:status, :headers, :body) {
      def call(block)
        block.call(status, headers, body).tap do |response|
          response = Array(response)

          if response.length != 3
            raise ActionClient::AfterSubmitError, <<~ERROR
              Callbacks declared with three arguments must return a Rack triplet,
              but this invocation only returns #{response.length}:

                #{response.inspect}

            ERROR
          end
        end
      end
    }
  end
end
