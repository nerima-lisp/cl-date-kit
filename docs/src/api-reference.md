# API Reference

All symbols are in the `CL-DATE-KIT` package. This page groups them by type;
see each source file's docstrings for full detail.

## Duration (`src/duration.lisp`)

Exact elapsed time (seconds + nanoseconds, signed).

`DURATION-OF-NANOS`, `DURATION-OF-SECONDS`, `DURATION-OF-MILLIS`, `DURATION-OF-MICROS`,
`DURATION-OF-MINUTES`,
`DURATION-OF-HOURS`, `DURATION-OF-DAYS` (fixed 24h days), `DURATION-ZERO` --
constructors.
All duration constructor arguments are exact integers; non-integral input
signals `TYPE-ERROR`.
`DURATION-SECONDS`, `DURATION-NANOS`, `DURATION-TO-NANOS`,
`DURATION-TO-SECONDS` (exact rational), `DURATION-TO-MILLIS`, `DURATION-TO-MICROS`,
`DURATION-TO-MINUTES`, `DURATION-TO-HOURS`, `DURATION-TO-DAYS` -- accessors
and conversions. Whole-unit conversions truncate fractional units toward zero.
`DURATION-WITH-SECONDS` and `DURATION-WITH-NANOS` immutably replace one
normalized field. Nanoseconds must be an exact integer from 0 through 999999999.
`DURATION-TO-DAYS-PART`, `DURATION-TO-HOURS-PART`,
`DURATION-TO-MINUTES-PART`, and `DURATION-TO-SECONDS-PART` decompose a
duration into fixed 24-hour days and signed remainders. `DURATION-TO-MILLIS-PART`,
`DURATION-TO-MICROS-PART`, and `DURATION-TO-NANOS-PART` return non-negative
parts of the normalized nanosecond field.
`DURATION-TRUNCATED-TO` discards fractional supported fixed units toward zero;
the supported unit keywords are `:NANOS`, `:MICROS`, `:MILLIS`, `:SECONDS`,
`:MINUTES`, `:HOURS`, and fixed 24-hour `:DAYS`.
`DURATION-PLUS`, `DURATION-MINUS`, `DURATION-NEGATE`, `DURATION-ABS`,
`DURATION-MULTIPLIED-BY`, `DURATION-DIVIDED-BY` -- arithmetic.
`DURATION-PLUS-*` and `DURATION-MINUS-*` provide exact integral
nanosecond, microsecond, millisecond, second, minute, hour, and fixed 24-hour
day arithmetic.
`DURATION-ZERO-P`, `DURATION-NEGATIVE-P`, `DURATION-POSITIVE-P`,
`DURATION-COMPARE`, `DURATION=`, `DURATION<`, `DURATION<=`, `DURATION>`,
`DURATION>=` -- predicates and ordering.
`DURATION-BETWEEN` dispatches on matching temporal value types: `INSTANT`,
`LOCAL-TIME`, `LOCAL-DATE-TIME`, `OFFSET-TIME`, `OFFSET-DATE-TIME`, and
`ZONED-DATE-TIME`. Local values use their local timeline; offset and zoned
values use the absolute timeline.

## Period (`src/period.lisp`)

Calendar-based years/months/days delta.

`MAKE-PERIOD`, `PERIOD-OF`, `PERIOD-OF-YEARS`, `PERIOD-OF-MONTHS`,
`PERIOD-OF-DAYS` -- constructors. `PERIOD-BETWEEN` returns the calendar delta
between two `LOCAL-DATE` values, using the same semantics as `LOCAL-DATE-UNTIL`.
All period constructor arguments must be exact integers; non-integral input
signals `TYPE-ERROR`.
`PERIOD-YEARS`, `PERIOD-MONTHS`, `PERIOD-DAYS` -- accessors.
`PERIOD-WITH-YEARS`, `PERIOD-WITH-MONTHS`, `PERIOD-WITH-DAYS` -- immutable
single-component replacement; replacement values must be exact integers.
`PERIOD-PLUS-YEARS`, `PERIOD-PLUS-MONTHS`, `PERIOD-PLUS-DAYS`, and matching
`PERIOD-MINUS-*` functions -- adjust exactly one calendar component with an
exact integer amount, preserving the other components without normalizing months.
`PERIOD-PLUS`, `PERIOD-MINUS`, `PERIOD-NEGATE`, `PERIOD-MULTIPLIED-BY`,
`PERIOD-ABS`, `PERIOD-NORMALIZED` (folds years/months, leaves days) --
arithmetic. `PERIOD-TO-TOTAL-MONTHS` -- calendar-month conversion.
`PERIOD-ZERO-P`, `PERIOD-NEGATIVE-P`, `PERIOD=` -- predicates.

## LocalDate (`src/local-date.lisp`)

Proleptic-Gregorian calendar date, no time-of-day or zone.

