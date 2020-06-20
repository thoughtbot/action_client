module ActionClient
  class ParseError < ActionClient::Error
    attr_reader :body, :cause, :content_type

    def initialize(cause, body, content_type)
      super(cause.message)
      @cause = cause
      @content_type = content_type
      @body = body
    end
  end
end
