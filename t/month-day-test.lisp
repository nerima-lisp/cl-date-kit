;;;; t/month-day-test.lisp

(in-package #:cl-date-kit/test)

(describe "MonthDay"
  (it "validates calendar fields while retaining February 29"
    (expect (month-day-month (make-month-day 2 29)) :to-be 2)
    (expect (month-day-day (make-month-day 2 29)) :to-be 29)
    (signals invalid-month-day (make-month-day 2 30))
    (signals invalid-month-day (make-month-day 13 1))
    (signals invalid-month-day (make-month-day 0 1))
    (signals invalid-month-day (make-month-day 1 0))
    (signals invalid-month-day (make-month-day 1 1.5)))
  (it "derives the current month-day from an injected clock and zone"
    (let ((clock (make-fixed-clock (make-instant 0))))
      (expect (month-day= (month-day-now :clock clock) (make-month-day 1 1)) :to-be-truthy)
      (expect (month-day= (month-day-now :clock clock :zone (zone-offset-of-hours -1))
                           (make-month-day 12 31))
              :to-be-truthy)))
  (it "converts to LocalDate with leap-year-aware February handling"
    (let ((leap-day (make-month-day 2 29)))
      (expect (month-day-valid-year-p leap-day 2024) :to-be-truthy)
      (expect (month-day-valid-year-p leap-day 2023) :to-be-falsy)
      (expect (month-day-valid-year-p leap-day 2000) :to-be-truthy)
      (expect (not (month-day-valid-year-p leap-day 2100)) :to-be-truthy)
      (expect (not (month-day-valid-year-p leap-day 2024.5)) :to-be-truthy)
      (expect (local-date= (month-day-at-year leap-day 2024) (make-local-date 2024 2 29)) :to-be-truthy)
      (expect (local-date= (month-day-at-year leap-day 2023) (make-local-date 2023 2 28)) :to-be-truthy)
      (signals invalid-month-day (month-day-at-year leap-day 2024.5))))
  (it "converts LocalDate, orders values, and replaces immutable fields"
    (let ((value (month-day-from-local-date (make-local-date 2024 6 15)))
          (earlier (make-month-day 6 14))
          (later (make-month-day 7 1)))
      (expect (month-day= value (make-month-day 6 15)) :to-be-truthy)
      (expect (month-day-compare earlier value) :to-be -1)
      (expect (month-day-compare later value) :to-be 1)
      (expect (month-day-compare value (make-month-day 6 15)) :to-be 0)
      (expect (month-day< value later) :to-be-truthy)
      (expect (month-day<= value value) :to-be-truthy)
      (expect (month-day> later value) :to-be-truthy)
      (expect (month-day>= value value) :to-be-truthy)
      (expect (month-day= (month-day-with-month (make-month-day 3 31) 4) (make-month-day 4 30)) :to-be-truthy)
      (expect (month-day= (month-day-with-day value 1) (make-month-day 6 1)) :to-be-truthy)
      (signals invalid-month-day (month-day-with-month value 13))
      (signals invalid-month-day (month-day-with-month value 1.5))
      (signals invalid-month-day (month-day-with-day value 31)))))

(describe "MonthDay boundary and field contracts" (it "orders adjacent days in the same month and preserves strict relations" (let ((earlier (month-day-of 2 28)) (later (month-day-of 2 29))) (expect (month-day-compare earlier later) :to-be -1) (expect (month-day< earlier later) :to-be-truthy) (expect (month-day> earlier later) :to-be-falsy) (expect (month-day>= earlier later) :to-be-falsy))) (it "clamps February replacements and retains immutable source values" (let* ((value (month-day-of 3 31)) (february (month-day-with-month value 2))) (expect (month-day= february (month-day-of 2 29)) :to-be-truthy) (expect (month-day= value (month-day-of 3 31)) :to-be-truthy) (expect (local-date= (month-day-at-year (month-day-of 6 15) 2023) (make-local-date 2023 6 15)) :to-be-truthy) (signals invalid-month-day (make-month-day 1.5 1)))))
