require "test_helper"
require "integration_test_case"

module ActionClient
  class CallbacksTest < ActionClient::IntegrationTestCase
    CallbackError = Class.new(StandardError)

    test "executes a block declared in an after_submit callback" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: {"Content-Type": "application/json"},
        status: 422
      )
      error_class = Class.new(ArgumentError)
      client = declare_client {
        after_submit do |status, _, body|
          if status == 422
            raise error_class, body.fetch("error")
          end
        end

        def create
          post url: "https://example.com/articles"
        end
      }

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "executes methods specified in an after_submit callback" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %(success)
      )
      client = declare_client {
        after_submit :upcase_body

        def create
          post url: "https://example.com/articles"
        end

        private def upcase_body(status, headers, body)
          response.body = body.upcase
        end
      }

      response = client.create.submit

      assert_equal "SUCCESS", response.body
    end

    test "executes methods specified in an after_submit callback matching the status" do
      stub_request(:post, "https://example.com/articles").and_return(
        status: 422
      )
      client = declare_client {
        after_submit :raise_error, only_status: 422

        def create
          post url: "https://example.com/articles"
        end

        private def raise_error
          raise CallbackError
        end
      }

      assert_raises(CallbackError) { client.create.submit }
    end

    test "executes methods specified in an after_submit callback when not matching the status" do
      stub_request(:post, "https://example.com/articles").and_return(
        status: 422
      )
      client = declare_client {
        after_submit :raise_error, except_status: 200

        def create
          post url: "https://example.com/articles"
        end

        private def raise_error
          raise CallbackError
        end
      }

      assert_raises(CallbackError) { client.create.submit }
    end

    test "after_submit executes on the body when passed a single argument" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: {"Content-Type" => "application/json"},
        status: 201
      )
      client = declare_client {
        after_submit { |body| response.body = body.with_indifferent_access }

        def create
          post url: "https://example.com/articles"
        end
      }

      status, headers, body = *client.create.submit

      assert_equal 201, status
      assert_equal "application/json", headers["Content-Type"]
      assert_equal "created", body.fetch(:status)
    end

    test "can modify the response from an after_submit callback" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: {"Content-Type" => "application/json"},
        status: 200
      )
      client = declare_client {
        after_submit do |status, _, body|
          response.status = status + 1
          response["Content-Type"] = "text/plain"
          response.body = body.map { |key, value| "#{key}: #{value}" }.join
        end

        def create
          post url: "https://example.com/articles"
        end
      }

      status, headers, body = *client.create.submit

      assert_equal 201, status
      assert_equal "text/plain", headers["Content-Type"]
      assert_equal "status: created", body
    end

    test "executes after_submit callbacks in the order they're declared" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "modified"}),
        headers: {"Content-Type": "application/json"},
        status: 200
      )
      client = declare_client {
        after_submit { response.body["status"] = "modified" }
        after_submit { |body| response.body = body.transform_keys(&:upcase) }

        def create
          post url: "https://example.com/articles" do |body|
            response.body = body.with_indifferent_access
          end
        end
      }

      response = client.create.submit

      assert_equal "modified", response.body.fetch(:STATUS)
    end

    test "can declare a request-specific after_submit accepting a Rack triplet" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: {"Content-Type": "application/json"},
        status: 200
      )
      client = declare_client {
        def create
          post url: "https://example.com/articles" do |status, headers, body|
            body["status"] = "modified"
            [status, headers, body]
          end
        end
      }

      response = client.create.submit

      assert_equal "modified", response.body.fetch("status")
    end

    test "can declare a request-specific after_submit accepting the body" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"status": "created"}),
        headers: {"Content-Type": "application/json"},
        status: 200
      )
      client = declare_client {
        def create
          post url: "https://example.com/articles" do |body|
            response.body = body.with_indifferent_access
          end
        end
      }

      status, headers, body = *client.create.submit

      assert_equal 200, status
      assert_equal "application/json", headers["Content-Type"]
      assert_equal "created", body.fetch(:status)
    end

    test "does not execute after_submit blocks that don't match the status" do
      stub_request(:post, "https://example.com/articles").and_return(status: 200)
      error_class = Class.new(ArgumentError)
      client = declare_client {
        after_submit(only_status: 422) { raise error_class }

        def create
          post url: "https://example.com/articles"
        end
      }

      response = client.create.submit

      assert_equal 200, response.status
    end

    test "can declare an after_submit callback matching the status code" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: {"Content-Type": "application/json"},
        status: 422
      )
      error_class = Class.new(ArgumentError)
      client = declare_client {
        after_submit(only_status: 422) { |body| raise error_class, body.fetch("error") }

        def create
          post url: "https://example.com/articles"
        end
      }

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "can match an after_submit callback with a mixture of Numeric and Symbol status codes" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: {"Content-Type": "application/json"},
        status: 401
      )
      error_class = Class.new(ArgumentError)
      client = declare_client {
        after_submit only_status: [:unauthorized, 403] do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      }

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "can pass only the body to the block of an after_submit callback declaring a matching status code" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: {"Content-Type": "application/json"},
        status: 422
      )
      error_class = Class.new(ArgumentError)
      client = declare_client {
        after_submit only_status: 422 do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      }

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "can after_submit a callback that declares an Array containing the status code" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: {"Content-Type": "application/json"},
        status: 401
      )
      error_class = Class.new(ArgumentError)
      client = declare_client {
        after_submit only_status: [401, 403] do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      }

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "can after_submit a callback that declares a Range of matching status codes" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %({"error": "failed"}),
        headers: {"Content-Type": "application/json"},
        status: 422
      )
      error_class = Class.new(ArgumentError)
      client = declare_client {
        after_submit only_status: 400..500 do |body|
          raise error_class, body.fetch("error")
        end

        def create
          post url: "https://example.com/articles"
        end
      }

      exception = assert_raises(error_class) { client.create.submit }

      assert_includes exception.message, "failed"
    end

    test "each time a request is submitted, it receives its own middleware stack" do
      client = declare_client {
        after_submit do |body|
          body["callbacks"].push("class")
          body
        end

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
      }
      stub_request(:any, %r{example.com}).to_return(
        headers: {"Content-Type": "application/json"},
        body: {callbacks: []}.to_json
      )

      create_response = client.create.submit
      destroy_response = client.destroy.submit
      all_response = client.all.submit

      assert_equal ["class", "create"], create_response.body["callbacks"]
      assert_equal ["class", "destroy"], destroy_response.body["callbacks"]
      assert_equal ["class"], all_response.body["callbacks"]
    end
  end

  class CallbackActionNameTest < ActionClient::IntegrationTestCase
    CallbackError = Class.new(StandardError)

    test "executes methods specified in an after_submit callback" do
      stub_request(:post, "https://example.com/articles").and_return(
        body: %(success)
      )
      client = declare_client {
        after_submit :upcase_body

        def create
          post url: "https://example.com/articles"
        end

        private def upcase_body(status, headers, body)
          response.body = body.upcase
        end
      }

      response = client.create.submit

      assert_equal "SUCCESS", response.body
    end

    test "executes methods specified in an after_submit callback matching the status" do
      stub_request(:post, "https://example.com/articles").and_return(
        status: 422
      )
      client = declare_client {
        after_submit :raise_error, only_status: 422

        def create
          post url: "https://example.com/articles"
        end

        private def raise_error
          raise CallbackError
        end
      }

      assert_raises(CallbackError) { client.create.submit }
    end

    test "executes a single method specified by only: in an after_submit callback" do
      stub_request(:post, "https://example.com/articles")
      client = declare_client {
        after_submit :raise_error, only: :create

        def create
          post url: "https://example.com/articles"
        end

        private def raise_error
          raise CallbackError
        end
      }

      assert_raises(CallbackError) { client.create.submit }
    end

    test "executes multiple methods specified by only: in an after_submit callback" do
      stub_request(:any, "https://example.com/articles")
      client = declare_client {
        after_submit :raise_error, only: [:create, :all]

        def create
          post url: "https://example.com/articles"
        end

        def all
          get url: "https://example.com/articles"
        end

        private def raise_error
          raise CallbackError
        end
      }

      assert_raises(CallbackError) { client.create.submit }
      assert_raises(CallbackError) { client.all.submit }
    end

    test "executes methods specified in an after_submit callback when not matching the status" do
      stub_request(:post, "https://example.com/articles").and_return(
        status: 422
      )
      client = declare_client {
        after_submit :raise_error, except_status: 200

        def create
          post url: "https://example.com/articles"
        end

        private def raise_error
          raise CallbackError
        end
      }

      assert_raises(CallbackError) { client.create.submit }
    end
  end
end
