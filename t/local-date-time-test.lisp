;;;; t/local-date-time-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "construction and field accessors"
  (it
    "LOCAL-DATE-TIME-OF builds from raw year/month/day/hour/minute/second"
    (let ((dt (local-date-time-of 2024 3 10 2 30 15)))
      (expect (local-date-time-year dt) :to-be 2024)
      (expect (local-date-time-month dt) :to-be 3)
      (expect (local-date-time-day dt) :to-be 10)
      (expect (local-date-time-hour dt) :to-be 2)
      (expect (local-date-time-minute dt) :to-be 30)
      (expect (local-date-time-second dt) :to-be 15)))
  (it
    "MAKE-LOCAL-DATE-TIME rejects non-component values with TYPE-ERROR"
    (signals type-error (make-local-date-time (make-local-date 2024 3 10) 0))
    (signals type-error (make-local-date-time 0 (make-local-time 2 30 15)))))

(describe
  "arithmetic that crosses midnight carries into the date"
  (it
    "LOCAL-DATE-TIME-PLUS-HOURS rolls into the next day"
    (expect
      (local-date-time=
        (local-date-time-plus-hours (local-date-time-of 2024 1 1 23 0 0) 2)
        (local-date-time-of 2024 1 2 1 0 0))
      :to-be-truthy))
  (it
    "LOCAL-DATE-TIME-MINUS-HOURS rolls into the previous day"
    (expect
      (local-date-time=
        (local-date-time-minus-hours (local-date-time-of 2024 1 1 0 30 0) 1)
        (local-date-time-of 2023 12 31 23 30 0))
      :to-be-truthy))
  (it
    "LOCAL-DATE-TIME millisecond arithmetic carries across midnight"
    (let ((start (local-date-time-of 2024 1 1 23 59 59 999500000))
          (end (local-date-time-of 2024 1 2 0 0 0 500000)))
      (expect (local-date-time= (local-date-time-plus-millis start 1) end) :to-be-truthy)
      (expect (local-date-time= (local-date-time-minus-millis end 1) start) :to-be-truthy)))
  (it
    "LOCAL-DATE-TIME microsecond arithmetic carries across midnight"
    (let ((start (local-date-time-of 2024 1 1 23 59 59 999500000))
          (end (local-date-time-of 2024 1 2 0 0 0 250000)))
      (expect (local-date-time= (local-date-time-plus-micros start 750) end) :to-be-truthy)
      (expect (local-date-time= (local-date-time-minus-micros end 750) start) :to-be-truthy)))
  (it
    "LOCAL-DATE-TIME-PLUS-DAYS/MONTHS/YEARS delegate to LOCAL-DATE, keeping the time-of-day"
    (let ((dt (local-date-time-of 2023 1 31 10 0 0)))
      (expect
        (local-date-time=
          (local-date-time-plus-months dt 1)
          (local-date-time-of 2023 2 28 10 0 0))
        :to-be-truthy))))

(describe
  "duration and period arithmetic"
  (it
    "LOCAL-DATE-TIME-PLUS-DURATION is the inverse of LOCAL-DATE-TIME-MINUS-DURATION"
    (let ((dt (local-date-time-of 2024 6 15 12 0 0))
          (d (duration-of-hours 5)))
      (expect
        (local-date-time=
          (local-date-time-minus-duration (local-date-time-plus-duration dt d) d)
          dt)
        :to-be-truthy)))
  (it
    "LOCAL-DATE-TIME-PLUS-PERIOD adjusts the date, not the time"
    (expect
      (local-date-time=
        (local-date-time-plus-period
          (local-date-time-of 2024 1 1 9 0 0)
          (make-period :months 1))
        (local-date-time-of 2024 2 1 9 0 0))
      :to-be-truthy)))

