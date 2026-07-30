;;;; src/conditions.lisp
(in-package #:cl-date-kit)

(define-condition cl-date-kit-error (error)
  ()
  (:documentation
    "Base condition for domain validation errors signaled by CL-DATE-KIT. Catch
this to handle invalid temporal values and format violations without naming
each specific condition."))

(define-condition invalid-date (cl-date-kit-error)
  ((year :initarg :year :reader invalid-date-year)
    (month :initarg :month :reader invalid-date-month)
    (day :initarg :day :reader invalid-date-day))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~D-~D-~D is not a valid proleptic-Gregorian date."
        (invalid-date-year condition)
        (invalid-date-month condition)
        (invalid-date-day condition))))
  (:documentation
    "Signaled by MAKE-LOCAL-DATE and LOCAL-DATE-OF-YEAR-DAY when
the year/month/day (or year/day-of-year) combination does not name a real
calendar date, e.g. a month outside 1-12 or a day past the end of its month."))

(define-condition invalid-day-of-week (cl-date-kit-error)
  ((value :initarg :value :reader invalid-day-of-week-value))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~S is not a valid ISO weekday or integral weekday amount."
        (invalid-day-of-week-value condition))))
  (:documentation
    "Signaled by the DAY-OF-WEEK value APIs when a weekday keyword, ISO weekday number, or arithmetic amount is invalid."))

(define-condition invalid-month (cl-date-kit-error)
  ((value :initarg :value :reader invalid-month-value))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~S is not a valid ISO month keyword or number."
        (invalid-month-value condition))))
  (:documentation
    "Signaled by the MONTH value APIs when a month keyword, ISO month number,
or arithmetic amount is invalid."))

(define-condition invalid-year-month (cl-date-kit-error)
  ((year :initarg :year :reader invalid-year-month-year)
    (month :initarg :month :reader invalid-year-month-month))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~S-~S is not a valid proleptic-Gregorian year-month."
        (invalid-year-month-year condition)
        (invalid-year-month-month condition))))
  (:documentation
    "Signaled by MAKE-YEAR-MONTH when YEAR is not an integer or
MONTH is not an integer in the inclusive range 1 through 12."))

(define-condition invalid-year (cl-date-kit-error)
  ((value :initarg :value :reader invalid-year-value))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~S is not an integral proleptic-Gregorian year."
        (invalid-year-value condition))))
  (:documentation "Signaled by MAKE-YEAR when VALUE is not an integer."))

