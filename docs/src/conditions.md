# Conditions

Every condition cl-date-kit signals inherits from `CL-DATE-KIT-ERROR`, so
catching that one condition handles any failure from this library.

| Condition | Signaled by | Why |
|---|---|---|
| `INVALID-DATE` | `MAKE-LOCAL-DATE`, `LOCAL-DATE-OF-YEAR-DAY` | The year/month/day (or year/day-of-year) does not name a real proleptic-Gregorian date. |
| `INVALID-DAY-OF-WEEK` | `DAY-OF-WEEK-VALUE`, `DAY-OF-WEEK-FROM-VALUE`, `DAY-OF-WEEK-PLUS`, `DAY-OF-WEEK-MINUS` | A weekday keyword, ISO weekday number, or arithmetic amount is invalid. |
| `INVALID-MONTH` | `MONTH-VALUE`, `MONTH-FROM-VALUE`, and Month arithmetic/query functions | A month keyword, ISO month number, or arithmetic amount is invalid. |
| `INVALID-YEAR-MONTH` | `MAKE-YEAR-MONTH` | The month is outside 1-12 or either field is not an integer. |
| `INVALID-MONTH-DAY` | `MAKE-MONTH-DAY` | The month/day pair cannot occur in a leap year. |
| `INVALID-YEAR` | `MAKE-YEAR` | The proleptic-Gregorian year is not an integer. |
| `INVALID-TIME` | `MAKE-LOCAL-TIME` | Hour, minute, second, or nanosecond is out of range. Leap seconds are not modeled, matching java.time, Temporal, Go `time`, and Rust's `time`/`chrono`. |
| `DATE-TIME-PARSE-ERROR` | Every `PARSE-*` function | The input string does not match the expected ISO-8601/RFC-3339 grammar. |
| `TIME-ZONE-NOT-FOUND` | `FIND-TIME-ZONE` | No TZif file for that IANA name under `TZDIR` or `/usr/share/zoneinfo` -- including when the name is rejected outright for containing `..` or starting with `/`, which would otherwise let a caller read arbitrary files off disk. |
| `MALFORMED-TZIF` | The TZif parser | A file exists at the expected path but its header or data blocks are not RFC 8536-shaped. |
| `NONEXISTENT-LOCAL-TIME` | `RESOLVE-LOCAL-DATE-TIME` with `:DISAMBIGUATION :STRICT` | The local date-time falls in a spring-forward gap: the wall clock jumped past it. |
| `AMBIGUOUS-LOCAL-TIME` | `RESOLVE-LOCAL-DATE-TIME` with `:DISAMBIGUATION :STRICT` | The local date-time falls in a fall-back overlap: the wall clock repeated it under two different offsets. |
| `INVALID-ZONE-OFFSET` | `ZONE-OFFSET-OF-HMS` | Hours, minutes, or seconds are out of range, have mixed signs, or the magnitude exceeds the ISO-8601 limit of +-18:00 (java.time's `ZoneOffset.MIN`/`MAX`) -- including +-18:00 itself with a nonzero minute or second. |

## Disambiguation policies

`RESOLVE-LOCAL-DATE-TIME` and `ZONED-DATE-TIME-OF-LOCAL` take a
`:DISAMBIGUATION` keyword instead of always signaling on a gap or overlap,
because most callers building a `ZONED-DATE-TIME` from user input want *a*
answer, not an exception:

- `:COMPATIBLE` (the default) -- the offset after a gap; the earlier offset
  in an overlap.
- `:EARLIER` -- the offset before a gap; the earlier offset in an overlap.
- `:LATER` -- the offset after a gap; the later offset in an overlap.
- `:STRICT` -- signals `NONEXISTENT-LOCAL-TIME` or `AMBIGUOUS-LOCAL-TIME`
  instead of picking one.

`RESOLVE-LOCAL-DATE-TIME` only ever returns an offset -- it has no
wall-clock fields of its own to adjust, so for a gap it simply picks which
of the two bracketing offsets to pair with the *original* local date-time
as-is. `ZONED-DATE-TIME-OF-LOCAL` owns a full date-time, so for a gap under
`:COMPATIBLE`/`:LATER` it additionally shifts the local fields forward by
the gap's length, and under `:EARLIER` shifts them backward -- landing on
the first real wall-clock reading in the new offset, exactly like
java.time's default resolver:

```lisp
(zoned-date-time-of-local (local-date-time-of 2024 3 10 2 30 0) ny)
;; => 2024-03-10T03:30:00-04:00[America/New_York]  (:COMPATIBLE: +1h, into EDT)
(zoned-date-time-of-local (local-date-time-of 2024 3 10 2 30 0) ny :disambiguation :earlier)
;; => 2024-03-10T01:30:00-05:00[America/New_York]  (:EARLIER: -1h, into EST)
```

Pass `:STRICT` to either function if your application needs to reject a
gap or overlap instead of picking a resolution.
