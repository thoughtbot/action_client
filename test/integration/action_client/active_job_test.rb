require "test_helper"
require "active_job_test_case"

module ActionClient
  class ActiveJobTest < ActionClient::ActiveJobTestCase
    class RetryOnWithStatusOptionsTest < ActiveJobTest
      test ".retry_on without options always executes" do
        job = declare_job {
          retry_on(Timeout::Error)
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping")
          .to_raise(Timeout::Error)
          .then.to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_requested :get, "https://example.com/ping", times: 2
      end

      test ".retry_on accepts other options" do
        job = declare_job {
          retry_on(Timeout::Error, attempts: 1)
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping")
          .to_raise(Timeout::Error)
          .then.to_return(status: 200)

        assert_raises(Timeout::Error) do
          perform_enqueued_jobs { client.ping.submit_later }
        end

        assert_requested :get, "https://example.com/ping", times: 1
        assert_performed_jobs(1)
      end

      test ".retry_on raises when passed both only_status: and except_status:" do
        exception = assert_raises(ArgumentError) {
          declare_job {
            retry_on(only_status: 200, except_status: 200)
          }
        }

        assert_includes exception.message, "except_status:"
        assert_includes exception.message, "only_status:"
      end

      test ".retry_on accepts both Error arguments and status options" do
        job = declare_job {
          retry_on(StandardError, only_status: 500)
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping")
          .to_raise(StandardError)
          .then.to_return(status: 500)
          .then.to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_requested :get, "https://example.com/ping", times: 3
      end

      test ".retry_on with only_status retries for a matching status" do
        job = declare_job {
          retry_on(only_status: 500)
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping")
          .to_return(status: 500)
          .then.to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_requested :get, "https://example.com/ping", times: 2
      end

      test ".retry_on yields the error to a block" do
        exception = nil
        job = declare_job {
          retry_on(only_status: 500) { |_, e| exception = e }
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping").to_return(status: 500)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_includes exception.message, "500"
      end

      test ".retry_on with only_status does not retry when the status does not matching" do
        job = declare_job {
          retry_on(only_status: 500)
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping").to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_requested :get, "https://example.com/ping", times: 1
      end

      test ".retry_on with except_status retries for a matching status" do
        job = declare_job {
          retry_on(except_status: 200)
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping")
          .to_return(status: 500)
          .then.to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_requested :get, "https://example.com/ping", times: 2
      end

      test ".retry_on with except_status does not retry when a status does not match" do
        job = declare_job {
          retry_on(except_status: 200)
        }
        client = declare_client {
          self.submission_job = job

          def ping
            get url: "https://example.com/ping"
          end
        }
        stub_request(:get, "https://example.com/ping").to_return(status: 200)

        perform_enqueued_jobs { client.ping.submit_later }

        assert_requested :get, "https://example.com/ping", times: 1
      end
    end

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
