# ActionClient

Make HTTP calls by leveraging Rails rendering

## This project is in its early phases of development

Its interface, behavior, and name are likely to change drastically before being
published to RubyGems. Use at your own risk.

## Usage

Considering a hypothetical scenario where we need to make a [`POST`
request][mdn-post] to `https://example.com/articles` with a JSON payload of `{
"title": "Hello, World" }`.

### Declaring the Client

First, declare the `ArticlesClient` as a descendant of `ActionClient::Base`:

```ruby
class ArticlesClient < ActionClient::Base
end
```

### Requests

Next, declare the request method. In this case, the semantics are similar to
[Rails' existing controller naming conventions][naming-actions], so let's lean
into that by declaring the `create` action so that it accepts a `title:` option:

```ruby
class ArticlesClient < ActionClient::Base
  def create(title:)
  end
end
```

### Constructing the Request

Our client action will need to make an [HTTP `POST` request][mdn-post] to
`https://example.com/articles`, so let's declare that call:

```ruby
class ArticlesClient < ActionClient::Base
  def create(title:)
    post url: "https://example.com/articles"
  end
end
```

The request will need a payload for its body, so let's declare the template as
`app/views/articles_client/create.json.erb`:

```json+erb
{ "title": <%= @title %> }
```

Since the template needs access to the `@title` instance variable, update the
client's request action to declare it:

```ruby
class ArticlesClient < ActionClient::Base
  def create(title:)
    @title = title

    post url: "https://example.com/articles"
  end
end
```

By default, `ActionClient` will deduce the request's
[`Content-Type`][mdn-content-type] and [`Accept`][mdn-accept] HTTP headers based
on the format of the action's template. In this example's case, since we've
declared `.json.erb`, the `Content-Type` will be set to `application/json`. The
same would be true for a template named `create.json.jbuilder`.

If we were to declare the template as `create.xml.erb` or `create.xml.builder`,
the `Content-Type` header would be set to `application/xml`.

For requests that have not explicitly set the `Accept` header and cannot infer
it from the body's template format, a URL with a file extension will be used to
determine the [`Accept` header][mdn-accept].

[mdn-post]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST
[naming-actions]: https://guides.rubyonrails.org/action_controller_overview.html#methods-and-actions
[mdn-content-type]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
[mdn-accept]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept

### Responses

Finally, it's time to submit the request.

In the application code that needs to make the HTTP call, invoke the `#submit`
method:

```ruby
request = ArticlesClient.create(title: "Hello, World")

response = request.submit
```

The `#submit` call transmits the HTTP request, and processes the response
through a stack of [Rack middleware][rack].

The return value is an instance of a [`Rack::Response`][Rack::Response], which
responds to `#status`, `#headers`, and `#body`.

If you'd prefer to deal with the [Rack status-headers-body
triplet][rack-triplet] directly, you can coerce the
[`Rack::Response`][Rack::Response] into an `Array` for multiple assignment by
splatting (`*`) the return value directly:,

```ruby
request = ArticlesClient.create(title: "Hello, World")

status, headers, body = *request.submit
```

### Response body parsing

When `ActionClient` is able to infer the request's `Content-Type` to be either
JSON, [JSON-LD][], or XML, it will parse the returned `body` value ahead of
time.

Responses with `Content-Type: application/json` headers will be parsed into
Ruby objects by [`JSON.parse`][json-parse]. JSON objects will
become instances of
[`HashWithIndifferentAccess`][HashWithIndifferentAccess], so that keys can be
accessed via `Symbol` or  `String`.

Responses with `Content-Type: application/xml` headers will be parsed into
[`Nokogiri::XML::Document` instances][nokogiri-document] by
[`Nokogiri::XML`][nokogiri-xml].

If the response body is invalid JSON or XML, `#submit` will raise an
`ActionClient::ParseError`. You can `rescue` from this exception specifically,
then access both the original response `#body` and the `#content_type` from the
instance:

```ruby
def fetch_articles
  response = ArticlesClient.all.submit

  # ...

  response.body.map { |attributes| Article.new(attributes) }
rescue ActionClient::ParseError => error
  Rails.logger.warn "Failed to parse body: #{error.body}. Falling back to empty result set"

  []
end
```

It's important to note that parsing occurs before any other middlewares declared
in `ActionClient::Base` descendants. If your invocation `rescue` block catches
an exception, none of the middlewares would have been run at that point in the
execution.

