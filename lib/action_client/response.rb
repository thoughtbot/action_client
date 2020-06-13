module ActionClient
  class Response < Rack::Response
    def initialize(body = nil, *arguments)
      super

      self.body = body
    end
  end
end
