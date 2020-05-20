require "net/http"

module ActionClient
  module Applications
    module Net
      class HttpClient
        def call(env)
          request = ActionDispatch::Request.new(env)
          method = request.request_method.to_s.downcase

          response = ::Net::HTTP.public_send(
            method,
            URI(request.original_url),
            request.body.read,
            ActionClient::Utils.headers_to_hash(request.headers),
          )

          ActionDispatch::Response.new(
            response.code,
            response.each_header.to_h.transform_keys { |key| key.titleize.gsub(" ", "-") },
            Array(response.body),
          ).to_a
        end
      end
    end
  end
end