[JSON-LD]: https://json-ld.org/
[rack]: https://github.com/rack/rack
[Rack::Response]: https://www.rubydoc.info/gems/rack/Rack/Response
[rack-triplet]: https://github.com/rack/rack/blob/master/SPEC.rdoc#the-response-
[json-parse]: https://ruby-doc.org/stdlib-2.6.3/libdoc/json/rdoc/JSON.html#method-i-parse
[HashWithIndifferentAccess]: https://api.rubyonrails.org/classes/ActiveSupport/HashWithIndifferentAccess.html
[ruby-hash]: https://ruby-doc.org/core-2.7.1/Hash.html
[nokogiri-xml]: https://nokogiri.org/rdoc/Nokogiri.html#XML-class_method
[nokogiri-document]: https://nokogiri.org/rdoc/Nokogiri/XML/Document.html

### Query Parameters

To set a request's query parameters, pass them a `Hash` under the `query:`
option:

```ruby
class ArticlesClient < ActionClient::Base
  def all(search_term:)
    get url: "https://examples.com/articles", query: { q: search_term }
  end
end
```

You can also pass query parameters directly as part of the `url:` or `path:`
option:

```ruby
class ArticlesClient < ActionClient::Base
  default url: "https://examples.com"

  def all(search_term:, **query_parameters)
    get path: "/articles?q={search_term}", query: query_parameters
  end
end
```

When a key-value pair exists in both the `path:` (or `url:`) option and `query:`
option, the value present in the URL will be overridden by the `query:` value.

### ActiveJob integration

If the call to the Client HTTP request can occur outside of Rails'
request-response cycle, transmit it in the background by calling
`#submit_later`:

```ruby
request = ArticlesClient.create(title: "Hello, from ActiveJob!")

request.submit_later(wait: 1.hour)
```

All [options passed to `#submit_later`][active-job-options] will be forwarded
along to `ActiveJob`.

To emphasize the immediacy of submitting a Request inline, `#submit_now` is an
alias for `#submit`.

[active-job-options]: https://guides.rubyonrails.org//active_job_basics.html#enqueue-the-job

#### Extending `ActionClient::SubmissionJob`

In some cases, we'll need to take action after a client submits a request from a
background worker.

To enqueued an `ActionClient::Base` descendant class' requests with a custom
`ActiveJob`, first declare the job:

```ruby
# app/jobs/articles_client_job.rb
class ArticlesClientJob < ActionClient::SubmissionJob
  after_perform only_status: 500..599 do
    status, headers, body = *response

    Rails.logger.info("Retrying ArticlesClient job with status: #{status}...")

    retry_job queue: "low_priority"
  end
end
```

Similarly, to execute an `after_perform` for statuses that **do not match**
the given status codes, declare the `except_status:` option:

```ruby
# app/jobs/articles_client_job.rb
class ArticlesClientJob < ActionClient::SubmissionJob
  after_perform except_status: 200 do
    status, headers, body = *response

    Rails.logger.info("Retrying ArticlesClient job with status: #{status}...")

    retry_job queue: "low_priority"
  end
end
```

Within the block, the Rack triplet is available as `response`.

Next, configure your client class to enqueue jobs with that class:

```ruby
class ArticlesClient < ActionClient::Base
  self.submission_job = ArticlesClientJob
end
```

The `ActionClient::SubmissionJob` provides an extended version of
[`ActiveJob::Base.after_perform`][after_perform] that accepts a `only_status:`
option, to serve as a guard clause filter.

[after_perform]: https://api.rubyonrails.org/classes/ActiveJob/Callbacks/ClassMethods.html#method-i-after_perform

## Configuration

### Declaring `default` options

Descendants of `ActionClient::Base` can specify some defaults:

```ruby
class ArticlesClient < ActionClient::Base
  default url: "https://example.com"
  default headers: { "Authorization": "Token #{ENV.fetch('EXAMPLE_API_TOKEN')}" }

  def create(title:)
    post path: "/articles", locals: { title: title }
  end
end
```

When specifying default `headers:` values, descendant key-value pairs will
override inherited key-value pairs. Consider the following inheritance
hierarchy:

```ruby
class ApplicationClient < ActionClient::Base
  default headers: {
    "X-Special": "abc123",
    "Content-Type": "text/plain",
  }
end

class ArticlesClient < ApplicationClient
  default headers: {
    "Content-Type": "application/json"
  }
end
```

