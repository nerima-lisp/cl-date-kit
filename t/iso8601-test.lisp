;;;; t/iso8601-test.lisp
(in-package #:cl-date-kit/test)

(progn
  (describe
    "OffsetDateTime ISO 8601"
    (it
      "formats local date-time and fixed offset"
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
        (expect
          (cl-date-kit:format-offset-date-time value)
          :to-equal
          "2024-06-15T12:34:56.123000000+09:00")))
    (it
      "parses numeric and UTC offsets"
      (let ((numeric (cl-date-kit:parse-offset-date-time "2024-06-15T12:34:56.123-04:00"))
            (utc (cl-date-kit:parse-offset-date-time "2024-06-15T12:34:56Z")))
        (expect (cl-date-kit:offset-date-time-hour numeric) :to-be 12)
        (expect
          (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset numeric))
          :to-be
          -14400)
        (expect
          (zone-offset-total-seconds (cl-date-kit:offset-date-time-offset utc))
          :to-be
          0)))
    (it
      "round-trips a signed expanded year"
      (let ((value (cl-date-kit:parse-offset-date-time "+10000-06-15T12:34:56+09:00")))
        (expect
          (cl-date-kit:format-offset-date-time value)
          :to-equal
          "+10000-06-15T12:34:56+09:00")
        (expect
          (cl-date-kit:offset-date-time=
            (cl-date-kit:parse-offset-date-time (cl-date-kit:format-offset-date-time value))
            value)
          :to-be-truthy)))
    (it
      "rejects an offset-less local date-time"
      (signals
        date-time-parse-error
        (cl-date-kit:parse-offset-date-time "2024-06-15T12:34:56"))))
  (describe
    "ZoneOffset ISO 8601"
    (it
      "formats canonical extended notation and parses UTC, basic, and extended notation"
      (expect
        (cl-date-kit:format-zone-offset (zone-offset-of-hms -4 -30 -15))
        :to-equal
        "-04:30:15")
      (dolist (case '(("Z" 0)
            ("+09" 32400)
            ("+0900" 32400)
            ("+09:00" 32400)
            ("-043015" -16215)
            ("-04:30:15" -16215)))
        (destructuring-bind (string total-seconds) case
          (expect
            (zone-offset-total-seconds (cl-date-kit:parse-zone-offset string))
            :to-be
            total-seconds))))
    (it
      "normalizes malformed and out-of-range offsets to DATE-TIME-PARSE-ERROR"
      (dolist (string '("+" "+0" "+090" "+09:0" "+09:000" "+180001" "UTC"))
        (signals date-time-parse-error (cl-date-kit:parse-zone-offset string))))))

(describe
  "OffsetTime ISO 8601"
  (it
    "formats and parses a local time with a required offset"
    (let ((value (offset-time-of 12 34 56 123000000 (zone-offset-of-hms -4 -30 0))))
      (expect (format-offset-time value) :to-equal "12:34:56.123000000-04:30")
      (expect
        (offset-time= (parse-offset-time "12:34:56.123-04:30") value)
        :to-be-truthy)))
  (it
    "parses UTC and rejects an offset-less local time"
    (expect
      (zone-offset-total-seconds (offset-time-offset (parse-offset-time "12:34:56Z")))
      :to-be
      0)
    (signals date-time-parse-error (parse-offset-time "12:34:56"))))

