;;;; t/month-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "Month"
  (it
    "converts between ISO month keywords and numeric values"
    (expect (cl-date-kit:month-value :january) :to-be 1)
    (expect (cl-date-kit:month-value :december) :to-be 12)
    (expect (cl-date-kit:month-from-value 1) :to-be :january)
    (expect (cl-date-kit:month-from-value 12) :to-be :december))
  (it
    "round-trips every ISO month value and preserves full-year arithmetic"
    (loop for value from 1 to 12
          for month = (cl-date-kit:month-from-value value)
          do (expect (cl-date-kit:month-value month) :to-be value) (expect (cl-date-kit:month-plus month 12) :to-be month) (expect (cl-date-kit:month-minus month 12) :to-be month)))
  (it
    "exposes leap-aware month facts and calendar quarters"
    (expect (cl-date-kit:month-length :february t) :to-be 29)
    (expect (cl-date-kit:month-length :february nil) :to-be 28)
    (expect (cl-date-kit:month-min-length :february) :to-be 28)
    (expect (cl-date-kit:month-max-length :february) :to-be 29)
    (expect (cl-date-kit:month-first-day-of-year :march t) :to-be 61)
    (expect (cl-date-kit:month-quarter-of-year :august) :to-be 3)
    (expect (cl-date-kit:month-first-month-of-quarter :august) :to-be :july))
  (it
    "wraps ISO month arithmetic and derives a LocalDate month"
    (expect (cl-date-kit:month-plus :december 1) :to-be :january)
    (expect (cl-date-kit:month-plus :january -1) :to-be :december)
    (expect (cl-date-kit:month-minus :january 1) :to-be :december)
    (expect
      (cl-date-kit:month-from-local-date (make-local-date 2024 2 29))
      :to-be
      :february))
  (it
    "derives the current month from an injected clock and zone"
    (let ((clock (make-fixed-clock (make-instant 0))))
      (expect (month-now :clock clock) :to-be :january)
      (expect
        (month-now :clock clock :zone (zone-offset-of-hours -1))
        :to-be
        :december)))
  (it
    "rejects non-ISO months and non-integral arithmetic"
    (signals cl-date-kit:invalid-month (cl-date-kit:month-value :smarch))
    (signals cl-date-kit:invalid-month (cl-date-kit:month-from-value 13))
    (signals type-error (cl-date-kit:month-plus :january 1/2)))
  (it
    "validates month facts and wraps large negative arithmetic"
    (signals cl-date-kit:invalid-month (cl-date-kit:month-min-length :smarch))
    (signals type-error (cl-date-kit:month-length :january :true))
    (signals type-error (cl-date-kit:month-first-day-of-year :january 1))
    (expect (cl-date-kit:month-plus :march -25) :to-be :february)))
