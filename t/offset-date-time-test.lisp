;;;; t/offset-date-time-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "OffsetDateTime"
  (it
    "constructs an immutable local date-time with a fixed offset"
    (let ((value
          (cl-date-kit:offset-date-time-of
            2024
            6
            15
            12
            34
            56
            123000000
            (zone-offset-of-hours 9))))
      (expect (cl-date-kit:offset-date-time-year value) :to-be 2024)
      (expect (cl-date-kit:offset-date-time-nanosecond value) :to-be 123000000)
      (expect
        (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset value))
        :to-be
        32400)))
  (it
    "converts to and from INSTANT without losing nanoseconds"
    (let* ((original
          (cl-date-kit:offset-date-time-of
            2024
            6
            15
            12
            34
            56
            123456789
            (zone-offset-of-hours -4)))
           (instant (cl-date-kit:offset-date-time-to-instant original))
           (round-trip
          (cl-date-kit:offset-date-time-of-instant instant (zone-offset-of-hours -4))))
      (expect (cl-date-kit:offset-date-time= round-trip original) :to-be-truthy)
      (expect (cl-date-kit:offset-date-time-nanosecond round-trip) :to-be 123456789)))
  (it
    "distinguishes same-instant and same-local offset changes"
    (let* ((original
          (cl-date-kit:offset-date-time-of 2024 6 15 12 0 0 0 (zone-offset-of-hours 9)))
           (same-instant
          (cl-date-kit:offset-date-time-with-offset-same-instant
            original
            (zone-offset-of-hours 0)))
           (same-local
          (cl-date-kit:offset-date-time-with-offset-same-local
            original
            (zone-offset-of-hours 0))))
      (expect (cl-date-kit:offset-date-time-hour same-instant) :to-be 3)
      (expect (cl-date-kit:offset-date-time-hour same-local) :to-be 12)
      (expect (cl-date-kit:offset-date-time= original same-instant) :to-be-truthy)
      (expect (cl-date-kit:offset-date-time< original same-local) :to-be-truthy)))
  (it
    "uses elapsed-time and calendar arithmetic appropriately"
    (let* ((original
          (cl-date-kit:offset-date-time-of 2024 3 9 12 0 0 0 (zone-offset-of-hours -5)))
           (duration-result
          (cl-date-kit:offset-date-time-plus-duration original (duration-of-hours 25)))
           (period-result
          (cl-date-kit:offset-date-time-plus-period original (period-of-days 1))))
      (expect (cl-date-kit:offset-date-time-day duration-result) :to-be 10)
      (expect (cl-date-kit:offset-date-time-hour duration-result) :to-be 13)
      (expect (cl-date-kit:offset-date-time-day period-result) :to-be 10)
      (expect (cl-date-kit:offset-date-time-hour period-result) :to-be 12)))
  (it
    "uses the supplied clock for NOW"
    (let* ((clock (make-fixed-clock (make-instant 0 42)))
           (value
          (cl-date-kit:offset-date-time-now :clock clock :offset (zone-offset-of-hours 9))))
      (expect (cl-date-kit:offset-date-time-day value) :to-be 1)
      (expect (cl-date-kit:offset-date-time-hour value) :to-be 9)
      (expect (cl-date-kit:offset-date-time-nanosecond value) :to-be 42))))
