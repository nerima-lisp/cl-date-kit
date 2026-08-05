;;;; ZONED-DATE-TIME arithmetic, comparison, adjustment (truncation/rounding),
;;;; and NOW constructors.
;;;;
;;;; The four -NOW constructors (ZONED-DATE-TIME-NOW, LOCAL-DATE-TIME-NOW,
;;;; LOCAL-TIME-NOW, LOCAL-DATE-NOW) build OTHER types but live here because
;;;; they depend on ZONE-OFFSET-UTC/CURRENT-CLOCK/ZONED-DATE-TIME-OF-INSTANT,
;;;; which are only available this late in the load order.
(in-package #:cl-date-kit)

(defun zoned-date-time-plus-duration (zoned-date-time d)
  (zoned-date-time-of-instant
    (instant-plus-duration (zoned-date-time-to-instant zoned-date-time) d)
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-minus-duration (zoned-date-time d)
  (zoned-date-time-plus-duration zoned-date-time (duration-negate d)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro define-zoned-date-time-timeline-unit (unit instant-operation unit-description)
    (let* ((unit-name (symbol-name unit))
           (plus-name (intern (format nil "ZONED-DATE-TIME-PLUS-~A" unit-name)))
           (minus-name (intern (format nil "ZONED-DATE-TIME-MINUS-~A" unit-name))))
      `(progn
        (defun ,plus-name (zoned-date-time ,unit)
          ,(format
            nil
            "Return ZONED-DATE-TIME advanced by signed ~A on the absolute timeline."
            unit-description)
          (zoned-date-time-of-instant
            (,instant-operation (zoned-date-time-to-instant zoned-date-time) ,unit)
            (zoned-date-time-zone zoned-date-time)))
        (defun ,minus-name (zoned-date-time ,unit)
          (,plus-name zoned-date-time (- ,unit)))))))

(progn
  (define-zoned-date-time-timeline-unit nanos instant-plus-nanos "NANOSECONDS")
  (define-zoned-date-time-timeline-unit micros instant-plus-micros "MICROSECONDS")
  (define-zoned-date-time-timeline-unit millis instant-plus-millis "MILLISECONDS")
  (define-zoned-date-time-timeline-unit seconds instant-plus-seconds "SECONDS")
  (define-zoned-date-time-timeline-unit minutes instant-plus-minutes "MINUTES")
  (define-zoned-date-time-timeline-unit hours instant-plus-hours "HOURS"))

(defun zoned-date-time-plus-period (zoned-date-time period)
  "Adjusts local fields by PERIOD while retaining this value's offset when it
remains valid in the target local time."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-plus-period (zoned-date-time-local zoned-date-time) period)))

(defun zoned-date-time-plus-days (zoned-date-time days)
  "Return ZONED-DATE-TIME with DAYS added on its local calendar."
  (check-type days integer)
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-plus-days (zoned-date-time-local zoned-date-time) days)))

(defun zoned-date-time-minus-days (zoned-date-time days)
  "Return ZONED-DATE-TIME with DAYS subtracted on its local calendar."
  (zoned-date-time-plus-days zoned-date-time (- days)))

(defun zoned-date-time-plus-weeks (zoned-date-time weeks)
  "Return ZONED-DATE-TIME with WEEKS added on its local calendar."
  (check-type weeks integer)
  (zoned-date-time-plus-days zoned-date-time (* weeks 7)))

(defun zoned-date-time-minus-weeks (zoned-date-time weeks)
  "Return ZONED-DATE-TIME with WEEKS subtracted on its local calendar."
  (zoned-date-time-plus-weeks zoned-date-time (- weeks)))

(defun zoned-date-time-plus-months (zoned-date-time months)
  "Return ZONED-DATE-TIME with MONTHS added on its local calendar."
  (check-type months integer)
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-plus-months (zoned-date-time-local zoned-date-time) months)))

(defun zoned-date-time-minus-months (zoned-date-time months)
  "Return ZONED-DATE-TIME with MONTHS subtracted on its local calendar."
  (zoned-date-time-plus-months zoned-date-time (- months)))

(defun zoned-date-time-plus-years (zoned-date-time years)
  "Return ZONED-DATE-TIME with YEARS added on its local calendar."
  (check-type years integer)
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-plus-years (zoned-date-time-local zoned-date-time) years)))

(defun zoned-date-time-minus-years (zoned-date-time years)
  "Return ZONED-DATE-TIME with YEARS subtracted on its local calendar."
  (zoned-date-time-plus-years zoned-date-time (- years)))

(defun zoned-date-time-minus-period (zoned-date-time p)
  (zoned-date-time-plus-period zoned-date-time (period-negate p)))

(defmethod duration-between ((start zoned-date-time) (end zoned-date-time))
  (duration-between
    (zoned-date-time-to-instant start)
    (zoned-date-time-to-instant end)))

(defun zoned-date-time-until (start end)
  "Returns the signed nanosecond-precision DURATION from START to END."
  (duration-between start end))

(defun zoned-date-time-compare (a b)
  "Compares by absolute instant. Two ZONED-DATE-TIMEs in different zones that
name the same instant compare equal."
  (instant-compare (zoned-date-time-to-instant a) (zoned-date-time-to-instant b)))

(define-ordering-operators zoned-date-time zoned-date-time-compare)

(defun zoned-date-time-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  (zoned-date-time-of-instant (clock-now clock) zone))

(defun local-date-time-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  (zoned-date-time-local (zoned-date-time-now :zone zone :clock clock)))

(defun local-time-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  "Return the current local time in ZONE according to CLOCK."
  (local-date-time-time (local-date-time-now :zone zone :clock clock)))

(defun local-date-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  (local-date-time-date (local-date-time-now :zone zone :clock clock)))

(progn
  (defun zoned-date-time-truncated-to (zoned-date-time unit)
    "Returns ZONED-DATE-TIME with its local time truncated down to UNIT.
When the result is ambiguous, retains the original offset when it is valid."
    (check-type zoned-date-time zoned-date-time)
    (%zoned-date-time-with-local
      zoned-date-time
      (local-date-time-truncated-to (zoned-date-time-local zoned-date-time) unit)))
  (defun zoned-date-time-rounded-to (zoned-date-time unit &key (mode :half-even))
    "Return ZONED-DATE-TIME with its local time rounded to fixed-width UNIT.

MODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO, :HALF-UP,
or :HALF-EVEN (the default). The rounded local time is resolved in the zone;
when ambiguous, the original offset is retained when it remains valid."
    (check-type zoned-date-time zoned-date-time)
    (%zoned-date-time-with-local
      zoned-date-time
      (local-date-time-rounded-to
        (zoned-date-time-local zoned-date-time)
        unit
        :mode
        mode))))
