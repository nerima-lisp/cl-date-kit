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
`DURATION-ROUNDED-TO`, and every value type's corresponding `-ROUNDED-TO`
operation, support those same units and the modes `:FLOOR`, `:CEILING`,
`:TOWARD-ZERO`, `:AWAY-FROM-ZERO`, `:HALF-UP`, and `:HALF-EVEN` (the default).
They use exact integer nanosecond arithmetic; `:HALF-UP` resolves ties away
from zero and `:HALF-EVEN` resolves them to the even multiple.
`DURATION-PLUS`, `DURATION-MINUS`, `DURATION-NEGATE`, `DURATION-ABS`,
`DURATION-MULTIPLIED-BY`, `DURATION-DIVIDED-BY` -- arithmetic.
`DURATION-DIVIDED-BY` signals `INVALID-DURATION-DIVISION` when its divisor is
zero; the condition retains both operands for recovery or diagnostics.
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
`PERIOD-OF-DAYS`, `PERIOD-OF-WEEKS` -- constructors. `PERIOD-OF-WEEKS`
represents each week as seven days. `PERIOD-BETWEEN` returns the calendar delta
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

## LocalDate (`src/local-date.lisp`, `src/local-date-arithmetic.lisp`, `src/local-date-week.lisp`)

Proleptic-Gregorian calendar date, no time-of-day or zone.

`MAKE-LOCAL-DATE`, `LOCAL-DATE-OF`, `LOCAL-DATE-OF-YEAR-DAY`,
`LOCAL-DATE-OF-WEEK-DATE` --
constructors (signal `INVALID-DATE` for noninteger or calendar-invalid
fields). `LENGTH-OF-MONTH` accepts an integer year and a month integer in
`[1, 12]`, signaling `TYPE-ERROR` otherwise. `LOCAL-DATE-YEAR`,
`LOCAL-DATE-MONTH`, `LOCAL-DATE-DAY` -- accessors. `LEAP-YEAR-P`,
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
`LOCAL-DATE-FIRST-DAY-OF-YEAR`, `LOCAL-DATE-LAST-DAY-OF-YEAR`,
`LOCAL-DATE-FIRST-DAY-OF-NEXT-MONTH`, `LOCAL-DATE-FIRST-DAY-OF-NEXT-YEAR`
-- immutable calendar-boundary adjusters. `LOCAL-DATE-FIRST-IN-MONTH`,
`LOCAL-DATE-LAST-IN-MONTH`, `LOCAL-DATE-DAY-OF-WEEK-IN-MONTH` --
month-relative weekday adjusters. The last takes `(DATE ORDINAL DAY-OF-WEEK)`:
positive nonzero ordinals count from the first matching weekday, negative ones
from the last, and results may fall outside the input month. `LOCAL-DATE-NEXT-OR-SAME`, `LOCAL-DATE-NEXT`,
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
`LOCAL-DATE-OF-INSTANT` projects an `INSTANT` through either a fixed
`ZONE-OFFSET` or IANA `TIME-ZONE`, and returns its local date component.

## Month (`src/month.lisp`)

