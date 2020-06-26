require "test_helper"
require "generators/action_client/action_client_generator"

class ActionClientGeneratorTest < Rails::Generators::TestCase
  tests ActionClientGenerator
  destination Rails.root.join("tmp/generators")
  setup :prepare_destination

  test "generator creates client" do
    run_generator ["example"]

    assert_file "app/clients/example_client.rb" do |client|
      assert_match(/class ExampleClient < ApplicationClient/, client)
    end
  end

  test "generator creates client when passed the _client prefix" do
    run_generator ["example_client"]

    assert_file "app/clients/example_client.rb" do |client|
      assert_match(/class ExampleClient < ApplicationClient/, client)
    end
  end

  test "generator creates client with the provided actions" do
    run_generator ["example", "create", "show"]

    assert_file "app/clients/example_client.rb" do |client|
      assert_match(/class ExampleClient < ApplicationClient/, client)
      assert_match(/  def create/, client)
      assert_match(/  def show/, client)
    end
  end

  test "generator creates ApplicationClient" do
    run_generator ["example"]

    assert_file "app/clients/application_client.rb" do |client|
      assert_match(/class ApplicationClient < ActionClient::Base/, client)
    end
  end

  test "generator does not write over ApplicationClient if it already exists" do
    run_generator ["example"]
    stdout = run_generator ["example"]

    assert_no_match(%r{identical  app/clients/application_client.rb}, stdout)
  end

  test "destroy does not remove ApplicationClient" do
    run_generator ["example"], behavior: :invoke
    run_generator ["example"], behavior: :revoke

    assert_file "app/clients/application_client.rb" do |client|
      assert_match(/class ApplicationClient < ActionClient::Base/, client)
    end
  end

  test "generator creates view directory" do
    run_generator ["example"]

    assert_file("app/views/example_client/.keep")
  end

  test "generator creates config file" do
    run_generator ["example"]

    assert_file "config/clients/example.yml" do |client|
      assert_match(%r{  url: "https://example.com/example"}, client)
    end
  end

  test "generator creates preview" do
    run_generator ["example"]

    assert_file "test/clients/previews/example_client_preview.rb" do |client|
      assert_match(/class ExampleClientPreview < ActionClient::Preview/, client)
    end
  end

  test "generator creates preview with the provided actions" do
    run_generator ["example", "create", "show"]

    assert_file "test/clients/previews/example_client_preview.rb" do |client|
      assert_match(/class ExampleClientPreview < ActionClient::Preview/, client)
      assert_match(/  def create/, client)
      assert_match(/    ExampleClient.create/, client)
      assert_match(/  def show/, client)
      assert_match(/    ExampleClient.show/, client)
    end
  end

  test "check class collision" do
    Object.send :const_set, :ExampleClient, Class.new
    stderr = capture(:stderr) { run_generator ["example"] }
    assert_match(/The name 'ExampleClient' is either already used in your application or reserved/, stderr)
  ensure
    Object.send :remove_const, :ExampleClient
  end

  test "check preview class collision" do
    Object.send :const_set, :ExampleClientPreview, Class.new
    stderr = capture(:stderr) { run_generator ["example"] }
    assert_match(/The name 'ExampleClientPreview' is either already used in your application or reserved/, stderr)
  ensure
    Object.send :remove_const, :ExampleClientPreview
  end
end
