;;;; t/offset-date-time-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "OffsetDateTime"
  (it
    "constructs an immutable local date-time with a fixed offset"
    (let ((value
          (cl-date-kit:offset-date-time-of
            2024
            6
            15
            12
            34
            56
            123000000
            (zone-offset-of-hours 9))))
      (expect (cl-date-kit:offset-date-time-year value) :to-be 2024)
      (expect (cl-date-kit:offset-date-time-nanosecond value) :to-be 123000000)
      (expect
        (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset value))
        :to-be
        32400)))
  (it
    "converts to and from INSTANT without losing nanoseconds"
    (let* ((original
          (cl-date-kit:offset-date-time-of
            2024
            6
            15
            12
            34
            56
            123456789
            (zone-offset-of-hours -4)))
           (instant (cl-date-kit:offset-date-time-to-instant original))
           (round-trip
          (cl-date-kit:offset-date-time-of-instant instant (zone-offset-of-hours -4))))
      (expect (cl-date-kit:offset-date-time= round-trip original) :to-be-truthy)
      (expect (cl-date-kit:offset-date-time-nanosecond round-trip) :to-be 123456789)))
  (it
    "distinguishes same-instant and same-local offset changes"
    (let* ((original
          (cl-date-kit:offset-date-time-of 2024 6 15 12 0 0 0 (zone-offset-of-hours 9)))
           (same-instant
          (cl-date-kit:offset-date-time-with-offset-same-instant
            original
            (zone-offset-of-hours 0)))
           (same-local
          (cl-date-kit:offset-date-time-with-offset-same-local
            original
            (zone-offset-of-hours 0))))
      (expect (cl-date-kit:offset-date-time-hour same-instant) :to-be 3)
      (expect (cl-date-kit:offset-date-time-hour same-local) :to-be 12)
      (expect (cl-date-kit:offset-date-time= original same-instant) :to-be-truthy)
      (expect (cl-date-kit:offset-date-time< original same-local) :to-be-truthy)))
  (it
    "uses elapsed-time and calendar arithmetic appropriately"
    (let* ((original
            (cl-date-kit:offset-date-time-of 2024 3 9 12 0 0 0 (zone-offset-of-hours -5)))
           (duration-result
            (cl-date-kit:offset-date-time-plus-duration original (duration-of-hours 25)))
           (period-result
            (cl-date-kit:offset-date-time-plus-period original (period-of-days 1))))
      (expect (cl-date-kit:offset-date-time-day duration-result) :to-be 10)
      (expect (cl-date-kit:offset-date-time-hour duration-result) :to-be 13)
      (expect (cl-date-kit:offset-date-time-day period-result) :to-be 10)
      (expect (cl-date-kit:offset-date-time-hour period-result) :to-be 12)))
  (it
    "returns elapsed time across fixed offset representations"
    (let* ((start
             (cl-date-kit:offset-date-time-of
              2024 6 15 12 0 0 900000000 (zone-offset-of-hours 9)))
           (end
             (cl-date-kit:offset-date-time-of
              2024 6 15 3 0 1 100000000 (zone-offset-of-hours 0)))
           (duration (cl-date-kit:offset-date-time-until start end)))
      (expect (duration-seconds duration) :to-be 0)
      (expect (duration-nanos duration) :to-be 200000000)))
  (it
    "uses the supplied clock for NOW"
    (let* ((clock (make-fixed-clock (make-instant 0 42)))
           (value
          (cl-date-kit:offset-date-time-now :clock clock :offset (zone-offset-of-hours 9))))
      (expect (cl-date-kit:offset-date-time-day value) :to-be 1)
      (expect (cl-date-kit:offset-date-time-hour value) :to-be 9)
      (expect (cl-date-kit:offset-date-time-nanosecond value) :to-be 42)))
  (it
    "validates the value types accepted by its public constructor"
    (signals
      type-error
      (cl-date-kit:make-offset-date-time
        (make-local-date 2024 6 15)
        (zone-offset-utc)))
    (signals
      type-error
      (cl-date-kit:make-offset-date-time (local-date-time-of 2024 6 15 12 0 0) 0)))) (progn
(progn (describe "OffsetDateTime fixed-unit arithmetic" (it
  "carries fixed-unit arithmetic across a calendar boundary"
  (let* ((offset (zone-offset-of-hours -4))
         (value
           (cl-date-kit:offset-date-time-of
             2024 12 31 23 59 59 999500000 offset))
         (millis (cl-date-kit:offset-date-time-plus-millis value 1))
         (micros (cl-date-kit:offset-date-time-plus-micros value 750))
         (hours (cl-date-kit:offset-date-time-plus-hours value 2))
         (nanos (cl-date-kit:offset-date-time-plus-nanos value 500000))
         (minutes (cl-date-kit:offset-date-time-plus-minutes value 1)))
    (expect (cl-date-kit:offset-date-time-year millis) :to-be 2025)
    (expect (cl-date-kit:offset-date-time-day millis) :to-be 1)
    (expect (cl-date-kit:offset-date-time-nanosecond millis) :to-be 500000)
    (expect (cl-date-kit:offset-date-time-day micros) :to-be 1)
    (expect (cl-date-kit:offset-date-time-nanosecond micros) :to-be 250000)
    (expect (cl-date-kit:offset-date-time-hour hours) :to-be 1)
    (expect (cl-date-kit:offset-date-time-year nanos) :to-be 2025)
    (expect (cl-date-kit:offset-date-time-day nanos) :to-be 1)
    (expect (cl-date-kit:offset-date-time-nanosecond nanos) :to-be 0)
    (expect
      (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset nanos))
      :to-be -14400)
    (expect (cl-date-kit:offset-date-time-year minutes) :to-be 2025)
    (expect (cl-date-kit:offset-date-time-day minutes) :to-be 1)
    (expect (cl-date-kit:offset-date-time-hour minutes) :to-be 0)
    (expect (cl-date-kit:offset-date-time-minute minutes) :to-be 0)
    (expect (cl-date-kit:offset-date-time-second minutes) :to-be 59)
    (expect (cl-date-kit:offset-date-time-nanosecond minutes) :to-be 999500000)
    (expect
      (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset minutes))
      :to-be -14400)
    (expect
      (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset millis))
      :to-be -14400))) (it "reverses every fixed unit" (let ((value (cl-date-kit:offset-date-time-of 2024 1 1 0 0 0 0 (zone-offset-utc)))) (expect (cl-date-kit:offset-date-time-day (cl-date-kit:offset-date-time-minus-hours value 1)) :to-be 31) (expect (cl-date-kit:offset-date-time-minute (cl-date-kit:offset-date-time-minus-minutes value 1)) :to-be 59) (expect (cl-date-kit:offset-date-time-second (cl-date-kit:offset-date-time-minus-seconds value 1)) :to-be 59) (expect (cl-date-kit:offset-date-time-nanosecond (cl-date-kit:offset-date-time-minus-millis value 1)) :to-be 999000000) (expect (cl-date-kit:offset-date-time-nanosecond (cl-date-kit:offset-date-time-minus-micros value 1)) :to-be 999999000) (expect (cl-date-kit:offset-date-time-nanosecond (cl-date-kit:offset-date-time-minus-nanos value 1)) :to-be 999999999)))) (describe
  "fixed-unit truncation"
  (it
   "truncates local fields while preserving the fixed offset"
   (let* ((offset (zone-offset-of-hours -4))
          (result
           (cl-date-kit:offset-date-time-truncated-to
            (cl-date-kit:offset-date-time-of
             2024 2 29 23 59 58 789123456 offset)
            :hours)))
     (expect (cl-date-kit:offset-date-time-day result) :to-be 29)
     (expect (cl-date-kit:offset-date-time-hour result) :to-be 23)
     (expect (cl-date-kit:offset-date-time-minute result) :to-be 0)
     (expect
      (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset result))
      :to-be
      -14400))))

