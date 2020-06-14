module ActionClient
  class HttpStatusFilter
    delegate_missing_to :status_codes

    def initialize(http_status)
      @status_codes = Array(http_status || (100..599)).map do |status|
        Rack::Utils.status_code(status)
      end
    end

    private

    attr_reader :status_codes
  end
end
