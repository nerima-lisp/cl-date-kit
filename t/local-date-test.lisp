;;;; t/local-date-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "leap years and month lengths"
  (it
    "LEAP-YEAR-P follows the 4/100/400 rule"
    (expect (leap-year-p 2000) :to-be-truthy)
    (expect (leap-year-p 1900) :to-be nil)
    (expect (leap-year-p 2024) :to-be-truthy)
    (expect (leap-year-p 2023) :to-be nil))
  (it
    "LENGTH-OF-MONTH accounts for February in leap and non-leap years"
    (expect (length-of-month 2024 2) :to-be 29)
    (expect (length-of-month 2023 2) :to-be 28)
    (expect (length-of-month 2024 4) :to-be 30)
    (expect (length-of-month 2024 1) :to-be 31))
  (it
    "LENGTH-OF-MONTH signals TYPE-ERROR outside its integer calendar domain"
    (signals type-error (length-of-month 2024 13))
    (signals type-error (length-of-month 2024 2.0))))

(describe
  "LocalDate calendar facts"
  (it
    "derives leap-year, month length, and year length from the date value"
    (let ((leap-day (make-local-date 2024 2 29))
          (common-day (make-local-date 2023 2 28)))
      (expect (local-date-leap-year-p leap-day) :to-be-truthy)
      (expect (local-date-leap-year-p common-day) :to-be nil)
      (expect (local-date-length-of-month leap-day) :to-be 29)
      (expect (local-date-length-of-month common-day) :to-be 28)
      (expect (local-date-length-of-year leap-day) :to-be 366)
      (expect (local-date-length-of-year common-day) :to-be 365))))