An ISO-8601 month keyword, from `:JANUARY` through `:DECEMBER`, independent
of a year. `MONTH-VALUE` and `MONTH-FROM-VALUE` convert to and from ISO values
1 through 12, signaling `INVALID-MONTH` for other values. `MONTH-LENGTH`,
`MONTH-MIN-LENGTH`, `MONTH-MAX-LENGTH`, and `MONTH-FIRST-DAY-OF-YEAR` expose
leap-aware calendar facts. `MONTH-QUARTER-OF-YEAR` and
`MONTH-FIRST-MONTH-OF-QUARTER` expose calendar-quarter membership.
`MONTH-PLUS` and `MONTH-MINUS` apply integral arithmetic and wrap within the
ISO year. `MONTH-FROM-LOCAL-DATE` derives a month from a `LOCAL-DATE`.
`MONTH-NOW` derives the current month from an injectable `CLOCK` in a specified
`ZONE`.

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
It signals `TYPE-ERROR` for a non-`LOCAL-TIME` value or unsupported unit.
`LOCAL-TIME-ROUNDED-TO` uses the common rounding modes. Since a `LOCAL-TIME`
has no date, a result rounded upward past midnight wraps within its day.
`LOCAL-TIME-UNTIL` returns the signed nanosecond-precision `DURATION` from one
time-of-day to another; it does not wrap at midnight.
`LOCAL-TIME-AT-DATE` combines a time with a `LOCAL-DATE`.
`LOCAL-TIME-AT-OFFSET` combines a time with a fixed `ZONE-OFFSET` to produce
an `OFFSET-TIME`.
`LOCAL-TIME-OF-INSTANT` projects an `INSTANT` through either a fixed
`ZONE-OFFSET` or IANA `TIME-ZONE`, and returns its local time component.

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
`LOCAL-DATE-TIME-TRUNCATED-TO` accepts `:NANOS`, `:MICROS`, `:MILLIS`,
`:SECONDS`, `:MINUTES`, `:HOURS`, or `:DAYS`, retaining the local date. It
signals `TYPE-ERROR` for a non-`LOCAL-DATE-TIME` value or unsupported unit.
`LOCAL-DATE-TIME-ROUNDED-TO` uses the common rounding modes and carries into
the adjacent local date when rounding crosses midnight.
`LOCAL-DATE-TIME-UNTIL` returns the signed nanosecond-precision `DURATION`
between values on the local timeline.
`LOCAL-DATE-TIME-TO-EPOCH-SECOND` and `LOCAL-DATE-TIME-OF-EPOCH-SECOND` convert
through a fixed `ZONE-OFFSET`, as does `LOCAL-DATE-TIME-TO-INSTANT`.
They signal `TYPE-ERROR` for an invalid required `LOCAL-DATE-TIME`,
`ZONE-OFFSET`, or epoch-second integer input; invalid nanoseconds signal
`INVALID-TIME`.
`LOCAL-DATE-TIME-OF-INSTANT`, `LOCAL-DATE-OF-INSTANT`, and
`LOCAL-TIME-OF-INSTANT` accept either a fixed `ZONE-OFFSET` or IANA `TIME-ZONE`;
for a `TIME-ZONE`, they apply the offset in force at the supplied `INSTANT`.
`LOCAL-DATE-TIME-AT-ZONE` resolves a local value in a `TIME-ZONE` using the
same `:DISAMBIGUATION` rules as `ZONED-DATE-TIME-OF-LOCAL`, including DST gaps
and overlaps; it also accepts the same optional `:PREFERRED-OFFSET` keyword.
`LOCAL-DATE-TIME-AT-OFFSET` pairs the value with a fixed `ZONE-OFFSET`.

## Instant (`src/instant.lisp`)

An absolute point on the UTC timeline (Unix epoch seconds + nanoseconds).

`MAKE-INSTANT`, `INSTANT-EPOCH`, `INSTANT-OF-EPOCH-SECOND`,
`INSTANT-OF-EPOCH-NANOS`,
`INSTANT-OF-EPOCH-MILLIS`, and `INSTANT-OF-EPOCH-MICROS` -- constructors.
`INSTANT-EPOCH-SECOND`, `INSTANT-NANOSECOND`, `INSTANT-TO-EPOCH-NANOS`,
`INSTANT-TO-EPOCH-MILLIS`, and `INSTANT-TO-EPOCH-MICROS` -- accessors and
integer epoch conversions. Nanosecond conversions are exact; sub-millisecond
and sub-microsecond values round down on the UTC timeline.
`INSTANT-OF-UNIVERSAL-TIME` and `INSTANT-TO-UNIVERSAL-TIME` convert to and
from Common Lisp's integer `universal-time` epoch. The latter rejects an
`INSTANT` with non-zero nanoseconds by signaling `INSTANT-PRECISION-LOSS`, so
precision is never discarded.
`INSTANT-AT-ZONE` and `INSTANT-AT-OFFSET` express an `INSTANT` as a
`ZONED-DATE-TIME` in a zone or an `OFFSET-DATE-TIME` at a fixed offset.
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

`FORMAT-INTERVAL` emits the canonical
`FORMAT-INSTANT(start)/FORMAT-INSTANT(end)` representation. `PARSE-INTERVAL`
accepts exactly one slash in `<instant>/<instant>`, `<instant>/<duration>`, or
`<duration>/<instant>` form. Durations must be non-negative; `PERIOD` values
are not supported because interval endpoints are always absolute `INSTANT`s.
Empty sides, multiple separators, two durations, invalid components, negative
durations, and reverse endpoints signal `DATE-TIME-PARSE-ERROR`.

## Local-Date Interval (`src/interval.lisp`)

`LOCAL-DATE-INTERVAL` is a timezone-free, half-open calendar range `[start,
end)` of `LOCAL-DATE` values. `MAKE-LOCAL-DATE-INTERVAL` accepts equal bounds
for an empty range and signals `INVALID-INTERVAL` when the end precedes the
start. The exclusive end makes adjacent calendar ranges compose without
overlap; for example, `[2024-02-28, 2024-03-01)` contains both February 28 and
the leap day.

