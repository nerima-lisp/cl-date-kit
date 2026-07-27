;;;; t/local-time-test.lisp
(in-package #:cl-date-kit/test)

(describe "MAKE-LOCAL-TIME validation"
  (it "signals INVALID-TIME for an hour outside 0-23"
    (signals invalid-time (make-local-time 24 0 0)))

  (it "signals INVALID-TIME for a second outside 0-59 (no leap seconds)"
    (signals invalid-time (make-local-time 23 59 60)))

  (it "LOCAL-TIME-MIDNIGHT and LOCAL-TIME-NOON are the expected fixed points"
    (expect (local-time-hour (local-time-midnight)) :to-be 0)
    (expect (local-time-hour (local-time-noon)) :to-be 12)))

(describe "second-of-day conversion"
  (it "LOCAL-TIME-OF-SECOND-OF-DAY and LOCAL-TIME-TO-SECOND-OF-DAY round-trip"
    (let ((time (local-time-of-second-of-day 45296)))
      (expect (local-time-hour time) :to-be 12)
      (expect (local-time-minute time) :to-be 34)
      (expect (local-time-second time) :to-be 56)
      (expect (local-time-to-second-of-day time) :to-be 45296)))
  (it "LOCAL-TIME-OF-SECOND-OF-DAY rejects 86400"
    (signals invalid-time (local-time-of-second-of-day 86400))))

(describe "arithmetic wraps around midnight without carrying into a date"
  (it "LOCAL-TIME-PLUS-HOURS wraps past 23:00"
    (expect (local-time= (local-time-plus-hours (make-local-time 23 0 0) 2) (make-local-time 1 0 0)) :to-be-truthy))

  (it "LOCAL-TIME-MINUS-HOURS wraps before 00:00"
    (expect (local-time= (local-time-minus-hours (make-local-time 0 30 0) 1) (make-local-time 23 30 0)) :to-be-truthy))

  (it "LOCAL-TIME-PLUS-NANOS carries into seconds and minutes"
    (expect (local-time= (local-time-plus-nanos (make-local-time 0 0 59 999999999) 2) (make-local-time 0 1 0 1))
            :to-be-truthy)))

(describe "ordering"
  (it "LOCAL-TIME< / LOCAL-TIME> / LOCAL-TIME= agree with time-of-day order"
    (expect (local-time< (make-local-time 1 0 0) (make-local-time 2 0 0)) :to-be-truthy)
    (expect (local-time> (make-local-time 2 0 0) (make-local-time 1 0 0)) :to-be-truthy)
    (expect (local-time= (make-local-time 1 0 0) (make-local-time 1 0 0)) :to-be-truthy)))
