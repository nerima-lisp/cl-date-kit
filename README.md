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

The central idea is that a local wall-clock reading and an instant are
different types, and converting between them is where a zone's daylight-saving
gaps and overlaps have to be resolved explicitly:

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

An overlapping local time resolves the other way: pass `:preferred-offset` to
keep a previously chosen offset (`(zone-offset-of-hours -5)` picks the later,
EST reading of a 01:30 that occurs twice). Recurrence rules build on the same
distinction — see
[RFC 5545 recurrence](https://nerima-lisp.github.io/cl-date-kit/guide/core-concepts/)
for `PARSE-RRULE`, `MAKE-RRULE-SCHEDULE`, `MAKE-RRULE-SET`, and the streaming
`MAP-RRULE-SET-OCCURRENCES` k-way merge that enumerates `N` occurrences from
`K` sources in `O(N log K)` time and `O(K)` space.

## Install

```nix
# flake.nix
inputs.cl-date-kit = {
  url = "github:nerima-lisp/cl-date-kit/v1.0.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch.

For ASDF installation and runtime requirements, see the
[getting started guide](docs/src/getting-started.md).

## Documentation

- [Getting started](https://nerima-lisp.github.io/cl-date-kit/getting-started/)
- [API reference](https://nerima-lisp.github.io/cl-date-kit/reference/api/)
- [Architecture](https://nerima-lisp.github.io/cl-date-kit/reference/architecture/)
- [Compatibility](https://nerima-lisp.github.io/cl-date-kit/reference/compatibility/)

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
