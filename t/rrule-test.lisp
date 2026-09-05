(in-package #:cl-date-kit/test)

(defun rrule-test-local (year month day &optional (hour 9) (minute 0) (second 0))
  (local-date-time-of year month day hour minute second))

(defun rrule-test-schedule (dtstart source)
  (make-rrule-schedule dtstart (parse-rrule source)))

(defun rrule-test-utc-schedule (year month day source &optional (hour 9) (minute 0) (second 0))
  (rrule-test-schedule
    (zoned-date-time-of-local
      (rrule-test-local year month day hour minute second)
      (find-time-zone "UTC"))
    source))

(defun rrule-test-local-strings (occurrences)
  (mapcar
    (lambda (occurrence)
      (format-local-date-time (zoned-date-time-local occurrence)))
    occurrences))

(describe
    "RFC 5545 RRULE codec"
    (it
      "round-trips canonical clauses and exposes WKST"
      (let ((rule
            (parse-rrule
              "FREQ=MONTHLY;INTERVAL=2;WKST=SU;BYDAY=-1MO,2TU;BYMONTHDAY=-1,15;BYSETPOS=-1,2")))
        (expect
          (format-rrule rule)
          :to-equal
          "FREQ=MONTHLY;INTERVAL=2;WKST=SU;BYDAY=-1MO,2TU;BYMONTHDAY=-1,15;BYSETPOS=-1,2")
        (expect (rrule-week-start rule) :to-be :su)
        (expect (rrule-by-day-ordinal (first (rrule-by-day rule))) :to-be -1)
        (expect (rrule-by-day-weekday (second (rrule-by-day rule))) :to-be :tu)))
    (it
      "rejects duplicate, unknown, and mutually exclusive clauses"
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;COUNT=2;COUNT=3"))
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;BOGUS=1"))
      (signals invalid-rrule (parse-rrule "INTERVAL=2"))
      (signals
        invalid-rrule
        (make-rrule :frequency :daily :count 2 :until (rrule-test-local 2024 1 2))))
    (it
      "rejects RFC-invalid BY* values and combinations"
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;BYSECOND=60"))
      (signals invalid-rrule (parse-rrule "FREQ=MONTHLY;BYWEEKNO=1"))
      (signals invalid-rrule (parse-rrule "FREQ=WEEKLY;BYDAY=1MO"))
      (signals invalid-rrule (parse-rrule "FREQ=YEARLY;BYWEEKNO=1;BYDAY=1MO")))
    (it
      "rejects malformed RRULE wire-format input"
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;BYHOUR=9,,10"))
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;WKST=XX"))
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;BYDAY=M"))
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;UNTIL=2024013XT090000"))
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;UNTIL=2024"))
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;UNTIL=20240131X090000"))
      (signals invalid-rrule (parse-rrule 12345))
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;BOGUS"))
      (signals invalid-rrule (parse-rrule "FREQ=FORTNIGHTLY")))
    (it
      "round-trips UNTIL as a floating date-time and as an instant"
      (let ((floating-source "FREQ=DAILY;UNTIL=20240131T090000")
            (instant-source "FREQ=DAILY;UNTIL=20240131T090000Z"))
        (expect (format-rrule (parse-rrule floating-source)) :to-equal floating-source)
        (expect (format-rrule (parse-rrule instant-source)) :to-equal instant-source)))
    (it
      "writes to STREAM when supplied and returns the RRULE"
      (let* ((rule (parse-rrule "FREQ=DAILY;COUNT=2"))
             (output
              (with-output-to-string (stream)
                (expect (format-rrule rule stream) :to-be rule))))
        (expect output :to-equal "FREQ=DAILY;COUNT=2")))
    (it
      "exposes an RRULE validation reason and offending value"
      (let ((condition
            (handler-case (progn
                (parse-rrule "FREQ=DAILY;COUNT=2;COUNT=3")
                nil)
              (invalid-rrule (condition)
                condition))))
        (expect (typep condition 'invalid-rrule) :to-be-truthy)
        (expect (invalid-rrule-reason condition) :to-equal "duplicate RRULE clause")
        (expect (invalid-rrule-value condition) :to-equal "COUNT")))
    (progn
      (it
        "parses UNTIL as an instant for UTC schedules and a local date-time otherwise"
        (let ((utc-rule (parse-rrule "FREQ=DAILY;UNTIL=20240131T090000Z"))
              (local-rule (parse-rrule "FREQ=DAILY;UNTIL=20240131T090000")))
          (expect (instant-p (rrule-until utc-rule)) :to-be-truthy)
          (expect (local-date-time-p (rrule-until local-rule)) :to-be-truthy)
          (signals
            invalid-rrule
            (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;UNTIL=20240131T090000"))
          (signals
            invalid-rrule
            (rrule-test-schedule
              (zoned-date-time-of-local
                (rrule-test-local 2024 1 1 9)
                (find-time-zone "America/New_York"))
              "FREQ=DAILY;UNTIL=20240131T090000Z"))))
      (it
        "rejects invalid BYDAY constructors"
        (signals invalid-rrule (make-rrule-by-day :xx))
        (signals invalid-rrule (make-rrule-by-day :mo 0))
        (signals invalid-rrule (make-rrule-by-day :mo 54))
        (signals invalid-rrule (make-rrule-by-day :mo "1")))
      (it
        "canonicalizes numeric BY parts and rejects scalar BY parts"
        (let ((rule (make-rrule :frequency :daily :by-hour #(10 9 10))))
          (expect (rrule-by-hour rule) :to-equal (list 9 10))
          (expect (format-rrule rule) :to-equal "FREQ=DAILY;BYHOUR=9,10"))
        (signals invalid-rrule (make-rrule :frequency :daily :by-hour 9)))
      (it
        "validates direct RRULE constructor values"
        (signals invalid-rrule (make-rrule :frequency :fortnightly))
        (signals invalid-rrule (make-rrule :frequency :daily :interval 0))
        (signals invalid-rrule (make-rrule :frequency :daily :count 0))
        (signals invalid-rrule (make-rrule :frequency :daily :until :invalid))
        (signals invalid-rrule (make-rrule :frequency :daily :week-start :xx))
        (signals invalid-rrule (make-rrule :frequency :monthly :by-month-day (list 0)))
        (signals invalid-rrule (make-rrule :frequency :daily :by-set-pos (list 0))))
      (it
        "defaults INTERVAL to 1 and WEEK-START to :MO when unspecified"
        (let ((rule (make-rrule :frequency :daily)))
          (expect (rrule-interval rule) :to-be 1)
          (expect (rrule-week-start rule) :to-be :mo)))
      (it
        "accepts UNTIL forms compatible with UTC-offset and local DTSTART values"
        (expect
          (rrule-schedule-p
            (make-rrule-schedule
              (zoned-date-time-of-local (rrule-test-local 2024 1 1 9) (zone-offset-utc))
              (parse-rrule "FREQ=DAILY;UNTIL=20240131T090000Z")))
          :to-be-truthy)
        (expect
          (rrule-schedule-p
            (make-rrule-schedule
              (zoned-date-time-of-local
                (rrule-test-local 2024 1 1 9)
                (find-time-zone "America/New_York"))
              (parse-rrule "FREQ=DAILY;UNTIL=20240131T090000")))
          :to-be-truthy))))