(describe
  "LocalDate"
  (it
    "formats and parses YYYY-MM-DD"
    (expect (format-local-date (make-local-date 2024 3 10)) :to-equal "2024-03-10")
    (expect
      (local-date= (parse-local-date "2024-03-10") (make-local-date 2024 3 10))
      :to-be-truthy))
  (it
    "round-trips signed expanded ISO 8601 years"
    (dolist (case '(("-0001-01-02" -1 1 2) ("+10000-01-02" 10000 1 2)))
      (destructuring-bind (string year month day) case
        (let ((date (make-local-date year month day)))
          (expect (format-local-date date) :to-equal string)
          (expect (local-date= (parse-local-date string) date) :to-be-truthy))))
    (let ((date (make-local-date 10000 6 15)))
      (expect
        (local-date= (parse-local-date-ordinal (format-local-date-ordinal date)) date)
        :to-be-truthy)
      (expect
        (local-date=
          (parse-local-date-week-date (format-local-date-week-date date))
          date)
        :to-be-truthy)))
  (it
    "parses ISO 8601 basic calendar, ordinal, and week-date forms"
    (dolist (string '("20240615" "2024-167" "2024167" "2024-W24-6" "2024W246"))
      (expect
        (local-date= (parse-local-date string) (make-local-date 2024 6 15))
        :to-be-truthy)))
  (it
    "formats and parses canonical ordinal and week-date forms"
    (let ((date (make-local-date 2024 2 29)))
      (expect (format-local-date-ordinal date) :to-equal "2024-060")
      (expect (format-local-date-week-date date) :to-equal "2024-W09-4")
      (expect (local-date= (parse-local-date-ordinal "2024-060") date) :to-be-truthy)
      (expect
        (local-date= (parse-local-date-week-date "2024-W09-4") date)
        :to-be-truthy)))
  (it
    "PARSE-LOCAL-DATE signals DATE-TIME-PARSE-ERROR on malformed input"
    (dolist (string '("not-a-date" "10000-01-02" "2024-367" "2021-W53-1" "2024-W09-8"))
      (signals date-time-parse-error (parse-local-date string)))))

(describe
  "ISO 8601 offset parser boundaries"
  (it
    "rejects trailing characters after a complete offset"
    (dolist (parser (list (function parse-instant)
                          (function cl-date-kit:parse-offset-date-time)))
      (dolist (input (list "2024-06-15T12:00:00+04:00suffix"
                           "2024-06-15T12:00:00Zsuffix"))
        (signals date-time-parse-error (funcall parser input)))))
  (it
    "parses sliced offsets across date-time parser variants"
    (let ((instant (parse-instant "2024-06-15T12:00:00+093015"))
          (offset-date-time
            (parse-offset-date-time "2024-06-15T12:00:00+09:30:15"))
          (zoned-date-time
            (parse-zoned-date-time "2024-06-15T12:00:00+09:30:15"))
          (offset-time (parse-offset-time "12:00:00+093015")))
      (expect
        (instant= instant (parse-instant "2024-06-15T02:29:45Z"))
        :to-be-truthy)
      (dolist
          (offset
           (list (offset-date-time-offset offset-date-time)
                 (zoned-date-time-offset zoned-date-time)
                 (offset-time-offset offset-time)))
        (expect (zone-offset-total-seconds offset) :to-be 34215))))
  (it
    "retains parse errors for malformed sliced offsets"
    (dolist
        (entry
         (list
          (list (function parse-instant) "2024-06-15T12:00:00+09:0")
          (list (function parse-offset-date-time) "2024-06-15T12:00:00+09:0")
          (list (function parse-zoned-date-time) "2024-06-15T12:00:00+09:0")
          (list (function parse-offset-time) "12:00:00+09:0")))
      (destructuring-bind (parser input) entry
        (signals date-time-parse-error (funcall parser input))))))

(describe
  "Duration ISO 8601 day components"
  (it
    "accepts whole-day components with or without a time section"
    (expect (duration= (parse-duration "P0D") (duration-zero)) :to-be-truthy)
    (expect (duration= (parse-duration "P2D") (duration-of-days 2)) :to-be-truthy)
    (expect
      (duration=
        (parse-duration "P2DT3H4M5.006S")
        (duration-of-seconds (+ (* 2 86400) (* 3 3600) (* 4 60) 5) 6000000))
      :to-be-truthy)
    (expect (duration= (parse-duration "-P1D") (duration-of-days -1)) :to-be-truthy))
  (it
    "rejects missing duration components and time separators"
    (dolist (string '("P" "PT" "P2DT" "P2D3H"))
      (signals date-time-parse-error (parse-duration string)))))

(describe
  "YearMonth"
  (it
    "formats and parses canonical and basic ISO 8601 forms"
    (let ((value (make-year-month 2024 6)))
      (expect (format-year-month value) :to-equal "2024-06")
      (expect (year-month= (parse-year-month "2024-06") value) :to-be-truthy)
      (expect (year-month= (parse-year-month "202406") value) :to-be-truthy)))
  (it
    "round-trips signed expanded ISO 8601 years"
    (dolist (case '(("-0001-06" -1) ("+10000-06" 10000)))
      (destructuring-bind (string year) case
        (let ((value (make-year-month year 6)))
          (expect (format-year-month value) :to-equal string)
          (expect (year-month= (parse-year-month string) value) :to-be-truthy)))))
  (it
    "normalizes malformed and invalid values to DATE-TIME-PARSE-ERROR"
    (dolist (string '("2024-6" "10000-06" "2024-13" "2024-00" "2024-06-15" "year-month"))
      (signals date-time-parse-error (parse-year-month string)))))

(describe
  "MonthDay"
  (it
    "formats and parses canonical and basic ISO 8601 forms"
    (let ((value (make-month-day 6 15)))
      (expect (format-month-day value) :to-equal "--06-15")
      (expect (month-day= (parse-month-day "--06-15") value) :to-be-truthy)
      (expect (month-day= (parse-month-day "--0615") value) :to-be-truthy)))
  (it
    "normalizes malformed and invalid values to DATE-TIME-PARSE-ERROR"
    (dolist (string '("06-15" "--6-15" "--02-30" "--13-01" "month-day"))
      (signals date-time-parse-error (parse-month-day string)))))

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
  (it
    "normalizes malformed values to DATE-TIME-PARSE-ERROR"
    (dolist (string '("024" "20240" "-001" "year"))
      (signals date-time-parse-error (parse-year string)))))

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
      (expect (local-time-nanosecond time) :to-be 123456789))))

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
        :to-be-truthy))))

