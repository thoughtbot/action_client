module ActionClient
  class SubmissionJob < ActiveJob::Base
    class HttpStatusMismatchError < ActionClient::Error
    end

    attr_reader :response

    def self.after_perform(only_status: nil, except_status: nil, **options, &block)
      if [only_status, except_status].all?(&:present?)
        raise ArgumentError, "either pass only_status: or except_status:, not both"
      end

      http_status_filter = if only_status.present?
        HttpStatusFilter.new(only_status)
      elsif except_status.present?
        HttpStatusFilter.new(except_status, inclusion: false)
      else
        HttpStatusFilter.new(nil)
      end

      options[:if] = -> { http_status_filter.include?(response.status) }

      super(**options, &block)
    end

    def self.retry_on(*exception_classes, only_status: nil, except_status: nil, **options, &block)
      ([HttpStatusMismatchError] + exception_classes).each do |exception_class|
        super(exception_class, **options, &block)
      end

      if [only_status, except_status].compact.any?
        after_perform(only_status: only_status, except_status: except_status) do
          filter = [only_status, except_status].detect(&:present?)

          raise HttpStatusMismatchError, "#{response.status} does not match #{filter}"
        end
      end
    end

    def perform(client_class_name, action_name, *arguments)
      client_class = client_class_name.constantize

      request = client_class.public_send(action_name, *arguments)

      @response = request.submit_now
    end
  end
end