`LOCAL-DATE-INTERVAL-START`, `LOCAL-DATE-INTERVAL-END`,
`LOCAL-DATE-INTERVAL-EMPTY-P`, and `LOCAL-DATE-INTERVAL-LENGTH-IN-DAYS` inspect
the range. `LOCAL-DATE-INTERVAL-CONTAINS-P`, `-ENCLOSES-P`, `-OVERLAPS-P`,
`-ABUTS-P`, `-CONNECTED-P`, `-BEFORE-P`, and `-AFTER-P` apply the same
half-open set semantics as `INTERVAL`. `LOCAL-DATE-INTERVAL-INTERSECTION`,
`LOCAL-DATE-INTERVAL-SPAN`, `-UNION`, `-GAP`, and `-DIFFERENCE` provide the
corresponding set operations. `-UNION` returns `NIL` for a positive gap, while
`-DIFFERENCE` returns zero, one, or two non-empty calendar ranges.
`LOCAL-DATE-INTERVAL-WITH-START` and `-WITH-END` return a new range with one
bound replaced and retain the usual validity check.

`LOCAL-DATE-INTERVAL-P` recognizes a `LOCAL-DATE-INTERVAL`.
`FORMAT-LOCAL-DATE-INTERVAL` emits canonical
`YYYY-MM-DD/YYYY-MM-DD` half-open bounds. `PARSE-LOCAL-DATE-INTERVAL` accepts
the same date forms as `PARSE-LOCAL-DATE` on each side and signals
`DATE-TIME-PARSE-ERROR` for malformed, multiply separated, or reverse bounds.
`MAP-LOCAL-DATE-INTERVAL` calls its function once with one `LOCAL-DATE` for
each day in ascending `[start, end)` order. It stops when the function returns
`NIL` and always returns `NIL`. `DO-LOCAL-DATE-INTERVAL` is the corresponding
macro form; it accepts `&KEY RESULT`, which it returns after normal completion.
`(RETURN VALUE)` exits the macro's implicit block with `VALUE`.

```lisp
(do-local-date-interval
    (date (make-local-date-interval (local-date-of 2024 2 28)
                                     (local-date-of 2024 3 2))
          :result :complete)
  (when (local-date= date (local-date-of 2024 2 29))
    (return date)))
;; => a LOCAL-DATE for 2024-02-29
```

## Clock (`src/clock.lisp`)

`CLOCK-NOW` (a `DEFGENERIC`) -- the current `INSTANT` according to a clock.
`MAKE-SYSTEM-CLOCK` -- reads the real wall clock. `MAKE-FIXED-CLOCK` --
always returns the `INSTANT` it was built with; use in tests. `INSTANT-NOW`
-- convenience wrapper defaulting to `CURRENT-CLOCK`, which is the shared
system clock outside a clock context. `CALL-WITH-CLOCK` invokes a function with
a dynamically bound current clock; `(WITH-CLOCK (clock) ...)` is its macro
form. All `*-NOW` operations use this current clock unless passed an explicit
`CLOCK` argument.

`MAKE-OFFSET-CLOCK` composes any `CLOCK-NOW` implementation with an exact
`DURATION` offset. `MAKE-TICK-CLOCK` composes a clock that rounds down on the
UTC timeline to a strictly positive fixed `DURATION`; this also gives correct
flooring before the epoch. Both derived clock types expose their base clock and
their offset or tick duration through read-only accessors.

## Zone (`src/zone.lisp`, `src/zone-version.lisp`, `src/zone-local.lisp`)

`src/zone.lisp` owns TZif-backed IANA zone discovery, fixed-offset values,
instant-time state lookup, and transition enumeration. `src/zone-version.lisp`
owns parsing the IANA tzdata release version from the zoneinfo tree.
`src/zone-local.lisp` owns conversion between local fields and the UTC
timeline plus local-time DST classification and resolution. This split keeps
the one-way question "which offset applies at this instant?" separate from
the ambiguous reverse question "which instant does this local clock reading
mean?".