(define-condition invalid-month-day (cl-date-kit-error)
  ((month :initarg :month :reader invalid-month-day-month)
    (day :initarg :day :reader invalid-month-day-day))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~S-~S is not a valid month-day."
        (invalid-month-day-month condition)
        (invalid-month-day-day condition))))
  (:documentation
    "Signaled by MAKE-MONTH-DAY when MONTH and DAY do not name
a real month/day combination in a leap year.  February 29 is therefore valid."))

(define-condition invalid-time (cl-date-kit-error)
  ((hour :initarg :hour :reader invalid-time-hour)
    (minute :initarg :minute :reader invalid-time-minute)
    (second :initarg :second :reader invalid-time-second)
    (nanosecond :initarg :nanosecond :reader invalid-time-nanosecond))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~D:~D:~D.~9,'0D is not a valid time of day."
        (invalid-time-hour condition)
        (invalid-time-minute condition)
        (invalid-time-second condition)
        (invalid-time-nanosecond condition))))
  (:documentation
    "Signaled by MAKE-LOCAL-TIME when hour, minute, second, or
nanosecond falls outside its valid range (0-23, 0-59, 0-59, 0-999999999).
Leap seconds are not modeled, matching java.time, Temporal, Go time, and
Rust's time/chrono."))

(define-condition date-time-parse-error (cl-date-kit-error)
  ((string :initarg :string :reader date-time-parse-error-string)
    (expected :initarg :expected :reader date-time-parse-error-expected))
  (:report
    (lambda (condition stream)
      (format
        stream
        "Cannot parse ~S as ~A."
        (date-time-parse-error-string condition)
        (date-time-parse-error-expected condition))))
  (:documentation
    "Signaled by the PARSE-* functions in iso8601-date.lisp and iso8601.lisp when the
input string does not match the expected ISO-8601/RFC-3339 grammar."))

(define-condition date-time-format-error (cl-date-kit-error)
  ((pattern :initarg :pattern :reader date-time-format-error-pattern)
    (reason :initarg :reason :reader date-time-format-error-reason))
  (:report
    (lambda (condition stream)
      (format
        stream
        "Cannot format with pattern ~S: ~A."
        (date-time-format-error-pattern condition)
        (date-time-format-error-reason condition))))
  (:documentation
    "Signaled when a custom date-time pattern is invalid or
requires a field that its input value does not provide."))

(define-condition time-zone-not-found (cl-date-kit-error)
  ((name :initarg :name :reader time-zone-not-found-name))
  (:report
    (lambda (condition stream)
      (format
        stream
        "No time zone database entry for ~S. Searched TZDIR and /usr/share/zoneinfo."
        (time-zone-not-found-name condition))))
  (:documentation
    "Signaled by FIND-TIME-ZONE when no TZif file for the
requested IANA name (e.g. \"Asia/Tokyo\") exists under the TZDIR environment
variable or the default /usr/share/zoneinfo search path."))

(define-condition malformed-tzif (cl-date-kit-error)
  ((path :initarg :path :reader malformed-tzif-path)
    (reason :initarg :reason :reader malformed-tzif-reason))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~A is not a valid TZif file: ~A."
        (malformed-tzif-path condition)
        (malformed-tzif-reason condition))))
  (:documentation
    "Signaled while parsing a TZif file (RFC 8536) whose header, counts, data blocks, or POSIX footer are inconsistent with the format."))

(define-condition nonexistent-local-time (cl-date-kit-error)
  ((local-date-time
      :initarg
      :local-date-time
      :reader
      nonexistent-local-time-local-date-time)
    (zone :initarg :zone :reader nonexistent-local-time-zone))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~A does not exist in ~A: it falls in a daylight-saving-time gap."
        (nonexistent-local-time-local-date-time condition)
        (nonexistent-local-time-zone condition))))
  (:documentation
    "Signaled by RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION
:STRICT when the local date-time falls in a spring-forward gap, i.e. the wall
clock jumped past it and no offset makes it a real instant."))

(define-condition ambiguous-local-time (cl-date-kit-error)
  ((local-date-time
      :initarg
      :local-date-time
      :reader
      ambiguous-local-time-local-date-time)
    (zone :initarg :zone :reader ambiguous-local-time-zone)
    (earlier-offset
      :initarg
      :earlier-offset
      :reader
      ambiguous-local-time-earlier-offset)
    (later-offset :initarg :later-offset :reader ambiguous-local-time-later-offset))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~A is ambiguous in ~A: it occurs twice, at offset ~A and again at offset ~A."
        (ambiguous-local-time-local-date-time condition)
        (ambiguous-local-time-zone condition)
        (ambiguous-local-time-earlier-offset condition)
        (ambiguous-local-time-later-offset condition))))
  (:documentation
    "Signaled by RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION
:STRICT when the local date-time falls in a fall-back overlap, i.e. the wall
clock repeated it under two different offsets."))

(define-condition invalid-zoned-date-time-offset (cl-date-kit-error)
  ((local-date-time
      :initarg
      :local-date-time
      :reader
      invalid-zoned-date-time-offset-local-date-time)
    (offset :initarg :offset :reader invalid-zoned-date-time-offset-offset)
    (zone :initarg :zone :reader invalid-zoned-date-time-offset-zone))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~A at offset ~A is not valid in ~A."
        (invalid-zoned-date-time-offset-local-date-time condition)
        (invalid-zoned-date-time-offset-offset condition)
        (invalid-zoned-date-time-offset-zone condition))))
  (:documentation
    "Signaled by ZONED-DATE-TIME-OF-STRICT when OFFSET is not a valid
resolution of LOCAL-DATE-TIME in ZONE, including gaps and invalid overlap
offsets."))

(define-condition invalid-zone-offset (cl-date-kit-error)
  ((hours :initarg :hours :reader invalid-zone-offset-hours)
    (minutes :initarg :minutes :reader invalid-zone-offset-minutes)
    (seconds :initarg :seconds :reader invalid-zone-offset-seconds))
  (:report
    (lambda (condition stream)
      (format
        stream
        "~D:~D:~D is not a valid ISO-8601 UTC offset."
        (invalid-zone-offset-hours condition)
        (invalid-zone-offset-minutes condition)
        (invalid-zone-offset-seconds condition))))
  (:documentation
    "Signaled when a UTC offset has mixed signs, minute or second components outside 0-59, or a magnitude greater than 18:00."))

(define-condition invalid-interval (cl-date-kit-error)
  ((start :initarg :start :reader invalid-interval-start)
    (end :initarg :end :reader invalid-interval-end))
  (:report
    (lambda (condition stream)
      (format
        stream
        "An interval start ~S must not be after end ~S."
        (invalid-interval-start condition)
        (invalid-interval-end condition))))
  (:documentation "Signaled when an interval end precedes its start."))

(progn
  (define-condition invalid-duration-division (cl-date-kit-error)
    ((duration :initarg :duration :reader invalid-duration-division-duration)
      (divisor :initarg :divisor :reader invalid-duration-division-divisor))
    (:report
      (lambda (condition stream)
        (format
          stream
          "Cannot divide duration ~S by ~S."
          (invalid-duration-division-duration condition)
          (invalid-duration-division-divisor condition))))
    (:documentation "Signaled by DURATION-DIVIDED-BY when DIVISOR is zero."))
  (define-condition instant-precision-loss (cl-date-kit-error)
    ((instant :initarg :instant :reader instant-precision-loss-instant)
      (representation
        :initarg
        :representation
        :reader
        instant-precision-loss-representation))
    (:report
      (lambda (condition stream)
        (format
          stream
          "Cannot represent instant ~S as ~S without losing precision."
          (instant-precision-loss-instant condition)
          (instant-precision-loss-representation condition))))
    (:documentation
      "Signaled when converting an INSTANT would discard nonzero precision."))
  (define-condition invalid-rrule (cl-date-kit-error)
    ((reason :initarg :reason :reader invalid-rrule-reason)
      (value :initarg :value :reader invalid-rrule-value))
    (:report
      (lambda (condition stream)
        (format
          stream
          "Invalid RFC 5545 recurrence rule: ~A~@[ (~S)~]."
          (invalid-rrule-reason condition)
          (invalid-rrule-value condition))))
    (:documentation "Signaled when an RRULE or recurrence-set value is invalid.")))

(export
  (quote
    (invalid-duration-division
      invalid-duration-division-duration
      invalid-duration-division-divisor
      instant-precision-loss
      instant-precision-loss-instant
      instant-precision-loss-representation
      invalid-rrule
      invalid-rrule-reason
      invalid-rrule-value)))
