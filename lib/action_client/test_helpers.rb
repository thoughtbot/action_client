module ActionClient
  module TestHelpers
    include ActiveJob::TestHelper

    def assert_enqueued_request(request, **options, &block)
      client = request.client

      assert_enqueued_with(
        job: client.submission_job,
        args: [client.class.name, client.action_name, *client.action_arguments],
        **options,
        &block
      )
    end

    def assert_no_requests_enqueued(client_class = ActionClient::Base, **options, &block)
      job_class = client_class.submission_job

      assert_no_enqueued_jobs(only: job_class, **options, &block)
    end

    def assert_performed_request(request, **options, &block)
      client = request.client

      assert_performed_with(
        job: client.submission_job,
        args: [client.class.name, client.action_name, *client.action_arguments],
        **options,
        &block
      )
    end

    def assert_no_performed_requests(client_class = ActionClient::Base, **options, &block)
      job_class = client_class.submission_job

      assert_no_performed_jobs(only: job_class, **options, &block)
    end
  end
end
