# Architecture

## Date math: Howard Hinnant's days_from_civil / civil_from_days

`LOCAL-DATE` converts between (year, month, day) and an epoch-day count
using the algorithm from Howard Hinnant's "chrono-Compatible Low-Level Date
Algorithms" -- the same one behind libc++'s `<chrono>`, Rust's `time` crate,
and Abseil's `civil_time`. It is correct across the entire proleptic
Gregorian calendar, not just the range the host Lisp's `universal-time`
happens to support, and every other date operation (`PLUS-DAYS`, ordering,
`DAY-OF-WEEK`) is defined in terms of it rather than reimplementing calendar
arithmetic separately.

Epoch day 0 is 1970-01-01, matching `INSTANT`'s Unix epoch -- deliberately
not CL's native 1900-01-01 `universal-time` epoch, so every `EPOCH-SECOND`
and `EPOCH-DAY` in this library lines up directly with every other modern
language's timestamps.

## The TZif reader

`src/tzif.lisp` parses the on-disk IANA time zone database format (RFC
8536) directly from bytes: the v1 32-bit-transition block, the v2/v3 header
and 64-bit-transition block that supersedes it when present, and the
POSIX-TZ string footer. Reading the compiled `zoneinfo` files that are
already on disk -- rather than embedding a parsed copy of the database, as
Go's `time/tzdata` or Noda Time do -- is what keeps `cl-date-kit`
dependency-free: see [Compatibility](compatibility.md) for the trade-off
that comes with it.

Two details are easy to get backwards when implementing this:

- **The POSIX-TZ offset sign is inverted from ISO 8601.** `"JST-9"` means
  UTC+9, because the POSIX convention is "hours *subtracted* from local
  time to reach UTC." Every offset `zone.lisp` parses out of a POSIX-TZ
  string is flipped to the usual UTC-relative sign immediately, in
  `%PARSE-POSIX-NAME-OFFSET`, so the rest of the codebase never has to think
  about the POSIX sign convention again.
- **The type "before" a transition is not the type "at" it.** TZif stores,
  for each transition, the type that becomes active *starting* at that
  instant. The type in force *just before* transition `i` is the type at
  transition `i-1` (or a separate "initial type" before the very first
  transition) -- and gap/overlap detection needs both.

## Detecting daylight-saving gaps and overlaps

`%CLASSIFY-LOCAL-DATE-TIME` in `zone-local.lisp` is the one function every
gap/overlap-sensitive operation (`POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME`,
`RESOLVE-LOCAL-DATE-TIME`, and transitively `ZONED-DATE-TIME-OF-LOCAL`) goes
through, so there is exactly one implementation of the classification logic
to get right rather than two copies that could drift apart.

The technique: read a `LOCAL-DATE-TIME`'s fields as if they directly *were*
epoch seconds (pretend the wall-clock reading is UTC). For each transition,
compute what that transition's boundary instant would read as under the
offset *before* it and under the offset *after* it:

- If the offset increases (spring forward) and the naive value falls
  between those two readings, it is in the gap -- it never happened.
- If the offset decreases (fall back) and the naive value falls between
  them, it is in the overlap -- it happened twice, once under each offset.
- Otherwise, resolve normally: guess an offset by treating the naive value
  as if it were already a real UTC instant, convert to a candidate UTC
  instant using that guess, then look up the offset that is actually in
  force at that instant. One such step is enough, because the gap/overlap
  check above has already ruled out the only cases where it could land on
  an inconsistent answer.

This mirrors the approach used internally by java.time's `ZoneRules` and
similar logic in chrono-tz, applied here against TZif's transition table
directly rather than against a higher-level rule object.
