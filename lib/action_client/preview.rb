module ActionClient
  class Preview
    extend ActiveSupport::DescendantsTracker

    class_attribute :previews_path,
      instance_accessor: true,
      default: "test/clients/previews"

    class << self
      def all
        if descendants.empty?
          load_previews
        end

        descendants
      end

      def find(preview)
        all.find { |p| p.preview_name == preview }
      end

      def preview_name
        client_name.underscore
      end

      def client_name
        name.sub(/Preview$/, "")
      end

      def exists?(action_name)
        instance_methods.map(&:to_s).include?(action_name)
      end

      def action_methods
        client_class.action_methods
      end

      def to_param
        preview_name
      end

      private

      def client_class
        client_name.constantize
      end

      def load_previews
        Dir[Rails.root.join("#{previews_path}/**/*_preview.rb")].sort.each do |file|
          require_dependency(file)
        end
      end
    end

    attr_reader :action_name

    def initialize(action_name:)
      @action_name = action_name
    end

    def request
      public_send(action_name)
    end
  end
end
