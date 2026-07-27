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
[Conditions](conditions.md) for why it can come back with zero, one, or two
answers.

## Exact time vs. calendar time

`DURATION` is an exact elapsed time: `DURATION-OF-HOURS 24` is always
86400 seconds. `PERIOD` is calendar-based: "1 day" means "the same
wall-clock time tomorrow," which is 23, 24, or 25 real hours depending on
whether a daylight-saving transition falls in between. `ZONED-DATE-TIME`
keeps these as separate operations (`-PLUS-DURATION` vs. `-PLUS-PERIOD`)
rather than one, because collapsing them is exactly how "add a day" bugs
happen twice a year.

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

`INSTANT-NOW` (and, transitively, `ZONED-DATE-TIME-NOW`/`LOCAL-DATE-NOW`)
read the current time through `CLOCK-NOW`, a `DEFGENERIC` -- the one place in
this library that dispatches with CLOS rather than a plain `DEFSTRUCT` and
named functions. Pass a `FIXED-CLOCK` wherever a test needs "now" to be a
specific, repeatable value instead of the real wall clock.