`MAKE-LOCAL-DATE`, `LOCAL-DATE-OF`, `LOCAL-DATE-OF-YEAR-DAY`,
`LOCAL-DATE-OF-WEEK-DATE` --
constructors (signal `INVALID-DATE`). `LOCAL-DATE-YEAR`, `LOCAL-DATE-MONTH`,
`LOCAL-DATE-DAY` -- accessors. `LEAP-YEAR-P`, `LENGTH-OF-MONTH`,
`LOCAL-DATE-LEAP-YEAR-P`, `LOCAL-DATE-LENGTH-OF-MONTH`,
`LOCAL-DATE-LENGTH-OF-YEAR`,
`DAY-OF-WEEK`, `DAY-OF-WEEK-VALUE`, `DAY-OF-WEEK-FROM-VALUE`,
`DAY-OF-WEEK-LENGTH`, `DAY-OF-WEEK-PLUS`, `DAY-OF-WEEK-MINUS`,
`DAY-OF-YEAR`, `LOCAL-DATE-WEEK-BASED-YEAR`,
`LOCAL-DATE-WEEK-OF-WEEK-BASED-YEAR` -- calendar facts. `LOCAL-DATE-PLUS-DAYS`/`-WEEKS`/`-MONTHS`/`-YEARS` and their
`MINUS` counterparts, `LOCAL-DATE-PLUS-PERIOD`/`-MINUS-PERIOD` --
arithmetic (month/year arithmetic clamps to the shorter target month).
`LOCAL-DATE-UNTIL` -- the `PERIOD` between two dates.
`LOCAL-DATE-WITH-YEAR`, `LOCAL-DATE-WITH-MONTH`, `LOCAL-DATE-WITH-DAY`,
`LOCAL-DATE-WITH-DAY-OF-YEAR` -- immutable field replacement; year/month
replacement uses the same shorter-month clamping rule as date arithmetic.
`LOCAL-DATE-FIRST-DAY-OF-MONTH`, `LOCAL-DATE-LAST-DAY-OF-MONTH`,
`LOCAL-DATE-FIRST-DAY-OF-YEAR`, `LOCAL-DATE-LAST-DAY-OF-YEAR` -- immutable
calendar-boundary adjusters. `LOCAL-DATE-NEXT-OR-SAME`, `LOCAL-DATE-NEXT`,
`LOCAL-DATE-PREVIOUS-OR-SAME`, `LOCAL-DATE-PREVIOUS` -- weekday adjusters;
accept `:MONDAY` through `:SUNDAY`, with the `-OR-SAME` forms including the
input date and the other forms moving strictly forward or backward.
`LOCAL-DATE-COMPARE`, `LOCAL-DATE=`, `LOCAL-DATE<`, `LOCAL-DATE<=`,
`LOCAL-DATE>`, `LOCAL-DATE>=` -- ordering.
`LOCAL-DATE-TO-EPOCH-DAY`, `LOCAL-DATE-FROM-EPOCH-DAY` -- day-count
conversion (epoch day 0 is 1970-01-01).
`LOCAL-DATE-AT-TIME` and `LOCAL-DATE-AT-START-OF-DAY` -- combine a date with
a `LOCAL-TIME` or midnight, respectively. `LOCAL-DATE-AT-START-OF-DAY-IN-ZONE`
resolves that midnight in a fixed-offset or IANA `ZONE`; the default
`:COMPATIBLE` policy moves a nonexistent midnight forward across its gap.
`LOCAL-DATE-OF-INSTANT` projects an `INSTANT` through a fixed `ZONE-OFFSET`
and returns its local date component.

## Month (`src/month.lisp`)

An ISO-8601 month keyword, from `:JANUARY` through `:DECEMBER`, independent
of a year. `MONTH-VALUE` and `MONTH-FROM-VALUE` convert to and from ISO values
1 through 12, signaling `INVALID-MONTH` for other values. `MONTH-LENGTH`,
`MONTH-MIN-LENGTH`, `MONTH-MAX-LENGTH`, and `MONTH-FIRST-DAY-OF-YEAR` expose
leap-aware calendar facts. `MONTH-QUARTER-OF-YEAR` and
`MONTH-FIRST-MONTH-OF-QUARTER` expose calendar-quarter membership.
`MONTH-PLUS` and `MONTH-MINUS` apply integral arithmetic and wrap within the
ISO year. `MONTH-FROM-LOCAL-DATE` derives a month from a `LOCAL-DATE`.

## YearMonth (`src/year-month.lisp`)

