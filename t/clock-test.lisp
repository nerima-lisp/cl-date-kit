;;;; t/clock-test.lisp
(in-package #:cl-date-kit/test)

(describe "FIXED-CLOCK"
  (it "CLOCK-NOW always returns the instant it was built with"
    (let ((clock (make-fixed-clock (make-instant 42 7))))
      (expect (instant= (clock-now clock) (make-instant 42 7)) :to-be-truthy)
      (expect (instant= (clock-now clock) (make-instant 42 7)) :to-be-truthy))))

(describe "SYSTEM-CLOCK"
  (it "CLOCK-NOW returns a recent instant"
    (expect (> (instant-epoch-second (clock-now (make-system-clock))) 1700000000) :to-be-truthy))

  (it "INSTANT-NOW defaults to a system clock"
    (expect (> (instant-epoch-second (instant-now)) 1700000000) :to-be-truthy))

  (it "INSTANT-NOW accepts an explicit clock, e.g. a fixed one for deterministic tests"
    (expect (instant= (instant-now (make-fixed-clock (instant-epoch))) (instant-epoch)) :to-be-truthy)))
