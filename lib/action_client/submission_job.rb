module ActionClient
  class SubmissionJob < ActiveJob::Base
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

    def perform(client_class_name, action_name, *arguments)
      client_class = client_class_name.constantize

      request = client_class.public_send(action_name, *arguments)

      @response = request.submit_now
    end
  end
end
