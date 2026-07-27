# Development

The Nix workflow requires [Nix](https://nixos.org/download/) with flakes
enabled. From a tracked checkout, `flake.lock` pins nixpkgs, the test-only
`cl-weave` source tree, and treefmt so the following commands use a
reproducible toolchain:

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY and TZDIR already set
nix run .#test       # run the test suite
nix flake check      # tests + formatting + docs, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
```

Without Nix:

```sh
git clone --branch v1.0.0 https://github.com/nerima-lisp/cl-weave.git /path/to/cl-weave
CL_SOURCE_REGISTRY="/path/to/cl-weave//:$(pwd)//" sbcl --script run-tests.lisp
```

The non-Nix command uses the host's IANA time-zone database, normally under
`/usr/share/zoneinfo`; set `TZDIR` if it is installed elsewhere.

## Test layout

Tests live in `t/`, one file per `src/` file (`src/zone.lisp` ->
`t/zone-test.lisp`), and run under
[cl-weave](https://github.com/nerima-lisp/cl-weave), the org's test
framework, using `describe`/`it`/`expect`/`signals`.

The time-zone tests (`t/zone-test.lisp`, `t/zoned-date-time-test.lisp`) read
the real IANA time zone database rather than a fixture, so a passing test
run is direct evidence the TZif parser and daylight-saving disambiguation
handle real-world data, not just hand-crafted inputs. `nix flake check`
points `TZDIR` at nixpkgs' `tzdata` package so this does not depend on
whatever happens to be installed on the host.

## Adding a new time-zone-dependent test

Prefer zones whose behavior is well-documented and stable across years:
`Asia/Tokyo` (fixed UTC+9, no DST since 1951) for the "no daylight saving"
case, `America/New_York` (US DST rules) for gap/overlap cases, and
`Europe/London` for exercising the POSIX-TZ footer against a date far
beyond the explicit transition table. Pin the exact date and expected
offset in the test name, since DST rules occasionally change by regional
legislation and a future `tzdata` update should make a wrong assumption
fail loudly rather than silently.

## Governance

See the org-wide
[CODING_STANDARD](https://github.com/nerima-lisp/.github/blob/main/CODING_STANDARD.md),
[PACKAGE_STANDARD](https://github.com/nerima-lisp/.github/blob/main/PACKAGE_STANDARD.md),
and
[DEPENDENCY_POLICY](https://github.com/nerima-lisp/.github/blob/main/DEPENDENCY_POLICY.md).