A proleptic-Gregorian year and month without a day, suited to month-granularity
values such as billing periods. `MAKE-YEAR-MONTH` and `YEAR-MONTH-OF` construct
values, signaling `INVALID-YEAR-MONTH` for invalid fields. `YEAR-MONTH-YEAR`,
`YEAR-MONTH-MONTH`, `YEAR-MONTH-FROM-LOCAL-DATE`,
`YEAR-MONTH-TO-PROLEPTIC-MONTH`, and `YEAR-MONTH-FROM-PROLEPTIC-MONTH` access
and convert its fields. `YEAR-MONTH-LEAP-YEAR-P`,
`YEAR-MONTH-LENGTH-OF-MONTH`, and `YEAR-MONTH-LENGTH-OF-YEAR` expose calendar
facts, and
`YEAR-MONTH-VALID-DAY-P` tests whether an integral day occurs in the month.
`YEAR-MONTH-NOW` derives a value in an optional `ZONE` from an injectable
`CLOCK`.
`YEAR-MONTH-AT-DAY` and `YEAR-MONTH-AT-END-OF-MONTH` derive calendar dates.
`YEAR-MONTH-PLUS-MONTHS`,
`YEAR-MONTH-MINUS-MONTHS`, `YEAR-MONTH-PLUS-YEARS`,
`YEAR-MONTH-MINUS-YEARS`, and `YEAR-MONTH-UNTIL` provide month arithmetic.
`YEAR-MONTH-WITH-YEAR` and `YEAR-MONTH-WITH-MONTH` replace one immutable field.
`YEAR-MONTH-COMPARE`, `YEAR-MONTH=`, `YEAR-MONTH<`, `YEAR-MONTH<=`,
`YEAR-MONTH>`, and `YEAR-MONTH>=` order values by proleptic month index.
`FORMAT-YEAR-MONTH` emits canonical extended `YYYY-MM`; `PARSE-YEAR-MONTH`
also accepts basic `YYYYMM` and signals `DATE-TIME-PARSE-ERROR` on malformed
or invalid input. Years from `0` through `9999` use four digits; other years
use ISO 8601 signed expanded notation such as `-0001-06` or `+10000-06`.

## MonthDay (`src/month-day.lisp`)

A month and day without a year, suited to recurring annual dates such as
birthdays. `MAKE-MONTH-DAY` and `MONTH-DAY-OF` construct values, signaling
`INVALID-MONTH-DAY` for invalid fields; February 29 is valid. `MONTH-DAY-MONTH`,
`MONTH-DAY-DAY`, and `MONTH-DAY-FROM-LOCAL-DATE` access and derive fields.
`MONTH-DAY-VALID-YEAR-P` tests whether a value occurs in a year;
`MONTH-DAY-AT-YEAR` creates a `LOCAL-DATE`, clamping February 29 to February 28
in non-leap years. `MONTH-DAY-WITH-MONTH` and `MONTH-DAY-WITH-DAY` replace one
immutable field; replacing the month clamps a too-large day to the month end.
`MONTH-DAY-NOW` derives a value in an optional `ZONE` from an injectable
`CLOCK`.
`MONTH-DAY-COMPARE`, `MONTH-DAY=`, `MONTH-DAY<`, `MONTH-DAY<=`, `MONTH-DAY>`,
and `MONTH-DAY>=` order values by month then day. `FORMAT-MONTH-DAY` emits
canonical extended `--MM-DD`; `PARSE-MONTH-DAY` also accepts basic `--MMDD` and
signals `DATE-TIME-PARSE-ERROR` on malformed or invalid input.

## Year (`src/year.lisp`)

An integral proleptic-Gregorian year without a month, day, time, or zone.
`MAKE-YEAR`, `YEAR-OF`, `YEAR-FROM-LOCAL-DATE`, `YEAR-NOW`, and `YEAR-FROM-YEAR-MONTH`
construct or derive values; non-integral inputs signal `INVALID-YEAR`.
`YEAR-LEAP-P` and `YEAR-LENGTH` expose calendar properties.
`YEAR-NOW` derives a value in an optional `ZONE` from an injectable `CLOCK`.
`YEAR-VALID-MONTH-DAY-P` tests whether a `MONTH-DAY` occurs in the year.
`YEAR-AT-MONTH`, `YEAR-AT-MONTH-DAY`, and `YEAR-AT-DAY` create more precise values; the
month-day variant clamps February 29 to February 28 for a non-leap year.
`YEAR-PLUS-YEARS`, `YEAR-MINUS-YEARS`, `YEAR-UNTIL`, `YEAR-COMPARE`, and the
`YEAR=`/`YEAR<`/`YEAR<=`/`YEAR>`/`YEAR>=` predicates provide immutable
arithmetic and ordering. `FORMAT-YEAR` writes `YYYY` for years 0 through 9999 and a
signed expanded year outside it; `PARSE-YEAR` accepts both forms while
normalizing malformed input to `DATE-TIME-PARSE-ERROR`.

## LocalTime (`src/local-time.lisp`)

Wall-clock time of day, no date or zone. No leap seconds.

