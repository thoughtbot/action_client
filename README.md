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
    @title = "Hello, World"

    post url: "https://example.com/articles"
  end
end
```

By default, `ActionClient` will deduce the request's [`Content-Type:
application/json` HTTP header][mdn-content-type] based on the format of the
action's template. In this case, since we've declared `.json.erb`, the
`Content-Type` will be set to `application/json`. The same would be true for a
template named `create.json.jbuilder`.

If we were to declare the template as `create.xml.erb` or `create.xml.builder`,
the `Content-Type` header would be set to `application/xml`.

[mdn-post]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST
[naming-actions]: https://guides.rubyonrails.org/action_controller_overview.html#methods-and-actions
[mdn-content-type]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type

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

When `ActionClient` is able to infer the request's `Content-Type` to be either
`JSON` or `XML`, it will parse the returned `body` value ahead of time.

Requests make with `application/json` will be parsed into [`Hash`
instances][ruby-hash] by [`JSON.parse`][json-parse], and requests made with
`application/xml` will be parsed into [`Nokogiri::XML::Document`
instances][nokogiri-document] by [`Nokogiri::XML`][nokogiri-xml].

If you'd prefer to deal with the [Rack status-headers-body
triplet][rack-triplet] directly, you can coerce the
[`Rack::Response`][Rack::Response] into an `Array` for multiple assignment by
splatting (`*`) the return value directly:,

```ruby
request = ArticlesClient.create(title: "Hello, World")

status, headers, body = *request.submit
```

[rack]: https://github.com/rack/rack
[Rack::Response]: https://www.rubydoc.info/gems/rack/Rack/Response
[rack-triplet]: https://github.com/rack/rack/blob/master/SPEC.rdoc#the-response-
[json-parse]: https://ruby-doc.org/stdlib-2.6.3/libdoc/json/rdoc/JSON.html#method-i-parse
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

## Configuration

### Declaring `default` options

Descendants of `ActionClient::Base` can specify some defaults:

```ruby
class ArticlesClient < ActionClient::Base
  default url: "https://example.com"
  default headers: { "Content-Type": "application/json" }

  def create(title:)
    post path: "/articles", locals: { title: title }
  end
end
```

Default values can be overridden on a request-by-request basis.

When a default `url:` key is specified, a request's full URL will be built by
joining the base `default url: ...` value with the request's `path:` option.

### Declaring `after_submit` callbacks

When submitting requests from an `ActionClient::Base` descendant, it can be
useful to modify the response's body before returning the response to the
caller.

As an example, consider instantiating [`OpenStruct` instances][OpenStruct] from
each response body by declaring an `after_submit` hook:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit do |status, headers, body|
    [status, headers, OpenStruct.new(body)]
  end
end
```

When declaring `after_submit` hooks, it's important to make sure that the block
returns a [`Rack`-compliant triplet][Rack-Response] of `status`, `headers`, and
`body`.

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
      [status, headers, Article.new(body)]
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
      Article.new(body)
    end
  end
end
```

[OpenStruct]: https://ruby-doc.org/stdlib-2.7.1/libdoc/ostruct/rdoc/OpenStruct.html
[Rack-Response]: https://github.com/rack/rack/blob/master/SPEC.rdoc#label-Rack+applications
[ruby-block]: https://ruby-doc.org/core-2.7.1/doc/syntax/methods_rdoc.html#label-Block+Argument

### Executing `after_submit` for a range of HTTP Status Codes

In some cases, applications might want to raise Errors based on a response's
[HTTP Status Code][HTTP-codes].

For example, when a response has a [422 HTTP Status][422], the server is
indicating that there were invalid parameters.

To map that to an application-specific error code, declare an `after_submit`
that passes a `with_status: 422` as a keyword argument:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit with_status: 422 do |status, headers, body|
    raise MyApplication::InvalidDataError, body.fetch("error")
  end
end
```

In some cases, there are multiple HTTP Status codes that might map to a similar
concept. For example, a [401][] and [403][] might correspond to similar concepts
in your application, and you might want to handle them the same way.

You can pass them to `after_submit with_status:` as either an
[`Array`][ruby-array] or a [`Range`][ruby-range]:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit with_status: [401, 403] do |status, headers, body|
    raise MyApplication::SecurityError, body.fetch("error")
  end

  after_submit with_status: 401..403 do |status, headers, body|
    raise MyApplication::SecurityError, body.fetch("error")
  end
end
```

If the block is only concerned with the value of the `body`, declare the block
with a single argument:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit with_status: 422 do |body|
    raise MyApplication::ArgumentError, body.fetch("error")
  end
end
```

When passing the [HTTP Status Code][HTTP-codes] singularly or as an `Array`,
`after_submit` will also accept a `Symbol` that corresponds to the [name of the
Status Code][status-code-name]:

```ruby
class ArticlesClient < ActionClient::Base
  after_submit with_status: :unprocessable_entity do |body|
    raise MyApplication::ArgumentError, body.fetch("error")
  end

  after_submit with_status: [:unauthorized, :forbidden] do |body|
    raise MyApplication::SecurityError, body.fetch("error")
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

## Installation
Add this line to your application's Gemfile:

```ruby
gem "action_client", github: "thoughtbot/action_client"
```

And then execute:
```bash
$ bundle
```

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
