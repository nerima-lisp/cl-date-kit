(in-package #:cl-date-kit/test)

(progn
  (describe
    "period construction and equality"
    (it
      "PERIOD-OF-YEARS/MONTHS/DAYS build single-component periods"
      (expect (period= (period-of-years 2) (make-period :years 2)) :to-be-truthy)
      (expect (period= (period-of-months 3) (make-period :months 3)) :to-be-truthy)
      (expect (period= (period-of-days 4) (make-period :days 4)) :to-be-truthy))
    (it
      "PERIOD-OF constructs all calendar components"
      (expect
        (period= (period-of 1 -2 3) (make-period :years 1 :months -2 :days 3))
        :to-be-truthy))
    (it
      "PERIOD-BETWEEN delegates to LocalDate calendar arithmetic"
      (expect
        (period=
          (period-between (make-local-date 2020 1 31) (make-local-date 2021 3 1))
          (period-of 1 1 1))
        :to-be-truthy))
    (it
      "PERIOD-ZERO-P is true only for an all-zero period"
      (expect (period-zero-p (make-period)) :to-be-truthy)
      (expect (period-zero-p (make-period :days 1)) :to-be nil))
    (it
      "PERIOD-WITH-* replaces one component without mutating the source value"
      (let ((period (period-of 1 -2 3)))
        (expect (period= (period-with-years period 4) (period-of 4 -2 3)) :to-be-truthy)
        (expect (period= (period-with-months period 5) (period-of 1 5 3)) :to-be-truthy)
        (expect (period= (period-with-days period -6) (period-of 1 -2 -6)) :to-be-truthy)
        (expect (period= period (period-of 1 -2 3)) :to-be-truthy)))
  (describe
    "period constructor type contract"
    (it
      "rejects non-integral components at every public entry point"
      (signals type-error (make-period :years 1/2))
      (signals type-error (make-period :months 1/2))
      (signals type-error (make-period :days 1/2))
      (signals type-error (period-of-years 1/2))
      (signals type-error (period-of-months 1/2))
      (signals type-error (period-of-days 1/2))
      (signals type-error (period-of 1/2 0 0))
      (signals type-error (period-of 0 1/2 0))
      (signals type-error (period-of 0 0 1/2))
      (signals type-error (period-with-years (make-period) 1/2))
      (signals type-error (period-with-months (make-period) 1/2))
      (signals type-error (period-with-days (make-period) 1/2)))))
  (describe
    "period boundary and type contracts"
    (it
      "PERIOD= distinguishes component layouts with equal total months"
      (expect (period= (period-of 1 0 0) (period-of 0 12 0)) :to-be-falsy)
      (expect (period= (period-of 0 0 1) (period-of 0 0 2)) :to-be-falsy))
    (it
      "a zero period is not negative and is unchanged by PERIOD-ABS"
      (let ((zero (period-of 0 0 0)))
        (expect (period-zero-p zero) :to-be-truthy)
        (expect (period-negative-p zero) :to-be-falsy)
        (expect (period= (period-abs zero) zero) :to-be-truthy)))
    (it
      "PERIOD-NORMALIZED handles opposing year and month signs"
      (let ((positive (period-normalized (period-of -1 25 9)))
            (negative (period-normalized (period-of 1 -25 -9))))
        (expect (period= positive (period-of 1 1 9)) :to-be-truthy)
        (expect (period= negative (period-of -1 -1 -9)) :to-be-truthy)))
    (it
      "period predicates and normalizers reject non-period values"
      (signals type-error (period= (make-period) 0))
      (signals type-error (period-zero-p 0))
      (signals type-error (period-negative-p 0))
      (signals type-error (period-abs 0))
      (signals type-error (period-normalized 0))))
)

(describe
  "period arithmetic"
  (it
    "PERIOD-PLUS/MINUS-* updates only the requested component"
    (let ((period (period-of 1 11 -3)))
      (expect (period= (period-plus-years period 4) (period-of 5 11 -3)) :to-be-truthy)
      (expect (period= (period-plus-months period 2) (period-of 1 13 -3)) :to-be-truthy)
      (expect (period= (period-plus-days period 5) (period-of 1 11 2)) :to-be-truthy)
      (expect (period= (period-minus-years period 3) (period-of -2 11 -3)) :to-be-truthy)
      (expect (period= (period-minus-months period 14) (period-of 1 -3 -3)) :to-be-truthy)
      (expect (period= (period-minus-days period 4) (period-of 1 11 -7)) :to-be-truthy)
      (expect (period= period (period-of 1 11 -3)) :to-be-truthy)))
  (it
    "PERIOD-PLUS/MINUS-* require integral amounts"
    (signals type-error (period-plus-years (make-period) 1/2))
    (signals type-error (period-plus-months (make-period) 1/2))
    (signals type-error (period-plus-days (make-period) 1/2))
    (signals type-error (period-minus-years (make-period) 1/2))
    (signals type-error (period-minus-months (make-period) 1/2))
    (signals type-error (period-minus-days (make-period) 1/2)))
  (it
    "PERIOD-PLUS adds each component independently"
    (expect
      (period=
        (period-plus
          (make-period :years 1 :months 2 :days 3)
          (make-period :years 1 :months 11 :days 0))
        (make-period :years 2 :months 13 :days 3))
      :to-be-truthy))
  (it
    "PERIOD-MINUS subtracts each component independently"
    (expect
      (period=
        (period-minus
          (make-period :years 3 :months 2 :days 1)
          (make-period :years 1 :months -4 :days 5))
        (make-period :years 2 :months 6 :days -4))
      :to-be-truthy))
  (it
    "PERIOD-MULTIPLIED-BY scales all components by an integer"
    (expect
      (period=
        (period-multiplied-by (make-period :years -1 :months 2 :days -3) 4)
        (make-period :years -4 :months 8 :days -12))
      :to-be-truthy)
    (expect
      (period-zero-p
        (period-multiplied-by (make-period :years 1 :months 2 :days 3) 0))
      :to-be-truthy)
    (signals type-error (period-multiplied-by (make-period) 1/2)))
  (it
    "PERIOD-ABS uses the absolute value of every component"
    (expect
      (period=
        (period-abs (make-period :years -1 :months 2 :days -3))
        (make-period :years 1 :months 2 :days 3))
      :to-be-truthy))
  (it
    "PERIOD-NEGATIVE-P is true when any component is negative"
    (expect (period-negative-p (make-period :months -1 :days 2)) :to-be-truthy)
    (expect (period-negative-p (make-period :years 1 :months 2 :days 3)) :to-be nil))
  (it
    "PERIOD-TO-TOTAL-MONTHS ignores days and preserves the sign"
    (expect
      (period-to-total-months (make-period :years 2 :months 3 :days 99))
      :to-be
      27)
    (expect (period-to-total-months (make-period :years -2 :months -3)) :to-be -27))
  (it
    "PERIOD-NEGATE flips the sign of every component"
    (expect
      (period=
        (period-negate (make-period :years 1 :months -2 :days 3))
        (make-period :years -1 :months 2 :days -3))
      :to-be-truthy))
  (it
    "PERIOD-NORMALIZED folds YEARS/MONTHS but leaves DAYS untouched"
    (let ((normalized (period-normalized (make-period :months 25 :days 40))))
      (expect (period-years normalized) :to-be 2)
      (expect (period-months normalized) :to-be 1)
      (expect (period-days normalized) :to-be 40)))
  (it
    "PERIOD-NORMALIZED handles a negative total-months carry correctly"
    (let ((normalized (period-normalized (make-period :years 1 :months -13))))
      (expect (period-years normalized) :to-be 0)
      (expect (period-months normalized) :to-be -1))))

(describe "period week construction"
  (it "PERIOD-OF-WEEKS converts integral weeks to days"
    (expect (period= (period-of-weeks 0) (period-of-days 0)) :to-be-truthy)
    (expect (period= (period-of-weeks 3) (period-of-days 21)) :to-be-truthy)
    (expect (period= (period-of-weeks -2) (period-of-days -14)) :to-be-truthy))
  (it-each
      ((0) (3) (-2))
      "PERIOD-OF-WEEKS ~A has no year or month component"
      (weeks)
    (let ((period (period-of-weeks weeks)))
      (expect (= (period-years period) 0) :to-be-truthy)
      (expect (= (period-months period) 0) :to-be-truthy)))
  (it "PERIOD-OF-WEEKS rejects non-integral values" (signals type-error (period-of-weeks 1/2))))
