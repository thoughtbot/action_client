require "test_helper"
require "integration_test_case"

module ActionClient
  class CallbacksTest < ActionClient::IntegrationTestCase
    test "executes code declared in an after_submit callback" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: { "Content-Type": "application/json" },
        status: 422,
      )
      error_class = Class.new(ArgumentError)
      client = declare_client do
        after_submit do |status, _, body|
          if status == 422
            raise error_class, body.fetch("error")
          end
        end

        def create
          post url: "https://example.com/articles"
        end
      end

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "after_submit executes on the body when passed a single argument" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: { "Content-Type" => "application/json" },
        status: 201,
      )
      client = declare_client do
        after_submit { |body| body.with_indifferent_access }

        def create
          post url: "https://example.com/articles"
        end
      end

      status, headers, body = *client.create.submit

      assert_equal 201, status
      assert_equal "application/json", headers["Content-Type"]
      assert_equal "created", body.fetch(:status)
    end

    test "can modify the response from an after_submit callback" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: { "Content-Type" => "application/json" },
        status: 200,
      )
      client = declare_client do
        after_submit do |status, headers, body|
          [
            201,
            { "Content-Type" => "text/plain" },
            body.map { |key, value| "#{key}: #{value}" }.join,
          ]
        end

        def create
          post url: "https://example.com/articles"
        end
      end

      status, headers, body = *client.create.submit

      assert_equal 201, status
      assert_equal "text/plain", headers["Content-Type"]
      assert_equal "status: created", body
    end

    test "executes after_submit callbacks in the order they're declared" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "modified"}),
        headers: { "Content-Type": "application/json" },
        status: 200,
      )
      client = declare_client do
        after_submit { |status, headers, body| body["status"] = "modified"; [status, headers, body] }
        after_submit { |status, headers, body| [status, headers, body.transform_keys(&:upcase)] }

        def create
          post url: "https://example.com/articles" do |status, headers, body|
            [status, headers, body.with_indifferent_access]
          end
        end
      end

      response = client.create.submit

      assert_equal "modified", response.body.fetch(:STATUS)
    end

    test "can declare a request-specific after_submit accepting a Rack triplet" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: { "Content-Type": "application/json" },
        status: 200,
      )
      client = declare_client do
        def create
          post url: "https://example.com/articles" do |status, headers, body|
            body["status"] = "modified"
            [status, headers, body]
          end
        end
      end

      response = client.create.submit

      assert_equal "modified", response.body.fetch("status")
    end

    test "can declare a request-specific after_submit accepting the body" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: { "Content-Type": "application/json" },
        status: 200,
      )
      client = declare_client do
        def create
          post url: "https://example.com/articles" do |body|
            body.with_indifferent_access
          end
        end
      end

      status, headers, body = *client.create.submit

      assert_equal 200, status
      assert_equal "application/json", headers["Content-Type"]
      assert_equal "created", body.fetch(:status)
    end

    test "does not execute after_submit blocks that don't match the status" do
      stub_request(:post, "https://example.com/articles").and_return(status: 200)
      error_class = Class.new(ArgumentError)
      client = declare_client do
        after_submit(with_status: 422) { raise error_class }

        def create
          post url: "https://example.com/articles"
        end
      end

      response = client.create.submit

      assert_equal 200, response.status
    end

    test "can declare an after_submit callback matching the status code" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: { "Content-Type": "application/json" },
        status: 422,
      )
      error_class = Class.new(ArgumentError)
      client = declare_client do
        after_submit(with_status: 422) { |body| raise error_class, body.fetch("error") }

        def create
          post url: "https://example.com/articles"
        end
      end

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "can match an after_submit callback with a mixture of Numeric and Symbol status codes" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: { "Content-Type": "application/json" },
        status: 401,
      )
      error_class = Class.new(ArgumentError)
      client = declare_client do
        after_submit with_status: [:unauthorized, 403] do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      end

      exception = assert_raises(error_class) { client.create.submit}

      assert_includes exception.message, "failed"
    end

    test "can pass only the body to the block of an after_submit callback declaring a matching status code" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: { "Content-Type": "application/json" },
        status: 422,
      )
      error_class = Class.new(ArgumentError)
      client = declare_client do
        after_submit with_status: 422 do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      end

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "can after_submit a callback that declares an Array containing the status code" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: { "Content-Type": "application/json" },
        status: 401,
      )
      error_class = Class.new(ArgumentError)
      client = declare_client do
        after_submit with_status: [401, 403] do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      end

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "can after_submit a callback that decalares a Range of matching status codes" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: { "Content-Type": "application/json" },
        status: 422,
      )
      error_class = Class.new(ArgumentError)
      client = declare_client do
        after_submit with_status: 400..500 do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      end

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "each time a request is submitted, it receives its own middleware stack" do
      client = declare_client do
        after_submit { |body| body["callbacks"].push("class"); body }

        def create
          post url: "https://example.com/articles" do |body|
            body["callbacks"].push("create")
            body
          end
        end

        def destroy
          delete url: "https://example.com/articles/1" do |body|
            body["callbacks"].push("destroy")
            body
          end
        end

        def all
          get url: "https://example.com/articles"
        end
      end
      stub_request(:any, %r{example.com}).to_return(
        headers: { "Content-Type": "application/json" },
        body: { callbacks: [] }.to_json,
      )

      create_response = client.create.submit
      destroy_response = client.destroy.submit
      all_response = client.all.submit

      assert_equal ["class", "create"], create_response.body["callbacks"]
      assert_equal ["class", "destroy"], destroy_response.body["callbacks"]
      assert_equal ["class"], all_response.body["callbacks"]
    end
  end

  class CallbackErrorsTest < ActionClient::IntegrationTestCase
    test "raises an exception when the block does not return a triplet" do
      stub_request(:post, "https://example.com/articles")
      client = declare_client do
        after_submit { |status, headers, body| body }

        def create
          post url: "https://example.com/articles"
        end
      end

      assert_raises ActionClient::AfterSubmitError, /Rack triplet/ do
        client.create.submit
      end
    end

    test "does not raise an exception when a single argument block returns an Array of 1 item" do
      client = declare_client do
        def all
          get url: "https://example.com/articles" do |body|
            body.map(&:symbolize_keys)
          end
        end
      end
      stub_request(:get, %r{example.com}).to_return(
        headers: { "Content-Type": "application/json" },
        body: [{ id: 1 }].to_json,
      )

      response = client.all.submit

      assert_equal [{ id: 1 }], response.body
    end

    test "raises an exception when a single argument block does not return only the body" do
      stub_request(:post, "https://example.com/articles")
      client = declare_client do
        after_submit { |body| nil }

        def create
          post url: "https://example.com/articles"
        end
      end

      assert_raises ActionClient::AfterSubmitError, /body/ do
        client.create.submit
      end
    end
  end
end
