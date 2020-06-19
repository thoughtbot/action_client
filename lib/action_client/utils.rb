module ActionClient
  class Utils
    def self.headers_to_hash(rack_headers)
      rack_headers.each_with_object({}) do |(key, value), rewritten_headers|
        if key.starts_with?("HTTP_") || ActionDispatch::Http::Headers::CGI_VARIABLES.include?(key)
          rewritten_headers.merge!(titlecase_keys(key => value))
        end
      end
    end

    def self.titlecase_keys(headers)
      headers.reduce({}) do |rewritten_headers, (key, value)|
        formatted_key = key.delete_prefix("HTTP_").titleize.tr(" ", "-")

        rewritten_headers.merge(formatted_key => value)
      end
    end
  end
end