(describe
  "Instant"
  (progn
  (it
   "PARSE-INSTANT accepts a trailing Z"
   (let ((i (parse-instant "2024-06-15T12:34:56Z")))
     (expect (instant-epoch-second i) :to-be 1718454896)))
  (it
   "PARSE-INSTANT validates canonical UTC values"
   (expect
    (instant-epoch-second (parse-instant "2000-02-29T00:00:00Z"))
    :to-be
    951782400)
   (dolist
       (string
        '("2024-02-30T12:00:00Z"
          "2024-06-15T24:00:00Z"
          "2024-06-15T12:60:00Z"
          "2024-06-15T12:00:60Z"))
     (signals date-time-parse-error (parse-instant string)))))
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
  (it
    "PARSE-INSTANT signals DATE-TIME-PARSE-ERROR for malformed ISO suffixes"
    (dolist (string
        (list
          "2024-06-15T12:00:00"
          "2024-06-15T12:00:00+"
          "2024-06-15T12:00:00+040"
          "2024-06-15T12:00:00+04:00suffix"
          "2024-06-15T12:00:00Zsuffix"))
      (signals date-time-parse-error (parse-instant string)))))

(describe
  "ZonedDateTime"
  (it
    "formats and parses a bracketed zone id"
    (let* ((z
          (zoned-date-time-of-local
            (local-date-time-of 2024 6 15 12 0 0)
            (find-time-zone "America/New_York")))
           (s (format-zoned-date-time z)))
      (expect s :to-equal "2024-06-15T12:00:00-04:00[America/New_York]")
      (expect
        (time-zone-name (zoned-date-time-zone (parse-zoned-date-time s)))
        :to-equal
        "America/New_York")))
  (it
    "formats and parses a fixed offset without a zone suffix"
    (let ((value (parse-zoned-date-time "2024-06-15T12:34:56.123+09:30:15")))
      (expect
        (zone-offset-total-seconds (zoned-date-time-zone value))
        :to-be
        34215)
      (expect
        (format-zoned-date-time value)
        :to-equal
        "2024-06-15T12:34:56.123000000+09:30:15")))

  (it
    "accepts both valid offsets during a named-zone overlap"
    (dolist (entry
        '(("2024-11-03T01:30:00-04:00[America/New_York]" -14400)
          ("2024-11-03T01:30:00-05:00[America/New_York]" -18000)))
      (destructuring-bind (string expected-offset) entry
        (expect
          (=
            expected-offset
            (zone-offset-total-seconds
              (zoned-date-time-offset (parse-zoned-date-time string))))
          :to-be-truthy))))
  (it
    "rejects offsets that are invalid for the named zone"
    (signals
      date-time-parse-error
      (parse-zoned-date-time "2024-01-15T12:00:00-04:00[America/New_York]")))
  (it
    "PARSE-ZONED-DATE-TIME signals DATE-TIME-PARSE-ERROR for malformed strings"
    (dolist (string
        '("2024-06-15T12:00:00+04:00[America/New_York"
          "2024-06-15T12:00:00+04:00[]"
          "2024-06-15T12:00:00+04:00[America/New_York]trailing"))
      (signals date-time-parse-error (parse-zoned-date-time string)))))