(describe
  "MAKE-LOCAL-DATE validation"
  (it
    "signals INVALID-DATE for a day past the end of its month"
    (signals invalid-date (make-local-date 2023 2 30)))
  (it
    "signals INVALID-DATE for a month outside 1-12"
    (signals invalid-date (make-local-date 2023 13 1)))
  (it
    "signals INVALID-DATE for noninteger calendar fields"
    (signals invalid-date (make-local-date 2024 2.0 1))
    (signals invalid-date (make-local-date 2024 2 1.0)))
  (it
    "accepts February 29 in a leap year"
    (expect (local-date-day (make-local-date 2024 2 29)) :to-be 29))
  (it
    "signals a CL-DATE-KIT-ERROR that catches INVALID-DATE without naming it"
    (let ((condition
          (handler-case (make-local-date 2023 2 30)
            (cl-date-kit-error (signaled) signaled))))
      (expect (typep condition 'invalid-date) :to-be-truthy)
      (expect (invalid-date-year condition) :to-be 2023)
      (expect (invalid-date-month condition) :to-be 2)
      (expect (invalid-date-day condition) :to-be 30))))

(describe
  "epoch-day conversion (Howard Hinnant's days_from_civil/civil_from_days)"
  (it
    "1970-01-01 is epoch day 0"
    (expect (local-date-to-epoch-day (make-local-date 1970 1 1)) :to-be 0))
  (it
    "1969-12-31 is epoch day -1"
    (expect (local-date-to-epoch-day (make-local-date 1969 12 31)) :to-be -1))
  (progn
    (it-each
        ((1 1 1) (1600 2 29) (1900 1 1) (2000 2 29) (2024 3 10) (2400 12 31))
        "round-trips ~A-~A-~A through LOCAL-DATE-FROM-EPOCH-DAY"
        (year month day)
      (let ((date (make-local-date year month day)))
        (expect
          (local-date= (local-date-from-epoch-day (local-date-to-epoch-day date)) date)
          :to-be-truthy)))
    (it-property
        "LOCAL-DATE-FROM-EPOCH-DAY inverts LOCAL-DATE-TO-EPOCH-DAY for any epoch day"
        ((day (gen-integer :min -700000 :max 700000)))
      (expect (local-date-to-epoch-day (local-date-from-epoch-day day)) :to-equal day))))

(describe
  "date/time composition"
  (it
    "LOCAL-DATE-AT-TIME pairs the supplied immutable values"
    (expect
      (local-date-time=
        (local-date-at-time (make-local-date 2024 6 15) (make-local-time 12 34 56 7))
        (local-date-time-of 2024 6 15 12 34 56 7))
      :to-be-truthy))
  (it
    "LOCAL-DATE-AT-START-OF-DAY uses midnight"
    (expect
      (local-date-time=
        (local-date-at-start-of-day (make-local-date 2024 6 15))
        (local-date-time-of 2024 6 15 0 0 0))
      :to-be-truthy)))

(describe
  "ISO weekday values"
  (it
    "converts between ISO values and keyword weekdays"
    (expect (cl-date-kit:day-of-week-value :monday) :to-be 1)
    (expect (cl-date-kit:day-of-week-value :sunday) :to-be 7)
    (expect (cl-date-kit:day-of-week-from-value 1) :to-be :monday)
    (expect (cl-date-kit:day-of-week-from-value 7) :to-be :sunday))
  (it
    "wraps arithmetic in both directions"
    (expect (cl-date-kit:day-of-week-plus :sunday 1) :to-be :monday)
    (expect (cl-date-kit:day-of-week-plus :monday -1) :to-be :sunday)
    (expect (cl-date-kit:day-of-week-minus :monday 1) :to-be :sunday)
    (expect (cl-date-kit:day-of-week-length :wednesday) :to-be 7))
  (it
    "rejects invalid weekday designators and values"
    (signals
      cl-date-kit:invalid-day-of-week
      (cl-date-kit:day-of-week-value :weekday))
    (signals cl-date-kit:invalid-day-of-week (cl-date-kit:day-of-week-from-value 0))
    (signals
      cl-date-kit:invalid-day-of-week
      (cl-date-kit:day-of-week-plus :monday 1/2))))

(describe
  "DAY-OF-WEEK and DAY-OF-YEAR"
  (it
    "1970-01-01 was a Thursday"
    (expect (day-of-week (make-local-date 1970 1 1)) :to-be :thursday))
  (it
    "2024-03-10 was a Sunday"
    (expect (day-of-week (make-local-date 2024 3 10)) :to-be :sunday))
  (it
    "DAY-OF-YEAR of January 1st is 1 and December 31st is 365 or 366"
    (expect (day-of-year (make-local-date 2023 1 1)) :to-be 1)
    (expect (day-of-year (make-local-date 2023 12 31)) :to-be 365)
    (expect (day-of-year (make-local-date 2024 12 31)) :to-be 366))
  (it
    "LOCAL-DATE-OF-YEAR-DAY is the inverse of DAY-OF-YEAR"
    (expect
      (local-date= (local-date-of-year-day 2024 60) (make-local-date 2024 2 29))
      :to-be-truthy))
  (it
    "LOCAL-DATE-OF-YEAR-DAY signals INVALID-DATE for day 366 in a non-leap year"
    (signals invalid-date (local-date-of-year-day 2023 366))))

(describe
  "ISO 8601 week dates"
  (it
    "uses the adjacent calendar year when a date belongs to ISO week 1 or 53"
    (let ((new-year (make-local-date 2021 1 1))
          (week-one (make-local-date 2019 12 30)))
      (expect (local-date-week-based-year new-year) :to-be 2020)
      (expect (local-date-week-of-week-based-year new-year) :to-be 53)
      (expect (local-date-week-based-year week-one) :to-be 2020)
      (expect (local-date-week-of-week-based-year week-one) :to-be 1)))
  (it
    "LOCAL-DATE-OF-WEEK-DATE round-trips ISO week fields"
    (let ((date (local-date-of-week-date 2020 53 7)))
      (expect (local-date= date (make-local-date 2021 1 3)) :to-be-truthy)
      (expect (day-of-week date) :to-be :sunday)))
  (it
    "rejects a week 53 that does not exist in the requested week-based year"
    (signals invalid-date (local-date-of-week-date 2021 53 1))))

(describe
  "day/week/month/year arithmetic"
  (it
    "LOCAL-DATE-PLUS-DAYS carries across a year boundary"
    (expect
      (local-date=
        (local-date-plus-days (make-local-date 2023 12 31) 1)
        (make-local-date 2024 1 1))
      :to-be-truthy))
  (it
    "LOCAL-DATE-PLUS-WEEKS is seven times LOCAL-DATE-PLUS-DAYS"
    (expect
      (local-date=
        (local-date-plus-weeks (make-local-date 2024 1 1) 2)
        (local-date-plus-days (make-local-date 2024 1 1) 14))
      :to-be-truthy))
  (it
    "LOCAL-DATE-PLUS-MONTHS clamps to the shorter target month, like java.time"
    (expect
      (local-date=
        (local-date-plus-months (make-local-date 2023 1 31) 1)
        (make-local-date 2023 2 28))
      :to-be-truthy))
  (it
    "LOCAL-DATE-PLUS-MONTHS rolls over the year"
    (expect
      (local-date=
        (local-date-plus-months (make-local-date 2023 11 15) 3)
        (make-local-date 2024 2 15))
      :to-be-truthy))
  (it
    "LOCAL-DATE-PLUS-YEARS keeps Feb 29 clamped in a non-leap target year"
    (expect
      (local-date=
        (local-date-plus-years (make-local-date 2024 2 29) 1)
        (make-local-date 2025 2 28))
      :to-be-truthy))
  (it
    "LOCAL-DATE-MINUS-* are the inverse of LOCAL-DATE-PLUS-*"
    (let ((date (make-local-date 2024 6 15)))
      (expect
        (local-date= (local-date-minus-days (local-date-plus-days date 40) 40) date)
        :to-be-truthy)
      (expect
        (local-date= (local-date-minus-months (local-date-plus-months date 5) 5) date)
        :to-be-truthy)
      (expect
        (local-date= (local-date-minus-years (local-date-plus-years date 3) 3) date)
        :to-be-truthy)))
  (it
    "LOCAL-DATE-MINUS-WEEKS is the inverse of LOCAL-DATE-PLUS-WEEKS"
    (expect
      (local-date=
        (local-date-minus-weeks (local-date-plus-weeks (make-local-date 2024 6 15) 3) 3)
        (make-local-date 2024 6 15))
      :to-be-truthy)))

(describe
  "period-based arithmetic and LOCAL-DATE-UNTIL"
  (it
    "LOCAL-DATE-PLUS-PERIOD applies years, months, then days"
    (expect
      (local-date=
        (local-date-plus-period
          (make-local-date 2023 1 31)
          (make-period :years 1 :months 1 :days 1))
        (make-local-date 2024 3 1))
      :to-be-truthy))
  (it
    "LOCAL-DATE-UNTIL is the inverse of LOCAL-DATE-PLUS-PERIOD for whole-unit periods"
    (let* ((start (make-local-date 2020 1 31))
           (end (make-local-date 2021 3 1))
           (period (local-date-until start end)))
      (expect (period-years period) :to-be 1)
      (expect (period-months period) :to-be 1)
      (expect (period-days period) :to-be 1)
      (expect (local-date= (local-date-plus-period start period) end) :to-be-truthy)))
  (it
    "LOCAL-DATE-UNTIL handles a negative (backwards) period"
    (let ((period
          (local-date-until (make-local-date 2021 3 1) (make-local-date 2020 1 31))))
      (expect (period-years period) :to-be -1)
      (expect (period-months period) :to-be -1)
      (expect (period-days period) :to-be -1)))
  (it
    "LOCAL-DATE-UNTIL needs no day borrow when the day-of-month does not decrease"
    (let ((period
          (local-date-until (make-local-date 2024 1 15) (make-local-date 2024 3 15))))
      (expect (period-years period) :to-be 0)
      (expect (period-months period) :to-be 2)
      (expect (period-days period) :to-be 0)))
  (it
    "LOCAL-DATE-MINUS-PERIOD is the inverse of LOCAL-DATE-PLUS-PERIOD"
    (let* ((date (make-local-date 2024 3 1))
           (period (make-period :years 1 :months 1 :days 1)))
      (expect
        (local-date=
          (local-date-minus-period (local-date-plus-period date period) period)
          date)
        :to-be-truthy))))

(describe
  "ordering"
  (it
    "LOCAL-DATE< / LOCAL-DATE> / LOCAL-DATE= agree with epoch-day order"
    (expect
      (local-date< (make-local-date 2024 1 1) (make-local-date 2024 1 2))
      :to-be-truthy)
    (expect
      (local-date> (make-local-date 2024 1 2) (make-local-date 2024 1 1))
      :to-be-truthy)
    (expect
      (local-date= (make-local-date 2024 1 1) (make-local-date 2024 1 1))
      :to-be-truthy)))

(describe
  "immutable date field replacement and calendar adjusters"
  (it
    "LOCAL-DATE-WITH-YEAR and LOCAL-DATE-WITH-MONTH preserve the month-end clamp"
    (expect
      (local-date=
        (cl-date-kit:local-date-with-year (make-local-date 2024 2 29) 2023)
        (make-local-date 2023 2 28))
      :to-be-truthy)
    (expect
      (local-date=
        (cl-date-kit:local-date-with-month (make-local-date 2024 1 31) 2)
        (make-local-date 2024 2 29))
      :to-be-truthy))
  (it
    "LOCAL-DATE-WITH-DAY and LOCAL-DATE-WITH-DAY-OF-YEAR replace only the selected date field"
    (expect
      (local-date=
        (cl-date-kit:local-date-with-day (make-local-date 2024 3 10) 1)
        (make-local-date 2024 3 1))
      :to-be-truthy)
    (expect
      (local-date=
        (cl-date-kit:local-date-with-day-of-year (make-local-date 2024 3 10) 366)
        (make-local-date 2024 12 31))
      :to-be-truthy))
  (it
    "LOCAL-DATE-WITH-* preserves INVALID-DATE validation"
    (signals
      invalid-date
      (cl-date-kit:local-date-with-month (make-local-date 2024 1 1) 13))
    (signals
      invalid-date
      (cl-date-kit:local-date-with-day (make-local-date 2024 2 1) 30)))
  (it
    "LOCAL-DATE-WITH-MONTH rejects a non-integral month distinctly from an out-of-range one"
    (signals
      invalid-date
      (cl-date-kit:local-date-with-month (make-local-date 2024 1 1) :february)))
  (it
    "calendar boundary adjusters return immutable values"
    (let ((date (make-local-date 2024 2 15)))
      (expect
        (local-date=
          (cl-date-kit:local-date-first-day-of-month date)
          (make-local-date 2024 2 1))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-last-day-of-month date)
          (make-local-date 2024 2 29))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-first-day-of-year date)
          (make-local-date 2024 1 1))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-last-day-of-year date)
          (make-local-date 2024 12 31))
        :to-be-truthy)))
  (it
    "weekday adjusters distinguish inclusive and strict movement"
    (let ((monday (make-local-date 2024 6 3)))
      (expect
        (local-date= (cl-date-kit:local-date-next-or-same monday :monday) monday)
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-next monday :monday)
          (make-local-date 2024 6 10))
        :to-be-truthy)
      (expect
        (local-date= (cl-date-kit:local-date-previous-or-same monday :monday) monday)
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-previous monday :monday)
          (make-local-date 2024 5 27))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-next monday :friday)
          (make-local-date 2024 6 7))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-previous monday :friday)
          (make-local-date 2024 5 31))
        :to-be-truthy))))

