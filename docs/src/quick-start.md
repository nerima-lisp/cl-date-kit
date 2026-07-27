# Quick Start

## Naive calendar values

```lisp
(asdf:load-system "cl-date-kit")
(in-package :cl-date-kit)

(let ((date (make-local-date 2024 2 29)))
  (format-local-date (local-date-plus-years date 1)))
;; => "2025-02-28"  -- clamped, since 2025 is not a leap year

(local-date-until (make-local-date 2020 1 31) (make-local-date 2021 3 1))
;; => #S(PERIOD :YEARS 1 :MONTHS 1 :DAYS 1)
```

## Real-world timestamps with a time zone

```lisp
(let* ((ny (find-time-zone "America/New_York"))
       (zdt (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) ny)))
  (format-zoned-date-time zdt))
;; => "2024-06-15T12:00:00-04:00[America/New_York]"
```

## Daylight-saving gaps and overlaps

`2024-03-10T02:30:00` never happened in `America/New_York` -- clocks jumped
straight from 02:00 to 03:00. `RESOLVE-LOCAL-DATE-TIME` (which
`ZONED-DATE-TIME-OF-LOCAL` calls) lets you choose how to handle that:

```lisp
(resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) ny
                          :disambiguation :strict)
;; => signals NONEXISTENT-LOCAL-TIME

(resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) ny)
;; => #<ZONE-OFFSET -04:00>  (:COMPATIBLE, the default: the post-gap offset)
```

`2024-11-03T01:30:00` happens *twice* that same year, when clocks fall back
from 02:00 EDT to 01:00 EST:

```lisp
(possible-offsets-for-local-date-time (local-date-time-of 2024 11 3 1 30 0) ny)
;; => (#<ZONE-OFFSET -04:00> #<ZONE-OFFSET -05:00>)  -- earlier, then later
```

## Elapsed time vs. calendar time

`DURATION` is exact elapsed time; `PERIOD` is calendar-based. Adding a day
across a spring-forward transition is 23 real hours, not 24 -- which is
exactly why `ZONED-DATE-TIME` has separate `-PLUS-DURATION` and
`-PLUS-PERIOD` operations instead of one:

```lisp
(let* ((before (zoned-date-time-of-local (local-date-time-of 2024 3 9 12 0 0) ny))
       (after (zoned-date-time-plus-period before (period-of-days 1))))
  (values (format-zoned-date-time after)
          (duration-to-seconds (instant-until (zoned-date-time-to-instant before)
                                               (zoned-date-time-to-instant after)))))
;; => "2024-03-10T12:00:00-04:00[America/New_York]"
;;    82800  (23 hours, not 86400)
```

See [Core concepts](core-concepts.md) for the full type layering and
[API reference](api-reference.md) for every function.
