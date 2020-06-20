module ActionClient
  class SubmittableRequest < ActionDispatch::Request
    attr_reader :client

    def initialize(stack, env, client:, &block)
      super(env)
      @stack = stack
      @client = client
      @block = block
    end

    def submit
      app = @stack.build(ActionClient::Applications::Net::HttpClient.new)

      @client.submit(self, after_submit: @block) { app.call(env) }
    end
    alias submit_now submit

    def submit_later(**options)
      client.enqueue_job(options)
    end
  end
end