(describe
  "Duration"
  (it
    "formats as java.time's PT-style duration string"
    (expect (format-duration (duration-of-seconds 3661)) :to-equal "PT1H1M1S")
    (expect (format-duration (duration-zero)) :to-equal "PT0S")
    (expect (format-duration (duration-of-minutes 15)) :to-equal "PT15M"))
  (it
    "a negative duration is prefixed with a leading minus"
    (expect (format-duration (duration-of-seconds -5400)) :to-equal "-PT1H30M"))
  (it
    "round-trips through PARSE-DURATION"
    (dolist (d
        (list
          (duration-of-seconds 3661)
          (duration-zero)
          (duration-of-seconds -5400)
          (duration-of-millis 1500)))
      (expect (duration= (parse-duration (format-duration d)) d) :to-be-truthy))))
  (it
    "accepts ISO 8601 day components without losing exact precision"
    (expect
      (duration= (parse-duration "P2D") (duration-of-days 2))
      :to-be-truthy)
    (expect
      (duration= (parse-duration "P2DT3H4M5.006S")
                 (duration-of-seconds (+ (* 2 86400) (* 3 3600) (* 4 60) 5)
                                      6000000))
      :to-be-truthy)
    (expect
      (duration= (parse-duration "-P1D") (duration-of-days -1))
      :to-be-truthy))

