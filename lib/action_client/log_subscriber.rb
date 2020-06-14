module ActionClient
  class LogSubscriber < ActiveSupport::LogSubscriber
    def submit(event)
      client = event.payload[:client]
      action_name = event.payload[:action_name]
      request = event.payload[:request]
      action_name = color("#{client.class}##{action_name}", CYAN, true)
      http = color("#{request.method} #{request.url}", CYAN, true)

      info "#{action_name} - #{http} - #{duration(event)}"
    end

    private

    def duration(event)
      "(Duration #{event.duration.truncate(2)}ms)"
    end
  end
end