(describe
  "OffsetDateTime field replacement"
  (it
    "replaces all local fields while retaining the fixed offset"
    (let* ((offset (zone-offset-of-hours -4))
           (value (cl-date-kit:offset-date-time-of 2024 2 29 12 34 56 789 offset))
           (result
             (cl-date-kit:offset-date-time-with-nanosecond
               (cl-date-kit:offset-date-time-with-second
                 (cl-date-kit:offset-date-time-with-minute
                   (cl-date-kit:offset-date-time-with-hour
                     (cl-date-kit:offset-date-time-with-day-of-year
                       (cl-date-kit:offset-date-time-with-day
                         (cl-date-kit:offset-date-time-with-month
                           (cl-date-kit:offset-date-time-with-year value 2023)
                           3)
                         15)
                       100)
                     1)
                   2)
                 3)
               4)))
      (expect (cl-date-kit:offset-date-time-year result) :to-be 2023)
      (expect (cl-date-kit:offset-date-time-month result) :to-be 4)
      (expect (cl-date-kit:offset-date-time-day result) :to-be 10)
      (expect (cl-date-kit:offset-date-time-hour result) :to-be 1)
      (expect (cl-date-kit:offset-date-time-minute result) :to-be 2)
      (expect (cl-date-kit:offset-date-time-second result) :to-be 3)
      (expect (cl-date-kit:offset-date-time-nanosecond result) :to-be 4)
      (expect
        (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset result))
        :to-be
        -14400)
      (expect (cl-date-kit:offset-date-time-year value) :to-be 2024)
      (expect (cl-date-kit:offset-date-time-day value) :to-be 29)))
  (it
    "inherits LocalDateTime validation and month-end clamping"
    (let ((value (cl-date-kit:offset-date-time-of 2024 2 29 12 0 0)))
      (expect
        (cl-date-kit:offset-date-time-day
          (cl-date-kit:offset-date-time-with-year value 2023))
        :to-be
        28)
      (signals
        invalid-time
        (cl-date-kit:offset-date-time-with-minute value 60))))))