(progn
(describe
  "Period"
  (it
   "formats as a calendar ISO-8601 period string"
   (expect
    (format-period (make-period :years 1 :months 2 :days 3))
    :to-equal
    "P1Y2M3D")
   (expect (format-period (make-period)) :to-equal "P0D"))
  (it
   "round-trips signed calendar components and parses signs"
   (let ((period (make-period :years -1 :months 2 :days -3)))
     (expect (period= (parse-period (format-period period)) period) :to-be-truthy))
   (expect
    (period= (parse-period "P-1Y2M") (make-period :years -1 :months 2))
    :to-be-truthy)
   (expect
    (period= (parse-period "-P1Y2M3D") (make-period :years -1 :months -2 :days -3))
    :to-be-truthy)
   (expect
    (period= (parse-period "-P-1Y2M") (make-period :years 1 :months -2))
    :to-be-truthy))
  (it
   "accepts week components alongside date fields"
   (expect
    (period= (parse-period "P1Y2M3W4D") (make-period :years 1 :months 2 :days 25))
    :to-be-truthy)
   (expect (period= (parse-period "P-2W") (make-period :days -14)) :to-be-truthy))
  (it
   "rejects missing, malformed, and unordered components"
   (dolist (input (list "P" "-P" "P-Y" "P1D2M" "P1W2Y"))
     (signals date-time-parse-error (parse-period input)))))
(describe
  "Interval ISO 8601"
  (it
    "formats canonical UTC start/end endpoints"
    (expect
      (cl-date-kit:format-interval
        (cl-date-kit:make-interval
          (parse-instant "2024-06-15T12:00:00+09:00")
          (parse-instant "2024-06-15T14:00:00+09:00")))
      :to-equal
      "2024-06-15T03:00:00Z/2024-06-15T05:00:00Z"))
  (it
    "parses all supported representations"
    (dolist
      (input
       (list
        "2024-06-15T12:00:00Z/2024-06-15T14:00:00Z"
        "2024-06-15T12:00:00Z/PT2H"
        "PT2H/2024-06-15T14:00:00Z"))
      (expect
        (cl-date-kit:format-interval (cl-date-kit:parse-interval input))
        :to-equal
        "2024-06-15T12:00:00Z/2024-06-15T14:00:00Z")))
  (it
    "uses absolute instants when parsing offsets"
    (expect
      (cl-date-kit:format-interval
        (cl-date-kit:parse-interval "2024-06-15T12:00:00+09:00/PT1H"))
      :to-equal
      "2024-06-15T03:00:00Z/2024-06-15T04:00:00Z"))
  (it
    "accepts zero durations"
    (expect
      (cl-date-kit:format-interval
        (cl-date-kit:parse-interval "PT0S/2024-06-15T12:00:00Z"))
      :to-equal
      "2024-06-15T12:00:00Z/2024-06-15T12:00:00Z"))
  (it
    "rejects unsupported or invalid forms"
    (dolist
      (input
       (list
        "2024-06-15T12:00:00Z/-PT1S"
        "2024-06-15T14:00:00Z/2024-06-15T12:00:00Z"
        "2024-06-15T12:00:00Z/2024-06-15T14:00:00Z/"
        "/2024-06-15T12:00:00Z"
        "2024-06-15T12:00:00Z/"
        "PT1S/PT2S"
        #()))
      (signals date-time-parse-error (cl-date-kit:parse-interval input))))))

(describe "Duration precision" (it "round-trips every nanosecond digit without float conversion" (dolist (duration (list (duration-of-seconds 0 1) (duration-of-seconds 12 123456789) (duration-of-seconds -1 500000000))) (expect (duration= (parse-duration (format-duration duration)) duration) :to-be-truthy))) (it "accepts ISO 8601 comma decimal fractions" (expect (duration= (parse-duration "PT1,5H") (duration-of-seconds 5400)) :to-be-truthy) (expect (duration= (parse-duration "PT0,000000001S") (duration-of-seconds 0 1)) :to-be-truthy) (signals date-time-parse-error (parse-duration "PT1,5.0S"))))

(describe
  "ISO 8601 parser strictness"
  (it
    "rejects non-digits in fixed-width fields"
    (signals date-time-parse-error (parse-local-date "2024- 1-01")))
  (it
    "rejects empty and over-precise duration fractions"
    (dolist (input (list "PT1.S" "PT0.1234567890S"))
      (signals date-time-parse-error (parse-duration input))))
  (it
    "requires the fractional duration unit to be last"
    (signals date-time-parse-error (parse-duration "PT1.5H30M")))
  (it
    "retains exact fractional non-second durations"
    (expect
      (duration= (parse-duration "PT1.5H") (duration-of-seconds 5400))
      :to-be-truthy)))



(describe
  "LocalDateInterval ISO 8601"
  (it
    "round-trips exact half-open date endpoints"
    (dolist (input (list "2024-06-15/2024-06-20" "2024-06-15/2024-06-15" "-0001-01-01/+10000-12-31"))
      (expect
        (cl-date-kit:format-local-date-interval
          (cl-date-kit:parse-local-date-interval input))
        :to-equal
        input)))
  (it
    "rejects malformed and descending endpoints"
    (dolist
      (input
       (list
        "2024-06-15"
        "2024-06-15/"
        "/2024-06-20"
        "2024-06-15/2024-06-20/2024-06-21"
        "2024-06-20/2024-06-15"
        #()))
      (signals date-time-parse-error (cl-date-kit:parse-local-date-interval input)))))