`MAKE-LOCAL-TIME` (signals `INVALID-TIME`), `LOCAL-TIME-OF`, `LOCAL-TIME-OF-SECOND-OF-DAY`,
`LOCAL-TIME-OF-NANO-OF-DAY`, `LOCAL-TIME-MIDNIGHT`, `LOCAL-TIME-NOON` --
constructors.
`LOCAL-TIME-HOUR`, `LOCAL-TIME-MINUTE`, `LOCAL-TIME-SECOND`,
`LOCAL-TIME-NANOSECOND`, `LOCAL-TIME-TO-SECOND-OF-DAY`,
`LOCAL-TIME-TO-NANO-OF-DAY` -- accessors and day-relative conversions.
`LOCAL-TIME-PLUS-HOURS`/`-MINUTES`/`-SECONDS`/`-MILLIS`/`-MICROS`/`-NANOS` and their `MINUS`
counterparts -- arithmetic; wraps around midnight, never carries into a
date. `LOCAL-TIME-WITH-HOUR`, `LOCAL-TIME-WITH-MINUTE`,
`LOCAL-TIME-WITH-SECOND`, `LOCAL-TIME-WITH-NANOSECOND` -- immutable field
replacement. `LOCAL-TIME-COMPARE`, `LOCAL-TIME=`, `LOCAL-TIME<`, `LOCAL-TIME<=`,
`LOCAL-TIME>`, `LOCAL-TIME>=` -- ordering.
`LOCAL-TIME-TRUNCATED-TO` rounds down to `:NANOS`, `:MICROS`, `:MILLIS`,
`:SECONDS`, `:MINUTES`, `:HOURS`, or `:DAYS`; day truncation yields midnight.
`LOCAL-TIME-UNTIL` returns the signed nanosecond-precision `DURATION` from one
time-of-day to another; it does not wrap at midnight.
`LOCAL-TIME-AT-DATE` combines a time with a `LOCAL-DATE`.
`LOCAL-TIME-OF-INSTANT` projects an `INSTANT` through a fixed `ZONE-OFFSET`
and returns its local time component.

## LocalDateTime (`src/local-date-time.lisp`)

A `LOCAL-DATE` and `LOCAL-TIME` pair, no zone.

`MAKE-LOCAL-DATE-TIME`, `LOCAL-DATE-TIME-OF` (raw year/month/.../nanosecond)
-- constructors. `LOCAL-DATE-TIME-DATE`, `LOCAL-DATE-TIME-TIME`, and
passthrough field accessors (`-YEAR`, `-MONTH`, ..., `-NANOSECOND`).
Arithmetic mirrors `LOCAL-DATE`'s and `LOCAL-TIME`'s, plus
`-PLUS-DURATION`/`-MINUS-DURATION` and `-PLUS-PERIOD`/`-MINUS-PERIOD`; hour/
minute/second/millisecond/microsecond/nanosecond arithmetic carries into the date, unlike
`LOCAL-TIME` alone. `LOCAL-DATE-TIME-WITH-YEAR`, `-WITH-MONTH`, `-WITH-DAY`,
`-WITH-DAY-OF-YEAR`, `-WITH-HOUR`, `-WITH-MINUTE`, `-WITH-SECOND`, and
`-WITH-NANOSECOND` -- immutable field replacement. `LOCAL-DATE-TIME-COMPARE`, `=`, `<`, `<=`, `>`, `>=` --
ordering (by date, then time-of-day).
`LOCAL-DATE-TIME-TRUNCATED-TO` applies the same fixed-unit truncation as
`LOCAL-TIME-TRUNCATED-TO` while retaining the local date.
`LOCAL-DATE-TIME-UNTIL` returns the signed nanosecond-precision `DURATION`
between values on the local timeline.
`LOCAL-DATE-TIME-TO-EPOCH-SECOND`, `LOCAL-DATE-TIME-OF-EPOCH-SECOND`,
`LOCAL-DATE-TIME-TO-INSTANT`, and `LOCAL-DATE-TIME-OF-INSTANT` convert through
a fixed `ZONE-OFFSET`; they do not resolve IANA time-zone transitions.
`LOCAL-DATE-TIME-AT-ZONE` resolves a local value in a `TIME-ZONE` using the
same `:DISAMBIGUATION` rules as `ZONED-DATE-TIME-OF-LOCAL`, including DST gaps
and overlaps. `LOCAL-DATE-TIME-AT-OFFSET` pairs the value with a fixed
`ZONE-OFFSET`.

## Instant (`src/instant.lisp`)

An absolute point on the UTC timeline (Unix epoch seconds + nanoseconds).