(describe
  "OffsetDateTime calendar-unit arithmetic"
  (it
    "uses local calendar rules and preserves the fixed offset"
    (let* ((offset (cl-date-kit:zone-offset-of-hours 9))
           (month-end
             (cl-date-kit:offset-date-time-of 2024 1 31 12 0 0 0 offset))
           (leap-day
             (cl-date-kit:offset-date-time-of 2024 2 29 12 0 0 0 offset)))
      (expect
        (cl-date-kit:offset-date-time-day
          (cl-date-kit:offset-date-time-plus-days month-end 1))
        :to-be 1)
      (expect
        (cl-date-kit:offset-date-time-day
          (cl-date-kit:offset-date-time-minus-days month-end 1))
        :to-be 30)
      (expect
        (cl-date-kit:offset-date-time-day
          (cl-date-kit:offset-date-time-plus-weeks month-end 1))
        :to-be 7)
      (expect
        (cl-date-kit:offset-date-time-day
          (cl-date-kit:offset-date-time-minus-weeks month-end 1))
        :to-be 24)
      (let ((result (cl-date-kit:offset-date-time-plus-months month-end 1)))
        (expect (cl-date-kit:offset-date-time-month result) :to-be 2)
        (expect (cl-date-kit:offset-date-time-day result) :to-be 29)
        (expect
          (cl-date-kit:zone-offset-total-seconds
            (cl-date-kit:offset-date-time-offset result))
          :to-be 32400))
      (let ((result (cl-date-kit:offset-date-time-minus-months month-end 1)))
        (expect (cl-date-kit:offset-date-time-year result) :to-be 2023)
        (expect (cl-date-kit:offset-date-time-month result) :to-be 12)
        (expect (cl-date-kit:offset-date-time-day result) :to-be 31))
      (let ((result (cl-date-kit:offset-date-time-plus-years leap-day 1)))
        (expect (cl-date-kit:offset-date-time-year result) :to-be 2025)
        (expect (cl-date-kit:offset-date-time-month result) :to-be 2)
        (expect (cl-date-kit:offset-date-time-day result) :to-be 28))
      (let ((result (cl-date-kit:offset-date-time-minus-years leap-day 1)))
        (expect (cl-date-kit:offset-date-time-year result) :to-be 2023)
        (expect (cl-date-kit:offset-date-time-month result) :to-be 2)
        (expect (cl-date-kit:offset-date-time-day result) :to-be 28))))
  (it
    "requires integer calendar-unit amounts"
    (let ((value
            (cl-date-kit:offset-date-time-of
              2024 1 1 0 0 0 0 (cl-date-kit:zone-offset-utc))))
      (signals type-error
        (cl-date-kit:offset-date-time-plus-days value 1/2))
      (signals type-error
        (cl-date-kit:offset-date-time-minus-days value 1/2))
      (signals type-error
        (cl-date-kit:offset-date-time-plus-weeks value 1/2))
      (signals type-error
        (cl-date-kit:offset-date-time-minus-weeks value 1/2))
      (signals type-error
        (cl-date-kit:offset-date-time-plus-months value 1/2))
      (signals type-error
        (cl-date-kit:offset-date-time-minus-months value 1/2))
      (signals type-error
        (cl-date-kit:offset-date-time-plus-years value 1/2))
      (signals type-error
        (cl-date-kit:offset-date-time-minus-years value 1/2))))))

