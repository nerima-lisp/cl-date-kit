;;;; t/rrule-schedule-test.lisp -- DTSTART type variants (DATE, floating DATE-TIME, and
;;;; default-date skipping) and RRULE evaluation boundaries (DST, period limits, callbacks).
(in-package #:cl-date-kit/test)

(describe
  "RFC 5545 DATE RRULEs"
  (it
    "round-trips DATE UNTIL values and expands DATE DTSTART values"
    (let* ((rule (parse-rrule "FREQ=DAILY;UNTIL=20240201"))
           (schedule (make-rrule-schedule (make-local-date 2024 1 30) rule)))
      (expect (local-date-p (rrule-until rule)) :to-be-truthy)
      (expect (format-rrule rule) :to-equal "FREQ=DAILY;UNTIL=20240201")
      (expect
        (mapcar #'format-local-date (rrule-occurrences schedule))
        :to-equal
        '("2024-01-30" "2024-01-31" "2024-02-01"))))
  (it
    "rejects DATE DTSTART combinations that require a time of day"
    (let ((start (make-local-date 2024 1 1)))
      (signals invalid-rrule (rrule-test-schedule start "FREQ=HOURLY;COUNT=2"))
      (signals invalid-rrule (rrule-test-schedule start "FREQ=DAILY;BYHOUR=9"))
      (signals
        invalid-rrule
        (rrule-test-schedule start "FREQ=DAILY;UNTIL=20240102T000000"))))
  (it-each
      (("FREQ=MONTHLY;COUNT=2;BYMONTHDAY=5,15,25;BYSETPOS=1,-1" ("2024-01-05" "2024-01-25"))
       ("FREQ=MONTHLY;COUNT=2;BYMONTHDAY=5,15,25;BYSETPOS=3,-3" ("2024-01-05" "2024-01-25"))
       ("FREQ=MONTHLY;COUNT=1;BYMONTHDAY=5,15,25;BYSETPOS=2,-2" ("2024-01-15")))
      "applies BYSETPOS ~S to a DATE DTSTART, deduplicating when a positive and negative position select the same candidate"
      (source expected)
    (let ((schedule (make-rrule-schedule (make-local-date 2024 1 1) (parse-rrule source))))
      (expect
        (mapcar #'format-local-date (rrule-occurrences schedule :max-periods 1))
        :to-equal
        expected)))
  (it
    "rejects a DTSTART that is not a zoned date-time, local date-time, or local date"
    (signals invalid-rrule (make-rrule-schedule "2024-01-01" (parse-rrule "FREQ=DAILY")))))

(describe
  "RRULE evaluation boundaries"
  (it
    "skips DST gaps without consuming COUNT"
    (let* ((zone (find-time-zone "America/New_York"))
           (schedule
          (rrule-test-schedule
            (zoned-date-time-of-local (rrule-test-local 2024 3 9 2 30) zone)
            "FREQ=DAILY;COUNT=3")))
      (expect
        (rrule-test-local-strings (rrule-occurrences schedule :max-periods 4))
        :to-equal
        (list "2024-03-09T02:30:00" "2024-03-11T02:30:00" "2024-03-12T02:30:00"))))
  (it
    "uses the earlier offset for DST overlaps"
    (let* ((zone (find-time-zone "America/New_York"))
           (schedule
          (rrule-test-schedule
            (zoned-date-time-of-local (rrule-test-local 2024 11 3 1 30) zone)
            "FREQ=DAILY;COUNT=1"))
           (occurrence (first (rrule-occurrences schedule :max-periods 1))))
      (expect
        (zone-offset-total-seconds (zoned-date-time-offset occurrence))
        :to-be
        -14400)))
  (it
    "requires a period limit for unbounded schedules"
    (let ((schedule
          (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;BYMONTH=2;BYMONTHDAY=30")))
      (signals invalid-rrule (rrule-occurrences schedule))
      (expect (rrule-occurrences schedule :max-periods 3) :to-equal nil)))
  (it
    "applies the period limit before candidate emission"
    (let ((schedule (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY"))
          (occurrences nil))
      (map-rrule-occurrences
        (lambda (occurrence)
          (push occurrence occurrences)
          t)
        schedule
        :max-periods
        2)
      (expect (length occurrences) :to-be 2)))
  (progn
    (it
      "honors callback cancellation before the period bound"
      (let ((schedule (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY"))
            (occurrences nil))
        (map-rrule-occurrences
          (lambda (occurrence)
            (push occurrence occurrences)
            nil)
          schedule
          :max-periods
          3)
        (expect (length occurrences) :to-be 1)))
    (it
      "supports DO iteration completion and non-local early return"
      (let ((schedule (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;COUNT=2")))
        (let (occurrences)
          (expect
            (do-rrule-occurrences
              (occurrence schedule :max-periods 2 :result :finished)
              (push occurrence occurrences))
            :to-equal
            :finished)
          (expect
            (rrule-test-local-strings (nreverse occurrences))
            :to-equal
            (quote ("2024-01-01T09:00:00" "2024-01-02T09:00:00"))))
        (let (occurrences)
          (expect
            (do-rrule-occurrences
              (occurrence schedule :max-periods 2 :result :finished)
              (push occurrence occurrences)
              (return :stopped))
            :to-equal
            :stopped)
          (expect
            (rrule-test-local-strings occurrences)
            :to-equal
            (quote ("2024-01-01T09:00:00"))))))
    (it
      "passes MAX-PERIODS to unbounded schedules"
      (let ((schedule (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY")))
        (let (occurrences)
          (expect
            (do-rrule-occurrences
              (occurrence schedule :max-periods 2 :result :finished)
              (push occurrence occurrences))
            :to-equal
            :finished)
          (expect
            (rrule-test-local-strings (nreverse occurrences))
            :to-equal
            (quote ("2024-01-01T09:00:00" "2024-01-02T09:00:00"))))))))

(progn
  (describe
    "RRULE DTSTART default date components"
    (it
      "rejects malformed numeric RRULE values"
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;COUNT=1-2"))
      (signals invalid-rrule (parse-rrule "FREQ=MONTHLY;BYMONTHDAY=1-2")))
    (it
      "skips invalid default DATE-TIME monthly and yearly dates"
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 1 31 "FREQ=MONTHLY;COUNT=3")
            :max-periods
            5))
        :to-equal
        (list "2024-01-31T09:00:00" "2024-03-31T09:00:00" "2024-05-31T09:00:00"))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 2 29 "FREQ=YEARLY;COUNT=3")
            :max-periods
            9))
        :to-equal
        (list "2024-02-29T09:00:00" "2028-02-29T09:00:00" "2032-02-29T09:00:00")))
    (it
      "skips invalid default DATE monthly and yearly dates"
      (expect
        (mapcar
          #'format-local-date
          (rrule-occurrences
            (rrule-test-schedule (make-local-date 2024 1 31) "FREQ=MONTHLY;COUNT=3")
            :max-periods
            5))
        :to-equal
        (list "2024-01-31" "2024-03-31" "2024-05-31"))
      (expect
        (mapcar
          #'format-local-date
          (rrule-occurrences
            (rrule-test-schedule (make-local-date 2024 2 29) "FREQ=YEARLY;COUNT=3")
            :max-periods
            9))
        :to-equal
        (list "2024-02-29" "2028-02-29" "2032-02-29"))))
  (describe
    "RFC 5545 floating DATE-TIME schedules"
    (it
      "emits floating local date-times directly and honors COUNT"
      (let ((occurrences
            (rrule-occurrences
              (rrule-test-schedule (rrule-test-local 2024 1 1 9) "FREQ=DAILY;COUNT=3")
              :max-periods
              3)))
        (expect (every #'local-date-time-p occurrences) :to-be-truthy)
        (expect
          (mapcar #'format-local-date-time occurrences)
          :to-equal
          (list "2024-01-01T09:00:00" "2024-01-02T09:00:00" "2024-01-03T09:00:00"))))
    (it
      "honors an inclusive floating UNTIL and rejects other UNTIL types"
      (let ((start (rrule-test-local 2024 1 1 9)))
        (expect
          (mapcar
            #'format-local-date-time
            (rrule-occurrences
              (rrule-test-schedule start "FREQ=DAILY;UNTIL=20240103T090000")))
          :to-equal
          (list "2024-01-01T09:00:00" "2024-01-02T09:00:00" "2024-01-03T09:00:00"))
        (signals invalid-rrule (rrule-test-schedule start "FREQ=DAILY;UNTIL=20240103"))
        (signals
          invalid-rrule
          (rrule-test-schedule start "FREQ=DAILY;UNTIL=20240103T090000Z"))))
    (it
      "applies BYHOUR and BYMINUTE to floating schedules"
      (expect
        (mapcar
          #'format-local-date-time
          (rrule-occurrences
            (rrule-test-schedule
              (rrule-test-local 2024 1 1 9)
              "FREQ=DAILY;COUNT=2;BYHOUR=10;BYMINUTE=15")
            :max-periods
            3))
        :to-equal
        (list "2024-01-01T10:15:00" "2024-01-02T10:15:00")))
    (it
      "uses MAX-PERIODS for unbounded floating schedules"
      (expect
        (mapcar
          #'format-local-date-time
          (rrule-occurrences
            (rrule-test-schedule (rrule-test-local 2024 1 1 9) "FREQ=DAILY")
            :max-periods
            2))
        :to-equal
        (list "2024-01-01T09:00:00" "2024-01-02T09:00:00")))))
