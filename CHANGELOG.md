# Changelog

All notable changes to cl-date-kit are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0]

First stable release. The public API (every exported symbol's name, signature, and
behavior) is unchanged from 0.3.0. The version is bumped to 1.0.0 to mark the stable
release, not because of an incompatible API change.

### Fixed

- `package.lisp` and `conditions.lisp` each independently exported condition symbols,
  producing a split-brain export list: `invalid-rrule`/`invalid-rrule-reason`/
  `invalid-rrule-value` were double-exported, while `invalid-duration-division`,
  `invalid-duration-division-duration`, `invalid-duration-division-divisor`,
  `instant-precision-loss`, `instant-precision-loss-instant`,
  `instant-precision-loss-representation`, and the three
  `invalid-zoned-date-time-offset-*` reader accessors were never exported from
  `package.lisp` at all, making them unreachable outside the `cl-date-kit::` internal
  package for external callers. All exports now live solely in `package.lisp`.
- `run-coverage.lisp` called `asdf:load-system` with `:force "cl-date-kit"` (a bare
  string), which newer ASDF rejects; changed to `:force t`.
- `flake.nix`'s isolated-cache `ASDF_OUTPUT_TRANSLATIONS` directive used a malformed
  destination form (`(t "path" :implementation)`); corrected to the required nested
  list form (`(t ("path" :implementation))`).

### Changed (internal only -- no public API impact)

- Introduced `src/macros.lisp`, a shared `defmacro` foundation loaded immediately
  after `package.lisp`, and consolidated onto it:
  - `define-ordering-operators`, replacing 12 independent five-function
    `=`/`<`/`<=`/`>`/`>=` blocks across every comparable type.
  - `define-fixed-unit-arithmetic`, unifying three near-duplicate plus/minus-pair
    generator macros in `duration.lisp`, `local-time.lisp`, and `local-date-time.lisp`.
  - `define-date-kit-condition`, replacing 19 of `conditions.lisp`'s 20
    `define-condition` forms (name/slots/report-string all preserved byte-for-byte).
  - `define-period-fixed-component-arithmetic`, relocated from `period.lisp` as-is.
- Extended continuation-passing style from the library's existing enumeration APIs
  into its parsers: `posix-tz.lisp`'s POSIX-TZ grammar parser now threads an
  `on-success` continuation alongside its `invalid` failure continuation, with
  `parse-posix-tz-string` chaining multiple parse steps as nested continuations.
  `pattern-parser.lisp` gained an equivalent `%pattern-parse-parts` continuation
  chain for its multi-field pattern parse loop.
- Extracted POSIX-TZ grammar magic numbers (offset ranges, transition-time bounds,
  Julian-day/day-of-year/month-week-day rule ranges) into named `defconstant`s in
  `posix-tz.lisp`, and unified five `86400`-second-per-day literals onto the
  existing `+seconds-per-day+` constant.
- Split four oversized source files along existing internal seams, each producing
  two focused files (see `docs/src/index.md` for the current layer map):
  `iso8601-date.lisp` / `iso8601-year-month-day.lisp`,
  `zoned-date-time.lisp` / `zoned-date-time-arithmetic.lisp`,
  `iso8601.lisp` / `iso8601-offset.lisp`,
  `pattern-parser.lisp` / `pattern-builder.lisp`.
- Split the two largest test files, and two others, along their existing `describe`
  boundaries into 12 new files (`t/zone-test.lisp` alone went from 1322 lines into 5
  files); no test content was added, removed, or altered in this step.
- Upgraded the test-only `cl-weave` dependency from v1.1.4 to v1.3.0 and adopted its
  `before-each` fixtures, `it-run-if` conditional registration, and `it-property`
  generative tests; upgraded the build-only `cl-nix-forge` dependency from v0.4.0 to
  v0.5.0.
- Converted several hand-rolled `dolist`-based table tests to cl-weave's `it-each`,
  giving each case its own named pass/fail result instead of one aggregate result.

### Added

- Substantially expanded test coverage: the suite grew from 715 to 836 tests, and
  sb-cover expression coverage rose from stale/partial to 92%\+ across nearly every
  source file (several files moved from the 70s/80s% into the high 90s or 99%\+).
  Remaining gaps are either confirmed sb-cover instrumentation artifacts (compile-time
  and macro-expansion-time forms that sb-cover cannot attribute execution to) or
  specific defensive branches confirmed structurally unreachable through the public
  API.
- `it-property` round-trip tests: `local-date-from-epoch-day`/`-to-epoch-day` inverse
  over a wide epoch-day range, and `format-date-time-with-pattern`/
  `parse-date-time-with-pattern` inverse for a fixed ISO-style pattern over generated
  valid date-time field combinations.

[1.0.0]: https://github.com/nerima-lisp/cl-date-kit/releases/tag/v1.0.0
