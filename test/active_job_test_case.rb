require "integration_test_case"

module ActionClient
  class ActiveJobTestCase < ActionClient::IntegrationTestCase
    include ActiveJob::TestHelper
  end
end
