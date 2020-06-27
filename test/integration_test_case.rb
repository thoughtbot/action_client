require "action_client/engine"
require "template_test_helpers"

module ActionClient
  class IntegrationTestCase < ActiveSupport::TestCase
    include TemplateTestHelpers

    attr_accessor :declared_classes

    setup do
      ActionClient::Base.defaults = ActiveSupport::OrderedOptions.new
      self.declared_classes = Set.new
    end

    teardown do
      declared_classes.each do |client_class|
        Object.send :remove_const, client_class
      end
    end

    def declare_class(name, inherits: Object, &block)
      declared_classes.add(name)

      Class.new(inherits).tap do |declared_class|
        Object.send :const_set, name, declared_class

        if block.present?
          declared_class.class_eval(&block)
        end
      end
    end

    def declare_job(name = "TestClientJob", inherits: ActionClient::SubmissionJob, &block)
      declare_class(name, inherits: inherits, &block)
    end

    def declare_client(name = "TestClient", inherits: ActionClient::Base, &block)
      declare_class(name, inherits: inherits, &block)
    end

    def override_configuration(configuration, &block)
      originals = configuration.dup

      yield(configuration)
    ensure
      originals.each { |key, value| configuration[key] = value }
      configuration.delete_if { |key, _| originals.keys.exclude?(key) }
    end
  end
end
