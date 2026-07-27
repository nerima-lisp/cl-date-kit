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
    (expect (offset-time= same-instant (offset-time-of 3 0 0 0 (zone-offset-utc))) :to-be-truthy)))
 (it
  "wraps elapsed-time arithmetic within a day"
  (let ((value (offset-time-of 23 30 0 0 (zone-offset-of-hours -4))))
    (expect (offset-time-hour (offset-time-plus-duration value (duration-of-hours 2))) :to-be 1)
    (expect (offset-time-minute (offset-time-minus-duration value (duration-of-minutes 45))) :to-be 45)))
 (it
  "orders equivalent UTC times by local time to remain total"
  (let ((plus-one (offset-time-of 12 0 0 0 (zone-offset-of-hours 1)))
        (utc (offset-time-of 11 0 0 0 (zone-offset-utc))))
    (expect (offset-time> plus-one utc) :to-be-truthy)
    (expect (offset-time= plus-one utc) :to-be-falsy)))
 (it
  "uses the supplied clock for NOW"
  (let ((value (offset-time-now :clock (make-fixed-clock (make-instant 0 42))
                                :offset (zone-offset-of-hours 9))))
    (expect (offset-time-hour value) :to-be 9)
    (expect (offset-time-nanosecond value) :to-be 42))))
