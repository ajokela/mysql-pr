# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2025-11-25

### Changed

- **BREAKING**: Minimum Ruby version is now 3.0
- Modernized codebase with frozen string literals
- Updated to modern Ruby conventions and style
- Replaced deprecated `Fixnum` with `Integer`

### Removed

- Ruby 1.8.x and 1.9.x support
- Legacy encoding compatibility code

### Added

- **SSL/TLS connection support** - encrypted connections using Ruby's OpenSSL
  - `ssl_set` method for configuring SSL certificates
  - `ssl_options=` method for advanced SSL configuration
  - `ssl_enabled?` and `ssl_cipher` methods to query SSL status
  - Support for TLS 1.2 and TLS 1.3
- **MySQL 8.0 `caching_sha2_password` authentication** support
  - Full support for MySQL 8.0's default authentication plugin
  - Fast authentication path when password is cached
  - Full authentication via SSL or RSA encryption
  - Automatic auth plugin detection and switching
- Modern project structure with Bundler
- RSpec test configuration
- RuboCop for code style enforcement
- GitHub Actions CI pipeline
- Docker Compose configuration for testing
- Comprehensive README documentation

## [2.9.11] - 2012-06-13

### Added

- Initial release as mysql-pr (fork from mysql-ruby)
- Pure Ruby MySQL client implementation
- Prepared statements support
- Character set handling
