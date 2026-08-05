;;;; t/iso8601-offset-test.lisp
(in-package #:cl-date-kit/test)

;;; Offset/zone-aware ISO 8601 types: ZoneOffset, OffsetDateTime, OffsetTime,
;;; ZonedDateTime, and the Duration/Period amount round-trips (including the
;;; PARSE-DURATION/FORMAT-DURATION property test). See iso8601-test.lisp for
;;; the naive (zone-less) date/time types.

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
        (cl-date-kit:parse-offset-date-time "2024-06-15T12:34:56")))
    (it
      "PARSE-OFFSET-DATE-TIME signals DATE-TIME-PARSE-ERROR on non-string input"
      (signals date-time-parse-error (cl-date-kit:parse-offset-date-time 42)))
    (it
      "PARSE-OFFSET-DATE-TIME signals DATE-TIME-PARSE-ERROR when the T separator is missing"
      (signals
        date-time-parse-error
        (cl-date-kit:parse-offset-date-time "2024-06-15 12:34:56+09:00"))))
  (describe
    "ZoneOffset ISO 8601"
    (it
      "formats canonical extended notation"
      (expect
        (cl-date-kit:format-zone-offset (zone-offset-of-hms -4 -30 -15))
        :to-equal
        "-04:30:15"))
    (it
      "formats a zero offset as Z"
      (expect (cl-date-kit:format-zone-offset (zone-offset-utc)) :to-equal "Z"))
    (it-each
        (("Z" 0)
         ("+09" 32400)
         ("+0900" 32400)
         ("+09:00" 32400)
         ("-043015" -16215)
         ("-04:30:15" -16215))
        "parses ~S as ~A total seconds"
        (string total-seconds)
      (expect
        (zone-offset-total-seconds (cl-date-kit:parse-zone-offset string))
        :to-be
        total-seconds))
    (it-each
        (("+") ("+0") ("+090") ("+09:0") ("+09:000") ("+180001") ("UTC"))
        "normalizes ~S to DATE-TIME-PARSE-ERROR"
        (string)
      (signals date-time-parse-error (cl-date-kit:parse-zone-offset string)))
    (it
      "PARSE-ZONE-OFFSET signals DATE-TIME-PARSE-ERROR on non-string input"
      (signals date-time-parse-error (cl-date-kit:parse-zone-offset 42)))))

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
    (signals date-time-parse-error (parse-offset-time "12:34:56")))
  (it
    "PARSE-OFFSET-TIME signals DATE-TIME-PARSE-ERROR on non-string input"
    (signals date-time-parse-error (parse-offset-time 42))))

(describe
  "ISO 8601 offset parser boundaries"
  (it-each
      ((parse-instant "2024-06-15T12:00:00+04:00suffix")
       (parse-instant "2024-06-15T12:00:00Zsuffix")
       (cl-date-kit:parse-offset-date-time "2024-06-15T12:00:00+04:00suffix")
       (cl-date-kit:parse-offset-date-time "2024-06-15T12:00:00Zsuffix"))
      "~A rejects trailing characters in ~S"
      (parser input)
    (signals date-time-parse-error (funcall (symbol-function parser) input)))
  (it
    "parses sliced offsets across date-time parser variants"
    (let ((instant (parse-instant "2024-06-15T12:00:00+093015"))
          (offset-date-time (parse-offset-date-time "2024-06-15T12:00:00+09:30:15"))
          (zoned-date-time (parse-zoned-date-time "2024-06-15T12:00:00+09:30:15"))
          (offset-time (parse-offset-time "12:00:00+093015")))
      (expect (instant= instant (parse-instant "2024-06-15T02:29:45Z")) :to-be-truthy)
      (dolist (offset
          (list
            (offset-date-time-offset offset-date-time)
            (zoned-date-time-offset zoned-date-time)
            (offset-time-offset offset-time)))
        (expect (zone-offset-total-seconds offset) :to-be 34215))))
  (it-each
      ((parse-instant "2024-06-15T12:00:00+09:0")
       (cl-date-kit:parse-offset-date-time "2024-06-15T12:00:00+09:0")
       (parse-zoned-date-time "2024-06-15T12:00:00+09:0")
       (parse-offset-time "12:00:00+09:0"))
      "~A retains a parse error for ~S"
      (parser input)
    (signals date-time-parse-error (funcall (symbol-function parser) input))))

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
  (it-each
      (("P") ("PT") ("P2DT") ("P2D3H"))
      "rejects the missing duration component or time separator in ~S"
      (string)
    (signals date-time-parse-error (parse-duration string)))
  (it
    "PARSE-DURATION signals DATE-TIME-PARSE-ERROR on an empty string"
    (signals date-time-parse-error (parse-duration "")))
  (it
    "PARSE-DURATION signals DATE-TIME-PARSE-ERROR when the P designator is missing"
    (signals date-time-parse-error (parse-duration "1H")))
  (it
    "PARSE-DURATION signals DATE-TIME-PARSE-ERROR when a numeric component has no unit letter"
    (signals date-time-parse-error (parse-duration "PT5"))))

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
      (expect (zone-offset-total-seconds (zoned-date-time-zone value)) :to-be 34215)
      (expect
        (format-zoned-date-time value)
        :to-equal
        "2024-06-15T12:34:56.123000000+09:30:15")))
  (it-each
      (("2024-11-03T01:30:00-04:00[America/New_York]" -14400)
       ("2024-11-03T01:30:00-05:00[America/New_York]" -18000))
      "accepts ~S as a valid offset during a named-zone overlap"
      (string expected-offset)
    (expect
      (=
        expected-offset
        (zone-offset-total-seconds
          (zoned-date-time-offset (parse-zoned-date-time string))))
      :to-be-truthy))
  (it
    "rejects offsets that are invalid for the named zone"
    (signals
      date-time-parse-error
      (parse-zoned-date-time "2024-01-15T12:00:00-04:00[America/New_York]")))
  (it-each
      (("2024-06-15T12:00:00+04:00[America/New_York")
       ("2024-06-15T12:00:00+04:00[]")
       ("2024-06-15T12:00:00+04:00[America/New_York]trailing")
       ("2024-06-15T12:34:56")
       ("2024-06-15T12:00:00+04:00[Not/AZone]"))
      "PARSE-ZONED-DATE-TIME signals DATE-TIME-PARSE-ERROR for the malformed string ~S"
      (string)
    (signals date-time-parse-error (parse-zoned-date-time string)))
  (it
    "PARSE-ZONED-DATE-TIME signals DATE-TIME-PARSE-ERROR on non-string input"
    (signals date-time-parse-error (parse-zoned-date-time 42)))
  (it
    "accepts a lowercase t separator"
    (expect
      (zoned-date-time=
        (parse-zoned-date-time "2024-06-15t12:34:56+09:00")
        (parse-zoned-date-time "2024-06-15T12:34:56+09:00"))
      :to-be-truthy)))

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
  (it-each
      ((3661 0) (0 0) (-5400 0) (1 500000000))
      "round-trips ~A seconds and ~A nanoseconds through PARSE-DURATION"
      (seconds nanos)
    (let ((d (duration-of-seconds seconds nanos)))
      (expect (duration= (parse-duration (format-duration d)) d) :to-be-truthy)))
  (it-property
      "PARSE-DURATION inverts FORMAT-DURATION for any duration"
      ((seconds (gen-integer :min -1000000 :max 1000000))
       (nanos (gen-integer :min 0 :max 999999999)))
    (let ((d (duration-of-seconds seconds nanos)))
      (expect (duration= (parse-duration (format-duration d)) d) :to-be-truthy))))

