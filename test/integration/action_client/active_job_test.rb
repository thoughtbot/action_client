require "test_helper"
require "active_job_test_case"

module ActionClient
  class ActiveJobTest < ActionClient::ActiveJobTestCase
    # freeze so that test cases don't accidentally leak state across classes
    MetricsClientJob = Class.new(ActionClient::SubmissionJob).freeze
    MetricsClient = Class.new(ActionClient::Base) do
      def ping
        get url: "https://example.com/ping"
      end
    end

    class AfterPerformWithoutOptionsTest < ActiveJobTest
      MetricsClientJob = Class.new(ActionClient::SubmissionJob)

      setup { MetricsClientJob.reset_callbacks(:perform) }

      test "#after_perform without options always executes" do
        stub_request(:get, "https://example.com/ping").to_return(
          headers: { "Content-Type": "application/json" },
          body: { status: "success" }.to_json,
        )
        status, headers, body = []
        MetricsClientJob.after_perform { status, headers, body = *response }

        with_submission_job MetricsClient, MetricsClientJob do
          perform_enqueued_jobs { MetricsClient.ping.submit_later }
        end

        assert_equal 200, status
        assert_equal "application/json", headers["Content-Type"]
        assert_equal "success", body["status"]
      end
    end

    class AfterPerformWithStatusOptionsTest < ActiveJobTest
      MetricsClientJob = Class.new(ActionClient::SubmissionJob)

      setup { MetricsClientJob.reset_callbacks(:perform) }

      test "#after_perform executes a block for matching status codes" do
        status, headers, body = []
        stub_request(:get, "https://example.com/ping").
          to_return(
            headers: { "Content-Type": "application/json" },
            body: { status: "error" }.to_json,
            status: 500
          ).times(1).
          then.to_return(status: 200)
        MetricsClientJob.after_perform(with_status: 400..599) do
          status, headers, body = *response
          retry_job
        end

        with_submission_job MetricsClient, MetricsClientJob do
          perform_enqueued_jobs { MetricsClient.ping.submit_later }
        end

        assert_performed_jobs(2, only: MetricsClientJob)
        assert_requested :get, "https://example.com/ping", times: 2
        assert_equal 500, status
        assert_equal "application/json", headers["Content-Type"]
        assert_equal "error", body["status"]
      end

      test "#after_perform does not execute a block for other status codes" do
        stub_request(:get, "https://example.com/ping").to_return(status: 200)

        with_submission_job MetricsClient, MetricsClientJob do
          perform_enqueued_jobs { MetricsClient.ping.submit_later }
        end

        assert_no_enqueued_jobs
      end
    end
  end
end
