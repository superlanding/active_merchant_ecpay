# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release dates are the dates the version was published on [rubygems.org](https://rubygems.org/gems/active_merchant_ecpay).

## [Unreleased]

> `lib/active_merchant_ecpay/version.rb` on `master` is already `0.2.0`, but that version is **not on rubygems.org yet**
> (the "Publish gem" run for it failed with "No trusted publisher configured for this workflow"), so it is listed here.
> Once 0.2.0 is published, rename this section to `## [0.2.0] - YYYY-MM-DD` and use the date shown on rubygems.org.

### Added

- Support for Rails 7.0, 7.1, 7.2, 8.0 and 8.1 on Ruby 3.0 – 3.4. `actionview` and `activesupport` (`>= 7.0`, `< 8.2`) are now runtime dependencies.
- RSpec specs for request building, `CheckMacValue`, notification checks and configuration; they never touch the network. SimpleCov coverage with `COVERAGE=1`.
- GitHub Actions: a Ruby × Rails test matrix (`test.yml`) and automatic publishing to RubyGems through Trusted Publishing (`publish.yml`).
- `CHANGELOG.md`, a full `README.md`, and documentation rules in `CLAUDE.md`.

### Changed

- **Breaking:** requires Ruby `>= 3.0` (`required_ruby_version`); Rails older than 7.0 is no longer supported.
- Development dependencies were modernised (`bundler >= 2`, `rake >= 13`); `mocha` and the old `rails >= 2.3.14` development dependency were removed in favour of per-version `gemfiles/`.

## [0.1.2] - 2018-11-16

Versions `0.1.0` and `0.1.1` were never published to RubyGems, so their changes ship in this release.

### Added

- ECPay (綠界科技) AIO checkout integration for ActiveMerchant / OffsitePayments: the `payment_service_for` form helper with `CheckMacValue` (MD5) generation, and `Notification` parsing / verification. Payment methods: credit card, ATM, CVS, barcode and Alipay constants. (0.1.0)
- `Notification#card4no`: last four digits of the credit card. (0.1.1)

### Changed

- Gemspec description and `require` clean-up (`money` is now required explicitly).

[Unreleased]: https://github.com/superlanding/active_merchant_ecpay/commits/master
[0.1.2]: https://rubygems.org/gems/active_merchant_ecpay/versions/0.1.2
