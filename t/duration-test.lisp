;;;; t/duration-test.lisp
(in-package #:cl-date-kit/test)

(describe "duration constructors"
  (it "DURATION-OF-HOURS converts to seconds"
    (expect (duration-to-seconds (duration-of-hours 1)) :to-be 3600))

  (it "DURATION-OF-MILLIS normalizes a negative sub-second remainder into NANOS"
    (expect (duration-to-seconds (duration-of-millis -1500)) :to-be -3/2))

  (it "DURATION-ZERO has zero seconds and nanos"
    (expect (duration-zero-p (duration-zero)) :to-be-truthy)))

(describe "duration arithmetic"
  (it "DURATION-PLUS adds exactly, carrying nanos into seconds"
    (expect (duration-to-seconds (duration-plus (duration-of-seconds 1 700000000) (duration-of-seconds 1 700000000)))
            :to-be 34/10))

  (it "DURATION-MINUS is the inverse of DURATION-PLUS"
    (let ((a (duration-of-seconds 5 250000000)) (b (duration-of-seconds 2 500000000)))
      (expect (duration= (duration-minus (duration-plus a b) b) a) :to-be-truthy)))

  (it "DURATION-NEGATE flips the sign of a fractional duration"
    (expect (duration-to-seconds (duration-negate (duration-of-millis 1500))) :to-be -3/2))

  (it "DURATION-ABS is idempotent on an already-positive duration"
    (expect (duration= (duration-abs (duration-of-seconds 5)) (duration-of-seconds 5)) :to-be-truthy))

  (it "DURATION-ABS negates a negative duration"
    (expect (duration= (duration-abs (duration-of-seconds -5)) (duration-of-seconds 5)) :to-be-truthy)))

(describe "duration predicates and ordering"
  (it "DURATION-NEGATIVE-P is true only for a negative duration"
    (expect (duration-negative-p (duration-of-seconds -1)) :to-be-truthy)
    (expect (duration-negative-p (duration-of-seconds 0)) :to-be nil)
    (expect (duration-negative-p (duration-of-seconds 1)) :to-be nil))

  (it "DURATION-POSITIVE-P is true only for a positive duration"
    (expect (duration-positive-p (duration-of-seconds 1)) :to-be-truthy)
    (expect (duration-positive-p (duration-of-seconds 0)) :to-be nil))

  (it "DURATION< / DURATION> / DURATION= agree with DURATION-COMPARE"
    (expect (duration< (duration-of-seconds 1) (duration-of-seconds 2)) :to-be-truthy)
    (expect (duration> (duration-of-seconds 2) (duration-of-seconds 1)) :to-be-truthy)
    (expect (duration= (duration-of-seconds 2) (duration-of-seconds 2)) :to-be-truthy)
    (expect (duration<= (duration-of-seconds 2) (duration-of-seconds 2)) :to-be-truthy)
    (expect (duration>= (duration-of-seconds 2) (duration-of-seconds 2)) :to-be-truthy)))
