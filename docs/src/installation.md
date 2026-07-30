# Installation

## Via Nix flakes

```nix
# flake.nix
inputs.cl-date-kit = {
  url = "github:nerima-lisp/cl-date-kit/v0.1.0";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Pin a release tag, not the default branch: this is an org-wide policy so
that a sibling repository's history never breaks a consumer's build.

## Via ASDF directly

Clone this repository, then add its absolute path to ASDF's central registry
before loading the system:

```lisp
(push #P"/absolute/path/to/cl-date-kit/" asdf:*central-registry*)
(asdf:load-system "cl-date-kit")
```

Alternatively, configure `CL_SOURCE_REGISTRY` to find the checkout.

`cl-date-kit` has no ASDF dependencies (`:depends-on ()`); the only runtime
requirement beyond SBCL is a readable IANA time zone database, which is
already present on essentially every Linux and macOS install at
`/usr/share/zoneinfo`. See [Compatibility](compatibility.md) for how that
lookup works and what `TZDIR` overrides.
