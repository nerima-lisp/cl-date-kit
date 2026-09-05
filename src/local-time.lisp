(in-package #:cl-date-kit)

(defconstant +seconds-per-day+ 86400)

(defstruct (local-time (:constructor %make-local-time (hour minute second nanosecond))) (hour 0 :type (integer 0 23) :read-only t)
  (minute 0 :type (integer 0 59) :read-only t)
  (second 0 :type (integer 0 59) :read-only t)
  (nanosecond 0 :type (integer 0 999999999) :read-only t))

(defun make-local-time (hour minute second &optional (nanosecond 0))
  (unless (and
      (integerp hour)
      (integerp minute)
      (integerp second)
      (integerp nanosecond)
      (<= 0 hour 23)
      (<= 0 minute 59)
      (<= 0 second 59)
      (<= 0 nanosecond 999999999))
    (error
      (quote invalid-time)
      :hour
      hour
      :minute
      minute
      :second
      second
      :nanosecond
      nanosecond))
  (%make-local-time hour minute second nanosecond))

(defun local-time-of (hour minute second &optional (nanosecond 0))
  "Construct a LOCAL-TIME from wall-clock fields."
  (make-local-time hour minute second nanosecond))

(defun local-time-midnight ()
  (%make-local-time 0 0 0 0))

(defun local-time-noon ()
  (%make-local-time 12 0 0 0))

(defun local-time-to-second-of-day (time)
  (+
    (* (local-time-hour time) 3600)
    (* (local-time-minute time) 60)
    (local-time-second time)))

(defun local-time-to-nano-of-day (time)
  "Returns TIME's nanosecond offset from the start of its day."
  (+
    (* (local-time-to-second-of-day time) +nanos-per-second+)
    (local-time-nanosecond time)))

(defun local-time-of-second-of-day (second-of-day &optional (nanosecond 0))
  (unless (and
      (integerp second-of-day)
      (<= 0 second-of-day (1- +seconds-per-day+))
      (integerp nanosecond)
      (<= 0 nanosecond (1- +nanos-per-second+)))
    (error
      (quote invalid-time)
      :hour
      0
      :minute
      0
      :second
      second-of-day
      :nanosecond
      nanosecond))
  (multiple-value-bind (hour remainder) (floor second-of-day 3600)
    (multiple-value-bind (minute second) (floor remainder 60)
      (make-local-time hour minute second nanosecond))))

(defun local-time-of-nano-of-day (nano-of-day)
  "Constructs a LOCAL-TIME from its nanosecond offset within one day."
  (unless (and
      (integerp nano-of-day)
      (<= 0 nano-of-day (1- (* +seconds-per-day+ +nanos-per-second+))))
    (error 'invalid-time :hour 0 :minute 0 :second 0 :nanosecond nano-of-day))
  (multiple-value-bind (second-of-day nanosecond) (floor nano-of-day +nanos-per-second+)
    (local-time-of-second-of-day second-of-day nanosecond)))

(defun local-time-at-date (time date)
  "Combines TIME and DATE into a LOCAL-DATE-TIME."
  (make-local-date-time date time))

(defun local-time-at-offset (local-time offset)
  "Combines LOCAL-TIME and OFFSET into an OFFSET-TIME."
  (make-offset-time local-time offset))

(defun %local-time-plus-nanos-total (time delta-nanos)
  "Adds DELTA-NANOS nanoseconds to TIME, wrapping around midnight (LOCAL-TIME
arithmetic never carries into a date)."
  (let* ((total-nanos
        (+
          (* (local-time-to-second-of-day time) +nanos-per-second+)
          (local-time-nanosecond time)))
         (day-nanos (* +seconds-per-day+ +nanos-per-second+))
         (wrapped (mod (+ total-nanos delta-nanos) day-nanos)))
    (multiple-value-bind (second-of-day nanosecond) (floor wrapped +nanos-per-second+)
      (local-time-of-second-of-day second-of-day nanosecond))))

(defun %local-time-plus-components (time seconds nanos)
  (%local-time-plus-nanos-total time (+ (* seconds +nanos-per-second+) nanos)))

(define-fixed-unit-arithmetic
  local-time-plus-nanos
  local-time-minus-nanos
  n
  0
  1
  %local-time-plus-components)

(define-fixed-unit-arithmetic
  local-time-plus-micros
  local-time-minus-micros
  n
  0
  1000
  %local-time-plus-components)

(define-fixed-unit-arithmetic
  local-time-plus-millis
  local-time-minus-millis
  n
  0
  1000000
  %local-time-plus-components)

(define-fixed-unit-arithmetic
  local-time-plus-seconds
  local-time-minus-seconds
  n
  1
  0
  %local-time-plus-components)

(define-fixed-unit-arithmetic
  local-time-plus-minutes
  local-time-minus-minutes
  n
  60
  0
  %local-time-plus-components)

(define-fixed-unit-arithmetic
  local-time-plus-hours
  local-time-minus-hours
  n
  3600
  0
  %local-time-plus-components)

(defmethod duration-between ((start local-time) (end local-time))
  (duration-of-nanos
    (- (local-time-to-nano-of-day end) (local-time-to-nano-of-day start))))

(defun local-time-until (start end)
  "Returns the signed nanosecond-precision DURATION from START to END."
  (duration-between start end))

(defun local-time-compare (a b)
  (let ((delta
        (-
          (+
            (* (local-time-to-second-of-day a) +nanos-per-second+)
            (local-time-nanosecond a))
          (+
            (* (local-time-to-second-of-day b) +nanos-per-second+)
            (local-time-nanosecond b)))))
    (cond
      ((minusp delta) -1)
      ((plusp delta) 1)
      (t 0))))

(define-ordering-operators local-time local-time-compare)

(defun local-time-with-hour (time hour)
  "Returns TIME with HOUR."
  (make-local-time
    hour
    (local-time-minute time)
    (local-time-second time)
    (local-time-nanosecond time)))

(defun local-time-with-minute (time minute)
  "Returns TIME with MINUTE."
  (make-local-time
    (local-time-hour time)
    minute
    (local-time-second time)
    (local-time-nanosecond time)))

(defun local-time-with-second (time second)
  "Returns TIME with SECOND."
  (make-local-time
    (local-time-hour time)
    (local-time-minute time)
    second
    (local-time-nanosecond time)))

(defun local-time-with-nanosecond (time nanosecond)
  "Returns TIME with NANOSECOND."
  (make-local-time
    (local-time-hour time)
    (local-time-minute time)
    (local-time-second time)
    nanosecond))

(progn
  (defun local-time-truncated-to (time unit)
    "Returns TIME truncated down to fixed-width UNIT.

UNIT is one of :NANOS, :MICROS, :MILLIS, :SECONDS, :MINUTES, :HOURS, or
:DAYS. Signals TYPE-ERROR when TIME or UNIT is unsupported."
    (check-type time local-time)
    (let ((unit-nanos (%fixed-unit-nanos unit)))
      (local-time-of-nano-of-day
        (* (floor (local-time-to-nano-of-day time) unit-nanos) unit-nanos))))
  (defun local-time-rounded-to (time unit &key (mode :half-even))
    "Return TIME rounded to fixed-width UNIT, modulo one local day.

MODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO, :HALF-UP,
or :HALF-EVEN (the default). Upward results that cross midnight wrap to the
start of the local day."
    (check-type time local-time)
    (let* ((unit-nanos (%fixed-unit-nanos unit))
           (day-nanos (* +seconds-per-day+ +nanos-per-second+))
           (rounded-nanos
          (%round-fixed-unit-nanos (local-time-to-nano-of-day time) unit-nanos mode)))
      (local-time-of-nano-of-day (mod rounded-nanos day-nanos)))))
