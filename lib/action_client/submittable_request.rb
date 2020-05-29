module ActionClient
  class SubmittableRequest < ActionDispatch::Request
    def initialize(stack, env, client:, action_arguments:)
      super(env)
      @stack = stack
      @client = client
      @action_arguments = action_arguments
    end

    def submit
      app = @stack.build(ActionClient::Applications::Net::HttpClient.new)

      status, headers, body = app.call(env)

      ActionClient::Response.new(body, status, headers)
    end
    alias_method :submit_now, :submit

    def submit_later(**options)
      @client.submission_job.set(options).perform_later(
        @client.class.name,
        @client.action_name,
        *@action_arguments,
      )
    end
  end
end
