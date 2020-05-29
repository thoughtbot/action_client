require "integration_test_case"

module ActionClient
  class ActiveJobTestCase < ActionClient::IntegrationTestCase
    include ActiveJob::TestHelper

    def with_submission_job(client_class, job_class, &block)
      original_job_class = client_class.submission_job
      client_class.submission_job = job_class

      block.call
    ensure
      client_class.submission_job = original_job_class
    end
  end
end
