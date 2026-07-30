;;;; src/offset-time.lisp
;;;;
;;;; OFFSET-TIME pairs a LOCAL-TIME with a fixed UTC offset.  It intentionally
;;;; has no date, so it cannot identify an INSTANT by itself.
(in-package #:cl-date-kit)

(defstruct (offset-time (:constructor %make-offset-time (local-time offset))) (local-time nil :type local-time :read-only t)
  (offset nil :type zone-offset :read-only t))

(defun make-offset-time (local-time offset)
  (check-type local-time local-time)
  (check-type offset zone-offset)
  (%make-offset-time local-time offset))

(defun offset-time-of (hour minute second &optional (nanosecond 0) (offset (zone-offset-utc)))
  (make-offset-time (make-local-time hour minute second nanosecond) offset))

(defun offset-time-of-instant (instant offset)
  (make-offset-time
    (local-date-time-time (local-date-time-of-instant instant offset))
    offset))

(defun offset-time-time (offset-time)
  (offset-time-local-time offset-time))

(defun offset-time-hour (offset-time)
  (local-time-hour (offset-time-local-time offset-time)))

(defun offset-time-minute (offset-time)
  (local-time-minute (offset-time-local-time offset-time)))

(defun offset-time-second (offset-time)
  (local-time-second (offset-time-local-time offset-time)))

(defun offset-time-nanosecond (offset-time)
  (local-time-nanosecond (offset-time-local-time offset-time)))

(defun offset-time-with-hour (offset-time hour)
  "Returns OFFSET-TIME with HOUR, retaining its fixed offset."
  (make-offset-time
    (local-time-with-hour (offset-time-local-time offset-time) hour)
    (offset-time-offset offset-time)))

(defun offset-time-with-minute (offset-time minute)
  "Returns OFFSET-TIME with MINUTE, retaining its fixed offset."
  (make-offset-time
    (local-time-with-minute (offset-time-local-time offset-time) minute)
    (offset-time-offset offset-time)))

(defun offset-time-with-second (offset-time second)
  "Returns OFFSET-TIME with SECOND, retaining its fixed offset."
  (make-offset-time
    (local-time-with-second (offset-time-local-time offset-time) second)
    (offset-time-offset offset-time)))

(defun offset-time-with-nanosecond (offset-time nanosecond)
  "Returns OFFSET-TIME with NANOSECOND, retaining its fixed offset."
  (make-offset-time
    (local-time-with-nanosecond (offset-time-local-time offset-time) nanosecond)
    (offset-time-offset offset-time)))

(defun offset-time-with-offset-same-instant (offset-time offset)
  "Changes OFFSET while preserving the equivalent UTC time of day."
  (make-offset-time
    (local-time-plus-seconds
      (offset-time-local-time offset-time)
      (-
        (zone-offset-total-seconds offset)
        (zone-offset-total-seconds (offset-time-offset offset-time))))
    offset))

(defun offset-time-with-offset-same-local (offset-time offset)
  (make-offset-time (offset-time-local-time offset-time) offset))

(defun offset-time-plus-nanos (offset-time nanos)
  "Return OFFSET-TIME advanced by signed NANOSECONDS, wrapping within one day."
  (make-offset-time
    (local-time-plus-nanos (offset-time-local-time offset-time) nanos)
    (offset-time-offset offset-time)))

(defun offset-time-plus-micros (offset-time micros)
  "Return OFFSET-TIME advanced by signed MICROSECONDS, wrapping within one day."
  (make-offset-time
    (local-time-plus-micros (offset-time-local-time offset-time) micros)
    (offset-time-offset offset-time)))

(defun offset-time-plus-millis (offset-time millis)
  "Return OFFSET-TIME advanced by signed MILLISECONDS, wrapping within one day."
  (make-offset-time
    (local-time-plus-millis (offset-time-local-time offset-time) millis)
    (offset-time-offset offset-time)))

(defun offset-time-plus-seconds (offset-time seconds)
  "Return OFFSET-TIME advanced by signed SECONDS, wrapping within one day."
  (make-offset-time
    (local-time-plus-seconds (offset-time-local-time offset-time) seconds)
    (offset-time-offset offset-time)))

(defun offset-time-plus-minutes (offset-time minutes)
  "Return OFFSET-TIME advanced by signed MINUTES, wrapping within one day."
  (make-offset-time
    (local-time-plus-minutes (offset-time-local-time offset-time) minutes)
    (offset-time-offset offset-time)))

(defun offset-time-plus-hours (offset-time hours)
  "Return OFFSET-TIME advanced by signed HOURS, wrapping within one day."
  (make-offset-time
    (local-time-plus-hours (offset-time-local-time offset-time) hours)
    (offset-time-offset offset-time)))

(defun offset-time-minus-nanos (offset-time nanos)
  "Return OFFSET-TIME moved backward by signed NANOSECONDS, wrapping within one day."
  (offset-time-plus-nanos offset-time (- nanos)))

(defun offset-time-minus-micros (offset-time micros)
  "Return OFFSET-TIME moved backward by signed MICROSECONDS, wrapping within one day."
  (offset-time-plus-micros offset-time (- micros)))

(defun offset-time-minus-millis (offset-time millis)
  "Return OFFSET-TIME moved backward by signed MILLISECONDS, wrapping within one day."
  (offset-time-plus-millis offset-time (- millis)))

(defun offset-time-minus-seconds (offset-time seconds)
  "Return OFFSET-TIME moved backward by signed SECONDS, wrapping within one day."
  (offset-time-plus-seconds offset-time (- seconds)))

(defun offset-time-minus-minutes (offset-time minutes)
  "Return OFFSET-TIME moved backward by signed MINUTES, wrapping within one day."
  (offset-time-plus-minutes offset-time (- minutes)))

(defun offset-time-minus-hours (offset-time hours)
  "Return OFFSET-TIME moved backward by signed HOURS, wrapping within one day."
  (offset-time-plus-hours offset-time (- hours)))

(defun offset-time-plus-duration (offset-time duration)
  (make-offset-time
    (local-time-plus-nanos
      (offset-time-local-time offset-time)
      (duration-to-nanos duration))
    (offset-time-offset offset-time)))

(defun offset-time-minus-duration (offset-time duration)
  (offset-time-plus-duration offset-time (duration-negate duration)))

(defun %offset-time-utc-time (offset-time)
  (local-time-minus-seconds
    (offset-time-local-time offset-time)
    (zone-offset-total-seconds (offset-time-offset offset-time))))

(defun offset-time-compare (a b)
  "Orders by UTC time of day, then local time to retain a total ordering."
  (let ((utc-comparison
        (local-time-compare (%offset-time-utc-time a) (%offset-time-utc-time b))))
    (if (zerop utc-comparison) (local-time-compare (offset-time-local-time a) (offset-time-local-time b))
      utc-comparison)))

(defun offset-time= (a b)
  (zerop (offset-time-compare a b)))

(defun offset-time< (a b)
  (minusp (offset-time-compare a b)))

(defun offset-time<= (a b)
  (not (plusp (offset-time-compare a b))))

(defun offset-time> (a b)
  (plusp (offset-time-compare a b)))

(defun offset-time>= (a b)
  (not (minusp (offset-time-compare a b))))

(defmethod duration-between ((start offset-time) (end offset-time))
  (duration-between (%offset-time-utc-time start) (%offset-time-utc-time end)))

(defun offset-time-until (start end)
  "Returns the signed DURATION between START and END as UTC times of day.

Because OFFSET-TIME has no date, this does not cross a day boundary.  Two
values with equivalent UTC times of day therefore have a zero duration even
when OFFSET-TIME-COMPARE uses its local-time tie breaker."
  (duration-between start end))

(defun offset-time-now (&key (offset (zone-offset-utc)) (clock (current-clock)))
  (offset-time-of-instant (clock-now clock) offset)) (progn (defun offset-time-truncated-to (offset-time unit) "Returns OFFSET-TIME with its local time truncated down to fixed-width UNIT,\nretaining its offset.\n\nUNIT is one of :NANOS, :MICROS, :MILLIS, :SECONDS, :MINUTES, :HOURS, or\n:DAYS. Signals TYPE-ERROR when OFFSET-TIME or UNIT is unsupported." (check-type offset-time offset-time) (make-offset-time (local-time-truncated-to (offset-time-local-time offset-time) unit) (offset-time-offset offset-time))) (defun offset-time-rounded-to (offset-time unit &key (mode :half-even)) "Return OFFSET-TIME with its local time rounded to fixed-width UNIT.\n\nMODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO, :HALF-UP,\nor :HALF-EVEN (the default). The offset is retained and a result crossing\nmidnight wraps within the local day." (check-type offset-time offset-time) (make-offset-time (local-time-rounded-to (offset-time-local-time offset-time) unit :mode mode) (offset-time-offset offset-time))))
