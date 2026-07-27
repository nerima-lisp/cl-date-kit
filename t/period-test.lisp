;;;; t/period-test.lisp
(in-package #:cl-date-kit/test)

(describe "period construction and equality"
  (it "PERIOD-OF-YEARS/MONTHS/DAYS build single-component periods"
    (expect (period= (period-of-years 2) (make-period :years 2)) :to-be-truthy)
    (expect (period= (period-of-months 3) (make-period :months 3)) :to-be-truthy)
    (expect (period= (period-of-days 4) (make-period :days 4)) :to-be-truthy))

  (it "PERIOD-ZERO-P is true only for an all-zero period"
    (expect (period-zero-p (make-period)) :to-be-truthy)
    (expect (period-zero-p (make-period :days 1)) :to-be nil)))

(describe "period arithmetic"
  (it "PERIOD-PLUS adds each component independently"
    (expect (period= (period-plus (make-period :years 1 :months 2 :days 3) (make-period :years 1 :months 11 :days 0))
                      (make-period :years 2 :months 13 :days 3))
            :to-be-truthy))

  (it "PERIOD-NEGATE flips every component's sign"
    (expect (period= (period-negate (make-period :years 1 :months -2 :days 3)) (make-period :years -1 :months 2 :days -3))
            :to-be-truthy))

  (it "PERIOD-NORMALIZED folds YEARS/MONTHS but leaves DAYS untouched"
    (let ((normalized (period-normalized (make-period :months 25 :days 40))))
      (expect (period-years normalized) :to-be 2)
      (expect (period-months normalized) :to-be 1)
      (expect (period-days normalized) :to-be 40)))

  (it "PERIOD-NORMALIZED handles a negative total-months carry correctly"
    (let ((normalized (period-normalized (make-period :years 1 :months -13))))
      (expect (period-years normalized) :to-be 0)
      (expect (period-months normalized) :to-be -1))))
