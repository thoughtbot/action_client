module ActionClient
  class Template
    delegate_missing_to :@template

    def self.find(client, renderer: nil, variants: [])
      prefixes = Array(client.controller_path)
      renderer ||= client

      if renderer.lookup_context.any_templates?(client.action_name, prefixes)
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
      @variants = variants
    end

    def render(**options)
      body = @renderer.render(
        template: virtual_path,
        variants: @variants,
        **options
      )

      CGI.unescapeHTML(body.to_s.strip)
    end

    def content_type
      if (mime_type = Mime[format])
        mime_type.to_s
      end
    end

    def format
      if @template.respond_to?(:format)
        @template.format
      elsif handler.is_a?(ActionView::Template::Handlers::Raw)
        extension = File.extname(identifier)
        extension.delete_prefix(".")
      else
        formats.first
      end
    end
  end
end
