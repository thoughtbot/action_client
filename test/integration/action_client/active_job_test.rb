require "test_helper"
require "active_job_test_case"

module ActionClient
  class ActiveJobTest < ActionClient::ActiveJobTestCase
    # freeze so that test cases don't accidentally leak state across classes
    MetricsClientJob = Class.new(ActionClient::SubmissionJob).freeze
    MetricsClient = Class.new(ActionClient::Base) {
      def ping
        get url: "https://example.com/ping"
      end
    }

    class AfterPerformWithoutOptionsTest < ActiveJobTest
      MetricsClientJob = Class.new(ActionClient::SubmissionJob)

      setup { MetricsClientJob.reset_callbacks(:perform) }

      test ".after_perform without options always executes" do
        stub_request(:get, "https://example.com/ping").to_return(
          headers: {"Content-Type": "application/json"},
          body: {status: "success"}.to_json
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

      test ".after_perform executes a block when the status codes match only_status:" do
        status, headers, body = []
        stub_request(:get, "https://example.com/ping")
          .to_return(
            headers: {"Content-Type": "application/json"},
            body: {status: "error"}.to_json,
            status: 500
          ).times(1)
          .then.to_return(status: 200)
        MetricsClientJob.after_perform(only_status: 400..599) do
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

      test ".after_perform executes a block when the status codes does not match except_status:" do
        status, headers, body = []
        stub_request(:get, "https://example.com/ping")
          .to_return(
            headers: {"Content-Type": "application/json"},
            body: {status: "error"}.to_json,
            status: 500
          ).times(1)
          .then.to_return(status: 200)
        MetricsClientJob.after_perform(except_status: 200) do
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

      test ".after_perform skips execution of blocks when the status code does not match only_status:" do
        stub_request(:get, "https://example.com/ping").to_return(status: 200)
        MetricsClientJob.after_perform(only_status: 400..599) { raise }

        with_submission_job MetricsClient, MetricsClientJob do
          perform_enqueued_jobs { MetricsClient.ping.submit_later }
        end

        assert_no_enqueued_jobs
      end

      test ".after_perform skips execution of blocks when the status code does matches except_status:" do
        stub_request(:get, "https://example.com/ping").to_return(status: 200)
        MetricsClientJob.after_perform(except_status: 200) { raise }

        with_submission_job MetricsClient, MetricsClientJob do
          perform_enqueued_jobs { MetricsClient.ping.submit_later }
        end

        assert_no_enqueued_jobs
      end

      test ".after_perform raises when both only_status: and except_status: are present" do
        exception = assert_raises {
          MetricsClientJob.after_perform(except_status: 200, only_status: 200) { raise }
        }

        assert_includes exception.message, "except_status:"
        assert_includes exception.message, "only_status:"
      end
    end
  end
end