`ZONE-OFFSET-OF-HOURS`, `ZONE-OFFSET-OF-HMS`, `ZONE-OFFSET-OF-TOTAL-SECONDS`,
`ZONE-OFFSET-UTC` --
fixed-offset constructors. `ZONE-OFFSET-TOTAL-SECONDS` -- accessor.
`ZONE-OFFSET-COMPARE`, `ZONE-OFFSET=`, `ZONE-OFFSET<`, `ZONE-OFFSET<=`,
`ZONE-OFFSET>`, and `ZONE-OFFSET>=` compare fixed-offset values by total
seconds.
`FORMAT-ZONE-OFFSET` emits canonical `Z`, `+HH:MM`, or `+HH:MM:SS` notation.
`PARSE-ZONE-OFFSET` accepts `Z` plus basic or extended `+HH`, `+HHMM`,
`+HHMMSS`, `+HH:MM`, and `+HH:MM:SS` notation.
`AVAILABLE-TIME-ZONE-NAMES` -- returns a fresh, duplicate-free, `string<`-sorted
list of IANA names from TZif files under an explicitly supplied `:TZDIR`, or
under `$TZDIR` followed by `/usr/share/zoneinfo`; it excludes `posix/`,
`right/`, and non-TZif metadata. `TIME-ZONE-DATABASE-VERSION` reads a root's
`+VERSION` file when it contains exactly an IANA `YYYYx` release; otherwise it
extracts the leading `YYYYx` token from the first `# version <release>` comment
in `tzdata.zi`, discarding suffixes such as `-rearguard`. An explicit `:TZDIR`
examines only that root, otherwise it uses `$TZDIR` then
`/usr/share/zoneinfo`. It returns `NIL` when the metadata cannot be read or
is not in that form.
`FIND-TIME-ZONE` -- looks up an IANA zone by name (signals
`TIME-ZONE-NOT-FOUND`). `TIME-ZONE-NAME` -- accessor.
`ZONE-STATE-FOR-INSTANT` returns an opaque state for an `INSTANT` in either a
fixed `ZONE-OFFSET` or IANA `TIME-ZONE`. Its `ZONE-STATE-OFFSET`,
`ZONE-STATE-ABBREVIATION`, and `ZONE-STATE-DAYLIGHT-SAVING-P` accessors report
the selected offset, designation, and DST flag. Fixed offsets have no
designation and a false DST flag. `OFFSET-FOR-INSTANT` returns the state
offset. `POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME` --
0/1/2 candidate offsets for a wall-clock reading. `RESOLVE-LOCAL-DATE-TIME`
-- resolves to exactly one, per its `:DISAMBIGUATION` keyword (see
[Conditions](conditions.md)).

`LOCAL-DATE-TIME-TO-EPOCH-SECOND`, `LOCAL-DATE-TIME-OF-EPOCH-SECOND`, and
`LOCAL-DATE-TIME-TO-INSTANT` take a `LOCAL-DATE-TIME` (or epoch fields) and a
fixed `ZONE-OFFSET`; they do only numeric offset arithmetic and never consult
DST rules. `LOCAL-DATE-TIME-OF-INSTANT` accepts either a fixed `ZONE-OFFSET`
or an IANA `TIME-ZONE`; for an IANA zone it uses the offset in force at the
given `INSTANT`. `LOCAL-DATE-OF-INSTANT` and `LOCAL-TIME-OF-INSTANT` return
the corresponding component of that projection. To interpret a local value in
an IANA zone, use `RESOLVE-LOCAL-DATE-TIME` or
`ZONED-DATE-TIME-OF-LOCAL`: these perform gap/overlap resolution, whereas the
fixed-offset conversion functions cannot be ambiguous.
`LOCAL-DATE-TIME-ZONE-TRANSITION` -- inspection and diagnostics for an
ambiguous or nonexistent wall-clock reading: returns the responsible
`ZONE-TRANSITION` when `LOCAL-DATE-TIME` lies in a daylight-saving gap or
overlap in `ZONE`, otherwise `NIL` (including for fixed-offset zones). Use its
`ZONE-TRANSITION-INSTANT`, `ZONE-TRANSITION-OFFSET-BEFORE`, and
`ZONE-TRANSITION-OFFSET-AFTER` accessors plus `ZONE-TRANSITION-GAP-P` and
`ZONE-TRANSITION-OVERLAP-P` to describe the transition; use
`RESOLVE-LOCAL-DATE-TIME` instead when selecting a concrete resolution.
Classification covers both explicit TZif records and POSIX future rules.

`NEXT-ZONE-TRANSITION` and `PREVIOUS-ZONE-TRANSITION` return a
`ZONE-TRANSITION` for the next or previous offset change, respectively, or
`NIL` when no such change exists (including fixed-offset zones). Both searches
are strict: a transition exactly at the supplied `INSTANT` is excluded.
`ZONE-TRANSITION-INSTANT`, `ZONE-TRANSITION-OFFSET-BEFORE`, and
`ZONE-TRANSITION-OFFSET-AFTER` expose the change; `ZONE-TRANSITION-GAP-P` and
`ZONE-TRANSITION-OVERLAP-P` distinguish forward and backward clock changes.
`ZONE-TRANSITION-DURATION` returns the exact offset delta as a `DURATION`, and
`ZONE-TRANSITION-DATE-TIME-BEFORE` / `ZONE-TRANSITION-DATE-TIME-AFTER` project
the transition instant to its local date-time under the offsets before and
after the change, respectively. They expose the two local boundary readings;
they do not select a DST disambiguation policy.
For zones with a POSIX TZ footer, searches continue past the explicit TZif
table using that future rule.

