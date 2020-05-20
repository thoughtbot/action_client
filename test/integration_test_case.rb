require "action_client/engine"
require "template_test_helpers"

module ActionClient
  class IntegrationTestCase < ActiveSupport::TestCase
    include TemplateTestHelpers
  end
end
