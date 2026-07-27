;;;; t/year-test.lisp

(in-package #:cl-date-kit/test)

(describe "Year"
  (it "validates and derives its basic calendar properties"
    (expect (year-leap-p (make-year 2024)) :to-be-truthy)
    (expect (not (year-leap-p (make-year 2100))) :to-be-truthy)
    (expect (year-length (make-year 2024)) :to-be 366)
    (expect (year-length (make-year 2023)) :to-be 365)
    (signals invalid-year (make-year 2024.5)))

  (it "converts more precise local calendar values"
    (let ((date (make-local-date 2024 2 29)))
      (expect (year-value (year-from-local-date date)) :to-be 2024)
      (expect (year-value
               (year-from-year-month (make-year-month 2024 2)))
              :to-be 2024)))

  (it "combines a year with months, month-days, and ordinal days"
    (let ((value (make-year 2023)))
      (expect (year-month-month (year-at-month value 3)) :to-be 3)
      (expect (local-date-day
               (year-at-month-day value (make-month-day 2 29)))
              :to-be 28)
      (expect (local-date-month (year-at-day value 32)) :to-be 2)
      (expect (local-date-day (year-at-day value 32)) :to-be 1)))

  (it "uses immutable arithmetic and ordering"
    (let ((start (make-year -1))
          (end (make-year 2)))
      (expect (year-value (year-plus-years start 4)) :to-be 3)
      (expect (year-value (year-minus-years start 4)) :to-be -5)
      (expect (year-until start end) :to-be 3)
      (expect (year< start end) :to-be-truthy)
      (expect (year= end (make-year 2)) :to-be-truthy))))
