;;;; t/year-month-test.lisp

(in-package #:cl-date-kit/test)

(describe
  "YearMonth"
  (it "validates its calendar fields"
    (expect (year-month-year (make-year-month 2024 2)) :to-be 2024)
    (expect (year-month-month (make-year-month 2024 2)) :to-be 2)
    (signals invalid-year-month (make-year-month 2024 13))
    (signals invalid-year-month (make-year-month 2024 1.5)))
  (it "round-trips signed proleptic month indexes"
    (dolist (index '(-1 0 1 24288))
      (expect (year-month-to-proleptic-month
               (year-month-from-proleptic-month index))
              :to-be index)))
  (it "adds and subtracts months across year zero"
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
              :to-be-truthy)))
  (it "derives dates with correct month lengths"
    (let ((february (make-year-month 2024 2)))
      (expect (year-month-length-of-month february) :to-be 29)
      (expect (local-date-day (year-month-at-end-of-month february)) :to-be 29)
      (signals invalid-date (year-month-at-day february 30))))
  (it "converts LocalDate, compares values, and replaces immutable fields"
    (let ((value (year-month-from-local-date (make-local-date 2024 6 15))))
      (expect (year-month= value (make-year-month 2024 6)) :to-be-truthy)
      (expect (year-month-until value (make-year-month 2025 1)) :to-be 7)
      (expect (year-month< value (make-year-month 2025 1)) :to-be-truthy)
      (expect (year-month= (year-month-with-year value 2020)
                           (make-year-month 2020 6))
              :to-be-truthy)
      (expect (year-month= (year-month-with-month value 12)
                           (make-year-month 2024 12))
              :to-be-truthy))))
