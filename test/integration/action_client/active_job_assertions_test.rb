require "test_helper"
require "active_job_test_case"

module ActionClient
  class ActiveJobAssertionsTestCase < ActiveJobTestCase
    include ActionClient::TestHelpers

    def self.test(*arguments, rails: 5.2, &block)
      if Gem::Version.new(rails.to_s) <= Rails.gem_version
        super(*arguments, &block)
      else
        super(*arguments) { pass }
      end
    end

    def ignore_http_requests!
      stub_request(:get, %r{example.com})
    end
  end

  class AssertRequestEnqueuedTest < ActiveJobAssertionsTestCase
    test "#assert_enqueued_request accepts a request", rails: 6.0 do
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status", x: 1)

      request.submit_later

      assert_enqueued_request request
    end

    test "#assert_enqueued_request accepts a block" do
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status", x: 1)

      assert_enqueued_request(request) { request.submit_later }
    end

    test "#assert_enqueued_request accepts a options" do
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      assert_enqueued_request(request, queue: "low_priority") do
        request.submit_later(queue: "low_priority")
      end
    end

    test "#assert_enqueued_request raises with a request", rails: 6.0 do
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status", x: 1)

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_enqueued_request(request)
      end
    end

    test "#assert_enqueued_request raises from a block" do
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status", x: 1)

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_enqueued_request(request) {}
      end
    end
  end

  class AssertNoRequestsEnqueuedTest < ActiveJobAssertionsTestCase
    test "#assert_no_requests_enqueued does not fail when a request is not made" do
      assert_no_requests_enqueued
    end

    test "#assert_no_requests_enqueued accepts a block" do
      assert_no_requests_enqueued { 1 + 1 }
    end

    test "#assert_no_requests_enqueued accepts a options", rails: 6.0 do
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status")

      assert_no_requests_enqueued(queue: "low_priority") do
        request.submit_later(queue: "default")
      end
    end

    test "#assert_no_requests_enqueued does not raise for the argument" do
      job = declare_job
      client = declare_client {
        self.submission_job = job

        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status")

      request.submit_later

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_no_requests_enqueued(client)
      end
    end

    test "#assert_no_requests_enqueued raises without a block" do
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status")

      request.submit_later

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_no_requests_enqueued
      end
    end

    test "#assert_no_requests_enqueued raises from a block" do
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status")

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_no_requests_enqueued { request.submit_later }
      end
    end
  end

  class AssertRequestPerformedTest < ActiveJobAssertionsTestCase
    test "#assert_performed_request accepts a request", rails: 6.0 do
      ignore_http_requests!
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status")

      perform_enqueued_jobs { request.submit_later }

      assert_performed_request request
    end

    test "#assert_performed_request accepts a block" do
      ignore_http_requests!
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status")

      assert_performed_request(request) { request.submit_later }
    end

    test "#assert_performed_request accepts options", rails: 6.0 do
      ignore_http_requests!
      client = declare_client {
        def ping(name, **query)
          get url: "https://example.com/ping?name=#{name}", query: query
        end
      }
      request = client.ping("status")

      perform_enqueued_jobs { request.submit_later(queue: "low_priority") }

      assert_performed_request(request, queue: "low_priority")
    end

    test "#assert_enqueued_request raises with a request", rails: 6.0 do
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      perform_enqueued_jobs do
        assert_raises ActiveSupport::TestCase::Assertion do
          assert_performed_request(request)
        end
      end
    end

    test "#assert_enqueued_request raises with a block" do
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_performed_request(request) {}
      end
    end

    test "#assert_enqueued_request raises with options", rails: 6.0 do
      ignore_http_requests!
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      perform_enqueued_jobs do
        request.submit_later(queue: "default")

        exception = assert_raises(ActiveSupport::TestCase::Assertion) {
          assert_performed_request(request, queue: "low_priority")
        }
        assert_includes exception.message, "low_priority"
      end
    end
  end

  class AssertNoPerformedRequestsTest < ActiveJobAssertionsTestCase
    test "#assert_no_performed_requests does not fail when no requests are performed" do
      perform_enqueued_jobs do
        assert_no_performed_requests
      end
    end

    test "#assert_no_performed_requests accepts a block" do
      perform_enqueued_jobs do
        assert_no_performed_requests { 1 + 1 }
      end
    end

    test "#assert_no_performed_requests accepts a options", rails: 6.0 do
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      assert_no_performed_requests(queue: "low_priority") do
        request.submit_later(queue: "default")
      end
    end

    test "#assert_no_performed_requests does not raise for the argument class" do
      ignore_http_requests!
      job = declare_job
      client = declare_client {
        self.submission_job = job

        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      perform_enqueued_jobs { request.submit_later }

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_no_performed_requests(client)
      end
    end

    test "#assert_no_performed_requests raises without a block" do
      ignore_http_requests!
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      perform_enqueued_jobs { request.submit_later }

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_no_performed_requests
      end
    end

    test "#assert_no_performed_requests raises from a block" do
      ignore_http_requests!
      client = declare_client {
        def ping
          get url: "https://example.com/ping"
        end
      }
      request = client.ping

      perform_enqueued_jobs do
        assert_raises ActiveSupport::TestCase::Assertion do
          assert_no_performed_requests { request.submit_later }
        end
      end
    end
  end
end
