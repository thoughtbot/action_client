module ActionClient
  class SubmittableRequest < ActionDispatch::Request
    def initialize(stack, env)
      super(env)
      @stack = stack
    end

    def submit
      app = @stack.build(ActionClient::Applications::Net::HttpClient.new)

      status, headers, body = app.call(env)

      ActionClient::Response.new(body, status, headers)
    end
  end
end
