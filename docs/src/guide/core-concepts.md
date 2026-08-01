# Core Concepts

## Naive vs. zone-aware values

Like every reference library this is modeled on, cl-date-kit separates
values that carry no time zone ("naive" or "local") from ones that do:

| Naive | Zone-aware |
|---|---|
| `LOCAL-DATE`, `LOCAL-TIME`, `LOCAL-DATE-TIME` | `INSTANT`, `ZONED-DATE-TIME` |

A `LOCAL-DATE-TIME` of `2024-03-10T02:30:00` is just four numbers; it does
not become a real moment in history until you pair it with a `ZONE-OFFSET`
or `TIME-ZONE`. Doing that pairing is `RESOLVE-LOCAL-DATE-TIME` /
`ZONED-DATE-TIME-OF-LOCAL`, and it is the one place naive date-time
arithmetic most commonly goes wrong in other libraries -- see
[Conditions](../reference/conditions.md) for why it can come back with zero, one, or two
answers.

## Exact time vs. calendar time

`DURATION` is an exact elapsed time: `DURATION-OF-HOURS 24` is always
86400 seconds. `PERIOD` is calendar-based: "1 day" means "the same
wall-clock time tomorrow," which is 23, 24, or 25 real hours depending on
whether a daylight-saving transition falls in between. `ZONED-DATE-TIME`
keeps these as separate operations (`-PLUS-DURATION` vs. `-PLUS-PERIOD`)
rather than one, because collapsing them is exactly how "add a day" bugs
happen twice a year.

## RFC 5545 Recurrence Rules

`RRULE` is an immutable RFC 5545 recurrence-rule value.  It describes a
local-calendar pattern; `RRULE-SCHEDULE` supplies a zoned `DTSTART` for a
zone-aware timed event, a `LOCAL-DATE-TIME` `DTSTART` for a floating timed
event, or a `LOCAL-DATE` `DTSTART` for an all-day event. Zoned timed schedules
preserve wall-clock intent across
daylight-saving transitions rather than treating a recurrence as a fixed
elapsed duration. Use `ZONED-DATE-TIME-PLUS-DURATION` when the requirement is
instead a fixed elapsed interval.

Evaluate an RRULE only through a schedule created with
`MAKE-RRULE-SCHEDULE`. A zone-aware timed schedule requires a
`ZONED-DATE-TIME` DTSTART; candidate local date-times are resolved strictly in
that zone. A local time in a DST gap does not denote an occurrence and is
skipped. When a local time occurs twice during an overlap, evaluation selects
the earlier offset. This makes each generated zoned occurrence an unambiguous
instant while retaining the rule's local-calendar meaning. A floating schedule
uses a `LOCAL-DATE-TIME` DTSTART and emits `LOCAL-DATE-TIME` values directly,
without zone or DST resolution; its `UNTIL`, when present, must also be a
`LOCAL-DATE-TIME`. An all-day schedule requires a `LOCAL-DATE` DTSTART and
emits `LOCAL-DATE` values without zone or DST resolution. Its `UNTIL`, when
present, must also be a `LOCAL-DATE`; it permits only `DAILY`, `WEEKLY`,
`MONTHLY`, and `YEARLY` frequencies and rejects time-of-day `BY*` parts.

`COUNT` bounds the number of emitted occurrences, while `UNTIL` supplies an
inclusive final bound; RFC 5545 makes them mutually exclusive. `COUNT` is not
a search bound: a rule whose filters never produce an occurrence would never
reach its count. Therefore `MAP-RRULE-OCCURRENCES`, `RRULE-OCCURRENCES`, and
`DO-RRULE-OCCURRENCES` require a positive `:MAX-PERIODS` argument whenever
`UNTIL` is absent. This is a bound on evaluated frequency periods, not emitted
values, and guarantees termination when filters produce no candidates.
If this period limit is exhausted before `COUNT` is reached, evaluation returns
the generated prefix.
Callback cancellation and `RETURN` from the iteration macro still stop
evaluation early.

## ZoneOffset vs. TimeZone

`ZONE-OFFSET` is a fixed offset from UTC, like `+09:00` -- it never changes
and has no daylight-saving behavior of its own. `TIME-ZONE` is a named IANA
zone (`"Asia/Tokyo"`, `"America/New_York"`) backed by the parsed rules from
its TZif file, and its offset at a given instant can and does change through
the year. Anywhere a `ZONE-OFFSET` is accepted, a fixed offset is fine to
use for a value that will never need daylight-saving awareness (recorded
UTC timestamps, for instance); anywhere a wall-clock reading needs to become
a real moment in a specific place, use `FIND-TIME-ZONE`.

## The Clock protocol

`INSTANT-NOW` (and, transitively, `ZONED-DATE-TIME-NOW`, `LOCAL-DATE-TIME-NOW`,
`LOCAL-DATE-NOW`, and `LOCAL-TIME-NOW`)
read the current time through `CLOCK-NOW`, a `DEFGENERIC` -- the one place in
this library that dispatches with CLOS rather than a plain `DEFSTRUCT` and
named functions. Pass a `FIXED-CLOCK` wherever a test needs "now" to be a
specific, repeatable value instead of the real wall clock.

For a scoped operation, `CALL-WITH-CLOCK` invokes a function with a dynamically
bound clock and `(WITH-CLOCK (clock) ...)` provides the equivalent macro form.
Every `*-NOW` operation uses this contextual clock unless its optional `CLOCK`
argument is supplied explicitly.
