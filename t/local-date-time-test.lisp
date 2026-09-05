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
    "LOCAL-DATE-TIME nanosecond arithmetic carries across midnight in both directions"
    (let ((last-nanosecond (local-date-time-of 2024 1 1 23 59 59 999999999))
          (first-nanosecond (local-date-time-of 2024 1 2 0 0 0 0)))
      (expect (local-date-time= (local-date-time-plus-nanos last-nanosecond 1) first-nanosecond) :to-be-truthy)
      (expect (local-date-time= (local-date-time-minus-nanos first-nanosecond 1) last-nanosecond) :to-be-truthy)))
  (it
    "LOCAL-DATE-TIME nanosecond arithmetic carries full-day deltas into the date"
    (let ((start (local-date-time-of 2024 1 1 12 34 56 789))
          (end (local-date-time-of 2024 1 2 12 34 56 789)))
      (expect (local-date-time= (local-date-time-plus-nanos start 86400000000000) end) :to-be-truthy)))
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
    "LOCAL-DATE-TIME second and minute wrappers cross the year boundary"
    (expect
      (local-date-time=
        (local-date-time-plus-seconds (local-date-time-of 2023 12 31 23 59 59) 1)
        (local-date-time-of 2024 1 1 0 0 0))
      :to-be-truthy)
    (expect
      (local-date-time=
        (local-date-time-minus-seconds (local-date-time-of 2024 1 1 0 0 0) 1)
        (local-date-time-of 2023 12 31 23 59 59))
      :to-be-truthy)
    (expect
      (local-date-time=
        (local-date-time-plus-minutes (local-date-time-of 2023 12 31 23 59 0) 1)
        (local-date-time-of 2024 1 1 0 0 0))
      :to-be-truthy)
    (expect
      (local-date-time=
        (local-date-time-minus-minutes (local-date-time-of 2024 1 1 0 0 0) 1)
        (local-date-time-of 2023 12 31 23 59 0))
      :to-be-truthy))
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
        :to-be-truthy))
    (let* ((start (local-date-time-of 2024 2 29 23 59 59 900000000))
           (duration (duration-of-seconds 1 200000000))
           (end (local-date-time-of 2024 3 1 0 0 1 100000000)))
      (expect
        (local-date-time= (local-date-time-plus-duration start duration) end)
        :to-be-truthy)
      (expect
        (local-date-time= (local-date-time-minus-duration end duration) start)
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

(progn
  (describe
    "immutable date-time field replacement"
    (it
      "date fields preserve local time and retain date clamp semantics"
      (expect
        (local-date-time=
          (cl-date-kit:local-date-time-with-year
            (local-date-time-of 2024 2 29 12 34 56 7)
            2023)
          (local-date-time-of 2023 2 28 12 34 56 7))
        :to-be-truthy)
      (expect
        (local-date-time=
          (cl-date-kit:local-date-time-with-month
            (local-date-time-of 2024 1 31 12 34 56 7)
            2)
          (local-date-time-of 2024 2 29 12 34 56 7))
        :to-be-truthy)
      (expect
        (local-date-time=
          (cl-date-kit:local-date-time-with-day
            (local-date-time-of 2024 3 10 12 34 56 7)
            31)
          (local-date-time-of 2024 3 31 12 34 56 7))
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
      (let ((date-time (local-date-time-of 2024 3 10 1 2 3 4)))
        (expect
          (local-date-time=
            (cl-date-kit:local-date-time-with-hour date-time 23)
            (local-date-time-of 2024 3 10 23 2 3 4))
          :to-be-truthy)
        (expect (local-date-time-hour date-time) :to-be 1)
        (expect
          (local-date-time=
            (cl-date-kit:local-date-time-with-minute date-time 59)
            (local-date-time-of 2024 3 10 1 59 3 4))
          :to-be-truthy)
        (expect
          (local-date-time=
            (cl-date-kit:local-date-time-with-second date-time 58)
            (local-date-time-of 2024 3 10 1 2 58 4))
          :to-be-truthy)
        (expect
          (local-date-time=
            (cl-date-kit:local-date-time-with-nanosecond date-time 999)
            (local-date-time-of 2024 3 10 1 2 3 999))
          :to-be-truthy)))
    (it
      "LOCAL-DATE-TIME-WITH-* preserves date and time validation"
      (let ((date-time (local-date-time-of 2024 3 10 1 2 3 4)))
        (signals invalid-date (cl-date-kit:local-date-time-with-day date-time 32))
        (signals invalid-time (cl-date-kit:local-date-time-with-minute date-time 60))
        (signals invalid-time (cl-date-kit:local-date-time-with-second date-time 60))
        (signals invalid-time (cl-date-kit:local-date-time-with-nanosecond date-time 1000000000)))))
  (describe
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

(progn (describe
 "LocalDateTime truncation contract"
 (it
  "truncates every supported fixed unit while retaining the date"
  (let ((date-time (local-date-time-of 2024 2 29 12 34 56 789123456)))
   (dolist (scenario (quote ((:nanos 12 34 56 789123456)
                              (:micros 12 34 56 789123000)
                              (:millis 12 34 56 789000000)
                              (:seconds 12 34 56 0)
                              (:minutes 12 34 0 0)
                              (:hours 12 0 0 0)
                              (:days 0 0 0 0))))
    (destructuring-bind (unit hour minute second nanosecond) scenario
     (expect
      (local-date-time=
       (cl-date-kit:local-date-time-truncated-to date-time unit)
       (local-date-time-of 2024 2 29 hour minute second nanosecond))
      :to-be-truthy)))))
 (it
  "signals TYPE-ERROR for invalid values and units"
  (signals type-error (cl-date-kit:local-date-time-truncated-to 0 :seconds))
  (signals
   type-error
   (cl-date-kit:local-date-time-truncated-to
    (local-date-time-of 2024 2 29 0 0 0)
    :weeks)))) (describe "LocalDateTime fixed-unit rounding" (it "carries an upward round into the next date" (let ((rounded (local-date-time-rounded-to (local-date-time-of 2024 2 29 23 31 0) :hours :mode :ceiling))) (expect (local-date-time-year rounded) :to-be 2024) (expect (local-date-time-month rounded) :to-be 3) (expect (local-date-time-day rounded) :to-be 1) (expect (local-date-time-hour rounded) :to-be 0))) (it "uses half-even ties" (expect (local-date-time-hour (local-date-time-rounded-to (local-date-time-of 2024 6 1 12 30 0) :hours :mode :half-even)) :to-be 12))))
