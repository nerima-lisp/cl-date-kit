(in-package #:cl-date-kit)

(define-condition cl-date-kit-error (error)
  ()
  (:documentation
    "Base condition for domain validation errors signaled by CL-DATE-KIT."))

(define-date-kit-condition invalid-date (year month day)
  "~D-~D-~D is not a valid proleptic-Gregorian date."
  "Signaled by MAKE-LOCAL-DATE and LOCAL-DATE-OF-YEAR-DAY when
the year/month/day (or year/day-of-year) combination does not name a real
calendar date, e.g. a month outside 1-12 or a day past the end of its month.")

(define-date-kit-condition invalid-day-of-week (value)
  "~S is not a valid ISO weekday or integral weekday amount."
  "Signaled by the DAY-OF-WEEK value APIs when a weekday keyword, ISO weekday number, or arithmetic amount is invalid.")

(define-date-kit-condition invalid-month (value)
  "~S is not a valid ISO month keyword or number."
  "Signaled by the MONTH value APIs when a month keyword, ISO month number,
or arithmetic amount is invalid.")

(define-date-kit-condition invalid-year-month (year month)
  "~S-~S is not a valid proleptic-Gregorian year-month."
  "Signaled by MAKE-YEAR-MONTH when YEAR is not an integer or
MONTH is not an integer in the inclusive range 1 through 12.")

(define-date-kit-condition invalid-year (value)
  "~S is not an integral proleptic-Gregorian year."
  "Signaled by MAKE-YEAR when VALUE is not an integer.")

(define-date-kit-condition invalid-month-day (month day)
  "~S-~S is not a valid month-day."
  "Signaled by MAKE-MONTH-DAY when MONTH and DAY do not name
a real month/day combination in a leap year.  February 29 is therefore valid.")

(define-date-kit-condition invalid-time (hour minute second nanosecond)
  "~D:~D:~D.~9,'0D is not a valid time of day."
  "Signaled by MAKE-LOCAL-TIME when hour, minute, second, or
nanosecond falls outside its valid range (0-23, 0-59, 0-59, 0-999999999).
Leap seconds are not modeled.")

(define-date-kit-condition date-time-parse-error (string expected)
  "Cannot parse ~S as ~A."
  "Signaled by the PARSE-* functions in iso8601-date.lisp and iso8601.lisp when the
input string does not match the expected ISO-8601/RFC-3339 grammar.")

(define-date-kit-condition date-time-format-error (pattern reason)
  "Cannot format with pattern ~S: ~A."
  "Signaled when a custom date-time pattern is invalid or
requires a field that its input value does not provide.")

(define-date-kit-condition time-zone-not-found (name)
  "No time zone database entry for ~S. Searched TZDIR and /usr/share/zoneinfo."
  "Signaled by FIND-TIME-ZONE when no TZif file for the
requested IANA name (e.g. \"Asia/Tokyo\") exists under the TZDIR environment
variable or the default /usr/share/zoneinfo search path.")

(define-date-kit-condition malformed-tzif (path reason)
  "~A is not a valid TZif file: ~A."
  "Signaled while parsing a TZif file (RFC 8536) whose header, counts, data blocks, or POSIX footer are inconsistent with the format.")

(define-date-kit-condition nonexistent-local-time (local-date-time zone)
  "~A does not exist in ~A: it falls in a daylight-saving-time gap."
  "Signaled by RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION
:STRICT when the local date-time falls in a spring-forward gap, i.e. the wall
clock jumped past it and no offset makes it a real instant.")

(define-date-kit-condition ambiguous-local-time (local-date-time zone earlier-offset later-offset)
  "~A is ambiguous in ~A: it occurs twice, at offset ~A and again at offset ~A."
  "Signaled by RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION
:STRICT when the local date-time falls in a fall-back overlap, i.e. the wall
clock repeated it under two different offsets.")

(define-date-kit-condition invalid-zoned-date-time-offset (local-date-time offset zone)
  "~A at offset ~A is not valid in ~A."
  "Signaled by ZONED-DATE-TIME-OF-STRICT when OFFSET is not a valid
resolution of LOCAL-DATE-TIME in ZONE, including gaps and invalid overlap
offsets.")

(define-date-kit-condition invalid-zone-offset (hours minutes seconds)
  "~D:~D:~D is not a valid ISO-8601 UTC offset."
  "Signaled when a UTC offset has mixed signs, minute or second components outside 0-59, or a magnitude greater than 18:00.")

(define-date-kit-condition invalid-interval (start end)
  "An interval start ~S must not be after end ~S."
  "Signaled when an interval end precedes its start.")

(define-date-kit-condition invalid-duration-division (duration divisor)
  "Cannot divide duration ~S by ~S."
  "Signaled by DURATION-DIVIDED-BY when DIVISOR is zero.")

(define-date-kit-condition instant-precision-loss (instant representation)
  "Cannot represent instant ~S as ~S without losing precision."
  "Signaled when converting an INSTANT would discard nonzero precision.")

(define-date-kit-condition invalid-rrule (reason value)
  "Invalid RFC 5545 recurrence rule: ~A~@[ (~S)~]."
  "Signaled when an RRULE or recurrence-set value is invalid.")