`TIME-ZONE-TRANSITIONS-BETWEEN` returns a chronologically ordered list of
`ZONE-TRANSITION` values in the half-open range `[START, END)`. `ZONE` must
be a `TIME-ZONE` or fixed `ZONE-OFFSET`, and `START` and `END` must be
`INSTANT` values. `END` must be strictly after `START`; equal or reversed
bounds signal `INVALID-INTERVAL`. The result is `NIL` for fixed-offset zones
and for ranges without transitions. It includes future transitions supplied by
a POSIX TZ footer.

## ZonedDateTime (`src/zoned-date-time.lisp`)

A resolved, real-world timestamp: a `LOCAL-DATE-TIME` plus the `ZONE` and
`ZONE-OFFSET` it resolved to.

`ZONED-DATE-TIME-OF-LOCAL`, `ZONED-DATE-TIME-OF-INSTANT`, and
`ZONED-DATE-TIME-OF-EPOCH-SECOND` -- constructors. `ZONED-DATE-TIME-LOCAL`,
`ZONED-DATE-TIME-ZONE`, `ZONED-DATE-TIME-OFFSET` -- accessors.
`ZONED-DATE-TIME-TO-INSTANT` and `ZONED-DATE-TIME-TO-EPOCH-SECOND` --
conversion to the absolute timeline.
`ZONED-DATE-TIME-TO-OFFSET-DATE-TIME` snapshots the resolved local date-time
and offset as an `OFFSET-DATE-TIME`, preserving the instant while discarding
the zone ID and future transition rules.
`ZONED-DATE-TIME-WITH-FIXED-OFFSET-ZONE` replaces an IANA zone with the
resolved `ZONE-OFFSET` as a fixed zone. It preserves the stored local
date-time, offset, and instant, but discards the original zone ID and future
transition rules.
`ZONED-DATE-TIME-DATE`, `ZONED-DATE-TIME-TIME`, and the field accessors
`ZONED-DATE-TIME-YEAR` through `ZONED-DATE-TIME-NANOSECOND` return components
of the stored local date-time. They do not re-resolve the zone, so an overlap
value retains its resolved offset and wall-clock fields.
`ZONED-DATE-TIME-WITH-ZONE-SAME-INSTANT` -- re-expresses the same instant in
a different zone. `ZONED-DATE-TIME-WITH-ZONE-SAME-LOCAL` keeps the local
wall-clock fields and resolves them in a different zone.
`ZONED-DATE-TIME-OF-LOCAL`, `LOCAL-DATE-TIME-AT-ZONE`, and
`ZONED-DATE-TIME-WITH-ZONE-SAME-LOCAL` accept optional `:PREFERRED-OFFSET`
alongside `:DISAMBIGUATION`. During a DST overlap, a preferred offset that is
one of the two valid candidate offsets is selected; this supports restoring a
timestamp from a local date-time, offset, and zone. For normal local
times, gaps, or an invalid preferred offset, resolution instead follows
`:DISAMBIGUATION` as before.
`ZONED-DATE-TIME-OF-STRICT` takes a local date-time, offset, and zone, and
constructs a value only when that offset is valid under the zone rules at that
wall-clock time. It rejects gaps and invalid offsets for normal or overlap
local times; either candidate offset is accepted during an overlap. A fixed
`ZONE-OFFSET` zone is also supported.
`ZONED-DATE-TIME-WITH-EARLIER-OFFSET-AT-OVERLAP` and
`ZONED-DATE-TIME-WITH-LATER-OFFSET-AT-OVERLAP` select the first or second
occurrence of the same local wall-clock value during a DST overlap. For every
other resolved value, they return the original value unchanged.
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
`ZONED-DATE-TIME-ROUNDED-TO` uses the common rounding modes and applies the
same local resolution rule when its rounded value crosses a DST transition.
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

## RFC 5545 RRULE (`src/rrule.lisp`, `src/rrule-codec.lisp`, `src/rrule-date-selection.lisp`, `src/rrule-candidates.lisp`, `src/rrule-occurrences.lisp`)

