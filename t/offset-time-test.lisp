;;;; t/offset-time-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "OffsetTime"
  (it
    "constructs fixed-offset times and exposes their fields"
    (let ((value (offset-time-of 12 34 56 123000000 (zone-offset-of-hours 9))))
      (expect (offset-time-hour value) :to-be 12)
      (expect (offset-time-nanosecond value) :to-be 123000000)
      (expect (zone-offset-total-seconds (offset-time-offset value)) :to-be 32400)))
  (it
    "changes offsets by instant or by local time"
    (let* ((original (offset-time-of 12 0 0 0 (zone-offset-of-hours 9)))
           (same-instant (offset-time-with-offset-same-instant original (zone-offset-utc)))
           (same-local (offset-time-with-offset-same-local original (zone-offset-utc))))
      (expect (offset-time-hour same-instant) :to-be 3)
      (expect (offset-time-hour same-local) :to-be 12)
      (expect
        (offset-time= same-instant (offset-time-of 3 0 0 0 (zone-offset-utc)))
        :to-be-truthy)))
  (it
    "wraps elapsed-time arithmetic within a day"
    (let ((value (offset-time-of 23 30 0 0 (zone-offset-of-hours -4))))
      (expect
        (offset-time-hour (offset-time-plus-duration value (duration-of-hours 2)))
        :to-be
        1)
      (expect
        (offset-time-minute (offset-time-minus-duration value (duration-of-minutes 45)))
        :to-be
        45)))
  (it
    "orders equivalent UTC times by local time to remain total"
    (let ((plus-one (offset-time-of 12 0 0 0 (zone-offset-of-hours 1)))
          (utc (offset-time-of 11 0 0 0 (zone-offset-utc))))
      (expect (offset-time> plus-one utc) :to-be-truthy)
      (expect (offset-time= plus-one utc) :to-be-falsy)))
  (it
    "uses the supplied clock for NOW"
    (let ((value
          (offset-time-now
            :clock
            (make-fixed-clock (make-instant 0 42))
            :offset
            (zone-offset-of-hours 9))))
      (expect (offset-time-hour value) :to-be 9)
      (expect (offset-time-nanosecond value) :to-be 42)))
  (it
    "combines its date, local time, and fixed offset"
    (let ((value
          (cl-date-kit:offset-time-at-date
            (offset-time-of 23 59 58 7 (zone-offset-of-hours -3))
            (make-local-date 2024 2 29))))
      (expect
        (cl-date-kit:local-date=
          (cl-date-kit:offset-date-time-date value)
          (make-local-date 2024 2 29))
        :to-be-truthy)
      (expect
        (cl-date-kit:local-time=
          (cl-date-kit:offset-date-time-time value)
          (make-local-time 23 59 58 7))
        :to-be-truthy)
      (expect
        (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset value))
        :to-be
        -10800)))
  (it
    "returns the UTC time-of-day duration without the comparison tie breaker"
    (let ((plus-one (offset-time-of 12 0 0 0 (zone-offset-of-hours 1)))
          (utc (offset-time-of 11 0 0 0 (zone-offset-utc)))
          (start (offset-time-of 12 0 0 900000000 (zone-offset-of-hours 9)))
          (end (offset-time-of 3 0 1 100000000 (zone-offset-utc))))
      (expect (duration-zero-p (offset-time-until plus-one utc)) :to-be-truthy)
      (expect (duration-seconds (offset-time-until start end)) :to-be 0)
      (expect (duration-nanos (offset-time-until start end)) :to-be 200000000)))) (progn (describe "OffsetTime fixed-unit arithmetic" (it "wraps fixed-unit arithmetic and preserves the offset" (let* ((offset (zone-offset-of-hours -4)) (value (offset-time-of 23 59 59 999500000 offset)) (millis (offset-time-plus-millis value 1)) (micros (offset-time-plus-micros value 750)) (hours (offset-time-plus-hours value 2))) (expect (offset-time-hour millis) :to-be 0) (expect (offset-time-nanosecond millis) :to-be 500000) (expect (offset-time-hour micros) :to-be 0) (expect (offset-time-nanosecond micros) :to-be 250000) (expect (offset-time-hour hours) :to-be 1) (expect (zone-offset-total-seconds (offset-time-offset millis)) :to-be -14400))) (it "reverses every fixed unit" (let ((value (offset-time-of 0 0 0 0 (zone-offset-utc)))) (expect (offset-time-hour (offset-time-minus-hours value 1)) :to-be 23) (expect (offset-time-minute (offset-time-minus-minutes value 1)) :to-be 59) (expect (offset-time-second (offset-time-minus-seconds value 1)) :to-be 59) (expect (offset-time-nanosecond (offset-time-minus-millis value 1)) :to-be 999000000) (expect (offset-time-nanosecond (offset-time-minus-micros value 1)) :to-be 999999000) (expect (offset-time-nanosecond (offset-time-minus-nanos value 1)) :to-be 999999999)))) (describe
  "fixed-unit truncation"
  (it
   "truncates local time while preserving the fixed offset"
   (let* ((offset (zone-offset-of-hours 9))
          (result
           (cl-date-kit:offset-time-truncated-to
            (offset-time-of 12 34 56 789123456 offset)
            :minutes)))
     (expect (offset-time-hour result) :to-be 12)
     (expect (offset-time-minute result) :to-be 34)
     (expect (offset-time-second result) :to-be 0)
     (expect
      (zone-offset-total-seconds (offset-time-offset result))
      :to-be
      32400))))

(describe
  "OffsetTime field replacement"
  (it
    "replaces local fields without changing the fixed offset or source value"
    (let* ((offset (zone-offset-of-hours 9))
           (value (offset-time-of 12 34 56 789 offset))
           (result
             (cl-date-kit:offset-time-with-nanosecond
               (cl-date-kit:offset-time-with-second
                 (cl-date-kit:offset-time-with-minute
                   (cl-date-kit:offset-time-with-hour value 1)
                   2)
                 3)
               4)))
      (expect (offset-time-hour result) :to-be 1)
      (expect (offset-time-minute result) :to-be 2)
      (expect (offset-time-second result) :to-be 3)
      (expect (offset-time-nanosecond result) :to-be 4)
      (expect (zone-offset-total-seconds (offset-time-offset result)) :to-be 32400)
      (expect (offset-time-hour value) :to-be 12)
      (expect (offset-time-nanosecond value) :to-be 789)))
  (it
    "uses LocalTime field validation"
    (signals
      invalid-time
      (cl-date-kit:offset-time-with-hour (offset-time-of 12 0 0) 24))))

(describe
  "LocalTime at offset"
  (it
    "preserves local fields and the supplied fixed offset"
    (let* ((time (make-local-time 12 34 56 789123456))
           (offset (zone-offset-of-hours -4))
           (value (cl-date-kit:local-time-at-offset time offset)))
      (expect (offset-time-hour value) :to-be 12)
      (expect (offset-time-minute value) :to-be 34)
      (expect (offset-time-second value) :to-be 56)
      (expect (offset-time-nanosecond value) :to-be 789123456)
      (expect (zone-offset-total-seconds (offset-time-offset value)) :to-be -14400)))
  (it
    "uses MAKE-OFFSET-TIME type validation"
    (signals
      type-error
      (cl-date-kit:local-time-at-offset 0 (zone-offset-utc)))
    (signals
      type-error
      (cl-date-kit:local-time-at-offset (make-local-time 12 0 0) 0)))))

