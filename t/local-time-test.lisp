(in-package #:cl-date-kit/test)

(describe
  "MAKE-LOCAL-TIME validation"
  (it
    "signals INVALID-TIME for fields outside their valid ranges"
    (signals invalid-time (make-local-time 24 0 0))
    (signals invalid-time (make-local-time 0 60 0))
    (signals invalid-time (make-local-time 0 0 60))
    (signals invalid-time (make-local-time 0 0 0 1000000000)))
  (it
    "signals INVALID-TIME for non-integer fields"
    (dolist (time (list (list 1/2 0 0) (list 0 1/2 0) (list 0 0 1/2) (list 0 0 0 1/2)))
      (apply (lambda (hour minute second &optional nanosecond)
               (signals invalid-time (make-local-time hour minute second nanosecond)))
             time)))
  (it
    "LOCAL-TIME-MIDNIGHT and LOCAL-TIME-NOON are the expected fixed points"
    (expect (local-time-hour (local-time-midnight)) :to-be 0)
    (expect (local-time-hour (local-time-noon)) :to-be 12)))

(describe
  "second-of-day conversion"
  (it
    "LOCAL-TIME-OF-SECOND-OF-DAY and LOCAL-TIME-TO-SECOND-OF-DAY round-trip"
    (let ((time (local-time-of-second-of-day 45296)))
      (expect (local-time-hour time) :to-be 12)
      (expect (local-time-minute time) :to-be 34)
      (expect (local-time-second time) :to-be 56)
      (expect (local-time-to-second-of-day time) :to-be 45296)))
  (it
    "rejects invalid second-of-day and nanosecond values"
    (dolist (arguments (list (list -1) (list 86400) (list 0 -1) (list 0 1/2)))
      (apply (lambda (second-of-day &optional nanosecond)
               (signals invalid-time (local-time-of-second-of-day second-of-day nanosecond)))
             arguments))))

(describe
  "nanosecond-of-day conversion and date composition"
  (it
    "LOCAL-TIME-OF-NANO-OF-DAY and LOCAL-TIME-TO-NANO-OF-DAY preserve every field"
    (let ((time (make-local-time 12 34 56 7)))
      (expect (local-time-to-nano-of-day time) :to-be 45296000000007)
      (expect
        (local-time= (local-time-of-nano-of-day (local-time-to-nano-of-day time)) time)
        :to-be-truthy)))
  (it
    "accepts the final nanosecond and rejects invalid offsets"
    (expect
      (local-time=
        (local-time-of-nano-of-day 86399999999999)
        (make-local-time 23 59 59 999999999))
      :to-be-truthy)
    (dolist (nano-of-day (list -1 86400000000000 1/2))
      (signals invalid-time (local-time-of-nano-of-day nano-of-day))))
  (it
    "LOCAL-TIME-AT-DATE pairs the supplied immutable values"
    (expect
      (local-date-time=
        (local-time-at-date (make-local-time 12 34 56 7) (make-local-date 2024 6 15))
        (local-date-time-of 2024 6 15 12 34 56 7))
      :to-be-truthy)))

(describe
  "current local time"
    (it
      "LOCAL-TIME-NOW derives a zone-local time from a fixed clock"
      (expect
        (local-time=
          (local-time-now
            :zone (zone-offset-of-hours 9)
            :clock (make-fixed-clock (make-instant 0 123456789)))
          (make-local-time 9 0 0 123456789))
        :to-be-truthy))
    (it
      "LOCAL-TIME-NOW observes IANA daylight-saving offsets"
      (let ((zone (find-time-zone "America/New_York")))
        (expect
          (local-time=
            (local-time-now
              :zone zone
              :clock (make-fixed-clock (make-instant 1710054000 0)))
            (make-local-time 3 0 0))
          :to-be-truthy))))

(describe
  "arithmetic wraps around midnight without carrying into a date"
  (it
    "LOCAL-TIME-PLUS-HOURS wraps past 23:00"
    (expect
      (local-time=
        (local-time-plus-hours (make-local-time 23 0 0) 2)
        (make-local-time 1 0 0))
      :to-be-truthy))
  (it
    "LOCAL-TIME-MINUS-HOURS wraps before 00:00"
    (expect
      (local-time=
        (local-time-minus-hours (make-local-time 0 30 0) 1)
        (make-local-time 23 30 0))
      :to-be-truthy))
  (it
    "LOCAL-TIME-PLUS-NANOS carries into seconds and minutes"
    (expect
      (local-time=
        (local-time-plus-nanos (make-local-time 0 0 59 999999999) 2)
        (make-local-time 0 1 0 1))
      :to-be-truthy))
  (it
    "LOCAL-TIME millisecond arithmetic wraps at midnight"
    (expect
      (local-time=
        (local-time-plus-millis (make-local-time 23 59 59 999500000) 1)
        (make-local-time 0 0 0 500000))
      :to-be-truthy)
    (expect
      (local-time=
        (local-time-minus-millis (make-local-time 0 0 0 500000) 1)
        (make-local-time 23 59 59 999500000))
      :to-be-truthy))
  (it
    "LOCAL-TIME microsecond arithmetic preserves sub-millisecond precision"
    (expect
      (local-time=
        (local-time-plus-micros (make-local-time 0 0 0 999500000) 750)
        (make-local-time 0 0 1 250000))
      :to-be-truthy)
    (expect
      (local-time=
        (local-time-minus-micros (make-local-time 0 0 1 250000) 750)
        (make-local-time 0 0 0 999500000))
      :to-be-truthy))
  (it
    "second, minute, and nanosecond arithmetic handles reverse and negative deltas"
    (let ((midnight (make-local-time 0 0 0)))
      (expect
        (local-time= (local-time-minus-nanos midnight 1) (make-local-time 23 59 59 999999999))
        :to-be-truthy)
      (expect
        (local-time= (local-time-plus-seconds midnight -1) (make-local-time 23 59 59))
        :to-be-truthy)
      (expect
        (local-time= (local-time-minus-seconds midnight 1) (make-local-time 23 59 59))
        :to-be-truthy)
      (expect
        (local-time= (local-time-plus-minutes midnight -1) (make-local-time 23 59 0))
        :to-be-truthy)
      (expect
        (local-time= (local-time-minus-minutes midnight 1) (make-local-time 23 59 0))
        :to-be-truthy))))

(describe
  "ordering"
  (it
    "comparison predicates agree with nanosecond-precision time-of-day order"
    (let ((earlier (make-local-time 1 0 0))
          (later (make-local-time 1 0 0 1)))
      (expect (local-time< earlier later) :to-be-truthy)
      (expect (local-time> later earlier) :to-be-truthy)
      (expect (local-time= earlier (make-local-time 1 0 0)) :to-be-truthy)
      (expect (local-time<= earlier earlier) :to-be-truthy)
      (expect (local-time>= earlier earlier) :to-be-truthy)
      (expect (local-time-compare earlier later) :to-be -1)))
  (it
    "LOCAL-TIME-UNTIL returns signed nanosecond-precision durations without wrapping"
    (let ((negative-duration
            (local-time-until
              (make-local-time 23 59 59 900000000)
              (make-local-time 0 0 0 100000000)))
          (positive-duration
            (local-time-until
              (make-local-time 0 0 0 900000000)
              (make-local-time 0 0 1 100000000))))
      (expect (duration-seconds negative-duration) :to-be -86400)
      (expect (duration-nanos negative-duration) :to-be 200000000)
      (expect (duration-seconds positive-duration) :to-be 0)
      (expect (duration-nanos positive-duration) :to-be 200000000))))

(progn (describe
  "immutable time field replacement"
  (it
    "LOCAL-TIME-WITH-* replaces exactly the selected field"
    (let ((time (make-local-time 1 2 3 4)))
      (expect
        (local-time=
          (cl-date-kit:local-time-with-hour time 23)
          (make-local-time 23 2 3 4))
        :to-be-truthy)
      (expect
        (local-time=
          (cl-date-kit:local-time-with-minute time 59)
          (make-local-time 1 59 3 4))
        :to-be-truthy)
      (expect
        (local-time=
          (cl-date-kit:local-time-with-second time 58)
          (make-local-time 1 2 58 4))
        :to-be-truthy)
      (expect
        (local-time=
          (cl-date-kit:local-time-with-nanosecond time 999)
          (make-local-time 1 2 3 999))
        :to-be-truthy)))
  (it
    "LOCAL-TIME-WITH-* preserves INVALID-TIME validation"
    (signals
      invalid-time
      (cl-date-kit:local-time-with-hour (make-local-time 1 2 3) 24)))) (describe
  "fixed-unit truncation"
  (it
   "truncates local time without rolling forward"
   (let ((time (make-local-time 12 34 56 789123456)))
     (expect
      (local-time=
       (cl-date-kit:local-time-truncated-to time :minutes)
       (make-local-time 12 34 0))
      :to-be-truthy)
     (expect
      (local-time=
       (cl-date-kit:local-time-truncated-to time :millis)
       (make-local-time 12 34 56 789000000))
      :to-be-truthy)
     (expect
      (local-time=
       (cl-date-kit:local-time-truncated-to time :days)
       (local-time-midnight))
      :to-be-truthy)))
  (it
   "rejects unsupported units"
   (signals
    type-error
    (cl-date-kit:local-time-truncated-to (make-local-time 0 0 0) :weeks)))))

(describe "LocalTime OF constructor" (it "delegates wall-clock field validation to MAKE-LOCAL-TIME" (expect (local-time= (cl-date-kit:local-time-of 23 59 59 1) (make-local-time 23 59 59 1)) :to-be-truthy) (signals invalid-time (cl-date-kit:local-time-of 24 0 0))))

(progn (describe
 "LocalTime truncation contract"
 (it
  "truncates every supported fixed unit"
  (let ((time (make-local-time 12 34 56 789123456)))
   (dolist (scenario (quote ((:nanos 12 34 56 789123456)
                              (:micros 12 34 56 789123000)
                              (:millis 12 34 56 789000000)
                              (:seconds 12 34 56 0)
                              (:minutes 12 34 0 0)
                              (:hours 12 0 0 0)
                              (:days 0 0 0 0))))
    (destructuring-bind (unit hour minute second nanosecond) scenario
     (expect
      (local-time=
       (cl-date-kit:local-time-truncated-to time unit)
       (make-local-time hour minute second nanosecond))
      :to-be-truthy)))))
 (it
  "signals TYPE-ERROR for invalid values and units"
  (signals type-error (cl-date-kit:local-time-truncated-to 0 :seconds))
  (signals
   type-error
   (cl-date-kit:local-time-truncated-to (make-local-time 0 0 0) :weeks)))) (describe "LocalTime fixed-unit rounding" (it "uses tie modes and wraps upward at midnight" (expect (local-time-hour (local-time-rounded-to (make-local-time 12 30 0) :hours :mode :half-even)) :to-be 12) (expect (local-time-hour (local-time-rounded-to (make-local-time 12 30 0) :hours :mode :half-up)) :to-be 13) (let ((rounded (local-time-rounded-to (make-local-time 23 31 0) :hours :mode :ceiling))) (expect (local-time-hour rounded) :to-be 0) (expect (local-time-minute rounded) :to-be 0)))))