`MAKE-INSTANT`, `INSTANT-EPOCH`, `INSTANT-OF-EPOCH-SECOND`,
`INSTANT-OF-EPOCH-NANOS`,
`INSTANT-OF-EPOCH-MILLIS`, and `INSTANT-OF-EPOCH-MICROS` -- constructors.
`INSTANT-EPOCH-SECOND`, `INSTANT-NANOSECOND`, `INSTANT-TO-EPOCH-NANOS`,
`INSTANT-TO-EPOCH-MILLIS`, and `INSTANT-TO-EPOCH-MICROS` -- accessors and
integer epoch conversions. Nanosecond conversions are exact; sub-millisecond
and sub-microsecond values round down on the UTC timeline.
`INSTANT-PLUS-NANOS`, `INSTANT-PLUS-MICROS`, `INSTANT-PLUS-MILLIS`,
`INSTANT-PLUS-SECONDS`, `INSTANT-PLUS-MINUTES`, `INSTANT-PLUS-HOURS`, and
`INSTANT-PLUS-DAYS` perform fixed-unit arithmetic with exact nanosecond
normalization. `INSTANT-PLUS-DAYS` is exactly 86,400 seconds; all are elapsed,
not calendar, units. Their `INSTANT-MINUS-*` counterparts reverse the same
units.
`INSTANT-TRUNCATED-TO` rounds the UTC timeline down to `:NANOS`, `:MICROS`,
`:MILLIS`, `:SECONDS`, `:MINUTES`, `:HOURS`, or `:DAYS`, including for negative
epoch values.
`INSTANT-PLUS-DURATION`, `INSTANT-MINUS-DURATION`, `INSTANT-UNTIL` (->
`DURATION`) -- duration arithmetic.
`INSTANT-COMPARE`, `INSTANT=`, `INSTANT<`, `INSTANT<=`, `INSTANT>`,
`INSTANT>=` -- ordering.

## Interval (`src/interval.lisp`)

An absolute, half-open range `[start, end)` of `INSTANT` values. `MAKE-INTERVAL`
allows equal endpoints (an empty interval) but signals `INVALID-INTERVAL` when
the end precedes the start.

`INTERVAL-START`, `INTERVAL-END`, `INTERVAL-EMPTY-P`, and `INTERVAL-DURATION`
inspect an interval. `INTERVAL-CONTAINS-P` uses the half-open bounds, while
`INTERVAL-ENCLOSES-P`, `INTERVAL-OVERLAPS-P`, and `INTERVAL-ABUTS-P` compare two
intervals. `INTERVAL-CONNECTED-P` is true when intervals overlap or abut;
`INTERVAL-BEFORE-P` and `INTERVAL-AFTER-P` compare their half-open boundaries,
so abutting intervals are respectively before and after one another.
`INTERVAL-INTERSECTION` returns `NIL` for disjoint or merely
abutting ranges. `INTERVAL-SPAN` returns the smallest range covering both,
including a gap. `INTERVAL-UNION` returns that range only when the intervals
overlap or abut; it returns `NIL` when a positive gap separates them.
`INTERVAL-GAP` returns the separating interval only for disjoint ranges.

`INTERVAL-WITH-START` and `INTERVAL-WITH-END` return a new interval with one
bound replaced; both retain the interval validity checks and leave the source
interval unchanged. `INTERVAL-DIFFERENCE` returns the ordered, non-empty
portions of its first interval not covered by its second interval. Its result is
an empty list, a one-element list, or a two-element list of half-open
intervals.

## Clock (`src/clock.lisp`)

`CLOCK-NOW` (a `DEFGENERIC`) -- the current `INSTANT` according to a clock.
`MAKE-SYSTEM-CLOCK` -- reads the real wall clock. `MAKE-FIXED-CLOCK` --
always returns the `INSTANT` it was built with; use in tests. `INSTANT-NOW`
-- convenience wrapper defaulting to a system clock.

`MAKE-OFFSET-CLOCK` composes any `CLOCK-NOW` implementation with an exact
`DURATION` offset. `MAKE-TICK-CLOCK` composes a clock that rounds down on the
UTC timeline to a strictly positive fixed `DURATION`; this also gives correct
flooring before the epoch. Both derived clock types expose their base clock and
their offset or tick duration through read-only accessors.

## Zone (`src/zone.lisp`)

