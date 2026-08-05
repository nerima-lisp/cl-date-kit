;;;; src/duration.lisp
;;;;
;;;; DURATION is an exact elapsed time: java.time's Duration, Rust's
;;;; std::time::Duration (but signed, like java.time), Go's time.Duration.
;;;; Represented as SECONDS (any sign) plus NANOS, always normalized to
;;;; [0, 999999999] and added to SECONDS -- the same split java.time uses, so
;;;; that -0.5s reads as (SECONDS -1, NANOS 500000000).
(in-package #:cl-date-kit)

(defstruct (duration (:constructor %make-duration (seconds nanos))) (seconds 0 :type integer :read-only t)
  (nanos 0 :type (integer 0 999999999) :read-only t))

(defconstant +nanos-per-second+ 1000000000)

(defun %normalize-duration (seconds nanos)
  (multiple-value-bind (extra-seconds normalized-nanos) (floor nanos +nanos-per-second+)
    (%make-duration (+ seconds extra-seconds) normalized-nanos)))

(defun %duration-plus-components (duration seconds nanos)
  (%normalize-duration (+ (duration-seconds duration) seconds) (+ (duration-nanos duration) nanos)))

(defun duration-of-seconds (seconds &optional (nanos 0))
  "Build a duration from exact integral seconds and nanoseconds."
  (check-type seconds integer)
  (check-type nanos integer)
  (%normalize-duration seconds nanos))

(defun %duration-to-total-nanos (duration)
  "Return DURATION as an exact integral number of nanoseconds."
  (+ (* (duration-seconds duration) +nanos-per-second+) (duration-nanos duration)))

(defun duration-of-nanos (nanos)
  "Build a duration from an exact integral count of nanoseconds."
  (check-type nanos integer)
  (%normalize-duration 0 nanos))

(defun duration-of-millis (millis)
  "Build a duration from an exact integral count of milliseconds."
  (check-type millis integer)
  (duration-of-nanos (* millis 1000000)))

(defun duration-of-micros (micros)
  "Build a duration from an exact integral count of microseconds."
  (check-type micros integer)
  (duration-of-nanos (* micros 1000)))

(defun duration-of-minutes (minutes)
  "Build a duration from an exact integral count of minutes."
  (check-type minutes integer)
  (duration-of-seconds (* minutes 60)))

(defun duration-of-hours (hours)
  "Build a duration from an exact integral count of hours."
  (check-type hours integer)
  (duration-of-seconds (* hours 3600)))

(defun duration-of-days (days)
  "Build a duration from an exact integral count of fixed 24-hour days.

For daylight-saving-aware calendar days, use PERIOD-OF-DAYS."
  (check-type days integer)
  (duration-of-seconds (* days 86400)))

(defun duration-zero ()
  (%make-duration 0 0))

(defun duration-with-seconds (d seconds)
  "Return D with its normalized second field replaced by integral SECONDS."
  (check-type d duration)
  (check-type seconds integer)
  (%make-duration seconds (duration-nanos d)))

(defun duration-plus (a b)
  (%normalize-duration
    (+ (duration-seconds a) (duration-seconds b))
    (+ (duration-nanos a) (duration-nanos b))))

(defun duration-with-nanos (d nanos)
  "Return D with its normalized nanosecond field replaced by integral NANOS."
  (check-type d duration)
  (check-type nanos (integer 0 999999999))
  (%make-duration (duration-seconds d) nanos))

(define-fixed-unit-arithmetic
  duration-plus-nanos duration-minus-nanos nanos 0 1 %duration-plus-components
  :plus-documentation "Return D advanced by integral NANOSECONDS."
  :minus-documentation "Return D reduced by integral NANOSECONDS.")

(define-fixed-unit-arithmetic
  duration-plus-micros duration-minus-micros micros 0 1000 %duration-plus-components
  :plus-documentation "Return D advanced by integral MICROSECONDS."
  :minus-documentation "Return D reduced by integral MICROSECONDS.")

(define-fixed-unit-arithmetic
  duration-plus-millis duration-minus-millis millis 0 1000000 %duration-plus-components
  :plus-documentation "Return D advanced by integral MILLISECONDS."
  :minus-documentation "Return D reduced by integral MILLISECONDS.")

(define-fixed-unit-arithmetic
  duration-plus-seconds duration-minus-seconds seconds 1 0 %duration-plus-components
  :plus-documentation "Return D advanced by integral SECONDS."
  :minus-documentation "Return D reduced by integral SECONDS.")

(define-fixed-unit-arithmetic
  duration-plus-minutes duration-minus-minutes minutes 60 0 %duration-plus-components
  :plus-documentation "Return D advanced by integral MINUTES."
  :minus-documentation "Return D reduced by integral MINUTES.")

(define-fixed-unit-arithmetic
  duration-plus-hours duration-minus-hours hours 3600 0 %duration-plus-components
  :plus-documentation "Return D advanced by integral fixed-width HOURS."
  :minus-documentation "Return D reduced by integral fixed-width HOURS.")

(define-fixed-unit-arithmetic
  duration-plus-days duration-minus-days days 86400 0 %duration-plus-components
  :plus-documentation "Return D advanced by integral fixed 24-hour DAYS."
  :minus-documentation "Return D reduced by integral fixed 24-hour DAYS.")

(defun duration-negate (d)
  (%normalize-duration (- (duration-seconds d)) (- (duration-nanos d))))

(defun duration-minus (a b)
  (%normalize-duration
   (- (duration-seconds a) (duration-seconds b))
   (- (duration-nanos a) (duration-nanos b))))

(defun duration-abs (d)
  (if (duration-negative-p d) (duration-negate d)
    d))

(defun duration-zero-p (d)
  (and (zerop (duration-seconds d)) (zerop (duration-nanos d))))

(defun duration-negative-p (d)
  (minusp (duration-seconds d)))

(defun duration-positive-p (d)
  (not (or (duration-negative-p d) (duration-zero-p d))))

(defun %duration-to-whole-units (d unit-nanos)
  (truncate (%duration-to-total-nanos d) unit-nanos))

(defun duration-to-seconds (d)
  "The exact elapsed time in seconds, as a rational."
  (/ (%duration-to-total-nanos d) +nanos-per-second+))

(defun duration-to-nanos (d)
  "The exact elapsed time in nanoseconds."
  (%duration-to-total-nanos d))

(defun duration-to-millis (d)
  "Whole milliseconds in D, truncating a fractional millisecond toward zero."
  (%duration-to-whole-units d 1000000))

(defun duration-to-micros (d)
  "Whole microseconds in D, truncating a fractional microsecond toward zero."
  (%duration-to-whole-units d 1000))

(defun duration-to-minutes (d)
  "Whole minutes in D, truncating a fractional minute toward zero."
  (%duration-to-whole-units d (* 60 +nanos-per-second+)))

(defun duration-to-hours (d)
  "Whole hours in D, truncating a fractional hour toward zero."
  (%duration-to-whole-units d (* 3600 +nanos-per-second+)))

(defun duration-to-days (d)
  "Whole fixed 24-hour days in D, truncating a fractional day toward zero."
  (%duration-to-whole-units d (* 86400 +nanos-per-second+)))

(defun duration-to-days-part (d)
  "Whole fixed 24-hour days in D, truncating a fractional day toward zero."
  (duration-to-days d))

(defmacro define-duration-remainder-part (name whole-unit-function modulus documentation)
  "Define NAME as the signed remainder of (WHOLE-UNIT-FUNCTION D) modulo MODULUS."
  `(defun ,name (d)
     ,documentation
     (rem (,whole-unit-function d) ,modulus)))

(define-duration-remainder-part duration-to-hours-part duration-to-hours 24
  "The signed hour remainder in D after whole fixed days.")

(define-duration-remainder-part duration-to-minutes-part duration-to-minutes 60
  "The signed minute remainder in D after whole hours.")

(define-duration-remainder-part duration-to-seconds-part duration-seconds 60
  "The signed whole-second remainder in D after whole minutes.")

(defmacro define-duration-nanos-part (name divisor documentation)
  "Define NAME as D's normalized nanosecond field truncated by DIVISOR."
  `(defun ,name (d)
     ,documentation
     (truncate (duration-nanos d) ,divisor)))

(define-duration-nanos-part duration-to-millis-part 1000000
  "The non-negative millisecond part of D's normalized nanosecond field.")

(define-duration-nanos-part duration-to-micros-part 1000
  "The non-negative microsecond part of D's normalized nanosecond field.")

(define-duration-nanos-part duration-to-nanos-part 1
  "The non-negative nanosecond part of D's normalized representation.")

(progn
  (defun %duration-truncated-to-unit (duration unit-nanos)
  "Truncate normalized DURATION toward zero without composing epoch nanos."
  (let ((seconds (duration-seconds duration))
        (nanos (duration-nanos duration)))
    (if (<= unit-nanos +nanos-per-second+)
        (if (minusp seconds)
            (if (zerop nanos)
                (%make-duration seconds 0)
                (let ((whole-seconds (1- (- seconds)))
                      (magnitude-nanos (- +nanos-per-second+ nanos)))
                  (%normalize-duration
                   (- whole-seconds)
                   (- (* (floor magnitude-nanos unit-nanos) unit-nanos)))))
            (%make-duration
             seconds
             (* (floor nanos unit-nanos) unit-nanos)))
        (let ((seconds-per-unit (truncate unit-nanos +nanos-per-second+)))
          (%make-duration
           (* (truncate seconds seconds-per-unit) seconds-per-unit)
           0)))))

(defun duration-truncated-to (d unit)
  "Return D truncated toward zero to fixed-width UNIT.

UNIT is one of :NANOS, :MICROS, :MILLIS, :SECONDS, :MINUTES, :HOURS,
or :DAYS.  Calendar-sized units are intentionally rejected."
  (check-type d duration)
  (%duration-truncated-to-unit d (%fixed-unit-nanos unit)))

  (defun duration-rounded-to (d unit &key (mode :half-even))
    "Return D rounded to fixed-width UNIT using MODE.

MODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO,
:HALF-UP, or :HALF-EVEN.  :HALF-EVEN is the default."
    (check-type d duration)
    (duration-of-nanos
     (%round-fixed-unit-nanos (%duration-to-total-nanos d)
                              (%fixed-unit-nanos unit)
                              mode))))

(defun duration-multiplied-by (d factor)
  "Return D scaled by integral FACTOR without losing nanosecond precision."
  (check-type factor integer)
  (duration-of-nanos (* (%duration-to-total-nanos d) factor)))

(defun duration-divided-by (d divisor)
  "Return D divided by integral DIVISOR, truncating nanos toward zero."
  (check-type divisor integer)
  (when (zerop divisor)
    (error (quote invalid-duration-division) :duration d :divisor divisor))
  (duration-of-nanos (truncate (%duration-to-total-nanos d) divisor)))

(defun duration-compare (a b)
  "-1, 0, or 1 as A is less than, equal to, or greater than B."
  (cond
    ((< (duration-seconds a) (duration-seconds b)) -1)
    ((> (duration-seconds a) (duration-seconds b)) 1)
    ((< (duration-nanos a) (duration-nanos b)) -1)
    ((> (duration-nanos a) (duration-nanos b)) 1)
    (t 0)))

(define-ordering-operators duration duration-compare)

(defgeneric duration-between (start end)
  (:documentation
    "Return the signed exact DURATION from START to END.

Methods are provided for matching INSTANT, LOCAL-TIME, LOCAL-DATE-TIME,
OFFSET-TIME, OFFSET-DATE-TIME, and ZONED-DATE-TIME values. Local values use
their local timeline; offset and zoned values use the absolute timeline."))

(defparameter *duration-rounding-modes*
  '(:floor :ceiling :toward-zero :away-from-zero :half-up :half-even)
  "Valid MODE values accepted by DURATION-ROUNDED-TO.")

(progn
  (defun %round-fixed-unit-nanos (total-nanos unit-nanos mode)
    (check-type total-nanos integer)
    (check-type unit-nanos (integer 1))
    (unless (member mode *duration-rounding-modes*)
      (error (quote type-error)
             :datum mode
             :expected-type
             (cons 'member *duration-rounding-modes*)))
    (multiple-value-bind (floor-quotient remainder)
        (floor total-nanos unit-nanos)
      (let ((ceiling-quotient (if (zerop remainder)
                                  floor-quotient
                                  (1+ floor-quotient))))
        (* (case mode
             (:floor floor-quotient)
             (:ceiling ceiling-quotient)
             (:toward-zero (if (minusp total-nanos)
                               ceiling-quotient
                               floor-quotient))
             (:away-from-zero (if (minusp total-nanos)
                                  floor-quotient
                                  ceiling-quotient))
             (:half-up
              (cond
                ((< (* 2 remainder) unit-nanos) floor-quotient)
                ((> (* 2 remainder) unit-nanos) ceiling-quotient)
                ((minusp total-nanos) floor-quotient)
                (t ceiling-quotient)))
             (:half-even
              (cond
                ((< (* 2 remainder) unit-nanos) floor-quotient)
                ((> (* 2 remainder) unit-nanos) ceiling-quotient)
                ((evenp floor-quotient) floor-quotient)
                (t ceiling-quotient))))
           unit-nanos))))

  (defun %fixed-unit-nanos (unit)
    "Returns the nanosecond width of supported fixed truncation UNIT."
    (case unit
      (:nanos 1)
      (:micros 1000)
      (:millis 1000000)
      (:seconds +nanos-per-second+)
      (:minutes (* 60 +nanos-per-second+))
      (:hours (* 60 60 +nanos-per-second+))
      (:days (* 24 60 60 +nanos-per-second+))
      (otherwise
        (error (quote type-error)
               :datum unit
               :expected-type
               (quote (member :nanos :micros :millis :seconds :minutes :hours :days)))))))
