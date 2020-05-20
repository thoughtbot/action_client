module ActionClient
  class SubmittableRequest < ActionDispatch::Request
    def initialize(stack, env)
      super(env)
      @stack = stack
    end

    def submit
      app = @stack.build(ActionClient::Applications::Net::HttpClient.new)

      app.call(env)
    end
  end
end
