# cl-date-kit

[![CI](https://github.com/nerima-lisp/cl-date-kit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-date-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-date-kit/)

A dependency-free, SBCL-only date and time library. It builds the calendar
and clock shapes found in modern languages -- java.time's LocalDate/
LocalTime/LocalDateTime/Instant/Interval/Duration/Period/ZoneOffset/ZonedDateTime,
Rust's `time`/`chrono` split between naive and zone-aware values, JS
Temporal's disambiguation of daylight-saving gaps and overlaps, and Go
`time`'s simplicity -- on top of a from-scratch reader for the IANA time
zone database's on-disk TZif format (RFC 8536). Time zone data is read from
the `TZDIR` environment variable or `/usr/share/zoneinfo` at runtime rather
than bundled, so the library adds no ASDF dependency.

Named-zone local-time resolution binary-searches the TZif transition table and
examines only boundaries that can affect the requested wall-clock value under
that zone's parsed offsets. This preserves exact gap and overlap semantics
without a full scan of historical transitions for each conversion.

Full documentation is published at <https://nerima-lisp.github.io/cl-date-kit/>.
The source for that site lives in [docs/src/](docs/src/).

## Quick Start

```lisp
(asdf:load-system "cl-date-kit")

(let* ((ny (cl-date-kit:find-time-zone "America/New_York"))
       (zdt (cl-date-kit:zoned-date-time-of-local
             (cl-date-kit:local-date-time-of 2024 3 10 2 30 0) ny)))
  (cl-date-kit:format-zoned-date-time zdt))
;; => "2024-03-10T03:30:00-04:00[America/New_York]"
;; 02:30 never happened that day (the spring-forward gap); the default
;; :COMPATIBLE disambiguation shifts it forward by the gap's length, landing
;; on the first valid post-gap (EDT) reading, as java.time's default does.
```

For an overlap, preserve a previously chosen offset when reconstructing a
timestamp from a local date-time and IANA zone:

```lisp
(let ((ny (cl-date-kit:find-time-zone "America/New_York")))
  (cl-date-kit:format-zoned-date-time
   (cl-date-kit:zoned-date-time-of-local
    (cl-date-kit:local-date-time-of 2024 11 3 1 30 0) ny
    :preferred-offset (cl-date-kit:zone-offset-of-hours -5))))
;; => "2024-11-03T01:30:00-05:00[America/New_York]"
;; 01:30 occurs twice; -05:00 selects the later EST occurrence.
```

## RFC 5545 Recurrence Rules

Parse an RFC 5545 RRULE, pair it with a zoned `DTSTART` for zone-aware timed
events, a `LOCAL-DATE-TIME` `DTSTART` for floating timed events, or a
`LOCAL-DATE` `DTSTART` for all-day events, and enumerate the resulting
local-calendar occurrences:

```lisp
(let* ((tokyo (cl-date-kit:find-time-zone "Asia/Tokyo"))
       (rule (cl-date-kit:parse-rrule
              "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=3"))
       (schedule
         (cl-date-kit:make-rrule-schedule
          (cl-date-kit:zoned-date-time-of-local
           (cl-date-kit:local-date-time-of 2024 1 1 9 0 0) tokyo)
          rule)))
  (cl-date-kit:rrule-occurrences schedule :max-periods 3))
;; => the final weekday at 09:00 for January, February, and March
```

`FORMAT-RRULE` produces the canonical property-value form.  RRULE schedules
follow RFC 5545 local-calendar rules: nonexistent wall-clock times in DST gaps
are skipped, and ambiguous overlap times use the earlier offset.
Floating `LOCAL-DATE-TIME` schedules have no zone or DST resolution and emit
their local values directly. Their `UNTIL`, when present, is also a
`LOCAL-DATE-TIME`.
Schedules without `UNTIL` must pass a positive `:max-periods` to the
occurrence APIs; the limit counts evaluated frequency periods. `COUNT` limits
emitted occurrences, not the number of periods searched, so it cannot provide
a termination guarantee on its own.
When the limit is exhausted before `COUNT` is reached, the occurrence APIs
return the generated prefix.
For an all-day schedule, use an RFC 5545 `DATE` `UNTIL` value and a
date-based frequency (`DAILY` through `YEARLY`); time-of-day frequencies and
`BYHOUR`, `BYMINUTE`, and `BYSECOND` are rejected.

Use `MAKE-RRULE-SET` to compose multiple schedules with explicit inclusions
and exclusions. `RRULE-SET-OCCURRENCES` returns the chronological union of
the member schedules and `:rdates`, removes matching `:exdates`, and
deduplicates values that denote the same instant even when their time zones
differ. Its `:max-periods` value is passed to every member schedule.

`MAP-RRULE-SET-OCCURRENCES` uses a streaming k-way merge: it retains one next
occurrence per RRULE or RDATE source, selects the next value with a priority
queue, and advances every source that emitted a duplicate before continuing.
It therefore produces `N` results from `K` sources in `O(N log K)` merge time
and `O(K)` merge storage without materializing unbounded schedules. Returning
`NIL` from its callback stops iteration before requesting another occurrence.

## Install

```nix
# flake.nix
inputs.cl-date-kit = {
  url = "github:nerima-lisp/cl-date-kit/v0.2.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch.

For ASDF installation and runtime requirements, see the
[installation guide](docs/src/installation.md).

## Documentation

- [Quick start](https://nerima-lisp.github.io/cl-date-kit/quick-start/)
- [API reference](https://nerima-lisp.github.io/cl-date-kit/api-reference/)
- [Architecture](https://nerima-lisp.github.io/cl-date-kit/architecture/)
- [Compatibility](https://nerima-lisp.github.io/cl-date-kit/compatibility/)

## Development

Development commands require [Nix](https://nixos.org/download/) with flakes
enabled. `flake.lock` pins SBCL's package set, the test-only
[`cl-weave`](https://github.com/nerima-lisp/cl-weave) dependency, and the
formatting toolchain; run the commands from a tracked checkout so Nix can
evaluate the repository as a flake.

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY and TZDIR already set
nix run .#test       # run the test suite
nix run .#coverage -- coverage/ # write an SB-COVER HTML report
nix run .#benchmark  # ISO 8601, IANA time-zone, and recurrence hot-path measurements
nix flake check      # tests + formatting + docs, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
```

The benchmark command reports elapsed nanoseconds and SBCL allocation bytes
per operation. Set `CL_DATE_KIT_BENCHMARK_ITERATIONS` to override the default
of 100000 iterations.

Tests live in `t/` and run under [cl-weave](https://github.com/nerima-lisp/cl-weave),
the org's test framework. They read real IANA time zone data; `nix flake
check` points `TZDIR` at nixpkgs' `tzdata` package so this does not depend on
the host's copy.

## Contributing

See the org-wide [CONTRIBUTING](https://github.com/nerima-lisp/.github/blob/main/CONTRIBUTING.md)
guide and the [package standard](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md).

## Support

See [SUPPORT](https://github.com/nerima-lisp/.github/blob/main/SUPPORT.md).

## License

MIT. See [LICENSE](LICENSE).