(describe "OffsetDateTime epoch-second conversions" (it "round-trips epoch fields through fixed offsets across date boundaries" (dolist (case (list (list -1 123456789 (zone-offset-of-hours 9)) (list 0 0 (zone-offset-utc)) (list 1 999999999 (zone-offset-of-hms -3 -30 0)) (list 1234567890 42 (zone-offset-of-hours 14)))) (destructuring-bind (seconds nanosecond offset) case (let ((value (cl-date-kit:offset-date-time-of-epoch-second seconds nanosecond offset))) (expect (cl-date-kit:offset-date-time-to-epoch-second value) :to-be seconds) (expect (cl-date-kit:offset-date-time-nanosecond value) :to-be nanosecond) (expect (zone-offset= (cl-date-kit:offset-date-time-offset value) offset) :to-be-truthy))))))


(describe "OffsetDateTime zone conversion"
  (it "keeps the instant or local fields as requested"
    (let* ((zone (find-time-zone "America/New_York"))
           (value
             (cl-date-kit:offset-date-time-of
              2024 11 3 1 30 0 0 (zone-offset-of-hours 9)))
           (same-instant
             (cl-date-kit:offset-date-time-at-zone-same-instant value zone))
           (similar-local
             (cl-date-kit:offset-date-time-at-zone-similar-local value zone)))
      (expect (zoned-date-time-day same-instant) :to-be 2)
      (expect (zoned-date-time-hour same-instant) :to-be 12)
      (expect (zone-offset-total-seconds (zoned-date-time-offset same-instant))
        :to-be -14400)
      (expect (zoned-date-time-day similar-local) :to-be 3)
      (expect (zoned-date-time-hour similar-local) :to-be 1)
      (expect (zone-offset-total-seconds (zoned-date-time-offset similar-local))
        :to-be -14400)))
  (it "prefers a matching offset during the New York overlap"
    (let* ((zone (find-time-zone "America/New_York"))
           (earlier
             (cl-date-kit:offset-date-time-at-zone-similar-local
              (cl-date-kit:offset-date-time-of
               2024 11 3 1 30 0 0 (zone-offset-of-hours -4))
              zone))
           (later
             (cl-date-kit:offset-date-time-at-zone-similar-local
              (cl-date-kit:offset-date-time-of
               2024 11 3 1 30 0 0 (zone-offset-of-hours -5))
              zone)))
      (expect (zone-offset-total-seconds (zoned-date-time-offset earlier))
        :to-be -14400)
      (expect (zone-offset-total-seconds (zoned-date-time-offset later))
        :to-be -18000))))

