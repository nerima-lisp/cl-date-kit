;;;; t/pattern-test.lisp
(in-package #:cl-date-kit/test)

(progn (describe
  "compiled pattern formatters"
  (it
    "formats calendar, ordinal, and ISO week date fields"
    (let ((date (make-local-date 2024 2 29)))
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd 'day' DDD, YYYY-'W'ww-e" date)
        :to-equal
        "2024-02-29 day 060, 2024-W09-4")
      (expect (format-date-time-with-pattern "yyyy''MM" date) :to-equal "2024'02")))
  (it
    "formats ISO signed expanded calendar and week-based years"
    (let ((before-era (make-local-date -1 1 1))
          (expanded (make-local-date 10000 1 1))
          (week-date (local-date-of-week-date 10000 1 1)))
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd" before-era)
        :to-equal
        "-0001-01-01")
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd" expanded)
        :to-equal
        "+10000-01-01")
      (expect
        (format-date-time-with-pattern "YYYY-'W'ww-e" week-date)
        :to-equal
        "+10000-W01-1")))
  (progn
    (it
      "formats time and fractional-second fields"
      (let ((time (make-local-time 7 5 9 123456789)))
        (expect
          (format-date-time-with-pattern "HH:mm:ss.SSSSSS" time)
          :to-equal
          "07:05:09.123456")
        (expect (format-date-time-with-pattern "H:m:s.S" time) :to-equal "7:5:9.1")))
    (it
      "formats and parses 12-hour clocks with an explicit meridiem"
      (expect
        (format-date-time-with-pattern "hh:mm a" (make-local-time 0 5 0 0))
        :to-equal
        "12:05 AM")
      (expect
        (format-date-time-with-pattern "h:m a" (make-local-time 12 5 0 0))
        :to-equal
        "12:5 PM")
      (expect
        (format-date-time-with-pattern "hh:mm a" (make-local-time 13 5 0 0))
        :to-equal
        "01:05 PM")
      (expect
        (local-date-time=
          (parse-date-time-with-pattern "yyyy-MM-dd hh:mm a" "2024-02-29 12:05 AM")
          (local-date-time-of 2024 2 29 0 5 0 0))
        :to-be-truthy)
      (expect
        (local-date-time=
          (parse-date-time-with-pattern "yyyy-MM-dd h:mm a" "2024-02-29 12:05 PM")
          (local-date-time-of 2024 2 29 12 5 0 0))
        :to-be-truthy)
      (signals date-time-parse-error (parse-date-time-with-pattern "hh:mm" "12:00"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "hh:mm a" "00:00 AM"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "HH hh:mm a" "00 12:00 AM"))))
  (progn
    (it
      "formats English textual month, weekday, and AM/PM fields"
      (let ((value (local-date-time-of 2024 2 29 7 5 0 0)))
        (expect
          (format-date-time-with-pattern "EEEE, MMMM d yyyy HH:mm a" value)
          :to-equal
          "Thursday, February 29 2024 07:05 AM")
        (expect
          (format-date-time-with-pattern "EEE MMM HH a" value)
          :to-equal
          "Thu Feb 07 AM")))
    (it
      "formats and parses the bundled Japanese locale"
      (let ((value (local-date-time-of 2024 2 29 7 5 0 0)))
        (expect
          (format-date-time-with-pattern "EEEE MMMM d yyyy hh:mm a" value :locale :ja)
          :to-equal
          "木曜日 2月 29 2024 07:05 午前")
        (expect
          (local-date-time=
            (parse-date-time-with-pattern
              "EEE MMM d yyyy hh:mm a"
              "木 2月 29 2024 07:05 午前"
              :locale
              :ja)
            value)
          :to-be-truthy))))
  (it
    "formats and parses a custom locale"
    (let* ((short-months
          (vector
            "1月"
            "2月"
            "3月"
            "4月"
            "5月"
            "6月"
            "7月"
            "8月"
            "9月"
            "10月"
            "11月"
            "12月"))
           (months
          (vector
            "一月"
            "二月"
            "三月"
            "四月"
            "五月"
            "六月"
            "七月"
            "八月"
            "九月"
            "十月"
            "十一月"
            "十二月"))
           (short-weekdays (vector "月" "火" "水" "木" "金" "土" "日"))
           (weekdays
          (vector
            "月曜日"
            "火曜日"
            "水曜日"
            "木曜日"
            "金曜日"
            "土曜日"
            "日曜日"))
           (locale
          (make-date-time-locale
            :name
            :ja-test
            :short-months
            short-months
            :months
            months
            :short-weekdays
            short-weekdays
            :weekdays
            weekdays
            :am
            "午前"
            :pm
            "午後"))
           (value (local-date-time-of 2024 2 29 7 5 0 0)))
      (setf (aref short-months 1) "changed")
      (expect (aref (date-time-locale-short-months locale) 1) :to-equal "2月")
      (expect
        (format-date-time-with-pattern "EEE MMM a" value :locale locale)
        :to-equal
        "木 2月 午前")
      (expect
        (format-date-time-with-pattern "EEEE MMMM a" value :locale locale)
        :to-equal
        "木曜日 二月 午前")
      (expect
        (local-date-time=
          (parse-date-time-with-pattern
            "EEE MMM d yyyy HH:mm a"
            "木 2月 29 2024 07:05 午前"
            :locale
            locale)
          value)
        :to-be-truthy)
      (expect
        (local-date-time=
          (parse-date-time-with-pattern
            "EEEE MMMM d yyyy HH:mm a"
            "木曜日 二月 29 2024 07:05 午前"
            :locale
            locale)
          value)
        :to-be-truthy)))
  (it
    "formats local, fixed-offset, named-zone, and instant values"
    (let* ((local (local-date-time-of 2024 2 29 7 5 9 0))
           (offset (zone-offset-of-hms 9 30 0))
           (offset-value (cl-date-kit:offset-date-time-of 2024 2 29 7 5 9 0 offset))
           (offset-time-value (offset-time-of 7 5 9 0 offset))
           (tokyo (find-time-zone "Asia/Tokyo"))
           (new-york (find-time-zone "America/New_York"))
           (zoned (zoned-date-time-of-instant (make-instant 0) tokyo))
           (winter
          (local-date-time-to-instant
            (local-date-time-of 2024 1 15 12 0 0 0)
            (zone-offset-utc)))
           (summer
          (local-date-time-to-instant
            (local-date-time-of 2024 7 15 12 0 0 0)
            (zone-offset-utc))))
      (expect
        (format-date-time-with-pattern "yyyyMMdd'T'HHmmss" local)
        :to-equal
        "20240229T070509")
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd'T'HH:mm:ssXXX" offset-value)
        :to-equal
        "2024-02-29T07:05:09+09:30")
      (expect
        (format-date-time-with-pattern "HH:mm:ssXXX" offset-time-value)
        :to-equal
        "07:05:09+09:30")
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd HH:mm XXX V z" zoned)
        :to-equal
        "1970-01-01 09:00 +09:00 Asia/Tokyo JST")
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd HH:mm XXX V z" winter :zone new-york)
        :to-equal
        "2024-01-15 07:00 -05:00 America/New_York EST")
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd HH:mm XXX V z" summer :zone new-york)
        :to-equal
        "2024-07-15 08:00 -04:00 America/New_York EDT")
      (expect
        (format-date-time-with-pattern "yyyy-MM-dd'T'HH:mm:ssX" (make-instant 0))
        :to-equal
        "1970-01-01T00:00:00Z")))
  (it
    "reports malformed patterns and unavailable temporal fields"
    (signals date-time-format-error (make-date-time-formatter "MMMMM"))
    (progn
      (signals date-time-format-error (make-date-time-formatter "EE"))
      (signals date-time-format-error (make-date-time-formatter "hhh")))
    (signals date-time-format-error (make-date-time-formatter "aa"))
    (signals date-time-format-error (make-date-time-formatter "zz"))
    (signals date-time-format-error (make-date-time-formatter "MMM" :locale :zz))
    (signals date-time-format-error (make-date-time-formatter "yyyy-'unterminated"))
    (signals
      date-time-format-error
      (format-date-time-with-pattern "HH:mm" (make-local-date 2024 1 1)))
    (signals
      date-time-format-error
      (format-date-time-with-pattern "z" (make-instant 0)))
    (signals
      date-time-format-error
      (format-date-time-with-pattern
        "yyyy-MM-dd"
        (local-date-time-of 2024 1 1 0 0 0 0)
        :zone
        (find-time-zone "Asia/Tokyo")))
    (signals
      date-time-format-error
      (format-date-time-with-pattern
        "yyyy-MM-dd V"
        (local-date-time-of 2024 1 1 0 0 0 0)))
    (signals
      date-time-parse-error
      (parse-date-time-with-pattern "yyyy-MM-dd z" "2024-01-01 EST")))
  (it
    "parses calendar, ordinal, and week patterns"
    (let ((calendar
          (parse-date-time-with-pattern
            "yyyy-MM-dd'T'HH:mm:ss.SSS"
            "2024-02-29T07:05:09.123"))
          (ordinal (parse-date-time-with-pattern "yyyy-DDD" "2024-060"))
          (week (parse-date-time-with-pattern "YYYY-'W'ww-e" "2024-W09-4")))
      (expect
        (local-date-time= calendar (local-date-time-of 2024 2 29 7 5 9 123000000))
        :to-be-truthy)
      (expect
        (local-date-time=
          (parse-date-time-with-pattern "yyyyMMdd'T'HHmmss" "20240229T070509")
          (local-date-time-of 2024 2 29 7 5 9 0))
        :to-be-truthy)
      (expect (local-date= ordinal (make-local-date 2024 2 29)) :to-be-truthy)
      (expect (local-date= week (make-local-date 2024 2 29)) :to-be-truthy)))
  (it
    "parses English textual fields case-insensitively"
    (expect
      (local-date-time=
        (parse-date-time-with-pattern
          "EEEE, MMMM d yyyy HH:mm a"
          "thursday, february 29 2024 07:05 am")
        (local-date-time-of 2024 2 29 7 5 0 0))
      :to-be-truthy))
  (it
    "parses offset and named-zone patterns"
    (let* ((offset
          (parse-date-time-with-pattern
            "yyyy-MM-dd'T'HH:mm:ssXXX"
            "2024-02-29T07:05:09+09:30"))
           (offset-time (parse-date-time-with-pattern "HH:mm:ssXXX" "07:05:09+09:30"))
           (zoned
          (parse-date-time-with-pattern
            "yyyy-MM-dd HH:mm XXX V"
            "1970-01-01 09:00 +09:00 Asia/Tokyo")))
      (expect
        (zone-offset-total-seconds (offset-date-time-offset offset))
        :to-equal
        34200)
      (expect
        (zone-offset-total-seconds (offset-time-offset offset-time))
        :to-equal
        34200)
      (expect
        (instant= (zoned-date-time-to-instant zoned) (make-instant 0))
        :to-be-truthy)))
  (it
    "rejects ambiguous or inconsistent parsed values"
    (signals date-time-parse-error (parse-date-time-with-pattern "yMd" "20240229"))
    (signals
      date-time-parse-error
      (parse-date-time-with-pattern "yyyy-MM-dd" "2023-02-29"))
    (signals
      date-time-parse-error
      (parse-date-time-with-pattern
        "yyyy-MM-dd HH:mm XXX V"
        "1970-01-01 09:00 +08:00 Asia/Tokyo"))
    (signals
      date-time-parse-error
      (parse-date-time-with-pattern
        "EEEE, MMMM d yyyy HH:mm a"
        "Friday, February 29 2024 07:05 AM"))
    (signals
      date-time-parse-error
      (parse-date-time-with-pattern
        "EEEE, MMMM d yyyy HH:mm a"
        "Thursday, February 29 2024 13:05 AM")))) (describe
  "pattern parser boundary behavior"
  (it
    "rejects incomplete, conflicting, and malformed field input"
    (signals date-time-parse-error
      (parse-date-time-with-pattern "yyyy-MM" "2024-02"))
    (signals date-time-parse-error
      (parse-date-time-with-pattern "yyyy-DDD-MM-dd" "2024-060-02-29"))
    (signals date-time-parse-error
      (parse-date-time-with-pattern "YYYY-'W'ww" "2024-W09"))
    (signals date-time-parse-error
      (parse-date-time-with-pattern "MMMM d yyyy" "Fakemonth 1 2024"))
    (signals date-time-parse-error
      (parse-date-time-with-pattern "EEEE, yyyy-MM-dd" "Friday, 2024-02-29"))
    (signals date-time-parse-error
      (parse-date-time-with-pattern "hh:mm a" "12:00 noon"))
    (signals date-time-parse-error
      (parse-date-time-with-pattern "yyyy-MM-ddXXX" "2024-02-29+09:00"))
    (signals date-time-parse-error
      (parse-date-time-with-pattern "yyyy-MM-dd HH:mm" "2024-02-29 07:05x")))
  (it
    "returns local and offset time values without date fields"
    (expect
      (local-time-p (parse-date-time-with-pattern "HH:mm" "07:05"))
      :to-be-truthy)
    (expect
      (offset-time-p
        (parse-date-time-with-pattern "HH:mmXXX" "07:05+09:00"))
      :to-be-truthy))))
