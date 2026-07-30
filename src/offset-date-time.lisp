;;;; src/offset-date-time.lisp
;;;;
;;;; OFFSET-DATE-TIME pairs a LOCAL-DATE-TIME with a fixed UTC offset.  Unlike
;;;; ZONED-DATE-TIME it carries no IANA zone rules, making it the direct model
;;;; for RFC 3339 timestamps and Java's OffsetDateTime.
(in-package #:cl-date-kit)

(defstruct (offset-date-time
    (:constructor %make-offset-date-time (local-date-time offset))) (local-date-time nil :type local-date-time :read-only t)
  (offset nil :type zone-offset :read-only t))

(defun make-offset-date-time (local-date-time offset)
  (check-type local-date-time local-date-time)
  (check-type offset zone-offset)
  (%make-offset-date-time local-date-time offset))

(defun local-date-time-at-offset (local-date-time offset)
  "Pairs LOCAL-DATE-TIME with the fixed ZONE-OFFSET."
  (make-offset-date-time local-date-time offset))

(defun offset-time-at-date (offset-time date)
  "Pairs OFFSET-TIME with DATE as an OFFSET-DATE-TIME."
  (make-offset-date-time
    (local-time-at-date (offset-time-local-time offset-time) date)
    (offset-time-offset offset-time)))

(defun offset-date-time-of (year
    month
    day
    hour
    minute
    second
    &optional
    (nanosecond 0)
    (offset (zone-offset-utc)))
  (make-offset-date-time
    (local-date-time-of year month day hour minute second nanosecond)
    offset))

(defun offset-date-time-of-instant (instant offset)
  (make-offset-date-time (local-date-time-of-instant instant offset) offset))

(defun offset-date-time-to-instant (offset-date-time) (local-date-time-to-instant (offset-date-time-local-date-time offset-date-time) (offset-date-time-offset offset-date-time)))


(defun offset-date-time-at-zone-same-instant (offset-date-time zone)
  "Re-expresses the OFFSET-DATE-TIME instant under ZONE rules."
  (zoned-date-time-of-instant
    (offset-date-time-to-instant offset-date-time)
    zone))


(defun offset-date-time-at-zone-similar-local (offset-date-time zone)
  "Resolves OFFSET-DATE-TIME local fields in ZONE, preferring its offset."
  (zoned-date-time-of-local
    (offset-date-time-local-date-time offset-date-time)
    zone
    :preferred-offset (offset-date-time-offset offset-date-time)))

(defun offset-date-time-of-epoch-second (epoch-second nanosecond offset) "Construct an OFFSET-DATE-TIME by applying fixed OFFSET to Unix epoch fields." (make-offset-date-time (local-date-time-of-epoch-second epoch-second nanosecond offset) offset))

(defun offset-date-time-to-epoch-second (offset-date-time) "Return the Unix epoch-second represented by OFFSET-DATE-TIME." (local-date-time-to-epoch-second (offset-date-time-local-date-time offset-date-time) (offset-date-time-offset offset-date-time)))

(defun offset-date-time-date (offset-date-time)
  (local-date-time-date (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-time (offset-date-time)
  (local-date-time-time (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-year (offset-date-time)
  (local-date-time-year (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-month (offset-date-time)
  (local-date-time-month (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-day (offset-date-time)
  (local-date-time-day (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-hour (offset-date-time)
  (local-date-time-hour (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-minute (offset-date-time)
  (local-date-time-minute (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-second (offset-date-time)
  (local-date-time-second (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-nanosecond (offset-date-time)
  (local-date-time-nanosecond (offset-date-time-local-date-time offset-date-time)))

(defun offset-date-time-with-year (offset-date-time year)
  "Returns OFFSET-DATE-TIME with YEAR, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-year (offset-date-time-local-date-time offset-date-time) year)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-month (offset-date-time month)
  "Returns OFFSET-DATE-TIME with MONTH, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-month (offset-date-time-local-date-time offset-date-time) month)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-day (offset-date-time day)
  "Returns OFFSET-DATE-TIME with DAY, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-day (offset-date-time-local-date-time offset-date-time) day)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-day-of-year (offset-date-time day-of-year)
  "Returns OFFSET-DATE-TIME with DAY-OF-YEAR, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-day-of-year
      (offset-date-time-local-date-time offset-date-time)
      day-of-year)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-hour (offset-date-time hour)
  "Returns OFFSET-DATE-TIME with HOUR, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-hour (offset-date-time-local-date-time offset-date-time) hour)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-minute (offset-date-time minute)
  "Returns OFFSET-DATE-TIME with MINUTE, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-minute (offset-date-time-local-date-time offset-date-time) minute)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-second (offset-date-time second)
  "Returns OFFSET-DATE-TIME with SECOND, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-second (offset-date-time-local-date-time offset-date-time) second)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-nanosecond (offset-date-time nanosecond)
  "Returns OFFSET-DATE-TIME with NANOSECOND, retaining its fixed offset."
  (make-offset-date-time
    (local-date-time-with-nanosecond
      (offset-date-time-local-date-time offset-date-time)
      nanosecond)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-with-offset-same-instant (offset-date-time offset)
  (offset-date-time-of-instant
    (offset-date-time-to-instant offset-date-time)
    offset))

(defun offset-date-time-with-offset-same-local (offset-date-time offset)
  (make-offset-date-time
    (offset-date-time-local-date-time offset-date-time)
    offset))

(defun offset-date-time-plus-nanos (offset-date-time nanos)
  "Return OFFSET-DATE-TIME advanced by signed NANOSECONDS."
  (make-offset-date-time
    (local-date-time-plus-nanos
      (offset-date-time-local-date-time offset-date-time)
      nanos)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-plus-micros (offset-date-time micros)
  "Return OFFSET-DATE-TIME advanced by signed MICROSECONDS."
  (make-offset-date-time
    (local-date-time-plus-micros
      (offset-date-time-local-date-time offset-date-time)
      micros)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-plus-millis (offset-date-time millis)
  "Return OFFSET-DATE-TIME advanced by signed MILLISECONDS."
  (make-offset-date-time
    (local-date-time-plus-millis
      (offset-date-time-local-date-time offset-date-time)
      millis)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-plus-seconds (offset-date-time seconds)
  "Return OFFSET-DATE-TIME advanced by signed SECONDS."
  (make-offset-date-time
    (local-date-time-plus-seconds
      (offset-date-time-local-date-time offset-date-time)
      seconds)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-plus-minutes (offset-date-time minutes)
  "Return OFFSET-DATE-TIME advanced by signed MINUTES."
  (make-offset-date-time
    (local-date-time-plus-minutes
      (offset-date-time-local-date-time offset-date-time)
      minutes)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-plus-hours (offset-date-time hours)
  "Return OFFSET-DATE-TIME advanced by signed HOURS."
  (make-offset-date-time
    (local-date-time-plus-hours
      (offset-date-time-local-date-time offset-date-time)
      hours)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-minus-nanos (offset-date-time nanos)
  "Return OFFSET-DATE-TIME moved backward by signed NANOSECONDS."
  (offset-date-time-plus-nanos offset-date-time (- nanos)))

(defun offset-date-time-minus-micros (offset-date-time micros)
  "Return OFFSET-DATE-TIME moved backward by signed MICROSECONDS."
  (offset-date-time-plus-micros offset-date-time (- micros)))

(defun offset-date-time-minus-millis (offset-date-time millis)
  "Return OFFSET-DATE-TIME moved backward by signed MILLISECONDS."
  (offset-date-time-plus-millis offset-date-time (- millis)))

(defun offset-date-time-minus-seconds (offset-date-time seconds)
  "Return OFFSET-DATE-TIME moved backward by signed SECONDS."
  (offset-date-time-plus-seconds offset-date-time (- seconds)))

(defun offset-date-time-minus-minutes (offset-date-time minutes)
  "Return OFFSET-DATE-TIME moved backward by signed MINUTES."
  (offset-date-time-plus-minutes offset-date-time (- minutes)))

(defun offset-date-time-minus-hours (offset-date-time hours)
  "Return OFFSET-DATE-TIME moved backward by signed HOURS."
  (offset-date-time-plus-hours offset-date-time (- hours)))

(defun offset-date-time-plus-duration (offset-date-time duration)
  (offset-date-time-of-instant
    (instant-plus-duration (offset-date-time-to-instant offset-date-time) duration)
    (offset-date-time-offset offset-date-time)))

(defun offset-date-time-minus-duration (offset-date-time duration)
  (offset-date-time-plus-duration offset-date-time (duration-negate duration)))

(defun offset-date-time-plus-period (offset-date-time period)
  (make-offset-date-time
    (local-date-time-plus-period
      (offset-date-time-local-date-time offset-date-time)
      period)
    (offset-date-time-offset offset-date-time)))



(progn
  (defun offset-date-time-plus-days (offset-date-time days)
    "Return OFFSET-DATE-TIME with DAYS added on its local calendar."
    (check-type days integer)
    (offset-date-time-plus-period offset-date-time (period-of-days days)))

  (defun offset-date-time-minus-days (offset-date-time days)
    "Return OFFSET-DATE-TIME with DAYS subtracted on its local calendar."
    (check-type days integer)
    (offset-date-time-plus-days offset-date-time (- days)))

  (defun offset-date-time-plus-weeks (offset-date-time weeks)
    "Return OFFSET-DATE-TIME with WEEKS added on its local calendar."
    (check-type weeks integer)
    (offset-date-time-plus-days offset-date-time (* weeks 7)))

  (defun offset-date-time-minus-weeks (offset-date-time weeks)
    "Return OFFSET-DATE-TIME with WEEKS subtracted on its local calendar."
    (check-type weeks integer)
    (offset-date-time-plus-weeks offset-date-time (- weeks)))

  (defun offset-date-time-plus-months (offset-date-time months)
    "Return OFFSET-DATE-TIME with MONTHS added on its local calendar."
    (check-type months integer)
    (offset-date-time-plus-period offset-date-time (period-of-months months)))

  (defun offset-date-time-minus-months (offset-date-time months)
    "Return OFFSET-DATE-TIME with MONTHS subtracted on its local calendar."
    (check-type months integer)
    (offset-date-time-plus-months offset-date-time (- months)))

  (defun offset-date-time-plus-years (offset-date-time years)
    "Return OFFSET-DATE-TIME with YEARS added on its local calendar."
    (check-type years integer)
    (offset-date-time-plus-period offset-date-time (period-of-years years)))

  (defun offset-date-time-minus-years (offset-date-time years)
    "Return OFFSET-DATE-TIME with YEARS subtracted on its local calendar."
    (check-type years integer)
    (offset-date-time-plus-years offset-date-time (- years)))

  (defmethod duration-between ((start offset-date-time) (end offset-date-time))
    (duration-between
      (offset-date-time-to-instant start)
      (offset-date-time-to-instant end))))

(defun offset-date-time-until (start end)
  "Returns the signed nanosecond-precision DURATION from START to END."
  (duration-between start end))

(defun offset-date-time-compare (a b)
  "Compares by absolute instant, independent of each value's fixed offset."
  (instant-compare
    (offset-date-time-to-instant a)
    (offset-date-time-to-instant b)))

(defun offset-date-time= (a b)
  (zerop (offset-date-time-compare a b)))

(defun offset-date-time< (a b)
  (minusp (offset-date-time-compare a b)))

(defun offset-date-time<= (a b)
  (not (plusp (offset-date-time-compare a b))))

(defun offset-date-time> (a b)
  (plusp (offset-date-time-compare a b)))

(defun offset-date-time>= (a b)
  (not (minusp (offset-date-time-compare a b))))

(defun offset-date-time-now (&key (offset (zone-offset-utc)) (clock (current-clock)))
  (offset-date-time-of-instant (clock-now clock) offset)) (progn (defun offset-date-time-truncated-to (offset-date-time unit) "Returns OFFSET-DATE-TIME with local time truncated down to fixed-width UNIT,\nretaining its offset.\n\nUNIT is one of :NANOS, :MICROS, :MILLIS, :SECONDS, :MINUTES, :HOURS, or\n:DAYS. Signals TYPE-ERROR when OFFSET-DATE-TIME or UNIT is unsupported." (check-type offset-date-time offset-date-time) (make-offset-date-time (local-date-time-truncated-to (offset-date-time-local-date-time offset-date-time) unit) (offset-date-time-offset offset-date-time))) (defun offset-date-time-rounded-to (offset-date-time unit &key (mode :half-even)) "Return OFFSET-DATE-TIME with its local time rounded to fixed-width UNIT.\n\nMODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO, :HALF-UP,\nor :HALF-EVEN (the default). The offset is retained, and rounding across\nmidnight carries into the adjacent local date." (check-type offset-date-time offset-date-time) (make-offset-date-time (local-date-time-rounded-to (offset-date-time-local-date-time offset-date-time) unit :mode mode) (offset-date-time-offset offset-date-time))))