(progn (progn (progn
(describe
 "OffsetDateTime truncation contract"
 (it
  "truncates every supported fixed unit while retaining the date and offset"
  (let* ((offset (zone-offset-of-hours -4))
         (value
          (cl-date-kit:offset-date-time-of
           2024 2 29 12 34 56 789123456 offset)))
   (dolist (scenario (quote ((:nanos 12 34 56 789123456)
                              (:micros 12 34 56 789123000)
                              (:millis 12 34 56 789000000)
                              (:seconds 12 34 56 0)
                              (:minutes 12 34 0 0)
                              (:hours 12 0 0 0)
                              (:days 0 0 0 0))))
    (destructuring-bind (unit hour minute second nanosecond) scenario
     (expect
      (cl-date-kit:offset-date-time=
       (cl-date-kit:offset-date-time-truncated-to value unit)
       (cl-date-kit:offset-date-time-of
        2024 2 29 hour minute second nanosecond offset))
      :to-be-truthy)))))
 (it
  "signals TYPE-ERROR for invalid values and units"
  (signals
   type-error
   (cl-date-kit:offset-date-time-truncated-to 0 :seconds))
  (signals
   type-error
   (cl-date-kit:offset-date-time-truncated-to
    (cl-date-kit:offset-date-time-of 2024 2 29 0 0 0)
    :weeks))))
(describe
  "OffsetDateTime validation"
  (it
    "propagates epoch-second argument validation"
    (signals
      type-error
      (cl-date-kit:offset-date-time-of-epoch-second 0.5 0 (zone-offset-utc)))
    (signals
      type-error
      (cl-date-kit:offset-date-time-of-epoch-second 0 0 0))
    (signals
      invalid-time
      (cl-date-kit:offset-date-time-of-epoch-second 0 -1 (zone-offset-utc)))
    (signals
      invalid-time
      (cl-date-kit:offset-date-time-of-epoch-second 0 1000000000 (zone-offset-utc))))
  (it
    "propagates local date-time and offset validation"
    (signals
      invalid-date
      (cl-date-kit:offset-date-time-of 2024 2 30 0 0 0))
    (signals
      invalid-time
      (cl-date-kit:offset-date-time-of 2024 1 1 24 0 0))
    (signals
      type-error
      (cl-date-kit:offset-date-time-of 2024 1 1 0 0 0 0 0))))

(describe
  "OffsetDateTime zone conversion"
  (it
    "resolves the New York spring gap using compatible local time"
    (let* ((zone (find-time-zone "America/New_York"))
           (result
             (cl-date-kit:offset-date-time-at-zone-similar-local
               (cl-date-kit:offset-date-time-of
                 2024 3 10 2 30 0 0 (zone-offset-of-hours -5))
               zone)))
      (expect (zoned-date-time-hour result) :to-be 3)
      (expect (zoned-date-time-minute result) :to-be 30)
      (expect (zone-offset-total-seconds (zoned-date-time-offset result))
        :to-be -14400))))

  (describe
    "OffsetDateTime offset and instant boundaries"
    (it
      "orders equal instants consistently across fixed offsets"
      (let ((east (cl-date-kit:offset-date-time-of 2024 1 1 12 0 0 0 (zone-offset-of-hours 9)))
            (utc (cl-date-kit:offset-date-time-of 2024 1 1 3 0 0 0 (zone-offset-utc))))
        (expect (cl-date-kit:offset-date-time-compare east utc) :to-be 0)
        (expect (cl-date-kit:offset-date-time<= east utc) :to-be-truthy)
        (expect (cl-date-kit:offset-date-time>= east utc) :to-be-truthy)
        (expect (cl-date-kit:offset-date-time< east utc) :to-be-falsy)
        (expect (cl-date-kit:offset-date-time> east utc) :to-be-falsy)))
    (it
      "distinguishes offset changes across a date boundary without losing nanoseconds"
      (let* ((value (cl-date-kit:offset-date-time-of 2024 1 1 0 30 0 123456789 (zone-offset-of-hours 14)))
             (same-instant (cl-date-kit:offset-date-time-with-offset-same-instant value (zone-offset-of-hours -12)))
             (same-local (cl-date-kit:offset-date-time-with-offset-same-local value (zone-offset-of-hours -12))))
        (expect (cl-date-kit:offset-date-time-year same-instant) :to-be 2023)
        (expect (cl-date-kit:offset-date-time-month same-instant) :to-be 12)
        (expect (cl-date-kit:offset-date-time-day same-instant) :to-be 30)
        (expect (cl-date-kit:offset-date-time-hour same-instant) :to-be 22)
        (expect (cl-date-kit:offset-date-time-nanosecond same-instant) :to-be 123456789)
        (expect (cl-date-kit:offset-date-time= value same-instant) :to-be-truthy)
        (expect (cl-date-kit:offset-date-time-day same-local) :to-be 1)
        (expect (cl-date-kit:offset-date-time-hour same-local) :to-be 0)
        (expect (cl-date-kit:offset-date-time-nanosecond same-local) :to-be 123456789)
        (expect (cl-date-kit:offset-date-time= value same-local) :to-be-falsy)))
    (it
      "subtracts durations across the Unix epoch with a fixed offset"
      (let ((result
              (cl-date-kit:offset-date-time-minus-duration
                (cl-date-kit:offset-date-time-of 1970 1 1 0 30 0 0 (zone-offset-of-hours 1))
                (duration-of-hours 1))))
        (expect (cl-date-kit:offset-date-time-year result) :to-be 1969)
        (expect (cl-date-kit:offset-date-time-month result) :to-be 12)
        (expect (cl-date-kit:offset-date-time-day result) :to-be 31)
        (expect (cl-date-kit:offset-date-time-hour result) :to-be 23)
        (expect (cl-date-kit:offset-date-time-to-epoch-second result) :to-be -5400)))
    (it
      "rejects non-zone values for both zone conversion APIs"
      (let ((value (cl-date-kit:offset-date-time-of 2024 1 1 0 0 0)))
        (signals type-error (cl-date-kit:offset-date-time-at-zone-same-instant value 0))
        (signals type-error (cl-date-kit:offset-date-time-at-zone-similar-local value 0))))
  )) (describe "OffsetDateTime fixed-unit rounding" (it "carries local date rounding while retaining a negative offset" (let ((rounded (offset-date-time-rounded-to (offset-date-time-of 2024 2 29 23 31 0 0 (zone-offset-of-hours -4)) :hours :mode :ceiling))) (expect (offset-date-time-month rounded) :to-be 3) (expect (offset-date-time-day rounded) :to-be 1) (expect (offset-date-time-hour rounded) :to-be 0) (expect (zone-offset-total-seconds (offset-date-time-offset rounded)) :to-be -14400))))) (describe "OffsetDateTime instant comparisons" (it "orders equal, earlier, and later instants for inclusive comparisons" (let* ((value (cl-date-kit:offset-date-time-of 2024 6 15 12 0 0 0 (zone-offset-of-hours 9))) (same-instant (cl-date-kit:offset-date-time-with-offset-same-instant value (zone-offset-utc))) (before (cl-date-kit:offset-date-time-minus-seconds value 1)) (after (cl-date-kit:offset-date-time-plus-seconds value 1))) (expect (cl-date-kit:offset-date-time<= value same-instant) :to-be-truthy) (expect (cl-date-kit:offset-date-time<= value after) :to-be-truthy) (expect (cl-date-kit:offset-date-time<= value before) :to-be-falsy) (expect (cl-date-kit:offset-date-time>= value same-instant) :to-be-truthy) (expect (cl-date-kit:offset-date-time>= value before) :to-be-truthy) (expect (cl-date-kit:offset-date-time>= value after) :to-be-falsy)))))
