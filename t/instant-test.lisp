;;;; t/instant-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "construction"
  (it
    "MAKE-INSTANT normalizes an out-of-range nanosecond into EPOCH-SECOND"
    (let ((i (make-instant 0 -1)))
      (expect (instant-epoch-second i) :to-be -1)
      (expect (instant-nanosecond i) :to-be 999999999)))
  (it
    "INSTANT-EPOCH is 1970-01-01T00:00:00Z"
    (expect (instant-epoch-second (instant-epoch)) :to-be 0)
    (expect (instant-nanosecond (instant-epoch)) :to-be 0))
  (it
    "epoch millisecond and microsecond constructors round-trip integers"
    (dolist (value (list -1001 -1 0 1 1001))
      (expect (instant-to-epoch-millis (instant-of-epoch-millis value)) :to-be value)
      (expect (instant-to-epoch-micros (instant-of-epoch-micros value)) :to-be value)))
  (it
    "epoch conversions round down sub-unit negative instants"
    (let ((instant (make-instant -1 999999999)))
      (expect (instant-to-epoch-millis instant) :to-be -1)
      (expect (instant-to-epoch-micros instant) :to-be -1))))

(progn
  (describe
    "arithmetic"
    (it
      "INSTANT-PLUS-DURATION and INSTANT-UNTIL are inverses"
      (let ((start (make-instant 1000))
            (end (make-instant 2500)))
        (expect
          (instant= (instant-plus-duration start (instant-until start end)) end)
          :to-be-truthy)))
    (it
      "INSTANT-MINUS-DURATION undoes INSTANT-PLUS-DURATION"
      (let ((start (make-instant 1000 500000000))
            (d (duration-of-seconds 10 750000000)))
        (expect
          (instant= (instant-minus-duration (instant-plus-duration start d) d) start)
          :to-be-truthy)))
    (it
      "fixed-unit arithmetic normalizes across the Unix epoch"
      (let ((before-epoch (instant-of-epoch-millis -1)))
        (expect
          (instant= (instant-plus-millis before-epoch 1) (instant-epoch))
          :to-be-truthy)
        (expect
          (instant= (instant-minus-millis (instant-epoch) 1) before-epoch)
          :to-be-truthy)
        (expect
          (instant= (instant-plus-micros before-epoch 1000) (instant-epoch))
          :to-be-truthy)
        (expect
          (instant= (instant-minus-micros (instant-epoch) 1000) before-epoch)
          :to-be-truthy)))
    (it
      "fixed-unit arithmetic retains nanosecond precision"
      (let ((start (make-instant 0 999999500)))
        (expect
          (instant= (instant-plus-nanos start 500) (make-instant 1))
          :to-be-truthy)
        (expect
          (instant= (instant-plus-micros start 750) (make-instant 1 749500))
          :to-be-truthy)
        (expect
          (instant= (instant-plus-seconds start 3) (make-instant 3 999999500))
          :to-be-truthy)
        (expect
          (instant= (instant-minus-nanos (make-instant 1) 500) start)
          :to-be-truthy))))
  (describe
    "minute hour and day arithmetic"
    (it
      "uses fixed elapsed units across the Unix epoch"
      (let ((start (make-instant -1 500000000)))
        (expect
          (instant= (instant-plus-minutes start 1) (make-instant 59 500000000))
          :to-be-truthy)
        (expect
          (instant= (instant-plus-hours start 1) (make-instant 3599 500000000))
          :to-be-truthy)
        (expect
          (instant= (instant-plus-days start 1) (make-instant 86399 500000000))
          :to-be-truthy)
        (expect
          (instant= (instant-minus-minutes (instant-plus-minutes start 7) 7) start)
          :to-be-truthy)
        (expect
          (instant= (instant-minus-hours (instant-plus-hours start 7) 7) start)
          :to-be-truthy)
        (expect
          (instant= (instant-minus-days (instant-plus-days start 7) 7) start)
          :to-be-truthy)))))

(progn
  (describe
    "ordering"
    (it
      "INSTANT< / INSTANT> / INSTANT= agree with epoch order"
      (expect (instant< (make-instant 1) (make-instant 2)) :to-be-truthy)
      (expect (instant> (make-instant 2) (make-instant 1)) :to-be-truthy)
      (expect (instant= (make-instant 1 500) (make-instant 1 500)) :to-be-truthy))
    (it
      "compares seconds before nanoseconds at arbitrary epoch magnitudes"
      (let ((large-epoch (expt 10 100)))
        (dolist (case
                 (list
                  (list (make-instant large-epoch 0)
                        (make-instant large-epoch 1)
                        -1)
                  (list (make-instant -1 999999999) (make-instant 0 0) -1)
                  (list (make-instant large-epoch 7)
                        (make-instant large-epoch 7)
                        0)))
          (expect (instant-compare (first case) (second case))
                  :to-be
                  (third case))))))
  (describe
    "fixed-unit truncation"
    (it
      "rounds negative instants down on the UTC timeline"
      (let ((instant (make-instant -1 500000000)))
        (expect
          (instant= (cl-date-kit:instant-truncated-to instant :seconds) (make-instant -1))
          :to-be-truthy)
        (expect
          (instant=
            (cl-date-kit:instant-truncated-to instant :minutes)
            (make-instant -60))
          :to-be-truthy)))
    (it
      "removes fractional nanoseconds at millisecond precision"
      (expect
        (instant=
          (cl-date-kit:instant-truncated-to (make-instant 12 987654321) :millis)
          (make-instant 12 987000000))
        :to-be-truthy))))