(progn
  (describe
    "LocalDate TemporalAdjusters"
    (it
      "returns first days of the next month and year"
      (expect
        (local-date=
          (cl-date-kit:local-date-first-day-of-next-month (make-local-date 2024 1 31))
          (make-local-date 2024 2 1))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-first-day-of-next-year (make-local-date 2024 2 29))
          (make-local-date 2025 1 1))
        :to-be-truthy))
    (it
      "finds first and last weekdays within a month"
      (expect
        (local-date=
          (cl-date-kit:local-date-first-in-month (make-local-date 2024 6 15) :monday)
          (make-local-date 2024 6 3))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-last-in-month (make-local-date 2024 6 15) :monday)
          (make-local-date 2024 6 24))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-last-in-month (make-local-date 2024 2 15) :thursday)
          (make-local-date 2024 2 29))
        :to-be-truthy))
    (it
      "counts weekday ordinals from either month boundary and permits spillover"
      (expect
        (local-date=
          (cl-date-kit:local-date-day-of-week-in-month
            (make-local-date 2024 2 15)
            5
            :sunday)
          (make-local-date 2024 3 3))
        :to-be-truthy)
      (expect
        (local-date=
          (cl-date-kit:local-date-day-of-week-in-month
            (make-local-date 2024 2 15)
            -5
            :sunday)
          (make-local-date 2024 1 28))
        :to-be-truthy))
    (it
      "rejects invalid weekday ordinals"
      (signals
        invalid-date
        (cl-date-kit:local-date-day-of-week-in-month
          (make-local-date 2024 2 15)
          0
          :monday))
      (signals
        invalid-date
        (cl-date-kit:local-date-day-of-week-in-month
          (make-local-date 2024 2 15)
          1/2
          :monday))))
  (describe
    "LocalDate OF constructor"
    (it
      "delegates Gregorian field validation to MAKE-LOCAL-DATE"
      (expect
        (local-date= (cl-date-kit:local-date-of 2024 2 29) (make-local-date 2024 2 29))
        :to-be-truthy)
      (signals invalid-date (cl-date-kit:local-date-of 2023 2 29)))))

(describe
  "LOCAL-DATE-AT-START-OF-DAY-IN-ZONE"
  (it
    "uses midnight in a fixed-offset zone"
    (let ((value
          (local-date-at-start-of-day-in-zone
            (make-local-date 2024 6 15)
            (zone-offset-utc))))
      (expect
        (local-date-time=
          (zoned-date-time-local value)
          (local-date-time-of 2024 6 15 0 0 0))
        :to-be-truthy)))
  (it
    "moves a midnight gap to the first valid local time"
    (let ((value
          (local-date-at-start-of-day-in-zone
            (make-local-date 2018 11 4)
            (find-time-zone "America/Sao_Paulo"))))
      (expect
        (local-date-time=
          (zoned-date-time-local value)
          (local-date-time-of 2018 11 4 1 0 0))
        :to-be-truthy)))
  (it
    "rejects a midnight gap under strict disambiguation"
    (signals
      nonexistent-local-time
      (local-date-at-start-of-day-in-zone
        (make-local-date 2018 11 4)
        (find-time-zone "America/Sao_Paulo")
        :disambiguation
        :strict))))
