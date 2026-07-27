;;;; t/instant-test.lisp
(in-package #:cl-date-kit/test)

(describe "construction"
  (it "MAKE-INSTANT normalizes an out-of-range nanosecond into EPOCH-SECOND"
    (let ((i (make-instant 0 -1)))
      (expect (instant-epoch-second i) :to-be -1)
      (expect (instant-nanosecond i) :to-be 999999999)))

  (it "INSTANT-EPOCH is 1970-01-01T00:00:00Z"
    (expect (instant-epoch-second (instant-epoch)) :to-be 0)
    (expect (instant-nanosecond (instant-epoch)) :to-be 0)))

(describe "arithmetic"
  (it "INSTANT-PLUS-DURATION and INSTANT-UNTIL are inverses"
    (let ((start (make-instant 1000)) (end (make-instant 2500)))
      (expect (instant= (instant-plus-duration start (instant-until start end)) end) :to-be-truthy)))

  (it "INSTANT-MINUS-DURATION undoes INSTANT-PLUS-DURATION"
    (let ((start (make-instant 1000 500000000)) (d (duration-of-seconds 10 750000000)))
      (expect (instant= (instant-minus-duration (instant-plus-duration start d) d) start) :to-be-truthy))))

(describe "ordering"
  (it "INSTANT< / INSTANT> / INSTANT= agree with epoch order"
    (expect (instant< (make-instant 1) (make-instant 2)) :to-be-truthy)
    (expect (instant> (make-instant 2) (make-instant 1)) :to-be-truthy)
    (expect (instant= (make-instant 1 500) (make-instant 1 500)) :to-be-truthy)))
