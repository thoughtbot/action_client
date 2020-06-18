# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add support for `only:` to execute `after_submit` hooks for a given set of
  action names (added by [@seanpdoyle][])

- Add support for `except_status:` to exclude `after_submit` execution for a
  given set of HTTP Status codes (added by [@seanpdoyle][])

- Rename `with_status:` option for `after_submit` and `after_perform`
  declarations to `only_status:` (added by [@seanpdoyle][])

- Configure whether or not to mount Preview routes along with the directory
  they're loaded from.
  (added by [@seanpdoyle][])

- Add support for extending how the Response middleware parses body strings
  (added by [@seanpdoyle][])

- Merge descendant `default headers: {}` declarations into inherited values
  (added by [@seanpdoyle][])

- Determine a request's missing `Accept` HTTP Header based on the URL path's
  file extension (added by [@seanpdoyle][])

- When determining how to parse the response, fall back to the request's
  `Accept` header when the response's `Content-Type` header is missing
  (added by [@seanpdoyle][])

- Add support for inferring `Content-Type` based on the extension of raw
  templates (e.g. `articles_client/create.json`) (added by [@seanpdoyle[]])

- Change development branch to `main` (added by [@seanpdoyle][])

- Integrate with `ActiveJob` by declaring
  `ActionClient::SubmittableRequest#submit_later`. To declare background job
  customizations, set `ActionClient::Base.submission_job` to a descendant of
  `ActionClient::SubmissionJob`, then declare `after_perform` callbacks.
  (added by [@seanpdoyle][])

- Integrate with Rails' `config_for` by reading configuration files declared
  in `config/clients` named to match the client name. For example,
  `ArticlesClient` will read from `config/clients/articles.yml`.
  (added by [@seanpdoyle][])

- The `after_submit` callbacks, along with request-level block versions, and the
  specialized `with_status:` version (added by [@seanpdoyle][])

[@seanpdoyle]: https://github.com/seanpdoyle