Requests made by the `ArticlesClient` will inherit the `X-Special` header from
the `ApplicationClient`, and will override the `Content-Type` header to
`application/json`, since it's declared in the descendant class.

Default values can be overridden on a request-by-request basis.

When a default `url:` key is specified, a request's full URL will be built by
joining the base `default url: ...` value with the request's `path:` option.

### Configuring your clients in YAML

Consider the following configuration file declared at
`config/clients/articles.yml`:

```yaml
# config/clients/articles.yml
default: &default
  url: "https://staging.example.com"

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
  url: "https://example.com"
```

In this example, the `ArticlesClient.configuration` will read directly from the
environment-aware `config/clients/articles.yml` file.

The client class can access those values directly from `.configuration`:

```ruby
class ArticlesClient < ActionClient::Base
  default url: configuration.url
end
```

If there are `url:` or `headers:` declarations in the configuration file, they
will implicitly be forwarded as arguments to `default`.

When a matching configuration file does not exist,
`ActionClient::Base.configuration` returns an empty instance of
[`ActiveSupport::OrderedOptions`][OrderedOptions].

[OrderedOptions]: https://api.rubyonrails.org/classes/ActiveSupport/OrderedOptions.html

#### Configuring `config.action_client.parser`

By default, `ActionClient` will parse each response's body `String` based on the
value of the `Content-Type` header. Out of the box, `ActionClient` supports
parsing `application/json` and `application/xml` headers.

This feature is powered by an extensible set of configurations. If you'd like to
declare additional parsers for other `Content-Type` values, or you'd like to
override the existing parsers, declare a `Hash` mapping from `Content-Type`
values to callable blocks that accept a single String argument containing the
response's body `String`:

```ruby
# config/application.rb

config.action_client.parsers = {
  "text/plain": -> (body) { body.strip },
}
```

### Declaring `after_submit` callbacks

When submitting requests from an `ActionClient::Base` descendant, it can be
useful to modify the response's body before returning the response to the
caller.

As an example, consider instantiating [`OpenStruct` instances][OpenStruct] from
each response body by declaring an `after_submit` hook:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit { |body| response.body = OpenStruct.new(body) }
end
```

Alternatively, `after_submit` blocks can accept a Rack triplet of arguments:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit do |status, headers, body|
    if status == 201
      response.body = OpenStruct.new(body)
    end
  end
end
```

In addition to passing a block argument, you can specify a method name:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit :wrap_in_open_struct

  # ...

  private def wrap_in_open_struct(body)
    response.body = OpenStruct.new(body)
  end
end
```

#### Declaring Request-specific callbacks

To specify a Request-specific callback, pass a [block argument][ruby-block] that
accepts a `Rack` triplet.

For example, assuming that an `Article` model class exists and accepts
attributes as a `Hash`, consider constructing an instance from the `body`:

```ruby
class ArticlesClient < ActionClient::Base
  default url: "https://example.com"

  def create(title:)
    @title = title

    post path: "/articles" do |status, headers, body|
      if status == 201
        response.body = Article.new(body)
      end
    end
  end
end
```

Request-level blocks are executed _after_ class-level `after_submit` blocks.

#### Transforming the response's `body`

When your callback is only interested in modifying the `body`, you can declare
it with a single block argument:

```ruby
class ArticlesClient < ActionClient::Base
  default url: "https://example.com"

  def create(title:)
    @title = title

    post path: "/articles" do |body|
      response.body = Article.new(body)
    end
  end
end
```

[OpenStruct]: https://ruby-doc.org/stdlib-2.7.1/libdoc/ostruct/rdoc/OpenStruct.html
[Rack-Response]: https://github.com/rack/rack/blob/master/SPEC.rdoc#label-Rack+applications
[ruby-block]: https://ruby-doc.org/core-2.7.1/doc/syntax/methods_rdoc.html#label-Block+Argument

### Executing `after_submit` for a set of Requests

In some cases, a `ActionClient::Base` descendant might want to execute an
`after_submit` hook for a certain set of Request actions.

To specify which actions an `after_submit` hook should execute for, declare an
`after_submit` that passes theirs names as the `only:` option:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit(only: [:create, :update]) { |body| Article.new(body) }

  def create
    # ...
  end

  def update
    # ...
  end

  def all
    # ...
  end
end
```