(progn (describe
 "OffsetTime truncation contract"
 (it
  "truncates every supported fixed unit while retaining the offset"
  (let* ((offset (zone-offset-of-hours -4))
         (value (offset-time-of 12 34 56 789123456 offset)))
   (dolist (scenario (quote ((:nanos 12 34 56 789123456)
                              (:micros 12 34 56 789123000)
                              (:millis 12 34 56 789000000)
                              (:seconds 12 34 56 0)
                              (:minutes 12 34 0 0)
                              (:hours 12 0 0 0)
                              (:days 0 0 0 0))))
    (destructuring-bind (unit hour minute second nanosecond) scenario
     (expect
      (offset-time=
       (cl-date-kit:offset-time-truncated-to value unit)
       (offset-time-of hour minute second nanosecond offset))
      :to-be-truthy)))))
 (it
  "signals TYPE-ERROR for invalid values and units"
  (signals type-error (cl-date-kit:offset-time-truncated-to 0 :seconds))
  (signals
   type-error
   (cl-date-kit:offset-time-truncated-to
    (offset-time-of 0 0 0 0 (zone-offset-utc))
    :weeks)))) (describe "OffsetTime UTC day boundaries" (it "handles offset conversion, instant projection, duration, and comparisons across UTC day boundaries" (let ((value (offset-time-with-offset-same-instant (offset-time-of 0 15 30 987654321 (zone-offset-of-hours 1)) (zone-offset-of-hours -2)))) (expect (offset-time-hour value) :to-be 21) (expect (offset-time-minute value) :to-be 15) (expect (offset-time-second value) :to-be 30) (expect (offset-time-nanosecond value) :to-be 987654321)) (let* ((instant (make-instant -1 123456789)) (offset (zone-offset-of-hms -3 -30 0)) (from-instant (offset-time-of-instant instant offset)) (from-clock (offset-time-now :clock (make-fixed-clock instant) :offset offset))) (dolist (value (list from-instant from-clock)) (expect (offset-time-hour value) :to-be 20) (expect (offset-time-minute value) :to-be 29) (expect (offset-time-second value) :to-be 59) (expect (offset-time-nanosecond value) :to-be 123456789))) (let ((duration (duration-between (offset-time-of 23 30 0 100000000 (zone-offset-utc)) (offset-time-of 0 30 0 900000000 (zone-offset-utc))))) (expect (duration-seconds duration) :to-be -82800) (expect (duration-nanos duration) :to-be 800000000)) (let ((utc-early (offset-time-of 23 30 0 0 (zone-offset-of-hours 2))) (utc-late (offset-time-of 0 30 0 0 (zone-offset-of-hours -2)))) (expect (offset-time> utc-early utc-late) :to-be-truthy) (expect (offset-time< utc-late utc-early) :to-be-truthy) (expect (offset-time>= utc-early utc-late) :to-be-truthy) (expect (offset-time<= utc-late utc-early) :to-be-truthy)))))

