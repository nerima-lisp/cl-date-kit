# Compatibility

## Time zone data source

`FIND-TIME-ZONE` reads the compiled IANA time zone database (TZif, RFC
8536) from disk: first `$TZDIR/<name>`, then `/usr/share/zoneinfo/<name>`.
`TIME-ZONE-DATABASE-VERSION` reads an explicit `:TZDIR` root only; otherwise
it reads `$TZDIR` and then `/usr/share/zoneinfo`. It reads each root's
`+VERSION` first and accepts it only when it is exactly a `YYYYx` IANA release.
Otherwise it reads `tzdata.zi` and returns the leading `YYYYx` token from its
first `# version <release>` comment, discarding suffixes such as `-rearguard`.
It returns `NIL` rather than signaling when the metadata is missing, unreadable,
overlong, or malformed.
It does not bundle a copy of the database, so:

- The library adds no ASDF dependency, but its *correctness* depends on
  whatever `tzdata` is installed on the host -- the same trade-off Python's
  `zoneinfo` module makes by default.
- Under Nix, point `TZDIR` at nixpkgs' `tzdata` package
  (`"${pkgs.tzdata}/share/zoneinfo"`) for a build that does not depend on
  the host's copy; this repository's own `flake.nix` does exactly that for
  `nix flake check`.
- Zone names are validated to reject absolute paths and `..` components
  before touching the filesystem, so a caller cannot use `FIND-TIME-ZONE` to
  read arbitrary files.
- TZif headers, data blocks, and POSIX footer strings are structurally
  validated before allocating tables or dereferencing their indices. Truncated,
  internally inconsistent, or invalid POSIX-rule files signal `MALFORMED-TZIF`
  rather than leaking implementation-specific parsing or array-bound errors.

## Explicit transitions vs. the POSIX-TZ footer

A TZif v2/v3 file has two parts: an explicit table of transition instants
(which real `zic`-generated files extend many years into the future -- as
of this writing, typically to around 2037) and a POSIX-TZ-style rule string
describing behavior after the last explicit transition.

- `OFFSET-FOR-INSTANT` uses the POSIX-TZ rule correctly for any instant
  beyond the table, including far-future dates.
- All POSIX-TZ date rule forms are parsed: `Mm.w.d[/time]` (week/weekday of
  month), `Jn[/time]` (1--365, excluding February 29), and `n[/time]`
  (0--365, including February 29). Transition times accept a sign and up to
  167 hours, so a rule may cross a day or year boundary. A time with no
    suffix (or `w`) is wall time; `s` is standard time and `u`, `g`, and `z`
    are UTC. `POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME` and
    `RESOLVE-LOCAL-DATE-TIME` derive these yearly
  footer transitions, so far-future local gaps and overlaps are detected just
  like explicit TZif transitions.
- The footer must be fully consumed and contain valid abbreviations, offsets,
  and transition rules; malformed external zone data is rejected rather than
  being silently interpreted with partial rules.

## What is not modeled

- **Leap seconds.** `LOCAL-TIME`'s `SECOND` field is always 0-59, matching
  java.time, Temporal, Go `time`, and Rust's `time`/`chrono`.
- **Non-Gregorian calendars.** `LOCAL-DATE` is proleptic Gregorian only,
  extended backward with no adjustment for the Julian calendar or any
  regional switchover date.
- **Locale-sensitive text.** `DATE-TIME-FORMATTER` ships English `:EN` and
  Japanese `:JA` locales. `MAKE-DATE-TIME-LOCALE` can supply other translated
  month names, weekday names, and AM/PM text for `MMM`/`MMMM`, `EEE`/`EEEE`,
  and `a`; localized numerals are not supported. The 12-hour `h` field
  requires `a`; `a` also validates the existing 24-hour `H` field when both
  are present.
