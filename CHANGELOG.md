# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Charming::Internal::Inflections`: internal string inflection helpers
  (`camelize`, `underscore`, `demodulize`, `deconstantize`, `constantize`,
  `humanize`, `pluralize`) with ActiveSupport-compatible semantics for the
  inputs Charming produces. `pluralize` covers a deliberate subset of English
  rules; exotic words may need a generated migration renamed by hand.

### Removed

- The direct `activesupport` runtime dependency. `activemodel` remains and
  brings activesupport transitively. `Charming.env` now returns an internal
  `EnvInquirer` (same predicate API: `Charming.env.development?` etc.).
  No app-facing changes.
