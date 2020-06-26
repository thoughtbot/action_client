class ActionClientGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  argument :actions, type: :array, default: [], banner: "method method"

  def check_class_collision
    class_collisions(
      "#{class_name}Client",
      "#{class_name}ClientPreview"
    )
  end

  def create_action_client_file
    template_if_missing "application_client.rb", "app/clients/application_client.rb"
    template "action_client.rb", File.join("app/clients", class_path, "#{file_name}_client.rb")
  end

  def create_view_dir
    empty_directory_with_keep_file(
      File.join("app/views", class_path, "#{file_name}_client")
    )
  end

  def create_config_file
    template "config.yml", File.join("config/clients", class_path, "#{file_name}.yml")
  end

  def create_preview_file
    template "preview.rb", File.join("test/clients/previews", class_path, "#{file_name}_client_preview.rb")
  end

  private

  def file_name
    @_file_name ||= super.sub(/_client\z/i, "")
  end

  def template_if_missing(source, target)
    in_root do
      if behavior == :invoke && !File.exist?(target)
        template source, target
      end
    end
  end

  def empty_directory_with_keep_file(destination)
    empty_directory(destination)
    keep_file(destination)
  end

  def keep_file(destination)
    create_file("#{destination}/.keep")
  end
end
