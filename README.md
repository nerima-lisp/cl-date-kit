# cl-date-kit

[![CI](https://github.com/nerima-lisp/cl-date-kit/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nerima-lisp/cl-date-kit/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-MkDocs%20Material-0a7a5a)](https://nerima-lisp.github.io/cl-date-kit/)

A dependency-free, SBCL-only date and time library. It builds the calendar
and clock shapes found in modern languages -- java.time's LocalDate/
LocalTime/LocalDateTime/Instant/Duration/Period/ZoneOffset/ZonedDateTime,
Rust's `time`/`chrono` split between naive and zone-aware values, JS
Temporal's disambiguation of daylight-saving gaps and overlaps, and Go
`time`'s simplicity -- on top of a from-scratch reader for the IANA time
zone database's on-disk TZif format (RFC 8536). Time zone data is read from
the `TZDIR` environment variable or `/usr/share/zoneinfo` at runtime rather
than bundled, so the library adds no ASDF dependency.

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

## Install

```nix
# flake.nix
inputs.cl-date-kit = {
  url = "github:nerima-lisp/cl-date-kit/v0.1.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note the pinned tag. Consumers inside this org must pin a release tag rather
than follow the default branch.

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
nix flake check      # tests + formatting + docs, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
```

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
