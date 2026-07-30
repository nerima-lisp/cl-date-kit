# Development

The Nix workflow requires [Nix](https://nixos.org/download/) with flakes
enabled. From a tracked checkout, `flake.lock` pins nixpkgs, the test-only
`cl-weave` source tree, and treefmt so the following commands use a
reproducible toolchain:

```sh
nix develop          # SBCL with CL_SOURCE_REGISTRY and TZDIR already set
nix run .#test       # run the test suite
nix run .#coverage -- coverage/ # write an SB-COVER HTML report
nix run .#benchmark  # run microbenchmarks
nix flake check      # tests + formatting + docs, the same gate CI uses
nix fmt              # format Nix sources (treefmt)
```

GitHub Actions runs `nix flake check` for every push and pull request. The
flake is the CI entry point: it runs the test suite, checks Nix formatting,
and builds the documentation with MkDocs in strict mode.

The coverage command recompiles the production system with SBCL's built-in
SB-COVER instrumentation, runs `cl-date-kit/test`, and writes deterministic
HTML files to the supplied directory. Omit `coverage/` to use the temporary
directory reported by the command. A report is emitted only after the test
suite passes; test failures retain SBCL's nonzero exit status.

## Benchmark

`nix run .#benchmark` measures ISO 8601 parsing, IANA time-zone resolution,
and recurrence traversal, including direct yearly candidate expansion. It runs a
warm-up before recording multiple samples for every case, then reports median,
minimum, and maximum nanoseconds and bytes per operation. The default
configuration is seven samples of 100,000 iterations after 10,000 warm-up
iterations.

Set these environment variables to positive integers when comparing a change;
the warm-up value may also be zero:

```sh
CL_DATE_KIT_BENCHMARK_ITERATIONS=10000 \
CL_DATE_KIT_BENCHMARK_WARMUP_ITERATIONS=1000 \
CL_DATE_KIT_BENCHMARK_SAMPLES=9 \
nix run .#benchmark
```

Use the same Nix lockfile, sample count, iteration count, and host conditions
when comparing runs. The benchmark is a comparison-oriented microbenchmark,
not an absolute performance claim.

Without Nix:

```sh
git clone --branch v1.0.1 https://github.com/nerima-lisp/cl-weave.git /path/to/cl-weave
CL_SOURCE_REGISTRY="/path/to/cl-weave//:$(pwd)//" timeout --kill-after=10s 120s sbcl --script run-tests.lisp
```

This command requires GNU `timeout`. On macOS, install Homebrew Coreutils and
use `gtimeout` in place of `timeout`:

```sh
CL_SOURCE_REGISTRY="/path/to/cl-weave//:$(pwd)//" gtimeout --kill-after=10s 120s sbcl --script run-tests.lisp
```

If no timeout command is available, run SBCL directly:

```sh
CL_SOURCE_REGISTRY="/path/to/cl-weave//:$(pwd)//" sbcl --script run-tests.lisp
```

The non-Nix command uses the host's IANA time-zone database, normally under
`/usr/share/zoneinfo`; set `TZDIR` if it is installed elsewhere.

## Test layout

Tests live in `t/` and are organized by feature (`src/zone.lisp` ->
`t/zone-test.lisp`). Low-level modules may be covered indirectly by their
feature's integration tests. They run under
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
