;;;; t/year-month-test.lisp

(in-package #:cl-date-kit/test)

(describe "YearMonth"
  (it "validates calendar fields and proleptic month indexes"
    (expect (year-month-year (make-year-month 2024 2)) :to-be 2024)
    (expect (year-month-month (make-year-month 2024 2)) :to-be 2)
    (signals invalid-year-month (make-year-month 2024 13))
    (signals invalid-year-month (make-year-month 2024 1.5))
    (signals invalid-year-month (year-month-from-proleptic-month 1.5)))

  (it-each
      ((-25) (-13) (-12) (-1) (0) (1) (11) (12) (24288))
      "round-trips the proleptic month index ~A"
      (index)
    (expect (year-month-to-proleptic-month
             (year-month-from-proleptic-month index))
            :to-be index))

  (it "derives the current year-month from an injected clock and zone"
    (let ((clock (make-fixed-clock (make-instant 0))))
      (expect (year-month= (year-month-now :clock clock)
                           (make-year-month 1970 1))
              :to-be-truthy)
      (expect (year-month= (year-month-now :clock clock :zone (zone-offset-of-hours -1))
                           (make-year-month 1969 12))
              :to-be-truthy)))

  (it "adds and subtracts months and years across year zero"
    (let ((value (make-year-month 2024 1)))
      (expect (year-month= (year-month-plus-months value -1)
                           (make-year-month 2023 12))
              :to-be-truthy)
      (expect (year-month= (year-month-minus-months value 13)
                           (make-year-month 2022 12))
              :to-be-truthy)
      (expect (year-month= (year-month-plus-years value 2)
                           (make-year-month 2026 1))
              :to-be-truthy)
      (expect (year-month= (year-month-minus-years value 2)
                           (make-year-month 2022 1))
              :to-be-truthy)
      (signals invalid-year-month (year-month-plus-months value 1.5))
      (signals invalid-year-month (year-month-minus-months value 1.5))
      (signals invalid-year-month (year-month-plus-years value 1.5))
      (signals invalid-year-month (year-month-minus-years value 1.5))))

  (it "derives dates with correct month lengths"
    (let ((february (make-year-month 2024 2))
          (common-february (make-year-month 2023 2)))
      (expect (year-month-length-of-month february) :to-be 29)
      (expect (year-month-valid-day-p february 29) :to-be-truthy)
      (expect (not (year-month-valid-day-p common-february 29)) :to-be-truthy)
      (expect (not (year-month-valid-day-p february 0)) :to-be-truthy)
      (expect (not (year-month-valid-day-p february 29.0)) :to-be-truthy)
      (expect (local-date-day (year-month-at-end-of-month february)) :to-be 29)
      (signals invalid-date (year-month-at-day february 30))))

  (it "derives leap-year and year length from its year field"
    (let ((leap-february (make-year-month 2024 2))
          (common-february (make-year-month 2023 2)))
      (expect (year-month-leap-year-p leap-february) :to-be-truthy)
      (expect (year-month-leap-year-p common-february) :to-be nil)
      (expect (year-month-length-of-year leap-february) :to-be 366)
      (expect (year-month-length-of-year common-february) :to-be 365)))

  (it "converts LocalDate, compares values, and replaces immutable fields"
    (let ((earlier (year-month-from-local-date (make-local-date 2024 6 15)))
          (later (make-year-month 2025 1)))
      (expect (year-month= earlier (make-year-month 2024 6)) :to-be-truthy)
      (expect (year-month-until earlier later) :to-be 7)
      (expect (year-month-compare earlier later) :to-be -1)
      (expect (year-month-compare later earlier) :to-be 1)
      (expect (year-month-compare earlier (make-year-month 2024 6)) :to-be 0)
      (expect (year-month< earlier later) :to-be-truthy)
      (expect (year-month<= earlier earlier) :to-be-truthy)
      (expect (year-month> later earlier) :to-be-truthy)
      (expect (year-month>= later later) :to-be-truthy)
      (expect (year-month= (year-month-with-year earlier 2020)
                           (make-year-month 2020 6))
              :to-be-truthy)
      (expect (year-month= (year-month-with-month earlier 12)
                           (make-year-month 2024 12))
              :to-be-truthy)
      (signals invalid-year-month (year-month-with-year earlier 1.5))
      (signals invalid-year-month (year-month-with-month earlier 13))))

  (it "constructs aliases and derived values without changing the original"
    (let* ((value (year-month-of 2024 2))
           (changed-year (year-month-with-year value 2020))
           (changed-month (year-month-with-month value 12)))
      (expect (year-month= value (make-year-month 2024 2)) :to-be-truthy)
      (expect (year-month= changed-year (make-year-month 2020 2)) :to-be-truthy)
      (expect (year-month= changed-month (make-year-month 2024 12)) :to-be-truthy)
      (expect (year-month-year value) :to-be 2024)
      (expect (year-month-month value) :to-be 2)))

  (it "builds LocalDate values and reports false ordering predicates"
    (let ((earlier (year-month-of 2024 2))
          (later (year-month-of 2024 3)))
      (expect (local-date-p (year-month-at-day earlier 29)) :to-be-truthy)
      (signals invalid-date (year-month-at-day earlier 29.0))
      (expect (year-month= earlier later) :to-be nil)
      (expect (year-month< later earlier) :to-be nil)
      (expect (year-month<= later earlier) :to-be nil)
      (expect (year-month> earlier later) :to-be nil)
      (expect (year-month>= earlier later) :to-be nil)))
)
