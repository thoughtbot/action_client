module ActionClient
  class Template
    delegate_missing_to :template

    def self.find(client, renderer: client, variants: [])
      prefixes = Array(client.controller_path)

      if renderer.lookup_context.any_templates?(client.action_name, prefixes)
        template = renderer.lookup_context.find_template(
          client.action_name,
          prefixes,
          false,
          [],
          variants: variants
        )
        new(template, renderer)
      end
    end

    def initialize(template, renderer)
      @template = template
      @renderer = renderer
    end

    def render(**options)
      body = renderer.render(template: virtual_path, variants: variants, **options)

      CGI.unescapeHTML(body.to_s.strip)
    end

    def content_type
      if (mime_type = Mime[format])
        mime_type.to_s
      end
    end

    def format
      if template.respond_to?(:format)
        template.format
      elsif handler.is_a?(ActionView::Template::Handlers::Raw)
        extension = File.extname(identifier)
        extension.delete_prefix(".")
      else
        formats.first
      end
    end

    private

    attr_reader :renderer
    attr_reader :template
  end
end