(it
  "accepts ISO 8601 day components without losing exact precision"
  (expect (duration= (parse-duration "P2D") (duration-of-days 2)) :to-be-truthy)
  (expect
    (duration=
      (parse-duration "P2DT3H4M5.006S")
      (duration-of-seconds (+ (* 2 86400) (* 3 3600) (* 4 60) 5) 6000000))
    :to-be-truthy)
  (expect (duration= (parse-duration "-P1D") (duration-of-days -1)) :to-be-truthy))

(progn
  (describe
    "Period"
    (it
      "formats as a calendar ISO-8601 period string"
      (expect
        (format-period (make-period :years 1 :months 2 :days 3))
        :to-equal
        "P1Y2M3D")
      (expect (format-period (make-period)) :to-equal "P0D")
      (expect (format-period (make-period :months 5)) :to-equal "P5M")
      (expect (format-period (make-period :days 7)) :to-equal "P7D"))
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
    (it-each
        (("P") ("-P") ("P-Y") ("P1D2M") ("P1W2Y") ("1Y") ("P5"))
        "rejects the missing, malformed, or unordered component in ~S"
        (input)
      (signals date-time-parse-error (parse-period input))))
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
    (it-each
        (("2024-06-15T12:00:00Z/2024-06-15T14:00:00Z")
         ("2024-06-15T12:00:00Z/PT2H")
         ("PT2H/2024-06-15T14:00:00Z"))
        "parses the supported representation ~S"
        (input)
      (expect
        (cl-date-kit:format-interval (cl-date-kit:parse-interval input))
        :to-equal
        "2024-06-15T12:00:00Z/2024-06-15T14:00:00Z"))
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
    (it-each
        (("2024-06-15T12:00:00Z/-PT1S")
         ("2024-06-15T14:00:00Z/2024-06-15T12:00:00Z")
         ("2024-06-15T12:00:00Z/2024-06-15T14:00:00Z/")
         ("/2024-06-15T12:00:00Z")
         ("2024-06-15T12:00:00Z/")
         ("PT1S/PT2S")
         (#()))
        "rejects the unsupported or invalid form ~S"
        (input)
      (signals date-time-parse-error (cl-date-kit:parse-interval input)))))

(describe
  "Duration precision"
  (it-each
      ((0 1) (12 123456789) (-1 500000000))
      "round-trips ~A seconds and ~A nanoseconds without float conversion"
      (seconds nanos)
    (let ((duration (duration-of-seconds seconds nanos)))
      (expect
        (duration= (parse-duration (format-duration duration)) duration)
        :to-be-truthy)))
  (it
    "accepts ISO 8601 comma decimal fractions"
    (expect
      (duration= (parse-duration "PT1,5H") (duration-of-seconds 5400))
      :to-be-truthy)
    (expect
      (duration= (parse-duration "PT0,000000001S") (duration-of-seconds 0 1))
      :to-be-truthy)
    (signals date-time-parse-error (parse-duration "PT1,5.0S"))))

(describe
  "ISO 8601 parser strictness"
  (it
    "rejects non-digits in fixed-width fields"
    (signals date-time-parse-error (parse-local-date "2024- 1-01")))
  (it-each
      (("PT1.S") ("PT0.1234567890S"))
      "rejects the empty or over-precise duration fraction in ~S"
      (input)
    (signals date-time-parse-error (parse-duration input)))
  (it
    "requires the fractional duration unit to be last"
    (signals date-time-parse-error (parse-duration "PT1.5H30M")))
  (it
    "retains exact fractional non-second durations"
    (expect
      (duration= (parse-duration "PT1.5H") (duration-of-seconds 5400))
      :to-be-truthy)))