`RRULE` is the immutable representation of an RFC 5545 recurrence rule.
`MAKE-RRULE` constructs one from keyword arguments; `PARSE-RRULE` reads a
complete RRULE property value without the `RRULE:` prefix; and `FORMAT-RRULE`
returns its canonical property-value string. `MAKE-RRULE-BY-DAY` creates a
`BYDAY` item from an RFC weekday keyword (`:MO` through `:SU`) and an optional
nonzero ordinal, such as `(MAKE-RRULE-BY-DAY :MO -1)` for the last Monday.
RFC 5545 syntax and semantic validation failures signal `INVALID-RRULE`;
`INVALID-RRULE-REASON` identifies the violated rule and `INVALID-RRULE-VALUE`
contains the offending input when one is available.

`MAKE-RRULE` requires `:FREQUENCY`, one of `:SECONDLY`, `:MINUTELY`,
`:HOURLY`, `:DAILY`, `:WEEKLY`, `:MONTHLY`, or `:YEARLY`. `:INTERVAL` is a
positive integer and defaults to one. `:COUNT` is a positive occurrence limit;
`:UNTIL` is an inclusive final bound. They are mutually exclusive. `:WEEK-START`
sets `WKST` and defaults to `:MO`.

`:UNTIL` accepts an `INSTANT`, `LOCAL-DATE-TIME`, or `LOCAL-DATE`. A
`LOCAL-DATE` denotes RFC 5545 `DATE` notation and is valid only with an
all-day schedule whose `DTSTART` is also a `LOCAL-DATE`.

The remaining keyword arguments correspond directly to RFC rule parts:
`:BY-SECOND` (0--59; leap seconds are not represented), `:BY-MINUTE` (0--59), `:BY-HOUR` (0--23), `:BY-DAY`,
`:BY-MONTH-DAY` (1--31 or negative from month end), `:BY-YEAR-DAY` (1--366 or
negative from year end), `:BY-WEEK-NO` (1--53 or negative), `:BY-MONTH`
(1--12), and `:BY-SET-POS` (positive or negative position in the candidates
for one frequency interval). Each accepts a list or vector. `BYSETPOS` is
applied after the other `BY*` clauses select candidates.

`MAKE-RRULE-SCHEDULE` pairs an `RRULE` with a zoned, floating, or all-day
`DTSTART`. A `ZONED-DATE-TIME` DTSTART emits zoned occurrences and resolves
candidate local times in its zone. A `LOCAL-DATE-TIME` DTSTART is floating: it
emits `LOCAL-DATE-TIME` values directly, has no zone or DST resolution, and
requires a `LOCAL-DATE-TIME` `UNTIL` when present. A `LOCAL-DATE` DTSTART
emits `LOCAL-DATE` occurrences; it requires a `LOCAL-DATE` `UNTIL` when
present, allows only `:DAILY`, `:WEEKLY`, `:MONTHLY`, and `:YEARLY`, and
rejects `:BY-HOUR`, `:BY-MINUTE`, and `:BY-SECOND`.
`MAP-RRULE-OCCURRENCES` calls a function with each occurrence in order and
stops when it returns `NIL`.
`RRULE-OCCURRENCES` returns all occurrences of a finite schedule, and
`DO-RRULE-OCCURRENCES` is the corresponding iteration macro. A schedule
without `UNTIL` must receive a positive `:MAX-PERIODS` argument to any of
these APIs. `COUNT` limits emitted occurrences rather than searched periods,
so it cannot establish termination when candidate filters never match. The
limit counts evaluated frequency periods and therefore also terminates rules
whose candidate filters never match. `DO-RRULE-OCCURRENCES` takes
`:MAX-PERIODS` and optional `:RESULT` keyword arguments; `RETURN` still exits
its body early.
If the period limit is exhausted before `COUNT` is reached, the occurrence APIs
return the generated prefix.

Candidate local times are resolved strictly in the `DTSTART` zone. A local
time in a DST gap is skipped. For a DST overlap, the earlier valid offset is
selected. This differs from the general `ZONED-DATE-TIME-OF-LOCAL` default,
which uses `:COMPATIBLE` disambiguation.

```lisp
(let* ((zone (find-time-zone "Asia/Tokyo"))
       (rule (parse-rrule "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=3"))
       (schedule (make-rrule-schedule
                  (zoned-date-time-of-local
                   (local-date-time-of 2024 1 1 9 0 0) zone)
                  rule)))
  (format-rrule rule)
  (rrule-occurrences schedule :max-periods 3))
```

For example, explicitly bound a daily schedule without `UNTIL` with
`(RRULE-OCCURRENCES SCHEDULE :MAX-PERIODS 30)`.

## RFC 5545 Recurrence Sets (`src/rrule-set.lisp`)