`ZONE-OFFSET-OF-HOURS`, `ZONE-OFFSET-OF-HMS`, `ZONE-OFFSET-OF-TOTAL-SECONDS`,
`ZONE-OFFSET-UTC` --
fixed-offset constructors. `ZONE-OFFSET-TOTAL-SECONDS` -- accessor.
`ZONE-OFFSET-COMPARE`, `ZONE-OFFSET=`, `ZONE-OFFSET<`, `ZONE-OFFSET<=`,
`ZONE-OFFSET>`, and `ZONE-OFFSET>=` compare fixed-offset values by total
seconds.
`FORMAT-ZONE-OFFSET` emits canonical `Z`, `+HH:MM`, or `+HH:MM:SS` notation.
`PARSE-ZONE-OFFSET` accepts `Z` plus basic or extended `+HH`, `+HHMM`,
`+HHMMSS`, `+HH:MM`, and `+HH:MM:SS` notation.
`FIND-TIME-ZONE` -- looks up an IANA zone by name (signals
`TIME-ZONE-NOT-FOUND`). `TIME-ZONE-NAME` -- accessor.
`OFFSET-FOR-INSTANT` -- the offset in force at an `INSTANT`, for either a
`ZONE-OFFSET` or `TIME-ZONE`. `POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME` --
0/1/2 candidate offsets for a wall-clock reading. `RESOLVE-LOCAL-DATE-TIME`
-- resolves to exactly one, per its `:DISAMBIGUATION` keyword (see
[Conditions](conditions.md)).

`NEXT-ZONE-TRANSITION` and `PREVIOUS-ZONE-TRANSITION` return a
`ZONE-TRANSITION` for the next or previous offset change, respectively, or
`NIL` when no such change exists (including fixed-offset zones). Both searches
are strict: a transition exactly at the supplied `INSTANT` is excluded.
`ZONE-TRANSITION-INSTANT`, `ZONE-TRANSITION-OFFSET-BEFORE`, and
`ZONE-TRANSITION-OFFSET-AFTER` expose the change; `ZONE-TRANSITION-GAP-P` and
`ZONE-TRANSITION-OVERLAP-P` distinguish forward and backward clock changes.
For zones with a POSIX TZ footer, searches continue past the explicit TZif
table using that future rule.

## ZonedDateTime (`src/zoned-date-time.lisp`)

A resolved, real-world timestamp: a `LOCAL-DATE-TIME` plus the `ZONE` and
`ZONE-OFFSET` it resolved to.

`ZONED-DATE-TIME-OF-LOCAL`, `ZONED-DATE-TIME-OF-INSTANT`, and
`ZONED-DATE-TIME-OF-EPOCH-SECOND` -- constructors. `ZONED-DATE-TIME-LOCAL`,
`ZONED-DATE-TIME-ZONE`, `ZONED-DATE-TIME-OFFSET` -- accessors.
`ZONED-DATE-TIME-TO-INSTANT` and `ZONED-DATE-TIME-TO-EPOCH-SECOND` --
conversion to the absolute timeline.
`ZONED-DATE-TIME-DATE`, `ZONED-DATE-TIME-TIME`, and the field accessors
`ZONED-DATE-TIME-YEAR` through `ZONED-DATE-TIME-NANOSECOND` return components
of the stored local date-time. They do not re-resolve the zone, so an overlap
value retains its resolved offset and wall-clock fields.
`ZONED-DATE-TIME-WITH-ZONE-SAME-INSTANT` -- re-expresses the same instant in
a different zone. `ZONED-DATE-TIME-WITH-ZONE-SAME-LOCAL` keeps the local
wall-clock fields and resolves them in a different zone; it accepts the same
`:DISAMBIGUATION` keyword as `ZONED-DATE-TIME-OF-LOCAL`.
`ZONED-DATE-TIME-WITH-YEAR`, `-WITH-MONTH`, `-WITH-DAY`,
`-WITH-DAY-OF-YEAR`, `-WITH-HOUR`, `-WITH-MINUTE`, `-WITH-SECOND`,
and `-WITH-NANOSECOND` replace a local field while retaining the zone. At a
daylight-saving overlap they retain the original offset when it remains valid;
otherwise the changed local fields are resolved with `:COMPATIBLE`, including
the normal forward adjustment through a gap. Year/month replacement uses the
same month-end clamping as `LOCAL-DATE-TIME`. `-PLUS-DURATION`/
`-MINUS-DURATION` perform exact elapsed-time arithmetic. `ZONED-DATE-TIME-PLUS-HOURS`,
`-MINUTES`, `-SECONDS`, `-MILLIS`, `-MICROS`, and `-NANOS`, with matching
`ZONED-DATE-TIME-MINUS-*` functions, likewise use exact elapsed time and
therefore re-resolve the local display across daylight-saving transitions.
`ZONED-DATE-TIME-TRUNCATED-TO` truncates the local fields to a fixed unit; for
an overlap it retains the original offset when that offset remains valid.
`-PLUS-PERIOD`/
`-MINUS-PERIOD` perform calendar arithmetic and retain the current offset
when it remains valid in a daylight-saving overlap; otherwise they resolve
using `:COMPATIBLE`. `ZONED-DATE-TIME-PLUS-DAYS`, `-WEEKS`, `-MONTHS`, and
`-YEARS`, with matching `ZONED-DATE-TIME-MINUS-*` functions, are calendar-unit
helpers with the same local-calendar and overlap-resolution semantics.
`ZONED-DATE-TIME-UNTIL` returns an elapsed-time
`DURATION` between the absolute instants. `ZONED-DATE-TIME-COMPARE`, `=`,
`<`, `<=`, `>`, `>=` -- ordering, by absolute instant. `LOCAL-DATE-NOW`,
`LOCAL-DATE-TIME-NOW`, `LOCAL-TIME-NOW`, and `ZONED-DATE-TIME-NOW` --
convenience "now" accessors taking `:ZONE` and
`:CLOCK` keywords.

