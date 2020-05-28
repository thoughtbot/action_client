require "net/http"

module ActionClient
  module Applications
    module Net
      class HttpClient
        def call(env)
          request = ActionDispatch::Request.new(env)
          method = request.request_method.to_s.downcase

          uri = URI(request.original_url)
          request_class = ::Net::HTTP.const_get(method.camelize)
          http_request = request_class.new(uri)

          if request.body.present?
            http_request.body = request.body.read
          end

          ActionClient::Utils.headers_to_hash(request.headers).each do |key, value|
            http_request[key] = value
          end

          response = ::Net::HTTP.start(
            uri.hostname,
            uri.port,
            use_ssl: uri.scheme == "https"
          ) { |http|
            http.request(http_request)
          }

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
