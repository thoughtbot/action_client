require "action_client/engine"
require "template_test_helpers"

module ActionClient
  class IntegrationTestCase < ActiveSupport::TestCase
    include TemplateTestHelpers

    def declare_client(controller_path = nil, inherits: ActionClient::Base, &block)
      Class.new(inherits).tap do |client_class|
        if controller_path.present?
          client_class.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            def self.controller_path
              #{controller_path.inspect}
            end
          RUBY
        end

        client_class.class_eval(&block)
      end
    end

    setup do
      ActionClient::Base.defaults = ActiveSupport::OrderedOptions.new
    end
  end
end
