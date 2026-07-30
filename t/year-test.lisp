;;;; t/year-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "Year"
  (it
    "validates and derives its basic calendar properties"
    (expect (year-leap-p (make-year 2024)) :to-be-truthy)
    (expect (not (year-leap-p (make-year 2100))) :to-be-truthy)
    (expect (year-length (make-year 2024)) :to-be 366)
    (expect (year-length (make-year 2023)) :to-be 365)
    (expect (year= (year-of -44) (make-year -44)) :to-be-truthy)
    (signals invalid-year (make-year 2024.5))
    (signals invalid-year (year-of 2024.5)))
  (it
    "derives the current year from an injected clock and zone"
    (let ((clock (make-fixed-clock (make-instant 0))))
      (expect (year= (year-now :clock clock) (make-year 1970)) :to-be-truthy)
      (expect
        (year= (year-now :clock clock :zone (zone-offset-of-hours -1)) (make-year 1969))
        :to-be-truthy)))
  (it
    "converts more precise local calendar values"
    (let ((date (make-local-date 2024 2 29)))
      (expect (year-value (year-from-local-date date)) :to-be 2024)
      (expect
        (year-value (year-from-year-month (make-year-month 2024 2)))
        :to-be
        2024)))
  (it
    "combines a year with months, month-days, and ordinal days"
    (let ((value (make-year 2023))
          (leap-year (make-year 2024))
          (leap-day (make-month-day 2 29)))
      (expect (year-month-month (year-at-month value 3)) :to-be 3)
      (signals invalid-year-month (year-at-month value 3.0))
      (expect (not (year-valid-month-day-p value leap-day)) :to-be-truthy)
      (expect (year-valid-month-day-p leap-year leap-day) :to-be-truthy)
      (signals type-error (year-valid-month-day-p value (make-local-date 2023 2 28)))
      (expect (local-date-day (year-at-month-day value leap-day)) :to-be 28)
      (expect (local-date-month (year-at-day value 32)) :to-be 2)
      (expect (local-date-day (year-at-day value 32)) :to-be 1)
      (signals invalid-date (year-at-day value 366))))
  (it
    "uses immutable arithmetic, validates operands, and orders all relations"
    (let ((start (make-year -1))
          (middle (make-year 0))
          (end (make-year 2)))
      (expect (year-value (year-plus-years start 4)) :to-be 3)
      (expect (year-value (year-minus-years start 4)) :to-be -5)
      (signals invalid-year (year-plus-years start 1.5))
      (signals invalid-year (year-minus-years start 1.5))
      (expect (year-until start end) :to-be 3)
      (expect (year-compare start end) :to-be -1)
      (expect (year-compare end start) :to-be 1)
      (expect (year-compare middle (make-year 0)) :to-be 0)
      (expect (year< start end) :to-be-truthy)
      (expect (year< end start) :to-be-falsy)
      (expect (year<= start middle) :to-be-truthy)
      (expect (year<= middle middle) :to-be-truthy)
      (expect (year<= end start) :to-be-falsy)
      (expect (year> end start) :to-be-truthy)
      (expect (year> start end) :to-be-falsy)
      (expect (year>= end middle) :to-be-truthy)
      (expect (year>= middle middle) :to-be-truthy)
      (expect (year>= start end) :to-be-falsy)
      (expect (year= end (make-year 2)) :to-be-truthy)
      (expect (year= start end) :to-be-falsy))))
