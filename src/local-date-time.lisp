;;;; src/local-date-time.lisp
;;;;
;;;; LOCAL-DATE-TIME pairs a LOCAL-DATE with a LOCAL-TIME: java.time's
;;;; LocalDateTime, Temporal's PlainDateTime. Still no zone -- arithmetic that
;;;; crosses midnight carries into the date, unlike LOCAL-TIME alone.
(in-package #:cl-date-kit)

(defstruct (local-date-time (:constructor %make-local-date-time (date time))) (date nil :type local-date :read-only t)
  (time nil :type local-time :read-only t))

(defun make-local-date-time (date time)
  (check-type date local-date)
  (check-type time local-time)
  (%make-local-date-time date time))

(defun local-date-time-of (year month day hour minute second &optional (nanosecond 0))
  (make-local-date-time
    (make-local-date year month day)
    (make-local-time hour minute second nanosecond)))

(defun local-date-time-year (dt)
  (local-date-year (local-date-time-date dt)))

(defun local-date-time-month (dt)
  (local-date-month (local-date-time-date dt)))

(defun local-date-time-day (dt)
  (local-date-day (local-date-time-date dt)))

(defun local-date-time-hour (dt)
  (local-time-hour (local-date-time-time dt)))

(defun local-date-time-minute (dt)
  (local-time-minute (local-date-time-time dt)))

(defun local-date-time-second (dt)
  (local-time-second (local-date-time-time dt)))

(defun local-date-time-nanosecond (dt)
  (local-time-nanosecond (local-date-time-time dt)))

(defun local-date-time-plus-days (dt n)
  (%make-local-date-time
    (local-date-plus-days (local-date-time-date dt) n)
    (local-date-time-time dt)))

(defun local-date-time-minus-days (dt n)
  (local-date-time-plus-days dt (- n)))

(defun local-date-time-plus-weeks (dt n)
  (local-date-time-plus-days dt (* n 7)))

(defun local-date-time-minus-weeks (dt n)
  (local-date-time-plus-days dt (* n -7)))

(defun local-date-time-plus-months (dt n)
  (%make-local-date-time
    (local-date-plus-months (local-date-time-date dt) n)
    (local-date-time-time dt)))

(defun local-date-time-minus-months (dt n)
  (local-date-time-plus-months dt (- n)))

(defun local-date-time-plus-years (dt n)
  (local-date-time-plus-months dt (* n 12)))

(defun local-date-time-minus-years (dt n)
  (local-date-time-plus-months dt (* n -12)))

(defun %local-date-time-plus-components (date-time seconds nanos)
  "Adds signed second and nanosecond components in one calendar carry pass."
  (let ((time (local-date-time-time date-time)))
    (multiple-value-bind (second-carry normalized-nanos)
        (floor (+ (local-time-nanosecond time) nanos) +nanos-per-second+)
      (multiple-value-bind (day-delta second-of-day)
          (floor
           (+ (local-time-to-second-of-day time) seconds second-carry)
           +seconds-per-day+)
        (%make-local-date-time
         (local-date-plus-days (local-date-time-date date-time) day-delta)
         (local-time-of-second-of-day second-of-day normalized-nanos))))))

(defmacro define-local-date-time-fixed-unit-arithmetic
    (plus-name minus-name seconds-factor nanos-factor)
  `(progn
     (defun ,plus-name (date-time amount)
       (check-type amount integer)
       (%local-date-time-plus-components
        date-time
        (* amount ,seconds-factor)
        (* amount ,nanos-factor)))
     (defun ,minus-name (date-time amount)
       (check-type amount integer)
       (%local-date-time-plus-components
        date-time
        (* (- amount) ,seconds-factor)
        (* (- amount) ,nanos-factor)))))

(define-local-date-time-fixed-unit-arithmetic
    local-date-time-plus-nanos local-date-time-minus-nanos 0 1)
(define-local-date-time-fixed-unit-arithmetic
    local-date-time-plus-micros local-date-time-minus-micros 0 1000)
(define-local-date-time-fixed-unit-arithmetic
    local-date-time-plus-millis local-date-time-minus-millis 0 1000000)
(define-local-date-time-fixed-unit-arithmetic
    local-date-time-plus-seconds local-date-time-minus-seconds 1 0)
(define-local-date-time-fixed-unit-arithmetic
    local-date-time-plus-minutes local-date-time-minus-minutes 60 0)
(define-local-date-time-fixed-unit-arithmetic
    local-date-time-plus-hours local-date-time-minus-hours 3600 0)

(defun local-date-time-plus-duration (dt d)
  (%local-date-time-plus-components
   dt
   (duration-seconds d)
   (duration-nanos d)))

(defun local-date-time-minus-duration (dt d)
  (%local-date-time-plus-components
   dt
   (- (duration-seconds d))
   (- (duration-nanos d))))

(defun local-date-time-plus-period (dt p)
  (%make-local-date-time
    (local-date-plus-period (local-date-time-date dt) p)
    (local-date-time-time dt)))

(defun local-date-time-minus-period (dt p)
  (%make-local-date-time
    (local-date-minus-period (local-date-time-date dt) p)
    (local-date-time-time dt)))

(defmethod duration-between ((start local-date-time) (end local-date-time))
  (flet ((timeline-nanos (date-time)
           (+ (* (local-date-to-epoch-day (local-date-time-date date-time))
                 +seconds-per-day+
                 +nanos-per-second+)
              (local-time-to-nano-of-day (local-date-time-time date-time)))))
    (duration-of-nanos
     (- (timeline-nanos end) (timeline-nanos start)))))

(defun local-date-time-until (start end)
  "Returns the signed nanosecond-precision DURATION from START to END on the local timeline."
  (duration-between start end))(defun local-date-time-compare (a b)
  (let ((date-cmp
        (local-date-compare (local-date-time-date a) (local-date-time-date b))))
    (if (zerop date-cmp) (local-time-compare (local-date-time-time a) (local-date-time-time b))
      date-cmp)))

(defun local-date-time= (a b)
  (zerop (local-date-time-compare a b)))

(defun local-date-time< (a b)
  (minusp (local-date-time-compare a b)))

(defun local-date-time<= (a b)
  (not (plusp (local-date-time-compare a b))))

(defun local-date-time> (a b)
  (plusp (local-date-time-compare a b)))

(defun local-date-time>= (a b)
  (not (minusp (local-date-time-compare a b))))

(defun local-date-time-with-year (date-time year)
  "Returns DATE-TIME with YEAR, preserving its local time."
  (%make-local-date-time
    (local-date-with-year (local-date-time-date date-time) year)
    (local-date-time-time date-time)))

(defun local-date-time-with-month (date-time month)
  "Returns DATE-TIME with MONTH, preserving its local time."
  (%make-local-date-time
    (local-date-with-month (local-date-time-date date-time) month)
    (local-date-time-time date-time)))

(defun local-date-time-with-day (date-time day)
  "Returns DATE-TIME with DAY, preserving its local time."
  (%make-local-date-time
    (local-date-with-day (local-date-time-date date-time) day)
    (local-date-time-time date-time)))

(defun local-date-time-with-day-of-year (date-time day-of-year)
  "Returns DATE-TIME with DAY-OF-YEAR, preserving its local time."
  (%make-local-date-time
    (local-date-with-day-of-year (local-date-time-date date-time) day-of-year)
    (local-date-time-time date-time)))

(defun local-date-time-with-hour (date-time hour)
  "Returns DATE-TIME with HOUR, preserving its local date."
  (%make-local-date-time
    (local-date-time-date date-time)
    (local-time-with-hour (local-date-time-time date-time) hour)))

(defun local-date-time-with-minute (date-time minute)
  "Returns DATE-TIME with MINUTE, preserving its local date."
  (%make-local-date-time
    (local-date-time-date date-time)
    (local-time-with-minute (local-date-time-time date-time) minute)))

(defun local-date-time-with-second (date-time second)
  "Returns DATE-TIME with SECOND, preserving its local date."
  (%make-local-date-time
    (local-date-time-date date-time)
    (local-time-with-second (local-date-time-time date-time) second)))

(defun local-date-time-with-nanosecond (date-time nanosecond)
  "Returns DATE-TIME with NANOSECOND, preserving its local date."
  (%make-local-date-time
    (local-date-time-date date-time)
    (local-time-with-nanosecond (local-date-time-time date-time) nanosecond))) (progn (defun local-date-time-truncated-to (date-time unit) "Returns DATE-TIME with its local time truncated down to fixed-width UNIT.\n\nUNIT is one of :NANOS, :MICROS, :MILLIS, :SECONDS, :MINUTES, :HOURS, or\n:DAYS. Signals TYPE-ERROR when DATE-TIME or UNIT is unsupported." (check-type date-time local-date-time) (%make-local-date-time (local-date-time-date date-time) (local-time-truncated-to (local-date-time-time date-time) unit))) (defun local-date-time-rounded-to (date-time unit &key (mode :half-even)) "Return DATE-TIME with its local time rounded to fixed-width UNIT.\n\nMODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO, :HALF-UP,\nor :HALF-EVEN (the default). Rounding that crosses midnight carries into the\nadjacent local date." (check-type date-time local-date-time) (let* ((time-nanos (local-time-to-nano-of-day (local-date-time-time date-time))) (rounded-nanos (%round-fixed-unit-nanos time-nanos (%fixed-unit-nanos unit) mode))) (%local-date-time-plus-components date-time 0 (- rounded-nanos time-nanos)))))
