require "test_helper"
require "active_job_test_case"

module ActionClient
  class SubmitLaterTest < ActionClient::ActiveJobTestCase
    MetricsClient = Class.new(ActionClient::Base) do
      def ping(path = "ping", **options)
        get url: "https://example.com/#{path}", query: options
      end
    end

    MetricsClientJob = Class.new(ActionClient::SubmissionJob)

    test "#submit_later enqueues a Job with arguments and options" do
      stub_request(:get, "https://example.com/special-ping?status=special")
      request = MetricsClient.ping("special-ping", status: :special)

      perform_enqueued_jobs { request.submit_later }

      assert_requested :get, "https://example.com/special-ping?status=special", times: 1
    end

    test "#submit_later enqueues an ActiveJob::Job to execute the request" do
      stub_request(:get, "https://example.com/ping")

      perform_enqueued_jobs { MetricsClient.ping.submit_later }

      assert_requested :get, "https://example.com/ping", times: 1
    end

    test "#submit_later forwards options along when scheduling the ActiveJob::Job" do
      MetricsClient.ping.submit_later(queue: "requests")

      assert_enqueued_with job: ActionClient::SubmissionJob, queue: "requests"
    end

    test "#submit_later enqueues a different job class" do
      with_submission_job MetricsClient, MetricsClientJob do
        MetricsClient.ping.submit_later

        assert_enqueued_with(job: MetricsClientJob)
      end
    end
  end
end
