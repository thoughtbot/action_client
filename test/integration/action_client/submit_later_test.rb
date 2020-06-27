require "test_helper"
require "active_job_test_case"

module ActionClient
  class SubmitLaterTest < ActionClient::ActiveJobTestCase
    test "#submit_later enqueues a Job with arguments and options" do
      client = declare_client {
        def ping(path = "ping", **options)
          get url: "https://example.com/#{path}", query: options
        end
      }
      stub_request(:get, "https://example.com/special-ping?status=special")
      request = client.ping("special-ping", status: "special")

      perform_enqueued_jobs { request.submit_later }

      assert_requested :get, "https://example.com/special-ping?status=special", times: 1
    end

    test "#submit_later enqueues an ActiveJob::Job to execute the request" do
      stub_request(:get, "https://example.com/ping")
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }

      perform_enqueued_jobs { client.ping.submit_later }

      assert_requested :get, "https://example.com/ping", times: 1
    end

    test "#submit_later forwards options along when scheduling the ActiveJob::Job" do
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }

      assert_enqueued_with job: ActionClient::SubmissionJob, queue: "requests" do
        client.ping.submit_later(queue: "requests")
      end
    end

    test "#submit_later enqueues a different job class" do
      job = declare_job
      client = declare_client {
        self.submission_job = job

        def ping
          get url: "https://example.com/ping"
        end
      }

      assert_enqueued_with(job: job) { client.ping.submit_later }
    end
  end
end