(describe
  "epoch unit conversions"
  (it
    "round-trip zero, negative, unit-boundary, and bignum values"
    (dolist
        (conversion
         (list
          (list (function instant-of-epoch-nanos) (function instant-to-epoch-nanos) 1000000000)
          (list (function instant-of-epoch-millis) (function instant-to-epoch-millis) 1000)
          (list (function instant-of-epoch-micros) (function instant-to-epoch-micros) 1000000)))
      (destructuring-bind (constructor accessor unit) conversion
        (dolist (value
                 (list
                  -1
                  0
                  1
                  (1- unit)
                  unit
                  (1+ unit)
                  (* -1 (1+ unit))
                  (+ (* (expt 10 100) unit) 1)))
          (expect (funcall accessor (funcall constructor value)) :to-be value)))))
  (it
    "rejects non-integer epoch nanoseconds"
    (signals type-error (instant-of-epoch-nanos 1.5))))

(progn
  (describe
    "instant conversion shortcuts"
    (it
      "INSTANT-AT-ZONE retains the instant and derives zone-local fields"
      (let* ((instant (make-instant 0 123456789))
             (value (instant-at-zone instant (zone-offset-of-hours 9))))
        (expect (instant= (zoned-date-time-to-instant value) instant) :to-be-truthy)
        (expect (zoned-date-time-year value) :to-be 1970)
        (expect (zoned-date-time-month value) :to-be 1)
        (expect (zoned-date-time-day value) :to-be 1)
        (expect (zoned-date-time-hour value) :to-be 9)
        (expect (zoned-date-time-nanosecond value) :to-be 123456789)))
    (it
      "INSTANT-AT-OFFSET retains the instant and derives offset-local fields"
      (let* ((instant (make-instant 0 987654321))
             (value (instant-at-offset instant (zone-offset-of-hours -4))))
        (expect
          (instant= (cl-date-kit:offset-date-time-to-instant value) instant)
          :to-be-truthy)
        (expect (cl-date-kit:offset-date-time-year value) :to-be 1969)
        (expect (cl-date-kit:offset-date-time-month value) :to-be 12)
        (expect (cl-date-kit:offset-date-time-day value) :to-be 31)
        (expect (cl-date-kit:offset-date-time-hour value) :to-be 20)
        (expect (cl-date-kit:offset-date-time-nanosecond value) :to-be 987654321)))
    (it
      "requires instant and zone or offset arguments of the proper types"
      (signals type-error (instant-at-zone 1.5 (zone-offset-utc)))
      (signals type-error (instant-at-zone (instant-epoch) 1.5))
      (signals type-error (instant-at-offset 1.5 (zone-offset-utc)))
      (signals type-error (instant-at-offset (instant-epoch) 1.5))))
  (describe
    "epoch nanosecond normalization"
    (it
      "uses floor division so negative values retain a non-negative nanosecond field"
      (let ((instant (instant-of-epoch-nanos -1)))
        (expect (instant-epoch-second instant) :to-be -1)
        (expect (instant-nanosecond instant) :to-be 999999999)))))

(progn
  (describe
    "epoch-second construction"
    (it
      "normalizes a nanosecond adjustment while preserving the specified epoch seconds"
      (let ((instant (cl-date-kit:instant-of-epoch-second -1 -1)))
        (expect (instant-epoch-second instant) :to-be -2)
        (expect (instant-nanosecond instant) :to-be 999999999)))
    (it
      "requires integral fields"
      (signals type-error (cl-date-kit:instant-of-epoch-second 1.5))
      (signals type-error (cl-date-kit:instant-of-epoch-second 0 1.5))))
  (progn
  (it
   "signals a structured condition instead of rounding subsecond instants"
   (let* ((instant (make-instant 0 1))
          (condition
           (handler-case (instant-to-universal-time instant)
             (instant-precision-loss (signaled) signaled))))
     (expect (typep condition (quote instant-precision-loss)) :to-be-truthy)
     (expect (instant-precision-loss-instant condition) :to-be instant)
     (expect (instant-precision-loss-representation condition) :to-be :universal-time)))
  (it
   "rounds signed instants and applies tie rules"
   (expect (instant= (cl-date-kit:instant-rounded-to (make-instant 1 600000000) :seconds :mode :floor)
                     (make-instant 1)) :to-be-truthy)
   (expect (instant= (cl-date-kit:instant-rounded-to (make-instant 1 600000000) :seconds :mode :ceiling)
                     (make-instant 2)) :to-be-truthy)
   (expect (instant= (cl-date-kit:instant-rounded-to (make-instant -2 400000000) :seconds :mode :toward-zero)
                     (make-instant -1)) :to-be-truthy)
   (expect (instant= (cl-date-kit:instant-rounded-to (make-instant -2 400000000) :seconds :mode :away-from-zero)
                     (make-instant -2)) :to-be-truthy)
   (expect (instant= (cl-date-kit:instant-rounded-to (make-instant -2 500000000) :seconds :mode :half-up)
                     (make-instant -2)) :to-be-truthy)
   (expect (instant= (cl-date-kit:instant-rounded-to (make-instant 2 500000000) :seconds :mode :half-even)
                     (make-instant 2)) :to-be-truthy)
   (expect (instant= (cl-date-kit:instant-rounded-to (make-instant -3 500000000) :seconds :mode :half-even)
                     (make-instant -2)) :to-be-truthy)
   (signals type-error
    (cl-date-kit:instant-rounded-to (make-instant 1) :seconds :mode :nearest)))))
