# cl-date-kit

A dependency-free, SBCL-only date and time library.

Common Lisp has no standard date/time library beyond `get-universal-time`
and `decode-universal-time`, which cover neither time zones nor sub-second
precision. This project follows [nerima-lisp's coding
standard](https://github.com/nerima-lisp/.github/blob/main/CODING_STANDARD.md):
target SBCL only, and spend the effort a general-purpose date library would
spend on portability on getting the genuinely hard parts -- the IANA time
zone database and daylight-saving disambiguation -- right instead.

## Layers

cl-date-kit is organized as a serially loaded implementation stack; each layer
is built only on the ones below it:

1. **Duration** (`src/duration.lisp`) -- an exact elapsed time (seconds +
   nanoseconds). java.time's `Duration`, Rust's `Duration`, Go's
   `time.Duration`.
2. **Period** (`src/period.lisp`) -- a calendar-based years/months/days
   delta. java.time's `Period`.
3. **LocalDate / Month / YearMonth / MonthDay / Year / LocalTime / LocalDateTime** (`src/local-date.lisp`,
   `src/month.lisp`, `src/year-month.lisp`, `src/month-day.lisp`, `src/year.lisp`, `src/local-time.lisp`, `src/local-date-time.lisp`) --
   calendar date, ISO month, month-granularity, annual month/day, calendar year, wall-clock time, and their combinations,
   with no time zone attached. java.time's
   `LocalDate`/`LocalTime`/`LocalDateTime`, Temporal's `PlainDate`/`PlainTime`/
   `PlainDateTime`.
4. **Instant** (`src/instant.lisp`) -- an absolute point on the UTC
   timeline. java.time's `Instant`.
5. **Interval** (`src/interval.lisp`) -- a half-open `[start, end)` range of
   absolute `Instant` values, with overlap, intersection, span, and gap
   operations.
6. **Clock** (`src/clock.lisp`) -- a boundary protocol for where "now" comes
   from, so tests can inject a fixed instant. java.time's `Clock`.
7. **TZif** (`src/tzif.lisp`) -- a from-scratch reader for the IANA time
   zone database's on-disk binary format (RFC 8536).
8. **Zone** (`src/zone.lisp`, `src/zone-local.lisp`) -- `ZONE-OFFSET` (a
   fixed UTC offset) and `TIME-ZONE` (an IANA zone backed by TZif's parsed
   rules). The former owns zone data and instant-time lookup; the latter
   converts local fields and resolves a wall-clock `LOCAL-DATE-TIME` to one,
   zero, or two offsets depending on whether it falls in a daylight-saving gap
   or overlap.
9. **ZonedDateTime** (`src/zoned-date-time.lisp`) -- a `LOCAL-DATE-TIME`
   paired with a resolved `ZONE-OFFSET`: the "real-world timestamp" type.
10. **OffsetDateTime** (`src/offset-date-time.lisp`) -- a `LOCAL-DATE-TIME`
   with a fixed numeric offset, suited to RFC 3339 timestamps that have no
   IANA region identity.
11. **OffsetTime** (`src/offset-time.lisp`) -- a `LOCAL-TIME` with a fixed
    numeric offset, for offset-qualified times that intentionally omit a date.
12. **ISO8601** (`src/iso8601-date.lisp`, `src/iso8601.lisp`) -- ISO-8601/RFC-3339 formatting and
   parsing for every type above, including calendar, ordinal, and ISO week
   dates.

See [Core concepts](core-concepts.md) for how they fit together and
[Architecture](architecture.md) for the implementation decisions behind the
TZif parser and daylight-saving disambiguation.