`MAKE-RRULE-SET` composes a list or vector of homogeneous `RRULE-SCHEDULE`
values with explicit `:RDATES` and `:EXDATES` of the same type. Supported
types are `ZONED-DATE-TIME`, floating `LOCAL-DATE-TIME`, and `LOCAL-DATE`.
`RRULE-SET-OCCURRENCES` evaluates every schedule, forms the chronological
union with `:RDATES`, removes matching `:EXDATES`, and deduplicates values.
Zoned values are compared by instant; floating and all-day values are compared
by their local fields. It accepts the same `:MAX-PERIODS` safety bound and
passes it to every member schedule; each member without `UNTIL` requires it,
while an RDATE-only set does not. Use `MAP-RRULE-SET-OCCURRENCES` for
cancellable iteration and `DO-RRULE-SET-OCCURRENCES` for the corresponding
loop form.

## OffsetDateTime (`src/offset-date-time.lisp`)

A `LOCAL-DATE-TIME` paired with a fixed `ZONE-OFFSET`, without IANA zone
rules. Use it for RFC 3339-style timestamps when the numeric offset is known
but a region name and daylight-saving behavior are not.

`MAKE-OFFSET-DATE-TIME`, `OFFSET-DATE-TIME-OF`,
`OFFSET-DATE-TIME-OF-INSTANT`, and `OFFSET-DATE-TIME-OF-EPOCH-SECOND` -- constructors. `OFFSET-DATE-TIME-LOCAL-DATE-TIME`,
`OFFSET-DATE-TIME-OFFSET`, date/time accessors, and passthrough field accessors
(`-YEAR` through `-NANOSECOND`) -- accessors. `OFFSET-DATE-TIME-TO-INSTANT`
and `OFFSET-DATE-TIME-TO-EPOCH-SECOND` -- conversion to the absolute timeline.
`OFFSET-DATE-TIME-AT-ZONE-SAME-INSTANT` re-expresses that instant under zone
rules. `OFFSET-DATE-TIME-AT-ZONE-SIMILAR-LOCAL` instead resolves the
wall-clock fields in a zone, preferring the fixed offset when it is valid
during an overlap.
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
`OFFSET-DATE-TIME-TRUNCATED-TO` accepts `:NANOS`, `:MICROS`, `:MILLIS`,
`:SECONDS`, `:MINUTES`, `:HOURS`, or `:DAYS`, retaining the fixed offset. It
signals `TYPE-ERROR` for a non-`OFFSET-DATE-TIME` value or unsupported unit.
`OFFSET-DATE-TIME-ROUNDED-TO` uses the common rounding modes and carries into
the adjacent local date when needed.
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
`OFFSET-TIME-TRUNCATED-TO` accepts `:NANOS`, `:MICROS`, `:MILLIS`, `:SECONDS`,
`:MINUTES`, `:HOURS`, or `:DAYS`, retaining the fixed offset. It signals
`TYPE-ERROR` for a non-`OFFSET-TIME` value or unsupported unit.
`OFFSET-TIME-ROUNDED-TO` uses the common rounding modes and wraps within the
local day when upward rounding crosses midnight.
`OFFSET-TIME-UNTIL` returns a signed
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
`FORMAT-LOCAL-TIME`/`PARSE-LOCAL-TIME` (canonical extended
"HH:MM:SS[.nnnnnnnnn]" output; parsers also accept basic
"HHMMSS[.nnnnnnnnn]" time notation),
`FORMAT-LOCAL-DATE-TIME`/`PARSE-LOCAL-DATE-TIME` (the two joined by "T"),
`FORMAT-INSTANT`/`PARSE-INSTANT` (UTC, trailing "Z"),
`FORMAT-OFFSET-DATE-TIME`/`PARSE-OFFSET-DATE-TIME` (a required `Z` or numeric
offset, such as `2024-06-15T12:34:56+09:00`),
`FORMAT-OFFSET-TIME`/`PARSE-OFFSET-TIME` (a required `Z` or numeric offset,
such as `12:34:56+09:00`),
`FORMAT-ZONED-DATE-TIME`/`PARSE-ZONED-DATE-TIME` (adds an offset and, for a
named zone, a bracketed `[Zone/Id]`), `FORMAT-DURATION`/`PARSE-DURATION`
(`PT1H1M1S` output; parsing accepts day components such as `P2D` and dot or
comma decimal fractions),
`FORMAT-PERIOD`/`PARSE-PERIOD` (`P1Y2M3D` style; period parsing also accepts
signed components, a leading sign, and ordered week components). Every
`PARSE-*` function signals `DATE-TIME-PARSE-ERROR` on malformed input. Time
parsers accept both ISO 8601 basic and extended notation, while time-bearing
formatters always emit canonical extended notation.

