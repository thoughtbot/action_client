require "test_helper"
require "integration_test_case"

module ActionClient
  class ClientTestCase < ActionClient::IntegrationTestCase
    Article = Struct.new(:id, :title)
  end

  class ActionMethodsTest < ClientTestCase
    test "the Base class responds to action methods" do
      client = declare_client {
        def create
        end
      }

      responds_to_create = client.respond_to?(:create)
      responds_to_destroy = client.respond_to?(:destroy)

      assert_equal true, responds_to_create
      assert_equal false, responds_to_destroy
    end

    test "only exposes declared requests as action_methods" do
      client = declare_client {
        def create
        end

        def destroy
        end
      }

      action_methods = client.action_methods.to_a

      assert_equal ["create", "destroy"], action_methods.sort
    end
  end

  class RequestsTest < ClientTestCase
    test "constructs a request that encodes the port" do
      client = declare_client {
        def create
          post url: "https://localhost:3000/articles"
        end
      }

      request = client.create

      assert_equal "https://localhost:3000/articles", request.url
    end

    test "constructs a POST request with a JSON body declared with instance variables" do
      client = declare_client("article_client") {
        default url: "https://example.com"

        def create(article:)
          @article = article

          post path: "/articles"
        end
      }
      declare_template "article_client/create.json.erb", <<~ERB
        <%= { title: @article.title }.to_json %>
      ERB
      article = Article.new(nil, "Article Title")

      request = client.create(article: article)

      assert_equal "POST", request.method
      assert_equal "https://example.com/articles", request.original_url
      assert_equal({"title" => "Article Title"}, JSON.parse(request.body.read))
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a GET request without declaring a body template" do
      client = declare_client {
        default headers: {"Content-Type": "application/json"}
        default url: "https://example.com"

        def all
          get path: "/articles"
        end
      }

      request = client.all

      assert_equal "GET", request.method
      assert_equal "https://example.com/articles", request.original_url
      assert_predicate request.body.read, :blank?
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs an OPTIONS request without declaring a body template" do
      client = declare_client {
        default url: "https://example.com"

        def status
          options path: "/status"
        end
      }

      request = client.status

      assert_equal "OPTIONS", request.method
      assert_equal "https://example.com/status", request.original_url
      assert_predicate request.body.read, :blank?
    end

    test "constructs a HEAD request without declaring a body template" do
      client = declare_client {
        default url: "https://example.com"

        def status
          head path: "/status"
        end
      }

      request = client.status

      assert_equal "HEAD", request.method
      assert_equal "https://example.com/status", request.original_url
      assert_predicate request.body.read, :blank?
    end

    test "constructs a TRACE request without declaring a body template" do
      client = declare_client {
        default url: "https://example.com"

        def status
          trace path: "/status"
        end
      }

      request = client.status

      assert_equal "TRACE", request.method
      assert_equal "https://example.com/status", request.original_url
      assert_predicate request.body.read, :blank?
    end

    test "constructs a DELETE request without declaring a body template" do
      client = declare_client {
        default headers: {"Content-Type": "application/json"}
        default url: "https://example.com"

        def destroy(article:)
          delete path: "/articles/#{article.id}"
        end
      }
      article = Article.new("1", nil)

      request = client.destroy(article: article)

      assert_equal "DELETE", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_predicate request.body.read, :blank?
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a DELETE request with a JSON body template" do
      client = declare_client("article_client") {
        default url: "https://example.com"

        def destroy(article:)
          delete path: "/articles/#{article.id}"
        end
      }
      article = Article.new("1", nil)
      declare_template "article_client/destroy.json", <<~JS
        {"confirm": true}
      JS

      request = client.destroy(article: article)

      assert_equal "DELETE", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_equal({"confirm" => true}, JSON.parse(request.body.read))
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a PUT request with a JSON body declared with locals" do
      client = declare_client("article_client") {
        default url: "https://example.com"

        def update(article:)
          put path: "/articles/#{article.id}", locals: {
            article: article
          }
        end
      }
      declare_template "article_client/update.json.erb", <<~ERB
        <%= { title: article.title }.to_json %>
      ERB
      article = Article.new("1", "Article Title")

      request = client.update(article: article)

      assert_equal "PUT", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_equal({"title" => "Article Title"}, JSON.parse(request.body.read))
      assert_equal "application/json", request.headers["Content-Type"]
    end

    test "constructs a PATCH request with an XML body declared with locals" do
      client = declare_client("article_client") {
        default url: "https://example.com"

        def update(article:)
          patch path: "/articles/#{article.id}", locals: {
            article: article
          }
        end
      }
      declare_template "article_client/update.xml.erb", <<~ERB
        <xml><%= article.title %></xml>
      ERB
      article = Article.new("1", "Article Title")

      request = client.update(article: article)

      assert_equal "PATCH", request.method
      assert_equal "https://example.com/articles/1", request.original_url
      assert_equal "<xml>Article Title</xml>", request.body.read.strip
      assert_equal "application/xml", request.headers["Content-Type"]
    end

    test "constructs a request with a body wrapped by a layout" do
      client = declare_client("article_client") {
        def create(article:)
          post \
            layout: "article_client",
            locals: {article: article},
            url: "https://example.com/special/articles"
        end
      }
      declare_template "layouts/article_client.json.erb", <<~ERB
        { "response": <%= yield %> }
      ERB
      declare_template "article_client/create.json.erb", <<~ERB
        { "title": "<%= article.title %>" }
      ERB
      article = Article.new(nil, "From Layout")

      request = client.create(article: article)

      assert_equal(
        {"response" => {"title" => "From Layout"}},
        JSON.parse(request.body.read)
      )
    end

    test "construacts a JSON request body from a raw template" do
      client = declare_client("status_client") {
        default url: "https://example.com"

        def ping
          post path: "/ping"
        end
      }
      declare_template "status_client/ping.json", <<~JS
        {"status": "healthy"}
      JS

      request = client.ping

      assert_equal "https://example.com/ping", request.original_url
      assert_equal "application/json", request.headers["Content-Type"]
      assert_equal "healthy", JSON.parse(request.body.read).fetch("status")
    end

    test "constructs a request with the full URL passed as an option" do
      client = declare_client {
        def create(article:)
          post url: "https://example.com/special/articles"
        end
      }

      request = client.create(article: nil)

      assert_equal "https://example.com/special/articles", request.original_url
    end

    test "constructs a request with additional headers" do
      client = declare_client {
        default url: "https://example.com"
        default headers: {"Content-Type": "application/json"}

        def create(article:)
          post path: "/articles", headers: {"X-My-Header": "hello!"}
        end
      }

      request = client.create(article: nil)

      assert_equal "application/json", request.headers["Content-Type"]
      assert_equal "hello!", request.headers["X-My-Header"]
    end

    test "constructs a request with overridden headers" do
      client = declare_client {
        default url: "https://example.com"
        default headers: {"Content-Type": "application/json"}

        def create(article:)
          post path: "/articles", headers: {"Content-Type": "application/xml"}
        end
      }

      request = client.create(article: nil)

      assert_equal "application/xml", request.headers["Content-Type"]
    end

    test "joins the path: to the default url:" do
      client = declare_client {
        default url: "https://example.com"

        def all
          get path: "articles"
        end
      }

      request = client.all

      assert_equal "https://example.com/articles", request.url
    end

    test "supports query parameters in the url: option" do
      client = declare_client {
        def all
          get url: "https://example.com/articles?q=all"
        end
      }

      request = client.all

      assert_equal "https://example.com/articles?q=all", request.url
    end

    test "supports query parameters in the path: option" do
      client = declare_client {
        default url: "https://example.com"

        def all
          get path: "articles?q=all"
        end
      }

      request = client.all

      assert_equal "https://example.com/articles?q=all", request.url
    end

    test "supports query in the query: option" do
      client = declare_client {
        def all
          get url: "https://example.com/articles", query: {q: :all}
        end
      }

      request = client.all

      assert_equal "https://example.com/articles?q=all", request.url
    end

    test "merges URL query parameters with those passed under the query: option" do
      client = declare_client {
        def all(search_term:, **query_parameters)
          get url: "https://example.com/articles?q=#{search_term}", query: query_parameters
        end
      }

      request = client.all(search_term: "foo", page: 1)

      assert_equal "https://example.com/articles?page=1&q=foo", request.url
    end

    test "resolves the Accept header from the URL extension" do
      client = declare_client {
        def all
          get url: "https://example.com/articles.json"
        end
      }

      request = client.all

      assert_equal "application/json", request.headers["Accept"]
    end

    test "raises an ArgumentError if path: provided without default url:" do
      client = declare_client {
        def create(article:)
          post path: "ignored"
        end
      }

      assert_raises ArgumentError, /path|url/ do
        client.create(article: nil)
      end
    end

    test "raises an ArgumentError when both url: and path: are provided" do
      client = declare_client {
        def create(article:)
          post url: "ignored", path: "ignored"
        end
      }

      assert_raises ArgumentError, /path|url/ do
        client.create(article: nil)
      end
    end

    test "ensures each descendant gets its own copy of defaults" do
      application_client = declare_client {
        default url: "https://example.com"
      }
      articles_client = Class.new(application_client) {
        default url: "https://example.com/articles"

        def create
          post
        end
      }

      tags_client = Class.new(application_client) {
        default url: "https://example.com/tags"

        def create
          post
        end
      }

      articles_request = articles_client.create
      tags_request = tags_client.create

      assert_equal "https://example.com/articles", articles_request.url
      assert_equal "https://example.com/tags", tags_request.url
    end
  end

  class ResponsesTest < ClientTestCase
    test "responses can be splatted into Rack triplets" do
      client = declare_client {
        def all
          get url: "https://example.com/articles"
        end
      }
      stub_request(:any, "https://example.com/articles").and_return(
        body: %({"responded": true}),
        headers: {"Content-Type": "application/json"},
        status: 201
      )

      status, headers, body = *client.all.submit

      assert_equal 201, status
      assert_equal "application/json", headers["Content-Type"]
      assert_equal true, body["responded"]
    end

    test "#submit makes an appropriate HTTP request" do
      client = declare_client("article_client") {
        default url: "https://example.com"

        def create(article:)
          post path: "/articles", locals: {article: article}
        end
      }
      declare_template "article_client/create.json.erb", <<~ERB
        <%= { title: article.title }.to_json %>
      ERB
      article = Article.new(nil, "Article Title")
      stub_request(:any, Regexp.new("example.com")).and_return(
        body: %({"responded": true}),
        headers: {"Content-Type": "application/json"},
        status: 201
      )

      response = client.create(article: article).submit

      assert_equal response.status, 201
      assert_equal response.body, {"responded" => true}
      assert_requested :post, "https://example.com/articles", {
        body: {"title": "Article Title"},
        headers: {"Content-Type" => "application/json"}
      }
    end

    test "#submit parses a JSON response based on the `Content-Type`" do
      client = declare_client("article_client") {
        default url: "https://example.com"

        def create(article:)
          post path: "/articles", locals: {article: article}
        end
      }
      declare_template "article_client/create.json.erb", <<~ERB
        {"title": "<%= article.title %>"}
      ERB
      article = Article.new(nil, "Encoded as JSON")
      stub_request(:post, %r{example.com}).and_return(
        body: {"title": article.title, id: 1}.to_json,
        headers: {"Content-Type": "application/json;charset=UTF-8"},
        status: 201
      )

      response = client.create(article: article).submit

      assert_equal 201, response.status
      assert_equal "application/json;charset=UTF-8", response["Content-Type"]
      assert_equal({"title" => article.title, "id" => 1}, response.body)
    end

    test "#submit parses an XML response based on the `Content-Type`" do
      client = declare_client("article_client") {
        default url: "https://example.com"

        def create(article:)
          post path: "/articles", locals: {article: article}
        end
      }
      declare_template "article_client/create.xml.erb", <<~ERB
        <article title="<%= article.title %>"></article>
      ERB
      article = Article.new(nil, "Encoded as XML")
      stub_request(:post, %r{example.com}).and_return(
        body: %(<article title="#{article.title}" id="1"></article>),
        headers: {"Content-Type": "application/xml"},
        status: 201
      )

      response = client.create(article: article).submit

      assert_equal 201, response.status
      assert_equal "application/xml", response["Content-Type"]
      assert_equal article.title, response.body.root["title"]
      assert_equal "1", response.body.root["id"]
    end
  end
end
