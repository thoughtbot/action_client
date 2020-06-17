module ActionClient
  class SubmittableRequest < ActionDispatch::Request
    def initialize(stack, env, client:, action_arguments:, &block)
      super(env)
      @stack = stack
      @client = client
      @action_arguments = action_arguments
      @block = block
    end

    def submit
      app = @stack.build(ActionClient::Applications::Net::HttpClient.new)

      @client.submit(self, after_submit: @block) { app.call(env) }
    end
    alias submit_now submit

    def submit_later(**options)
      @client.submission_job.set(options).perform_later(
        @client.class.name,
        @client.action_name.to_s,
        *@action_arguments
      )
    end
  end
end
