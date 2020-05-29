module ActionClient
  module TestHelpers
    include ActiveJob::TestHelper

    def stub_request(request, *arguments)
      if request.is_a?(SubmittableRequest)
        ActionClient::Test::WebMockProxy.stub_request(request)
      else
        WebMock::API.stub_request(request, *arguments)
      end
    end

    def a_request(request, uri = nil)
      delegated_arguments = if request.is_a?(SubmittableRequest)
        [request.method.downcase.to_sym, request.url]
      else
        [request, uri]
      end

      WebMock::API.a_request(*delegated_arguments)
    end

    def assert_requested(request, *arguments, &block)
      delegated_arguments = if request.is_a?(SubmittableRequest)
        [
          request.method.downcase.to_sym,
          request.url,
          *arguments
        ]
      else
        [request] + arguments
      end

      WebMock::API.assert_requested(*delegated_arguments, &block)
    end

    def assert_not_requested(request, *arguments, &block)
      delegated_arguments = if request.is_a?(SubmittableRequest)
        [
          request.method.downcase.to_sym,
          request.url,
          *arguments
        ]
      else
        [request] + arguments
      end

      WebMock::API.assert_not_requested(*delegated_arguments, &block)
    end

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
