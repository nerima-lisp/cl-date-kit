# cl-date-kit

A dependency-free, SBCL-only date and time library.

Common Lisp has no standard date/time library beyond `get-universal-time`
and `decode-universal-time`, which cover neither time zones nor sub-second
precision. This project follows [nerima-lisp's coding
standard](https://github.com/nerima-lisp/.github/blob/main/CODING_STANDARD.md):
target SBCL only, and use the effort saved from portability for the IANA time
zone database and daylight-saving disambiguation.

## Layers

cl-date-kit is organized as a serially loaded implementation stack; each layer
is built only on the ones below it:

Loaded second, immediately after `package.lisp` and before any layer below,
`src/macros.lisp` defines the shared `DEFMACRO` infrastructure
(`DEFINE-ORDERING-OPERATORS`, `DEFINE-FIXED-UNIT-ARITHMETIC`,
`DEFINE-DATE-KIT-CONDITION`, `DEFINE-PERIOD-FIXED-COMPONENT-ARITHMETIC`) that
later layers use to generate their comparison operators, `PLUS`/`MINUS`
arithmetic, and conditions. It has no type of its own, so it isn't numbered
as a layer, but every layer below depends on it having loaded first.

1. **Duration** (`src/duration.lisp`) -- an exact elapsed time (seconds +
   nanoseconds).
2. **Period** (`src/period.lisp`) -- a calendar-based years/months/days
   delta.
3. **LocalDate / Month / YearMonth / MonthDay / Year / LocalTime / LocalDateTime** (`src/local-date.lisp`,
   `src/local-date-arithmetic.lisp`, `src/local-date-week.lisp`,
   `src/month.lisp`, `src/year-month.lisp`, `src/month-day.lisp`, `src/year.lisp`, `src/local-time.lisp`, `src/local-date-time.lisp`) --
   calendar date, ISO month, month-granularity, annual month/day, calendar year, wall-clock time, and their combinations,
   with no time zone attached.
4. **Instant** (`src/instant.lisp`) -- an absolute point on the UTC
   timeline.
5. **Interval** (`src/interval.lisp`) -- a half-open `[start, end)` range of
   absolute `Instant` values, with overlap, intersection, span, and gap
   operations.
6. **Clock** (`src/clock.lisp`) -- a boundary protocol for where "now" comes
   from, so tests can inject a fixed instant.
7. **TZif** (`src/tzif.lisp`) -- a reader for the IANA time
   zone database's on-disk binary format (RFC 8536).
8. **Zone** (`src/zone.lisp`, `src/zone-version.lisp`, `src/zone-local.lisp`)
   -- `ZONE-OFFSET` (a fixed UTC offset) and `TIME-ZONE` (an IANA zone backed
   by TZif's parsed rules). `zone.lisp` owns zone data and instant-time
   lookup, `zone-version.lisp` owns IANA tzdata release-version parsing, and
   `zone-local.lisp` converts local fields and resolves a wall-clock
   `LOCAL-DATE-TIME` to one, zero, or two offsets depending on whether it
   falls in a daylight-saving gap or overlap.
9. **ZonedDateTime** (`src/zoned-date-time.lisp`, `src/zoned-date-time-arithmetic.lisp`) -- a `LOCAL-DATE-TIME`
   paired with a resolved `ZONE-OFFSET`: the "real-world timestamp" type.
   `zoned-date-time.lisp` owns construction, disambiguation, and field
   access; `zoned-date-time-arithmetic.lisp` adds `PLUS`/`MINUS` arithmetic,
   truncation, comparison, and the `-NOW` constructors (including the
   `LOCAL-DATE-TIME`/`LOCAL-TIME`/`LOCAL-DATE` ones, which live here because
   they depend on machinery only available this late in the load order).
10. **OffsetDateTime** (`src/offset-date-time.lisp`) -- a `LOCAL-DATE-TIME`
   with a fixed numeric offset, suited to RFC 3339 timestamps that have no
   IANA region identity.
11. **OffsetTime** (`src/offset-time.lisp`) -- a `LOCAL-TIME` with a fixed
    numeric offset, for offset-qualified times that intentionally omit a date.
12. **ISO8601** (`src/iso8601-date.lisp`, `src/iso8601-year-month-day.lisp`,
   `src/iso8601.lisp`, `src/iso8601-offset.lisp`) -- ISO-8601/RFC-3339
   formatting and parsing for every type above, including calendar,
   ordinal, and ISO week dates. `iso8601-date.lisp` covers `LocalDate`;
   `iso8601-year-month-day.lisp` covers `YearMonth`/`MonthDay`/`Year`;
   `iso8601.lisp` covers `LocalTime`/`LocalDateTime`; and
   `iso8601-offset.lisp` covers the offset- and zone-aware types --
   `ZoneOffset`, `OffsetDateTime`, `OffsetTime`, and `ZonedDateTime`.

See [Core concepts](guide/core-concepts.md) for how they fit together and
[Architecture](reference/architecture.md) for the implementation decisions behind the
TZif parser and daylight-saving disambiguation.
