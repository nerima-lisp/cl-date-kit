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

## Continuation-passing style, used where it separates generation from selection

This library reaches for an explicit visitor/continuation argument -- a
function the callee invokes instead of allocating and returning a
collection -- in two situations, and stays with ordinary return values and
`MULTIPLE-VALUE-BIND` everywhere else. Forcing every function into
continuation-passing style would fight the "human readable" goal as much as
it would serve it; CPS earns its place only where it removes real
complexity.

**Streaming iteration over an unbounded or expensive-to-materialize
sequence.** `MAP-RRULE-OCCURRENCES`, `MAP-RRULE-SET-OCCURRENCES`, and
`MAP-LOCAL-DATE-INTERVAL` take a callback and call it once per occurrence
(the `DO-*` macros are `LOOP`-style sugar over the same `MAP-*` functions).
An RRULE without `COUNT`/`UNTIL` can describe an infinite recurrence;
returning a list is not an option, and a lazy sequence abstraction would be
a second concept to learn on top of Lisp's own function-calling
convention. `RRULE-CANDIDATES.LISP`'s internal candidate generators
(`%RRULE-DATE-CANDIDATES`, `%RRULE-LOCAL-CANDIDATES`) take an *optional*
visitor for the same reason at one layer down: with a visitor, a candidate
that BYSETPOS will discard is never consed into a throwaway list element.

**Separating "what are the candidates" from "which one wins" in a search.**
`%SELECT-POSIX-ZONE-TRANSITION` (`zone.lisp`) answers "the nearest POSIX-TZ
footer transition in DIRECTION from INSTANT." The two questions -- which
transitions are eligible, and which eligible transition is nearest -- used
to live in one nested loop that accumulated the answer through a mutable
`SETF`. Splitting the eligibility scan into a CPS producer,
`%MAP-CANDIDATE-POSIX-ZONE-TRANSITIONS`, that calls a visitor once per
eligible transition, and reducing over that visitor with a
direction-appropriate comparator closure in `%SELECT-POSIX-ZONE-TRANSITION`
itself, turns one function that did two things into two functions that
each do one -- the same shape as the streaming-iteration case, applied to
a search instead of an unbounded enumeration.

**Destination-passing, a close relative.** `ISO8601.LISP`'s `%WRITE-*`
functions (`%WRITE-LOCAL-DATE-TIME`, `%WRITE-ZONE-OFFSET`, and so on) take
a `STREAM` argument and write to it rather than returning a string, so a
composite formatter like `FORMAT-OFFSET-DATE-TIME` writes its date, time,
and offset pieces directly onto one shared stream inside a single
`WITH-OUTPUT-TO-STRING`, instead of allocating and concatenating three
intermediate strings. `PATTERN.LISP`'s `%WRITE-PATTERN-FIELD` follows the
same shape for the compiled pattern formatter.
