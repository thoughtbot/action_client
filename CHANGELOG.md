# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