Date-based formatters use four-digit years from `0000` through `9999`. Outside
that range they emit, and the corresponding extended parsers accept, ISO 8601
signed expanded years, for example `-0001-01-02` and `+10000-01-02`.

## Pattern Formatting (`src/pattern.lisp`)

`MAKE-DATE-TIME-FORMATTER` compiles a reusable formatter and retains its
`:LOCALE` (which defaults to `:EN`); `FORMAT-DATE-TIME` applies it to a
temporal value. `:LOCALE` may also be a `DATE-TIME-LOCALE` created by
`MAKE-DATE-TIME-LOCALE`.
`FORMAT-DATE-TIME-WITH-PATTERN` is the one-shot equivalent. Fields are `y`
(calendar year), `M` (numeric month at widths 1-2; abbreviated/full locale
month at widths 3-4), `d` (day), `D` (ordinal day), `Y` (ISO
week-based year), `w` (ISO week), `e` (ISO weekday), `H` (24-hour clock), `h`
(12-hour clock), `m`/`s` (time), `S`
(nanosecond fraction), `A` (millisecond of day), `X` (ISO offset), `V` (IANA
zone ID), and `z` (the active IANA zone abbreviation). `V` and `z` only
support width 1. `E` at widths 3-4 emits abbreviated/full locale weekday
names, and `a` emits the locale AM/PM text. `A` cannot be combined with `H`,
`h`, `m`, `s`, `S`, or `a` in the same pattern -- it stands alone as a
complete time source when parsed.
Quote literal text with apostrophes and escape an apostrophe with `''`.

`MAKE-DATE-TIME-LOCALE` accepts a keyword name, vectors of 12 abbreviated and
full month names, vectors of 7 abbreviated and full weekday names, and
nonempty AM/PM strings. It defensively copies the supplied text. Custom locales
are not registered globally; pass the resulting object through `:LOCALE`.
`FIND-DATE-TIME-LOCALE` looks up a bundled locale (`:EN` or `:JA`) by keyword.
A `DATE-TIME-LOCALE`'s fields are readable back out through
`DATE-TIME-LOCALE-NAME`, `DATE-TIME-LOCALE-SHORT-MONTHS`/`-MONTHS`,
`DATE-TIME-LOCALE-SHORT-WEEKDAYS`/`-WEEKDAYS`, and `DATE-TIME-LOCALE-AM`/`-PM`.

`LOCAL-DATE`, `LOCAL-TIME`, `LOCAL-DATE-TIME`, `OFFSET-DATE-TIME`,
`OFFSET-TIME`, `ZONED-DATE-TIME`, and `INSTANT` are supported. A pattern that asks a value for
a field it does not possess, or a malformed/unsupported pattern, signals
`DATE-TIME-FORMAT-ERROR`. With a width of at least four, the `y` and `Y`
fields use ISO 8601 signed expanded notation outside `0000` through `9999`,
such as `-0001` and `+10000`.

For an `INSTANT`, `FORMAT-DATE-TIME` and `FORMAT-DATE-TIME-WITH-PATTERN`
accept `:ZONE` as either an IANA `TIME-ZONE` or a fixed `ZONE-OFFSET`; local
fields and `X` are derived at that instant. The default remains UTC. `V` and
`z` require an IANA zone; `z` is formatting-only because abbreviations such as
`EST` are not globally unique.

`PARSE-DATE-TIME` is the inverse operation for a compiled formatter, and
`PARSE-DATE-TIME-WITH-PATTERN` is its one-shot equivalent. It reconstructs a
`LOCAL-DATE`, `LOCAL-TIME`, or `LOCAL-DATE-TIME` from calendar, ordinal, or ISO
week date fields and time fields. Adding `X` returns an `OFFSET-TIME` or
`OFFSET-DATE-TIME`; adding both `X` and `V` returns a `ZONED-DATE-TIME` after
checking that the offset is valid for the named zone. Minute and second fields
default to zero when omitted. The display-only `z` field is rejected during
parsing.

Parsing accepts the numeric field widths emitted by the formatter. Locale month,
weekday, and AM/PM text is case-insensitive. A parsed weekday must match the
reconstructed date, and an AM/PM marker must agree with the `H` hour. The
12-hour `h` field requires `a`; parsing normalizes `12 AM` to hour 0 and `12
PM` to hour 12. Adjacent
variable-width numeric fields are rejected because their boundary is ambiguous.
Malformed literals, invalid dates or times, unknown zones, and inconsistent
weekday, AM/PM, or offset/zone values signal `DATE-TIME-PARSE-ERROR`. `:EN`
and `:JA` are bundled locale identifiers; unsupported locale identifiers
signal `DATE-TIME-FORMAT-ERROR`.