## OffsetDateTime (`src/offset-date-time.lisp`)

A `LOCAL-DATE-TIME` paired with a fixed `ZONE-OFFSET`, without IANA zone
rules. Use it for RFC 3339-style timestamps when the numeric offset is known
but a region name and daylight-saving behavior are not.

`MAKE-OFFSET-DATE-TIME`, `OFFSET-DATE-TIME-OF`,
`OFFSET-DATE-TIME-OF-INSTANT`, and `OFFSET-DATE-TIME-OF-EPOCH-SECOND` -- constructors. `OFFSET-DATE-TIME-LOCAL-DATE-TIME`,
`OFFSET-DATE-TIME-OFFSET`, date/time accessors, and passthrough field accessors
(`-YEAR` through `-NANOSECOND`) -- accessors. `OFFSET-DATE-TIME-TO-INSTANT`
and `OFFSET-DATE-TIME-TO-EPOCH-SECOND` -- conversion to the absolute timeline.
`OFFSET-DATE-TIME-WITH-OFFSET-SAME-INSTANT`
changes the displayed offset while retaining the instant; `-SAME-LOCAL` retains
the wall-clock fields and therefore changes the instant.
`OFFSET-DATE-TIME-WITH-YEAR`, `-WITH-MONTH`, `-WITH-DAY`,
`-WITH-DAY-OF-YEAR`, `-WITH-HOUR`, `-WITH-MINUTE`, `-WITH-SECOND`,
and `-WITH-NANOSECOND` replace one local field while retaining the fixed
offset. Year/month replacement uses the same month-end clamping as
`LOCAL-DATE-TIME`. `OFFSET-DATE-TIME-PLUS-YEARS`, `-MONTHS`, `-WEEKS`, and
`-DAYS` perform local-calendar arithmetic, including month-end clamping, while
retaining the fixed offset; matching `OFFSET-DATE-TIME-MINUS-*` functions
reverse those operations. `OFFSET-DATE-TIME-PLUS-HOURS`, `-MINUTES`,
`-SECONDS`, `-MILLIS`, `-MICROS`, and `-NANOS` retain the fixed offset while
applying their corresponding fixed-unit arithmetic. `-PLUS-DURATION`/
`-MINUS-DURATION` perform elapsed-time arithmetic; `-PLUS-PERIOD`/
`-MINUS-PERIOD` perform calendar arithmetic in the fixed-offset local time.
`OFFSET-DATE-TIME-TRUNCATED-TO` truncates the local fields to a fixed unit while
retaining the fixed offset.
`OFFSET-DATE-TIME-UNTIL` returns an elapsed-time `DURATION` between the
absolute instants. `OFFSET-DATE-TIME-COMPARE`, `=`, `<`, `<=`, `>`, `>=`
order by absolute instant.
`OFFSET-DATE-TIME-NOW` takes `:OFFSET` and `:CLOCK` keywords.

## OffsetTime (`src/offset-time.lisp`)

A `LOCAL-TIME` paired with a fixed `ZONE-OFFSET`. It is suitable for an
offset-qualified time of day that deliberately has no calendar date, and thus
cannot be converted to an `INSTANT` by itself.

`MAKE-OFFSET-TIME`, `OFFSET-TIME-OF`, and `OFFSET-TIME-OF-INSTANT` construct
values. `OFFSET-TIME-AT-DATE` combines one with a `LOCAL-DATE` to produce an
`OFFSET-DATE-TIME`. `OFFSET-TIME-LOCAL-TIME`, `OFFSET-TIME-OFFSET`,
`OFFSET-TIME-TIME`, and the `-HOUR` through `-NANOSECOND` accessors expose
their components.
`OFFSET-TIME-WITH-OFFSET-SAME-INSTANT` retains the equivalent UTC time of day;
`-SAME-LOCAL` preserves the displayed fields. `OFFSET-TIME-WITH-HOUR`,
`-WITH-MINUTE`, `-WITH-SECOND`, and `-WITH-NANOSECOND` replace one local
field while retaining the fixed offset. `OFFSET-TIME-PLUS-HOURS`,
`-MINUTES`, `-SECONDS`, `-MILLIS`, `-MICROS`, and `-NANOS` perform fixed-unit
arithmetic while retaining the offset and wrapping within one day; matching
`OFFSET-TIME-MINUS-*` functions reverse those units. `OFFSET-TIME-PLUS-DURATION`
and `OFFSET-TIME-MINUS-DURATION` also wrap within one day.
`OFFSET-TIME-TRUNCATED-TO` truncates the local time to a fixed unit while
retaining the fixed offset. `OFFSET-TIME-UNTIL` returns a signed
`DURATION` between the equivalent UTC times of day and does not cross a date
boundary; equivalent UTC times therefore produce zero. `OFFSET-TIME-COMPARE`,
`=`, `<`, `<=`, `>`, and `>=` order by UTC time of day, then local time to
retain a total order.
`OFFSET-TIME-NOW` takes `:OFFSET` and `:CLOCK` keywords.

