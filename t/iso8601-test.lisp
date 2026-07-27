;;;; t/iso8601-test.lisp
(in-package #:cl-date-kit/test)

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
    "rejects an offset-less local date-time"
    (signals
      date-time-parse-error
      (cl-date-kit:parse-offset-date-time "2024-06-15T12:34:56"))))

(describe
  "LocalDate"
  (it
    "formats and parses YYYY-MM-DD"
    (expect (format-local-date (make-local-date 2024 3 10)) :to-equal "2024-03-10")
    (expect
      (local-date= (parse-local-date "2024-03-10") (make-local-date 2024 3 10))
      :to-be-truthy))
  (it
    "PARSE-LOCAL-DATE signals DATE-TIME-PARSE-ERROR on malformed input"
    (signals date-time-parse-error (parse-local-date "not-a-date"))))

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
      500000000)))

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
        :to-be-truthy))))

(describe
  "Instant"
  (it
    "PARSE-INSTANT accepts a trailing Z"
    (let ((i (parse-instant "2024-06-15T12:34:56Z")))
      (expect (instant-epoch-second i) :to-be 1718454896)))
  (it
    "round-trips through PARSE-INSTANT and FORMAT-INSTANT"
    (let ((i (make-instant 1718454896)))
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
        '("2024-06-15T12:00:00"
          "2024-06-15T12:00:00+"
          "2024-06-15T12:00:00+04"
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
    "round-trips through PARSE-PERIOD"
    (expect
      (period= (parse-period "P1Y2M3D") (make-period :years 1 :months 2 :days 3))
      :to-be-truthy)))

(describe
  "Duration precision"
  (it
    "round-trips every nanosecond digit without float conversion"
    (dolist (duration
        (list
          (duration-of-seconds 0 1)
          (duration-of-seconds 12 123456789)
          (duration-of-seconds -1 500000000)))
      (expect
        (duration= (parse-duration (format-duration duration)) duration)
        :to-be-truthy))))

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
  "Parser failure contract"
  (it
    "normalizes invalid semantic fields to DATE-TIME-PARSE-ERROR"
    (signals date-time-parse-error (parse-local-date "2024-02-30"))
    (signals date-time-parse-error (parse-local-time "24:00:00"))
    (signals date-time-parse-error (parse-local-date-time "2024-02-30T00:00:00")))
  (it
    "normalizes invalid offsets and unknown zones to DATE-TIME-PARSE-ERROR"
    (signals date-time-parse-error (parse-instant "2024-01-01T00:00:00+19:00"))
    (signals
      date-time-parse-error
      (parse-zoned-date-time "2024-01-01T00:00:00Z[Etc/No-Such-Zone]")))
  (it
    "rejects missing components and non-string duration and period inputs consistently"
    (dolist (input (list "" "PT" #()))
      (signals date-time-parse-error (parse-duration input)))
    (dolist (input (list "" "P" #()))
      (signals date-time-parse-error (parse-period input))))
  (it
    "rejects duplicate, out-of-order, and mixed-week components"
    (dolist (input (list "PT1H1H" "PT1M1H" "P1Y1Y" "P1D1M" "P1W1D"))
      (signals
        date-time-parse-error
        (if (search "PT" input) (parse-duration input)
          (parse-period input))))))
