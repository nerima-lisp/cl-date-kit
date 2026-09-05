(in-package #:cl-date-kit/test)

(describe
  "LocalDate"
  (it
    "formats and parses YYYY-MM-DD"
    (expect (format-local-date (make-local-date 2024 3 10)) :to-equal "2024-03-10")
    (expect
      (local-date= (parse-local-date "2024-03-10") (make-local-date 2024 3 10))
      :to-be-truthy))
  (it-each
      (("-0001-01-02" -1 1 2) ("+10000-01-02" 10000 1 2))
      "round-trips the signed expanded year in ~S"
      (string year month day)
    (let ((date (make-local-date year month day)))
      (expect (format-local-date date) :to-equal string)
      (expect (local-date= (parse-local-date string) date) :to-be-truthy)))
  (it
    "round-trips a signed expanded year through ordinal and week-date forms"
    (let ((date (make-local-date 10000 6 15)))
      (expect
        (local-date= (parse-local-date-ordinal (format-local-date-ordinal date)) date)
        :to-be-truthy)
      (expect
        (local-date=
          (parse-local-date-week-date (format-local-date-week-date date))
          date)
        :to-be-truthy)))
  (it-each
      (("20240615") ("2024-167") ("2024167") ("2024-W24-6") ("2024W246"))
      "parses ~S as the ISO 8601 basic, ordinal, or week-date form of 2024-06-15"
      (string)
    (expect
      (local-date= (parse-local-date string) (make-local-date 2024 6 15))
      :to-be-truthy))
  (it
    "formats and parses canonical ordinal and week-date forms"
    (let ((date (make-local-date 2024 2 29)))
      (expect (format-local-date-ordinal date) :to-equal "2024-060")
      (expect (format-local-date-week-date date) :to-equal "2024-W09-4")
      (expect (local-date= (parse-local-date-ordinal "2024-060") date) :to-be-truthy)
      (expect
        (local-date= (parse-local-date-week-date "2024-W09-4") date)
        :to-be-truthy)))
  (it-each
      (("not-a-date") ("10000-01-02") ("2024-367") ("2021-W53-1") ("2024-W09-8"))
      "PARSE-LOCAL-DATE signals DATE-TIME-PARSE-ERROR on ~S"
      (string)
    (signals date-time-parse-error (parse-local-date string)))
  (it
    "PARSE-LOCAL-DATE signals DATE-TIME-PARSE-ERROR on non-string input"
    (signals date-time-parse-error (parse-local-date 42)))
  (it
    "recognizes signed expanded-year ordinal and week-date forms through the generic parser"
    (let ((ordinal "-0001-002")
          (week "-0001-W01-2"))
      (expect
        (local-date= (parse-local-date ordinal) (parse-local-date-ordinal ordinal))
        :to-be-truthy)
      (expect
        (local-date= (parse-local-date week) (parse-local-date-week-date week))
        :to-be-truthy))))

(describe
  "YearMonth"
  (it
    "formats and parses canonical and basic ISO 8601 forms"
    (let ((value (make-year-month 2024 6)))
      (expect (format-year-month value) :to-equal "2024-06")
      (expect (year-month= (parse-year-month "2024-06") value) :to-be-truthy)
      (expect (year-month= (parse-year-month "202406") value) :to-be-truthy)))
  (it-each
      (("-0001-06" -1) ("+10000-06" 10000))
      "round-trips the signed expanded year in ~S"
      (string year)
    (let ((value (make-year-month year 6)))
      (expect (format-year-month value) :to-equal string)
      (expect (year-month= (parse-year-month string) value) :to-be-truthy)))
  (it-each
      (("2024-6") ("10000-06") ("2024-13") ("2024-00") ("2024-06-15") ("year-month"))
      "normalizes ~S to DATE-TIME-PARSE-ERROR"
      (string)
    (signals date-time-parse-error (parse-year-month string))))

(describe
  "MonthDay"
  (it
    "formats and parses canonical and basic ISO 8601 forms"
    (let ((value (make-month-day 6 15)))
      (expect (format-month-day value) :to-equal "--06-15")
      (expect (month-day= (parse-month-day "--06-15") value) :to-be-truthy)
      (expect (month-day= (parse-month-day "--0615") value) :to-be-truthy)))
  (it-each
      (("06-15") ("--6-15") ("--02-30") ("--13-01") ("month-day"))
      "normalizes ~S to DATE-TIME-PARSE-ERROR"
      (string)
    (signals date-time-parse-error (parse-month-day string))))

(describe
  "Year"
  (it
    "formats and parses canonical ISO 8601 forms"
    (expect (format-year (make-year 2024)) :to-equal "2024")
    (expect (year-value (parse-year "2024")) :to-be 2024)
    (expect (year-value (parse-year "0000")) :to-be 0)
    (expect (format-year (make-year -1)) :to-equal "-0001")
    (expect (year-value (parse-year "-0001")) :to-be -1)
    (expect (format-year (make-year 10000)) :to-equal "+10000")
    (expect (year-value (parse-year "+10000")) :to-be 10000))
  (it-each
      (("024") ("20240") ("-001") ("year"))
      "normalizes ~S to DATE-TIME-PARSE-ERROR"
      (string)
    (signals date-time-parse-error (parse-year string))))

(describe
  "LocalTime"
  (it
    "omits the fractional part when NANOSECOND is zero"
    (expect (format-local-time (make-local-time 1 2 3)) :to-equal "01:02:03"))
  (it
    "formats and parses a fractional-second time"
    (expect
      (format-local-time (make-local-time 1 2 3 500000000))
      :to-equal
      "01:02:03.500000000")
    (expect
      (local-time-nanosecond (parse-local-time "12:00:00.5"))
      :to-be
      500000000))
  (it
    "parses basic time notation with fractional seconds"
    (let ((time (parse-local-time "123456.123456789")))
      (expect (local-time-hour time) :to-be 12)
      (expect (local-time-minute time) :to-be 34)
      (expect (local-time-second time) :to-be 56)
      (expect (local-time-nanosecond time) :to-be 123456789)))
  (it
    "parses basic time notation without a fractional part"
    (let ((time (parse-local-time "123456")))
      (expect (local-time-hour time) :to-be 12)
      (expect (local-time-minute time) :to-be 34)
      (expect (local-time-second time) :to-be 56)
      (expect (local-time-nanosecond time) :to-be 0)))
  (it
    "PARSE-LOCAL-TIME signals DATE-TIME-PARSE-ERROR on a string that is neither extended nor basic notation"
    (signals date-time-parse-error (parse-local-time "12-00-00"))))

(describe
  "LocalDateTime"
  (it
    "joins date and time with T"
    (expect
      (format-local-date-time (local-date-time-of 2024 3 10 2 30 0))
      :to-equal
      "2024-03-10T02:30:00"))
  (it
    "round-trips through PARSE-LOCAL-DATE-TIME"
    (let ((dt (local-date-time-of 2024 3 10 2 30 15)))
      (expect
        (local-date-time= (parse-local-date-time (format-local-date-time dt)) dt)
        :to-be-truthy)))
  (it
    "round-trips a signed expanded year"
    (let ((dt (local-date-time-of -1 3 10 2 30 15)))
      (expect (format-local-date-time dt) :to-equal "-0001-03-10T02:30:15")
      (expect
        (local-date-time= (parse-local-date-time (format-local-date-time dt)) dt)
        :to-be-truthy)))
  (it
    "PARSE-LOCAL-DATE-TIME signals DATE-TIME-PARSE-ERROR when the T separator is missing"
    (signals date-time-parse-error (parse-local-date-time "2024-03-10 02:30:00"))))

(describe
  "Instant"
  (progn
    (it
      "PARSE-INSTANT accepts a trailing Z"
      (let ((i (parse-instant "2024-06-15T12:34:56Z")))
        (expect (instant-epoch-second i) :to-be 1718454896)))
    (progn
      (it
        "PARSE-INSTANT validates canonical UTC values"
        (expect
          (instant-epoch-second (parse-instant "2000-02-29T00:00:00Z"))
          :to-be
          951782400))
      (it-each
          (("2024-02-30T12:00:00Z")
           ("2024-06-15T24:00:00Z")
           ("2024-06-15T12:60:00Z")
           ("2024-06-15T12:00:60Z"))
          "PARSE-INSTANT rejects the invalid canonical UTC value ~S"
          (string)
        (signals date-time-parse-error (parse-instant string)))
      (it
        "PARSE-INSTANT rejects malformed canonical-shaped fields"
        (signals date-time-parse-error (parse-instant "2024-0x-15T12:00:00Z")))
      (it
        "PARSE-INSTANT falls back for lowercase separators and suffixes"
        (expect
          (instant=
            (parse-instant "2024-06-15t12:00:00z")
            (parse-instant "2024-06-15T12:00:00Z"))
          :to-be-truthy))))
  (it
    "round-trips through PARSE-INSTANT and FORMAT-INSTANT"
    (let ((i (make-instant 1718454896)))
      (expect (instant= (parse-instant (format-instant i)) i) :to-be-truthy)))
  (it
    "round-trips a signed expanded year"
    (let ((i (parse-instant "+10000-06-15T12:00:00Z")))
      (expect (format-instant i) :to-equal "+10000-06-15T12:00:00Z")
      (expect (instant= (parse-instant (format-instant i)) i) :to-be-truthy)))
  (it
    "PARSE-INSTANT accepts numeric RFC 3339 offsets"
    (expect
      (instant=
        (parse-instant "2024-06-15T12:00:00-04:00")
        (parse-instant "2024-06-15T16:00:00Z"))
      :to-be-truthy))
  (it-each
      (("2024-06-15T12:00:00")
       ("2024-06-15T12:00:00+")
       ("2024-06-15T12:00:00+040")
       ("2024-06-15T12:00:00+04:00suffix")
       ("2024-06-15T12:00:00Zsuffix"))
      "PARSE-INSTANT signals DATE-TIME-PARSE-ERROR for the malformed ISO suffix in ~S"
      (string)
    (signals date-time-parse-error (parse-instant string))))

(describe
  "LocalDateInterval ISO 8601"
  (it-each
      (("2024-06-15/2024-06-20")
       ("2024-06-15/2024-06-15")
       ("-0001-01-01/+10000-12-31"))
      "round-trips the exact half-open date endpoints in ~S"
      (input)
    (expect
      (cl-date-kit:format-local-date-interval
        (cl-date-kit:parse-local-date-interval input))
      :to-equal
      input))
  (it-each
      (("2024-06-15")
       ("2024-06-15/")
       ("/2024-06-20")
       ("2024-06-15/2024-06-20/2024-06-21")
       ("2024-06-20/2024-06-15")
       (#()))
      "rejects the malformed or descending endpoint in ~S"
      (input)
    (signals date-time-parse-error (cl-date-kit:parse-local-date-interval input))))