## ISO8601 (`src/iso8601-date.lisp`, `src/iso8601.lisp`)

`FORMAT-LOCAL-DATE`/`PARSE-LOCAL-DATE` (canonical "YYYY-MM-DD" output;
parses calendar, ordinal, and week date forms in both extended and basic
notation), `FORMAT-LOCAL-DATE-ORDINAL`/`PARSE-LOCAL-DATE-ORDINAL`
("YYYY-DDD"), `FORMAT-LOCAL-DATE-WEEK-DATE`/`PARSE-LOCAL-DATE-WEEK-DATE`
("YYYY-Www-D"),
`FORMAT-LOCAL-TIME`/`PARSE-LOCAL-TIME` ("HH:MM:SS[.nnnnnnnnn]"),
`FORMAT-LOCAL-DATE-TIME`/`PARSE-LOCAL-DATE-TIME` (the two joined by "T"),
`FORMAT-INSTANT`/`PARSE-INSTANT` (UTC, trailing "Z"),
`FORMAT-OFFSET-DATE-TIME`/`PARSE-OFFSET-DATE-TIME` (a required `Z` or numeric
offset, such as `2024-06-15T12:34:56+09:00`),
`FORMAT-OFFSET-TIME`/`PARSE-OFFSET-TIME` (a required `Z` or numeric offset,
such as `12:34:56+09:00`),
`FORMAT-ZONED-DATE-TIME`/`PARSE-ZONED-DATE-TIME` (adds an offset and, for a
named zone, a bracketed `[Zone/Id]`), `FORMAT-DURATION`/`PARSE-DURATION`
("PT1H1M1S" style), `FORMAT-PERIOD`/`PARSE-PERIOD` ("P1Y2M3D" style). Every
`PARSE-*` function signals `DATE-TIME-PARSE-ERROR` on malformed input.

Date-based formatters use four-digit years from `0000` through `9999`. Outside
that range they emit, and the corresponding extended parsers accept, ISO 8601
signed expanded years, for example `-0001-01-02` and `+10000-01-02`.

## Pattern Formatting (`src/pattern.lisp`)

`MAKE-DATE-TIME-FORMATTER` compiles a reusable, locale-independent formatter;
`FORMAT-DATE-TIME` applies it to a temporal value.
`FORMAT-DATE-TIME-WITH-PATTERN` is the one-shot equivalent. Fields are `y`
(calendar year), `M` (month), `d` (day), `D` (ordinal day), `Y` (ISO
week-based year), `w` (ISO week), `e` (ISO weekday), `H`/`m`/`s` (time), `S`
(nanosecond fraction), `X` (ISO offset), and `V` (IANA zone ID). Quote literal
text with apostrophes and escape an apostrophe with `''`.

`LOCAL-DATE`, `LOCAL-TIME`, `LOCAL-DATE-TIME`, `OFFSET-DATE-TIME`,
`OFFSET-TIME`, `ZONED-DATE-TIME`, and `INSTANT` are supported. A pattern that asks a value for
a field it does not possess, or a malformed/unsupported pattern, signals
`DATE-TIME-FORMAT-ERROR`. With a width of at least four, the `y` and `Y`
fields use ISO 8601 signed expanded notation outside `0000` through `9999`,
such as `-0001` and `+10000`.

`PARSE-DATE-TIME` is the inverse operation for a compiled formatter, and
`PARSE-DATE-TIME-WITH-PATTERN` is its one-shot equivalent. It reconstructs a
`LOCAL-DATE`, `LOCAL-TIME`, or `LOCAL-DATE-TIME` from calendar, ordinal, or ISO
week date fields and time fields. Adding `X` returns an `OFFSET-TIME` or
`OFFSET-DATE-TIME`; adding both `X` and `V` returns a `ZONED-DATE-TIME` after
checking that the offset is valid for the named zone. Minute and second fields
default to zero when omitted.

Parsing accepts the numeric field widths emitted by the formatter. Adjacent
variable-width numeric fields are rejected because their boundary is ambiguous.
Malformed literals, invalid dates or times, unknown zones, and inconsistent
offset/zone pairs signal `DATE-TIME-PARSE-ERROR`.
