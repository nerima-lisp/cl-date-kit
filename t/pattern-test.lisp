(in-package #:cl-date-kit/test)

(progn
  (describe
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
      "formats and parses millisecond-of-day with the A field"
      (let ((time (local-time-of 13 45 30 123000000)))
        (expect (format-date-time-with-pattern "A" time) :to-equal "49530123")
        (expect
          (local-time= (parse-date-time-with-pattern "A" "49530123") time)
          :to-be-truthy))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "HH:mm:ss A" "13:45:30 49530123")))
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
          "Thursday, February 29 2024 13:05 AM")))
    (progn
      (it
        "registers every pattern field with both a writer and a reader"
        (loop for character across cl-date-kit::+pattern-fields+
              for spec = (gethash character cl-date-kit::*pattern-fields*)
              do (progn
            (expect spec :to-be-truthy)
            (expect (functionp (cl-date-kit::pattern-field-spec-writer spec)) :to-be-truthy)
            (expect (functionp (cl-date-kit::pattern-field-spec-reader spec)) :to-be-truthy))))
      (it-each
          (("ddd") ("DDDD") ("www") ("eee") ("HHH") ("mmm") ("sss") ("SSSSSSSSSS") ("XXXX") ("VV"))
          "rejects pattern ~S for exceeding its field's supported width"
          (pattern)
        (signals date-time-format-error (make-date-time-formatter pattern)))
      (it
        "rejects a pattern that is not a string or that contains an unregistered field letter"
        (signals date-time-format-error (make-date-time-formatter 12345))
        (signals date-time-format-error (make-date-time-formatter "G")))
      (it
        "unescapes a doubled single quote inside a quoted literal"
        (expect
          (format-date-time-with-pattern "'don''t' yyyy" (make-local-date 2024 2 29))
          :to-equal
          "don't 2024"))
      (it
        "formats the numeric offset field at every supported width and rejects lossy sub-minute seconds"
        (let ((sub-minute (offset-time-of 7 5 9 0 (zone-offset-of-hms 9 30 15))))
          (expect
            (format-date-time-with-pattern "X" (offset-time-of 7 5 9 0 (zone-offset-of-hms 9 0 0)))
            :to-equal
            "+09")
          (expect
            (format-date-time-with-pattern "XX" (offset-time-of 7 5 9 0 (zone-offset-of-hms 9 30 0)))
            :to-equal
            "+0930")
          (expect (format-date-time-with-pattern "XXX" sub-minute) :to-equal "+09:30:15")
          (signals date-time-format-error (format-date-time-with-pattern "X" sub-minute))
          (signals date-time-format-error (format-date-time-with-pattern "XX" sub-minute))))
      (it
        "rejects formatting an unsupported value and a malformed formatter or parse input"
        (signals date-time-format-error (format-date-time-with-pattern "yyyy" 42))
        (signals type-error (format-date-time "not-a-formatter" (make-local-date 2024 1 1)))
        (signals type-error (parse-date-time "not-a-formatter" "2024-01-01"))
        (signals
          date-time-parse-error
          (parse-date-time (make-date-time-formatter "yyyy-MM-dd") 12345)))
      (it
        "reports field V against a fixed offset zone as not IANA"
        (signals
          date-time-format-error
          (format-date-time-with-pattern "V" (make-instant 0) :zone (zone-offset-of-hms 9 0 0))))
      (it
        "signals when DEFINE-PATTERN-FIELD is registered without a required clause"
        (signals error (macroexpand-1 '(cl-date-kit::define-pattern-field #\Q :read (values))))
        (signals
          error
          (macroexpand-1 '(cl-date-kit::define-pattern-field #\Q :write (values)))))
      (it-property
          "PARSE-DATE-TIME-WITH-PATTERN inverts FORMAT-DATE-TIME-WITH-PATTERN for any LOCAL-DATE-TIME"
          ((year (gen-integer :min 1 :max 9999))
           (month (gen-integer :min 1 :max 12))
           (day (gen-integer :min 1 :max 28))
           (hour (gen-integer :min 0 :max 23))
           (minute (gen-integer :min 0 :max 59))
           (second (gen-integer :min 0 :max 59)))
        (let ((value (local-date-time-of year month day hour minute second)))
          (expect
            (local-date-time=
              (parse-date-time-with-pattern
                "yyyy-MM-dd'T'HH:mm:ss"
                (format-date-time-with-pattern "yyyy-MM-dd'T'HH:mm:ss" value))
              value)
            :to-be-truthy)))))
  (describe
    "pattern parser boundary behavior"
    (it
      "rejects incomplete, conflicting, and malformed field input"
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "yyyy-MM" "2024-02"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "yyyy-DDD-MM-dd" "2024-060-02-29"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "YYYY-'W'ww" "2024-W09"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "MMMM d yyyy" "Fakemonth 1 2024"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "EEEE, yyyy-MM-dd" "Friday, 2024-02-29"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "hh:mm a" "12:00 noon"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "yyyy-MM-ddXXX" "2024-02-29+09:00"))
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "yyyy-MM-dd HH:mm" "2024-02-29 07:05x")))
    (it
      "returns local and offset time values without date fields"
      (expect
        (local-time-p (parse-date-time-with-pattern "HH:mm" "07:05"))
        :to-be-truthy)
      (expect
        (offset-time-p (parse-date-time-with-pattern "HH:mmXXX" "07:05+09:00"))
        :to-be-truthy))
    (it
      "rejects an ambiguous run of adjacent single-width numeric fields"
      (signals date-time-parse-error (parse-date-time-with-pattern "Md" "115"))
      (signals date-time-parse-error (parse-date-time-with-pattern "Hm" "0530")))
    (it
      "reads a single-width M field as a greedy digit run when unambiguous"
      (expect
        (local-date=
          (parse-date-time-with-pattern "M/d/yyyy" "3/5/2024")
          (make-local-date 2024 3 5))
        :to-be-truthy))
    (it
      "signals when a single-width numeric field has no digits to read"
      (signals date-time-parse-error (parse-date-time-with-pattern "d" "x")))
    (it
      "parses an explicitly signed extended year that is not adjacent to another field"
      (expect
        (local-date=
          (parse-date-time-with-pattern "y-MM-dd" "-0044-01-01")
          (make-local-date -44 1 1))
        :to-be-truthy))
    (it
      "signals on a literal mismatch and on a duplicated pattern field"
      (signals date-time-parse-error (parse-date-time-with-pattern "yyyy-MM-dd" "2024/02/29"))
      (signals date-time-parse-error (parse-date-time-with-pattern "yyyy-yyyy" "2024-2025")))
    (it
      "signals when a text field's delimiter is absent or matches with no text before it"
      (signals date-time-parse-error (parse-date-time-with-pattern "MMMM d" "February5"))
      (signals date-time-parse-error (parse-date-time-with-pattern "EEEE-d" "-15")))
    (it
      "signals when parsed weekday text is not a locale weekday name"
      (signals
        date-time-parse-error
        (parse-date-time-with-pattern "EEEE, yyyy-MM-dd" "Blahday, 2024-02-29")))))