(describe
  "ordering"
  (it
    "compares by date first, then time-of-day"
    (expect
      (local-date-time<
        (local-date-time-of 2024 1 1 23 0 0)
        (local-date-time-of 2024 1 2 0 0 0))
      :to-be-truthy)
    (expect
      (local-date-time=
        (local-date-time-of 2024 1 1 10 0 0)
        (local-date-time-of 2024 1 1 10 0 0))
      :to-be-truthy))
  (it
    "LOCAL-DATE-TIME-UNTIL returns the exact duration across date and nanosecond boundaries"
    (let ((duration
          (local-date-time-until
            (local-date-time-of 2024 2 28 23 59 59 900000000)
            (local-date-time-of 2024 2 29 0 0 0 100000000))))
      (expect (duration-seconds duration) :to-be 0)
      (expect (duration-nanos duration) :to-be 200000000))))

(progn (describe
  "immutable date-time field replacement"
  (it
    "date fields preserve local time and retain date clamp semantics"
    (expect
      (local-date-time=
        (cl-date-kit:local-date-time-with-month
          (local-date-time-of 2024 1 31 12 34 56 7)
          2)
        (local-date-time-of 2024 2 29 12 34 56 7))
      :to-be-truthy)
    (expect
      (local-date-time=
        (cl-date-kit:local-date-time-with-day-of-year
          (local-date-time-of 2024 1 1 12 34 56 7)
          366)
        (local-date-time-of 2024 12 31 12 34 56 7))
      :to-be-truthy))
  (it
    "time fields preserve local date"
    (let ((updated
          (cl-date-kit:local-date-time-with-nanosecond
            (cl-date-kit:local-date-time-with-second
              (cl-date-kit:local-date-time-with-minute
                (cl-date-kit:local-date-time-with-hour
                  (local-date-time-of 2024 3 10 1 2 3 4)
                  23)
                59)
              58)
            999)))
      (expect
        (local-date-time= updated (local-date-time-of 2024 3 10 23 59 58 999))
        :to-be-truthy)))
  (it
    "LOCAL-DATE-TIME-WITH-* preserves INVALID-TIME validation"
    (signals
      invalid-time
      (cl-date-kit:local-date-time-with-hour (local-date-time-of 2024 3 10 1 2 3) 24)))) (describe
  "fixed-unit truncation"
  (it
   "preserves the date while truncating local time"
   (let ((date-time (local-date-time-of 2024 2 29 23 59 58 123456789)))
     (expect
      (local-date-time=
       (cl-date-kit:local-date-time-truncated-to date-time :hours)
       (local-date-time-of 2024 2 29 23 0 0))
      :to-be-truthy)
     (expect
      (local-date-time=
       (cl-date-kit:local-date-time-truncated-to date-time :millis)
       (local-date-time-of 2024 2 29 23 59 58 123000000))
      :to-be-truthy)))))

(describe "LocalDateTime direct conversions" (it "resolves DST overlaps and gaps through the requested zone rule" (let* ((zone (find-time-zone "America/New_York")) (overlap (local-date-time-of 2024 11 3 1 30 0)) (earlier (cl-date-kit:local-date-time-at-zone overlap zone :disambiguation :earlier)) (later (cl-date-kit:local-date-time-at-zone overlap zone :disambiguation :later)) (gap (cl-date-kit:local-date-time-at-zone (local-date-time-of 2024 3 10 2 30 0) zone))) (expect (cl-date-kit:zone-offset-total-seconds (cl-date-kit:zoned-date-time-offset earlier)) :to-be -14400) (expect (cl-date-kit:zone-offset-total-seconds (cl-date-kit:zoned-date-time-offset later)) :to-be -18000) (expect (cl-date-kit:local-date-time-hour (cl-date-kit:zoned-date-time-local gap)) :to-be 3) (expect (cl-date-kit:local-date-time-minute (cl-date-kit:zoned-date-time-local gap)) :to-be 30))) (it "pairs a local date-time with a fixed offset" (let* ((local (local-date-time-of 2024 7 27 9 0 0)) (offset (zone-offset-of-hours 9)) (value (cl-date-kit:local-date-time-at-offset local offset))) (expect (cl-date-kit:offset-date-time-local-date-time value) :to-be local) (expect (cl-date-kit:offset-date-time-offset value) :to-be offset) (signals type-error (cl-date-kit:local-date-time-at-offset local 0)))))
