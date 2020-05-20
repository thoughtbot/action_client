module ActionClient
  module Middleware
    Tagger = proc do |request|
      "ActionClient - #{request.request_method} - #{request.original_url}"
    end
  end
end
