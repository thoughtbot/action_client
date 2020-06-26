module ActionClient
  class Template
    delegate_missing_to :template

    def self.find(client, renderer: client, variants: [])
      prefixes = Array(client.controller_path)

      if renderer.lookup_context.any_templates?(client.action_name, prefixes)
        variants = variants.map(&:to_s)
        template = renderer.lookup_context.find_template(
          client.action_name,
          prefixes,
          false,
          [],
          variants: variants
        )
        new(template, renderer, variants)
      end
    end

    def initialize(template, renderer, variants)
      @template = template
      @renderer = renderer
      @variants = Array(variants)
    end

    def render(**options)
      body = renderer.render(template: virtual_path, variants: variants, **options)

      CGI.unescapeHTML(body.to_s.strip)
    end

    def content_type
      mime_type = Mime[format]

      if mime_type.present?
        mime_type.to_s
      end
    end

    private

    attr_reader :renderer
    attr_reader :template
    attr_reader :variants

    def format
      template.try(:format) || (
        if handler.is_a?(ActionView::Template::Handlers::Raw)
          File.extname(identifier).delete_prefix(".")
        else
          formats.first
        end
      )
    end
  end
end
