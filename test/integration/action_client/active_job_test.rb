require "test_helper"
require "active_job_test_case"

module ActionClient
  class ActiveJobTest < ActionClient::ActiveJobTestCase
    class AfterPerformWithoutOptionsTest < ActiveJobTest
      test ".after_perform without options always executes" do
        response = nil
        job = declare_job { after_perform { response = self.response } }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping").to_return(
          headers: {"Content-Type": "application/json"},
          body: {status: "success"}.to_json
        )

        perform_enqueued_jobs { client.ping.submit_later }

        assert_equal 200, response.status
        assert_equal "application/json", response.headers["Content-Type"]
        assert_equal "success", response.body["status"]
      end
    end

    class AfterPerformWithStatusOptionsTest < ActiveJobTest
      test ".after_perform executes a block when the status codes match only_status:" do
        response = nil
        job = declare_job {
          after_perform(only_status: 400..599) do
            response = self.response
            retry_job
          end
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping")
          .to_return(
            headers: {"Content-Type": "application/json"},
            body: {status: "error"}.to_json,
            status: 500
          ).times(1)
          .then.to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_performed_jobs(2, only: job)
        assert_requested :get, "https://example.com/ping", times: 2
        assert_equal 500, response.status
        assert_equal "application/json", response.headers["Content-Type"]
        assert_equal "error", response.body["status"]
      end

      test ".after_perform executes a block when the status codes does not match except_status:" do
        response = nil
        job = declare_job {
          after_perform(except_status: 200) do
            response = self.response
            retry_job
          end
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping")
          .to_return(
            headers: {"Content-Type": "application/json"},
            body: {status: "error"}.to_json,
            status: 500
          ).times(1)
          .then.to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_performed_jobs(2, only: job)
        assert_requested :get, "https://example.com/ping", times: 2
        assert_equal 500, response.status
        assert_equal "application/json", response.headers["Content-Type"]
        assert_equal "error", response.body["status"]
      end

      test ".after_perform skips execution of blocks when the status code does not match only_status:" do
        job = declare_job { after_perform(only_status: 400..599) { raise } }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping").to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_no_enqueued_jobs
      end

      test ".after_perform skips execution of blocks when the status code does matches except_status:" do
        job = declare_job { after_perform(except_status: 200) { raise } }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping").to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_no_enqueued_jobs
      end

      test ".after_perform raises when both only_status: and except_status: are present" do
        exception = assert_raises {
          declare_job { after_perform(except_status: 200, only_status: 200) { raise } }
        }

        assert_includes exception.message, "except_status:"
        assert_includes exception.message, "only_status:"
      end
    end
  end
end
