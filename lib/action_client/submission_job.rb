module ActionClient
  class SubmissionJob < ActiveJob::Base
    attr_reader :response

    def self.after_perform(with_status: nil, **options, &block)
      if with_status.present?
        filter = proc do
          HttpStatusFilter.new(with_status).include?(response.status)
        end

        super(if: filter, **options, &block)
      else
        super(**options, &block)
      end
    end

    def perform(client_class_name, action_name, *arguments)
      client_class = client_class_name.constantize

      request = client_class.public_send(action_name, *arguments)

      @response = request.submit_now
    end
  end
end
