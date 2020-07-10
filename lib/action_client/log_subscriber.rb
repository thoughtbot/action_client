module ActionClient
  class LogSubscriber < ActiveSupport::LogSubscriber
    def submit(event)
      client = event.payload[:client]
      action_name = event.payload[:action_name]
      request = event.payload[:request]
      action_name = "#{client.class}##{action_name}"
      http = "#{request.method} #{request.url}"

      info "#{action_name} - #{http} #{duration(event)}"
    end

    private

    def duration(event)
      "(Duration #{event.duration.truncate(2)}ms)"
    end
  end
end
