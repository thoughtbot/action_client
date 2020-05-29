module TemplateTestHelpers
  def around(&block)
    Dir.mktmpdir do |tmpdir|
      temporary_directory = Pathname(tmpdir)

      @partial_path = temporary_directory.join("app", "views")
      @config_path = temporary_directory.join("config")
      @fixture_path = temporary_directory.join("test", "clients", "fixtures")

      with_view_path_prefixes(@partial_path) do
        with_config_path(@config_path) do
          with_fixture_path_prefixes(@fixture_path) do
            block.call
          end
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
    with_path_prefixes(ActionClient::Base, temporary_view_directory, &block)
  end

  def with_fixture_path_prefixes(temporary_view_directory, &block)
    with_path_prefixes(ActionClient::Test::Client, temporary_view_directory, &block)
  end

  def with_path_prefixes(client_class, temporary_view_directory, &block)
    view_paths = client_class.view_paths

    client_class.prepend_view_path(temporary_view_directory)

    block.call
  ensure
    client_class.view_paths = view_paths
  end

  def declare_fixture(path, body)
    declare_file(@fixture_path, path, body)
  end

  def declare_template(path, body)
    declare_file(@partial_path, path, body)
  end

  def declare_config(path, body)
    declare_file(@config_path, path, body)
  end

  def declare_file(directory, path, body)
    directory.join(path).tap do |file|
      file.dirname.mkpath

      file.write(body)
    end
  end
end
