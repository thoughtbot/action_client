module TemplateTestHelpers
  def around(&block)
    Dir.mktmpdir do |temporary_directory|
      @partial_path = Pathname(temporary_directory).join("app", "views")
      @config_path = Pathname(temporary_directory).join("config")

      with_view_path_prefixes(@partial_path) do
        with_config_path(@config_path) do
          block.call
        end
      end
    end
  end

  def with_config_path(temporary_directory, &block)
    config_path = ActionClient::Base.config_path

    ActionClient::Base.config_path = temporary_directory

    block.call
  ensure
    ActionClient::Base.config_path = config_path
  end

  def with_view_path_prefixes(temporary_view_directory, &block)
    view_paths = ActionClient::Base.view_paths

    ActionClient::Base.prepend_view_path(temporary_view_directory)

    block.call
  ensure
    ActionClient::Base.view_paths = view_paths
  end

  def declare_config(partial_path, body)
    @config_path.join(partial_path).tap do |file|
      file.dirname.mkpath

      file.write(body)
    end
  end

  def declare_template(partial_path, body)
    @partial_path.join(partial_path).tap do |file|
      file.dirname.mkpath

      file.write(body)
    end
  end
end