(progn (describe "OffsetTime equality and constructor contracts" (it "treats matching local and UTC times as equal" (let* ((offset (zone-offset-of-hours 9)) (a (offset-time-of 12 0 0 0 offset)) (b (offset-time-of 12 0 0 0 offset))) (expect (offset-time-compare a b) :to-be 0) (expect (offset-time= a b) :to-be-truthy) (expect (offset-time<= a b) :to-be-truthy) (expect (offset-time>= a b) :to-be-truthy) (expect (offset-time< a b) :to-be-falsy) (expect (offset-time> a b) :to-be-falsy) (expect (duration-zero-p (offset-time-until a b)) :to-be-truthy))) (it "validates constructor argument types" (signals type-error (make-offset-time 0 (zone-offset-utc))) (signals type-error (make-offset-time (make-local-time 12 0 0) 0)))) (describe "OffsetTime fixed-unit rounding" (it "preserves both positive and negative offsets" (let ((east (offset-time-rounded-to (offset-time-of 23 31 0 0 (zone-offset-of-hours 9)) :hours :mode :ceiling)) (west (offset-time-rounded-to (offset-time-of 12 30 0 0 (zone-offset-of-hours -5)) :hours :mode :half-up))) (expect (offset-time-hour east) :to-be 0) (expect (zone-offset-total-seconds (offset-time-offset east)) :to-be 32400) (expect (offset-time-hour west) :to-be 13) (expect (zone-offset-total-seconds (offset-time-offset west)) :to-be -18000)))))
