module TemplateTestHelpers
  def around(&block)
    Dir.mktmpdir do |temporary_directory|
      @partial_path = Pathname(temporary_directory).join("app", "views")

      with_view_path_prefixes(@partial_path) do
        block.call
      end
    end
  end

  def with_view_path_prefixes(temporary_view_directory, &block)
    view_paths = ActionClient::Base.view_paths

    ActionClient::Base.prepend_view_path(temporary_view_directory)

    block.call
  ensure
    ActionClient::Base.view_paths = view_paths
  end

  def declare_template(partial_path, body)
    @partial_path.join(partial_path).tap do |file|
      file.dirname.mkpath

      file.write(body)
    end
  end
end
