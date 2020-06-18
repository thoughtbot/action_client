module ActionClient
  class HttpStatusFilter
    def initialize(http_status, inclusion: true)
      @http_status = http_status
      @inclusion = inclusion
    end

    def include?(matching_status)
      code = to_code(matching_status)

      included = if status_codes.respond_to?(:cover?)
        status_codes.cover? code
      else
        status_codes.include? code
      end

      if inclusion
        included
      else
        !included
      end
    end

    private

    attr_reader :http_status, :inclusion

    def status_codes
      case http_status
      when nil
        100..599
      when Range
        http_status
      else
        Array(http_status).map { |status| to_code(status) }
      end
    end

    def to_code(status)
      Rack::Utils.status_code(status)
    end
  end
end
