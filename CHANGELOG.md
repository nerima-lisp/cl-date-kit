# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

## [0.1.0] - 2026-07-30

### Added

- Initial release: `duration` and `period` deltas, `local-date`/`local-time`/
  `local-date-time` naive calendar values, `instant` and a `clock` protocol,
  a from-scratch IANA TZif (RFC 8536) reader with POSIX-TZ-footer
  extrapolation, `zone-offset`/`time-zone` with daylight-saving gap/overlap
  disambiguation, `zoned-date-time`, and ISO-8601/RFC-3339 formatting and
  parsing for every type.
- `offset-date-time` and `offset-time`, fixed-UTC-offset counterparts to
  `zoned-date-time` and `local-time`, with the same ISO-8601 formatting and
  parsing support as the rest of the library.
- RFC 5545 recurrence rules: `parse-rrule`/`format-rrule`,
  `make-rrule-schedule` for zone-aware, floating, or all-day `DTSTART`
  values, `map-rrule-occurrences`/`rrule-occurrences`/`do-rrule-occurrences`
  for enumerating occurrences, and `make-rrule-set` with
  `rrule-set-occurrences`/`map-rrule-set-occurrences` to compose multiple
  schedules with `RDATE`/`EXDATE` via a streaming k-way merge.
- `interval` and `local-date-interval`, half-open interval types with
  `contains`/`encloses`/`overlaps`/`abuts`/`connected`/`before`/`after`
  predicates and `intersection`/`span`/`union`/`gap`/`difference`
  operations.
- Locale-aware pattern formatting: built-in `:en` and `:ja`
  `date-time-locale` values, plus `make-date-time-locale` for supplying
  translated month names, weekday names, and AM/PM text.
- A dynamic clock context: `call-with-clock`/`with-clock` bind the clock
  used by every `*-now` operation for the duration of a scoped call.
- `truncated-to` and `rounded-to` operations (with selectable rounding
  mode) across `duration`, `local-time`, `local-date-time`, `instant`,
  `zoned-date-time`, `offset-date-time`, and `offset-time`.
- Zone-transition introspection: `time-zone-transition`, `zone-state`,
  `time-zone-transitions-between`, and `time-zone-database-version`.
- Calendar utilities: day-of-week and month arithmetic, plus
  `local-date-day-of-week-in-month`, `local-date-first-in-month`,
  `local-date-last-in-month`, `local-date-first-day-of-next-month`, and
  `local-date-first-day-of-next-year`.

### Changed

- Named-zone local-time resolution now binary-searches the TZif transition
  table instead of scanning it, examining only the boundaries that can
  affect the requested wall-clock value under the zone's parsed offsets.
