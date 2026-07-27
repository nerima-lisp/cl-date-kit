;;;; t/month-day-test.lisp

(in-package #:cl-date-kit/test)

(describe
  "MonthDay"
  (it "validates calendar fields while retaining February 29"
    (expect (month-day-month (make-month-day 2 29)) :to-be 2)
    (expect (month-day-day (make-month-day 2 29)) :to-be 29)
    (signals invalid-month-day (make-month-day 2 30))
    (signals invalid-month-day (make-month-day 13 1)))
  (it "converts to LocalDate with leap-year-aware February handling"
    (let ((leap-day (make-month-day 2 29)))
      (expect (month-day-valid-year-p leap-day 2024) :to-be-truthy)
      (expect (month-day-valid-year-p leap-day 2023) :to-be-falsy)
      (expect (local-date= (month-day-at-year leap-day 2024)
                           (make-local-date 2024 2 29))
              :to-be-truthy)
      (expect (local-date= (month-day-at-year leap-day 2023)
                           (make-local-date 2023 2 28))
              :to-be-truthy)))
  (it "converts LocalDate, orders values, and replaces immutable fields"
    (let ((value (month-day-from-local-date (make-local-date 2024 6 15))))
      (expect (month-day= value (make-month-day 6 15)) :to-be-truthy)
      (expect (month-day< value (make-month-day 7 1)) :to-be-truthy)
      (expect (month-day= (month-day-with-month (make-month-day 3 31) 4)
                          (make-month-day 4 30))
              :to-be-truthy)
      (expect (month-day= (month-day-with-day value 1)
                          (make-month-day 6 1))
              :to-be-truthy))))
