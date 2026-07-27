;;;; t/pattern-test.lisp

(in-package #:cl-date-kit/test)

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
    "formats time and fractional-second fields"
    (let ((time (make-local-time 7 5 9 123456789)))
      (expect (format-date-time-with-pattern "HH:mm:ss.SSSSSS" time) :to-equal "07:05:09.123456")
      (expect (format-date-time-with-pattern "H:m:s.S" time) :to-equal "7:5:9.1")))
  (it
    "formats local, fixed-offset, named-zone, and instant values"
    (let* ((local (local-date-time-of 2024 2 29 7 5 9 0))
           (offset (zone-offset-of-hms 9 30 0))
           (offset-value
             (cl-date-kit:offset-date-time-of 2024 2 29 7 5 9 0 offset))
           (tokyo (find-time-zone "Asia/Tokyo"))
           (zoned (zoned-date-time-of-instant (make-instant 0) tokyo)))
      (expect (format-date-time-with-pattern "yyyyMMdd'T'HHmmss" local) :to-equal "20240229T070509")
      (expect (format-date-time-with-pattern "yyyy-MM-dd'T'HH:mm:ssXXX" offset-value)
              :to-equal
              "2024-02-29T07:05:09+09:30")
      (expect (format-date-time-with-pattern "yyyy-MM-dd HH:mm XXX V" zoned)
              :to-equal
              "1970-01-01 09:00 +09:00 Asia/Tokyo")
      (expect (format-date-time-with-pattern "yyyy-MM-dd'T'HH:mm:ssX" (make-instant 0))
              :to-equal
              "1970-01-01T00:00:00Z")))
  (it
    "reports malformed patterns and unavailable temporal fields"
    (signals date-time-format-error (make-date-time-formatter "MMM"))
    (signals date-time-format-error (make-date-time-formatter "yyyy-'unterminated"))
    (signals date-time-format-error (format-date-time-with-pattern "HH:mm" (make-local-date 2024 1 1)))
    (signals date-time-format-error
      (format-date-time-with-pattern "yyyy-MM-dd V" (local-date-time-of 2024 1 1 0 0 0 0)))))