Similarly, to specify which actions an `after_submit` hook **should not**
execute for, declare an `after_submit` that passes theirs names as the `except:`
option:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit(except: [:all]) { |body| Article.new(body) }

  def create
    # ...
  end

  def update
    # ...
  end

  def all
    # ...
  end
end
```

### Executing `after_submit` for a range of HTTP Status Codes

In some cases, applications might want to raise Errors based on a response's
[HTTP Status Code][HTTP-codes].

For example, when a response has a [422 HTTP Status][422], the server is
indicating that there were invalid parameters.

To map that to an application-specific error code, declare an `after_submit`
that passes a `only_status: 422` as a keyword argument:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit only_status: 422 do |status, headers, body|
    raise MyApplication::InvalidDataError, body.fetch("error")
  end
end
```

In some cases, there are multiple HTTP Status codes that might map to a similar
concept. For example, a [401][] and [403][] might correspond to similar concepts
in your application, and you might want to handle them the same way.

You can pass them to `after_submit only_status:` as either an
[`Array`][ruby-array] or a [`Range`][ruby-range]:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit only_status: [401, 403] do |status, headers, body|
    raise MyApplication::SecurityError, body.fetch("error")
  end

  after_submit only_status: 401..403 do |status, headers, body|
    raise MyApplication::SecurityError, body.fetch("error")
  end
end
```

If the block is only concerned with the value of the `body`, declare the block
with a single argument:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit only_status: 422 do |body|
    raise MyApplication::ArgumentError, body.fetch("error")
  end
end
```

When passing the [HTTP Status Code][HTTP-codes] singularly or as an `Array`,
`after_submit` will also accept a `Symbol` that corresponds to the [name of the
Status Code][status-code-name]:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit only_status: :unprocessable_entity do |body|
    raise MyApplication::ArgumentError, body.fetch("error")
  end

  after_submit only_status: [:unauthorized, :forbidden] do |body|
    raise MyApplication::SecurityError, body.fetch("error")
  end
end
```

### Excluding an `after_submit` for a range of HTTP Status Codes

To _exclude_ responses that don't match a particular set of HTTP Status codes,
declare the `after_submit` with `except_status:` instead:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit except_status: [:success, :created] do |body|
    raise MyApplication::ArgumentError, body.fetch("error")
  end
end
```

[HTTP-codes]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
[401]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/401
[403]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/403
[422]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/422
[ruby-array]: https://ruby-doc.org/core-2.7.1/Array.html
[ruby-range]: https://ruby-doc.org/core-2.7.1/Range.html
[status-code-name]: https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

### Previews

Inspired by [`ActionMailer::Previews`][action_mailer_previews], you can view
previews for an exemplary outbound HTTP request:

```ruby
# test/clients/previews/articles_client_preview.rb
class ArticlesClientPreview < ActionClient::Preview
  def create
    ArticlesClient.create(title: "Hello, from Previews!")
  end
end
```

To view the URL, headers and payload that would be generated by that request,
visit
<http://localhost:3000/rails/action_client/clients/articles_client/create>.

Each request's preview page also include a copy-pastable, terminal-ready [`cURL`
command][curl].

[action_mailer_previews]: https://guides.rubyonrails.org/action_mailer_basics.html#previewing-emails
[curl]: https://curl.haxx.se/

### Configuring Previews

By default, Preview routes are available in all environments except for
`production`, and can be changed by setting
`config.action_client.enable_previews`.

By default, Preview declarations are loaded from `test/clients/previews`, and
can be changed by setting `config.action_client.previews_path`.

```ruby
# config/application.rb

config.action_client.enable_previews = true
config.action_client.previews_path = "spec/previews/clients"
```

## Testing

To integrate `ActionClient`-provided assertions into your tests, include the
`ActionClient::TestHelpers` module:

```ruby
# test/controllers/articles_controller_test.rb
class ArticlesControllerTest < ActionDispatch::IntegrationTest
  include ActionClient::TestHelpers

  # ...
end
```

### Integrating with WebMock

In your application's test suite, it will often be helpful to replace the
transmission of HTTP requests with fake HTTP response data.

`ActionClient` builds on top of [`webmock`][webmock] to provide an interface for
substituting mocked HTTP responses into your test runs.

To construct a `webmock`-provided [`stub_request` chain][stub_request], first
include the `ActionClient::TestHelpers` module into your testing environment.
Then, pass a `ActionClient`-constructed request to `stub_request`, chaining the
typical Webmock configurations off of that object:

