module ActionClient
  class Template
    delegate_missing_to :@template

    def self.find(lookup_context, client, variants: [])
      prefixes = Array(client.controller_path)

      if lookup_context.any_templates?(client.action_name, prefixes)
        template = lookup_context.find_template(
          client.action_name,
          prefixes,
          false,
          [],
          variants: variants
        )
        new(template)
      end
    end

    def initialize(template)
      @template = template
    end
  end
end