```ruby
class TestCase < ActiveSupport::TestCase
  include ActionClient::TestHelpers

  test "submits an HTTP request to create an Article" do
    request = ArticlesClient.create(title: "Hello, World")
    stub_request(request).to_return(
      status: 422,
      headers: { "Content-Type" => "application/json" },
      body: { status: "invalid" }.to_json,
    )

    # ... exercise phase

    assert_requested request, times: 1
  end
end
```

The object returned by `stub_request(ArticlesClient.create(...))` responds to
all of the same methods as the [`webmock`-provided `stub_request`
helper][stub_request], along with supporting some additional options.

### Assertions

Similar to the extensions made to [Webmock's `stub_request`][stub_request],
mixing-in the `ActionClient::TestHelpers` module into your tests also extends
[Webmock's `assert_requested` and `assert_not_requested`][assertions].

### Stubbing return values with `to_fixture`

When chaining together a `stub_request` declaration,
invoke the `to_fixture` method to construct a response from fixture files:

```ruby
stub_request(ArticlesClient.create(title: "My Test Title")).to_fixture(
  status: 200,
  headers: { "X-Special-Header" => "abc123" },
)
```

When a chain ends with `to_fixture`, `ActionClient` will:

1.  lookup a view template in the `test/client/fixtures` directory named in a
    way that corresponds to the `ActionClient::Base` descendant, and the stubbed
    request name. In this case, the template name will be
    `articles_client/create`.

2.  render that template to a `String`

3.  pass that `String` to the `to_return` method as the `body:` option

4.  determine the stubbed response's [`Content-Type` header][content_type] based
    on the format of the rendered template, and merge it into the `to_return`
    call's `headers:` option. For example, `articles_client/create.json` will
    result in merging `headers: { "Content-Type": application/json" }`, and
    `articles_client/create.xml` will result in
    `headers: { "Content-Type": "application/xml" }`.

The view templates that are resolved by the `to_fixture` call can also be
dynamic, like any other Rails template. If your fixture template requires local
variables to render, you can pass them in as a `Hash` to the `to_fixture` call:

```ruby
stub_request(ArticlesClient.create(title: "My Test Title")).to_fixture(
  status: 200,
  headers: { "X-Special-Header" => "abc123" },
  locals: { title: "My Test Title" },
)
```

Then, reference those values in the fixture template:

```json+erb
<%# test/client/fixtures/articles_client/create.json.erb %>
{ "id": 1, "title": "<%= title %>" }
```

By default, the request options will be made available as template-local
variables. For example, a call to `stub_request(ArticlesClient.create(title: "My
Title"))` will result in a `title` template-local variable with the value of `"My
Title"`.

Declaring different fixture templates for different [HTTP Status
Codes][mdn-http-status], leveraging the power of Rails' [`ActionPack`
variants][variants].

For example, to declare fixtures for both a successful request and an invalid
request, declare a template variant for each:

```json+erb
<%# test/client/fixtures/articles_client/create.json+created.erb %>
{ "id": 1, "title": "<%= title %>" }

<%# test/client/fixtures/articles_client/create.json+unprocessable_entity.erb %>
{ "error": "invalid!" }
```

Then, when declaring the stub, pass that status code (as a `Symbol`) to the
`status:` option:

```ruby
stub_request(ArticlesClient.create(title: "My Valid Title")).to_fixture(
  status: :created, locals: { title: "My Valid Title" },
)
stub_request(ArticlesClient.create(title: "")).to_fixture(
  status: :unprocessable_entity,
)
```

If Rails' variant resolution fails to find a specific template for an HTTP
Status variant, it will fall back to the more general template available.

In addition to using [HTTP Status Code names are variants][status-code-names],
you can also declare and refer to templates named with the Integer version as
well.

For example, to recreate the example above with Status Code Integers, declare
the templates like so:

```json+erb
<%# test/client/fixtures/articles_client/create.json+201.erb %>
{ "id": 1, "title": "<%= title %>" }

<%# test/client/fixtures/articles_client/create.json+422.erb %>
{ "error": "invalid!" }
```

And replace `:created` and `:unprocessable_entity` with `201` and `422`,
respectively:


```ruby
stub_request(ArticlesClient.create(title: "My Valid Title")).to_fixture(
  status: 201, locals: { title: "My Valid Title" },
)
stub_request(ArticlesClient.create(title: "")).to_fixture(
  status: 422,
)
```

**NOTE** Templates declared with variants in their file names **must** be
suffixed with a templating language suffix. For example,
`create.json+unprocessable_entity` _will not_ be recognized, but
`create.json+unprocessable_entity.erb` will.

[webmock]: https://github.com/bblimke/webmock
[stub_request]: https://github.com/bblimke/webmock#stubbing
[assertions]: https://github.com/bblimke/webmock/tree/v3.8.3#setting-expectations-in-testunit
[content_type]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
[variants]: https://guides.rubyonrails.org/4_1_release_notes.html#action-pack-variants
[mdn-http-status]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status
[status-code-names]: https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

### Configuring Fixtures

By default, fixture declarations are loaded from `test/clients/fixtures`, and
can be changed by setting `config.action_client.fixtures_path`.

```ruby
# config/application.rb

config.action_client.fixtures_path = "spec/fixtures/clients"
```

### ActiveJob Assertions

`ActionClient` provides a collection of assertions to verify that
requests processed by invoking `#submit_later` are enqueued or performed.

Inspired by the [Rails-provided `ActiveJob::TestHelper`
assertions][ActiveJob::TestHelper], `ActionClient` assertions verify that a
request has been performed, or been enqueued to be performed by a background
job.

When [`config.active_job.queue_adapter = :test`][test-adapter]:

* `assert_enqueued_request(request, **options, &block)`
* `assert_no_enqueued_requests(client_class, **options, &block)`

```ruby
# wrap the test's Exercise Phase
test "#create enqueues a request to the Articles API" do
  assert_enqueued_request ArticlesClient.create(title: "Hello, World")) do
    post articles_path(params: { article: { title: "Hello, World" } })
  end
end

# or assert after the test's Exercise Phase (requires Rails >= 6.0)
test "#create enqueues a request to the Articles API" do
  post articles_path(params: { article: { title: "Hello, World" } })

  assert_enqueued_request ArticlesClient.create(title: "Hello, World"))
end

# wrap the test's Exercise Phase
test "#create does not enqueue a request to the Articles API when invalid" do
  assert_no_enqueued_requests ArticlesClient do
    post articles_path(params: { article: { title: "" } })
  end
end

# or assert after the test's Exercise Phase (requires Rails >= 6.0)
test "#create does not enqueue a request to the Articles API when invalid" do
  post articles_path(params: { article: { title: "" } })

  assert_no_enqueued_requests ArticlesClient
end
```

When [`config.active_job.queue_adapter = :inline`][inline-adapter]:

* `assert_performed_request(request, **options, &block)`
* `assert_no_performed_requests(client_class, **options, &block)`

```ruby
# wrap the test's Exercise Phase
test "#create enqueues a request to the Articles API" do
  assert_performed_request ArticlesClient.create(title: "Hello, World")) do
    post articles_path(params: { article: { title: "Hello, World" } })
  end
end

# or assert after test's the Exercise Phase
test "#create enqueues a request to the Articles API" do
  perform_enqueued_jobs do
    post articles_path(params: { article: { title: "Hello, World" } })

    assert_performed_request ArticlesClient.create(title: "Hello, World"))
  end
end

# wrap the test's Exercise Phase
test "#create does not enqueue a request to the Articles API when invalid" do
  assert_no_performed_requests ArticlesClient do
    post articles_path(params: { article: { title: "" } })
  end
end

# or assert after test's the Exercise Phase
test "#create does not enqueue a request to the Articles API when invalid" do
  perform_enqueued_jobs do
    post articles_path(params: { article: { title: "" } })

    assert_no_performed_requests ArticlesClient
  end
end
```

[ActiveJob::TestHelper]: https://api.rubyonrails.org/classes/ActiveJob/TestHelper.html
[test-adapter]: https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/TestAdapter.html
[inline-adapter]: https://api.rubyonrails.org/classes/ActiveJob/QueueAdapters/InlineAdapter.html

## Installation
Add this line to your application's Gemfile:

```ruby
gem "action_client", github: "thoughtbot/action_client", branch: "main"
```

And then execute:
```bash
$ bundle
```

## Contributing

This project's Ruby code is linted by [standard][]. New code that is added
through Pull Requests cannot include any linting violations.

To helper ensure that your contributions don't contain any violations, please
consider [integrating Standard into your editor workflow][standard-editor].

[standard]: https://github.com/testdouble/standard
[standard-editor]: https://github.com/testdouble/standard#how-do-i-run-standard-in-my-editor

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
