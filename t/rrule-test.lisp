;;;; t/rrule-test.lisp
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

(progn
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
    "exposes an RRULE validation reason and offending value"
    (let ((condition
            (handler-case
                (progn (parse-rrule "FREQ=DAILY;COUNT=2;COUNT=3") nil)
              (invalid-rrule (condition) condition))))
      (expect (typep condition 'invalid-rrule) :to-be-truthy)
      (expect (invalid-rrule-reason condition) :to-equal "duplicate RRULE clause")
      (expect (invalid-rrule-value condition) :to-equal "COUNT")))
  (progn
  (it "parses UNTIL as an instant for UTC schedules and a local date-time otherwise"
    (let ((utc-rule (parse-rrule "FREQ=DAILY;UNTIL=20240131T090000Z"))
          (local-rule (parse-rrule "FREQ=DAILY;UNTIL=20240131T090000")))
      (expect (instant-p (rrule-until utc-rule)) :to-be-truthy)
      (expect (local-date-time-p (rrule-until local-rule)) :to-be-truthy)
      (signals invalid-rrule
        (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;UNTIL=20240131T090000"))
      (signals invalid-rrule
        (rrule-test-schedule
          (zoned-date-time-of-local
            (rrule-test-local 2024 1 1 9)
            (find-time-zone "America/New_York"))
          "FREQ=DAILY;UNTIL=20240131T090000Z"))))
  (it "rejects invalid BYDAY constructors"
    (signals invalid-rrule (make-rrule-by-day :xx))
    (signals invalid-rrule (make-rrule-by-day :mo 0))
    (signals invalid-rrule (make-rrule-by-day :mo 54))
    (signals invalid-rrule (make-rrule-by-day :mo "1")))
  (it "canonicalizes numeric BY parts and rejects scalar BY parts" (let ((rule (make-rrule :frequency :daily :by-hour #(10 9 10)))) (expect (rrule-by-hour rule) :to-equal (list 9 10)) (expect (format-rrule rule) :to-equal "FREQ=DAILY;BYHOUR=9,10")) (signals invalid-rrule (make-rrule :frequency :daily :by-hour 9)))
  (it "validates direct RRULE constructor values"
    (signals invalid-rrule (make-rrule :frequency :fortnightly))
    (signals invalid-rrule (make-rrule :frequency :daily :interval 0))
    (signals invalid-rrule (make-rrule :frequency :daily :count 0))
    (signals invalid-rrule (make-rrule :frequency :daily :until :invalid))
    (signals invalid-rrule (make-rrule :frequency :daily :week-start :xx))
    (signals invalid-rrule (make-rrule :frequency :monthly :by-month-day (list 0)))
    (signals invalid-rrule (make-rrule :frequency :daily :by-set-pos (list 0))))
  (it "accepts UNTIL forms compatible with UTC-offset and local DTSTART values"
    (expect
      (rrule-schedule-p
        (make-rrule-schedule
          (zoned-date-time-of-local
            (rrule-test-local 2024 1 1 9)
            (zone-offset-utc))
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
(describe
  "RFC 5545 DATE RRULEs"
  (it
    "round-trips DATE UNTIL values and expands DATE DTSTART values"
    (let* ((rule (parse-rrule "FREQ=DAILY;UNTIL=20240201"))
           (schedule
             (make-rrule-schedule
              (make-local-date 2024 1 30)
              rule)))
      (expect (local-date-p (rrule-until rule)) :to-be-truthy)
      (expect (format-rrule rule) :to-equal "FREQ=DAILY;UNTIL=20240201")
      (expect
       (mapcar #'format-local-date (rrule-occurrences schedule))
       :to-equal
       '("2024-01-30" "2024-01-31" "2024-02-01"))))
  (it
    "rejects DATE DTSTART combinations that require a time of day"
    (let ((start (make-local-date 2024 1 1)))
      (signals invalid-rrule
        (rrule-test-schedule start "FREQ=HOURLY;COUNT=2"))
      (signals invalid-rrule
        (rrule-test-schedule start "FREQ=DAILY;BYHOUR=9"))
      (signals invalid-rrule
        (rrule-test-schedule start "FREQ=DAILY;UNTIL=20240102T000000"))))))

(describe
  "RFC 5545 RRULE expansion"
  (it
    "expands each frequency from DTSTART and honors COUNT"
    (dolist (spec
        '(("FREQ=SECONDLY;COUNT=3"
            9
            0
            0
            ("2024-01-01T09:00:00" "2024-01-01T09:00:01" "2024-01-01T09:00:02"))
          ("FREQ=MINUTELY;COUNT=3"
            9
            0
            0
            ("2024-01-01T09:00:00" "2024-01-01T09:01:00" "2024-01-01T09:02:00"))
          ("FREQ=HOURLY;COUNT=3"
            9
            0
            0
            ("2024-01-01T09:00:00" "2024-01-01T10:00:00" "2024-01-01T11:00:00"))
          ("FREQ=DAILY;COUNT=3"
            9
            0
            0
            ("2024-01-01T09:00:00" "2024-01-02T09:00:00" "2024-01-03T09:00:00"))
          ("FREQ=WEEKLY;COUNT=3"
            9
            0
            0
            ("2024-01-01T09:00:00" "2024-01-08T09:00:00" "2024-01-15T09:00:00"))
          ("FREQ=MONTHLY;COUNT=3"
            9
            0
            0
            ("2024-01-01T09:00:00" "2024-02-01T09:00:00" "2024-03-01T09:00:00"))
          ("FREQ=YEARLY;COUNT=3"
            9
            0
            0
            ("2024-01-01T09:00:00" "2025-01-01T09:00:00" "2026-01-01T09:00:00"))))
      (destructuring-bind (source hour minute second expected) spec
        (expect
          (rrule-test-local-strings
            (rrule-occurrences (rrule-test-utc-schedule 2024 1 1 source hour minute second) :max-periods 3))
          :to-equal
          expected))))
  (it
    "applies time and calendar BY* parts, including negative ordinals"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule
            2024
            1
            1
            "FREQ=DAILY;COUNT=3;BYHOUR=9;BYMINUTE=15;BYSECOND=30") :max-periods 3))
      :to-equal
      '("2024-01-01T09:15:30" "2024-01-02T09:15:30" "2024-01-03T09:15:30"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;COUNT=3;BYDAY=-1MO") :max-periods 3))
      :to-equal
      '("2024-01-29T09:00:00" "2024-02-26T09:00:00" "2024-03-25T09:00:00"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;COUNT=3;BYMONTHDAY=-1") :max-periods 3))
      :to-equal
      '("2024-01-31T09:00:00" "2024-02-29T09:00:00" "2024-03-31T09:00:00"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=2;BYYEARDAY=-1") :max-periods 2))
      :to-equal
      '("2024-12-31T09:00:00" "2025-12-31T09:00:00"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 31 "FREQ=YEARLY;COUNT=2;BYMONTH=2,3") :max-periods 2))
      :to-equal
      '("2024-03-31T09:00:00" "2025-03-31T09:00:00"))

(progn
  (expect
    (rrule-occurrences
      (rrule-test-utc-schedule
        2024 1 1 "FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1,-31;BYSETPOS=2")
      :max-periods 1)
    :to-equal
    nil)
  (expect
    (rrule-test-local-strings
      (rrule-occurrences
        (rrule-test-utc-schedule
          2024 1 1 "FREQ=YEARLY;COUNT=1;BYMONTH=1;BYMONTHDAY=-1,1;BYSETPOS=1")
        :max-periods 1))
    :to-equal
    (quote ("2024-01-01T09:00:00"))))

    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=2;BYMONTH=2;BYMONTHDAY=-1") :max-periods 2))
      :to-equal
      '("2024-02-29T09:00:00" "2025-02-28T09:00:00"))
    (progn
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2023 1 1 "FREQ=YEARLY;COUNT=2;BYMONTH=2;BYMONTHDAY=29") :max-periods 6))
        :to-equal
        (quote ("2024-02-29T09:00:00" "2028-02-29T09:00:00")))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=3;BYMONTHDAY=2") :max-periods 1))
        :to-equal
        (quote ("2024-01-02T09:00:00"
                "2024-02-02T09:00:00"
                "2024-03-02T09:00:00")))))
  (progn
  (it
    "evaluates ordinal BYDAY across yearly and monthly scopes"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=3;BYDAY=-1MO")
          :max-periods 3))
      :to-equal
      (quote ("2024-12-30T09:00:00" "2025-12-29T09:00:00" "2026-12-28T09:00:00")))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=3;BYMONTH=2;BYDAY=-1MO")
          :max-periods 3))
      :to-equal
      (quote ("2024-02-26T09:00:00" "2025-02-24T09:00:00" "2026-02-23T09:00:00")))
    (expect
      (rrule-occurrences
        (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;BYDAY=6MO")
        :max-periods 12)
      :to-equal
      nil))
  (it
  "applies BYSETPOS after filtering, deduplicating, and sorting"
  (expect
   (rrule-test-local-strings
    (rrule-occurrences
     (rrule-test-utc-schedule
      2024 1 1
      "FREQ=MONTHLY;COUNT=3;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1")
     :max-periods 3))
   :to-equal
   '("2024-01-31T09:00:00" "2024-02-29T09:00:00"
     "2024-03-29T09:00:00"))
  (expect
   (rrule-test-local-strings
    (rrule-occurrences
     (rrule-test-utc-schedule
      2024 1 1 "FREQ=DAILY;COUNT=2;BYHOUR=9,10;BYSETPOS=2,1,2")
     :max-periods 2))
   :to-equal
   '("2024-01-01T09:00:00" "2024-01-01T10:00:00"))
  (expect
   (rrule-test-local-strings
    (rrule-occurrences
     (rrule-test-utc-schedule
      2024 1 1 "FREQ=DAILY;COUNT=4;BYHOUR=9,10;BYSETPOS=-1,1")
     :max-periods 2))
   :to-equal
   '("2024-01-01T09:00:00" "2024-01-01T10:00:00"
     "2024-01-02T09:00:00" "2024-01-02T10:00:00"))
  (expect
   (rrule-test-local-strings
    (rrule-occurrences
     (rrule-test-utc-schedule
      2024 1 1 "FREQ=DAILY;COUNT=4;BYHOUR=9,10,11;BYSETPOS=-2,-1")
     :max-periods 2))
   :to-equal
   '("2024-01-01T10:00:00" "2024-01-01T11:00:00"
     "2024-01-02T10:00:00" "2024-01-02T11:00:00"))
  (expect
   (rrule-occurrences
    (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;COUNT=1;BYSETPOS=-2")
    :max-periods 2)
   :to-equal nil)
  (expect
   (rrule-test-local-strings
    (rrule-occurrences
     (rrule-test-utc-schedule 2024 1 31 "FREQ=MONTHLY;COUNT=4;BYMONTHDAY=31")
     :max-periods 7))
   :to-equal
   '("2024-01-31T09:00:00" "2024-03-31T09:00:00"
     "2024-05-31T09:00:00" "2024-07-31T09:00:00"))
  (expect
   (rrule-occurrences
    (rrule-test-utc-schedule
     2024 1 1 "FREQ=DAILY;UNTIL=20240103T090000Z;BYSETPOS=2")
    :max-periods 3)
   :to-equal nil)))
  (it
    "uses WKST to choose two-week periods"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 1997 8 5 "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU") :max-periods 2))
      :to-equal
      '("1997-08-05T09:00:00"
        "1997-08-10T09:00:00"
        "1997-08-19T09:00:00"
        "1997-08-24T09:00:00"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule
            1997
            8
            5
            "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=SU") :max-periods 3))
      :to-equal
      '("1997-08-05T09:00:00"
        "1997-08-17T09:00:00"
        "1997-08-19T09:00:00"
        "1997-08-31T09:00:00"))))

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
      (expect (zone-offset-total-seconds (zoned-date-time-offset occurrence)) :to-be -14400)))
  (it
    "requires a period limit for unbounded schedules"
    (let ((schedule (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;BYMONTH=2;BYMONTHDAY=30")))
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
         (do-rrule-occurrences (occurrence schedule :max-periods 2 :result :finished) (push occurrence occurrences))
         :to-equal
         :finished)
        (expect
         (rrule-test-local-strings (nreverse occurrences))
         :to-equal
         (quote ("2024-01-01T09:00:00" "2024-01-02T09:00:00"))))
      (let (occurrences)
        (expect
         (do-rrule-occurrences (occurrence schedule :max-periods 2 :result :finished) (push occurrence occurrences) (return :stopped))
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
         (do-rrule-occurrences (occurrence schedule :max-periods 2 :result :finished)
           (push occurrence occurrences))
         :to-equal
         :finished)
        (expect
         (rrule-test-local-strings (nreverse occurrences))
         :to-equal
         (quote ("2024-01-01T09:00:00" "2024-01-02T09:00:00"))))))))

(progn
  (describe "RRULE DTSTART default date components"
    (it "rejects malformed numeric RRULE values"
      (signals invalid-rrule (parse-rrule "FREQ=DAILY;COUNT=1-2"))
      (signals invalid-rrule (parse-rrule "FREQ=MONTHLY;BYMONTHDAY=1-2")))
    (it "skips invalid default DATE-TIME monthly and yearly dates"
      (expect (rrule-test-local-strings
               (rrule-occurrences
                (rrule-test-utc-schedule 2024 1 31 "FREQ=MONTHLY;COUNT=3") :max-periods 5))
              :to-equal
              (list "2024-01-31T09:00:00" "2024-03-31T09:00:00" "2024-05-31T09:00:00"))
      (expect (rrule-test-local-strings
               (rrule-occurrences
                (rrule-test-utc-schedule 2024 2 29 "FREQ=YEARLY;COUNT=3") :max-periods 9))
              :to-equal
              (list "2024-02-29T09:00:00" "2028-02-29T09:00:00" "2032-02-29T09:00:00")))
    (it "skips invalid default DATE monthly and yearly dates"
      (expect (mapcar #'format-local-date
                       (rrule-occurrences
                        (rrule-test-schedule
                         (make-local-date 2024 1 31)
                         "FREQ=MONTHLY;COUNT=3") :max-periods 5))
              :to-equal
              (list "2024-01-31" "2024-03-31" "2024-05-31"))
      (expect (mapcar #'format-local-date
                       (rrule-occurrences
                        (rrule-test-schedule
                         (make-local-date 2024 2 29)
                         "FREQ=YEARLY;COUNT=3") :max-periods 9))
              :to-equal
              (list "2024-02-29" "2028-02-29" "2032-02-29"))))
  (describe "RFC 5545 floating DATE-TIME schedules"
    (it "emits floating local date-times directly and honors COUNT"
      (let ((occurrences
              (rrule-occurrences
               (rrule-test-schedule
                (rrule-test-local 2024 1 1 9)
                "FREQ=DAILY;COUNT=3") :max-periods 3)))
        (expect (every #'local-date-time-p occurrences) :to-be-truthy)
        (expect (mapcar #'format-local-date-time occurrences)
                :to-equal
                (list "2024-01-01T09:00:00"
                      "2024-01-02T09:00:00"
                      "2024-01-03T09:00:00"))))
    (it "honors an inclusive floating UNTIL and rejects other UNTIL types"
      (let ((start (rrule-test-local 2024 1 1 9)))
        (expect (mapcar #'format-local-date-time
                         (rrule-occurrences
                          (rrule-test-schedule
                           start
                           "FREQ=DAILY;UNTIL=20240103T090000")))
                :to-equal
                (list "2024-01-01T09:00:00"
                      "2024-01-02T09:00:00"
                      "2024-01-03T09:00:00"))
        (signals invalid-rrule
          (rrule-test-schedule start "FREQ=DAILY;UNTIL=20240103"))
        (signals invalid-rrule
          (rrule-test-schedule start "FREQ=DAILY;UNTIL=20240103T090000Z"))))
    (it "applies BYHOUR and BYMINUTE to floating schedules"
      (expect (mapcar #'format-local-date-time
                       (rrule-occurrences
                        (rrule-test-schedule
                         (rrule-test-local 2024 1 1 9)
                         "FREQ=DAILY;COUNT=2;BYHOUR=10;BYMINUTE=15") :max-periods 3))
              :to-equal
              (list "2024-01-01T10:15:00" "2024-01-02T10:15:00")))
    (it "uses MAX-PERIODS for unbounded floating schedules"
      (expect (mapcar #'format-local-date-time
                       (rrule-occurrences
                        (rrule-test-schedule
                         (rrule-test-local 2024 1 1 9)
                         "FREQ=DAILY")
                        :max-periods 2))
              :to-equal
              (list "2024-01-01T09:00:00" "2024-01-02T09:00:00")))))

(describe
    "RRULE COUNT-only period limits"
    (it
      "requires a bound when filters make COUNT-only schedules unsatisfiable"
      (dolist
        (schedule
          (list
            (rrule-test-schedule
              (make-local-date 2024 1 1)
              "FREQ=MONTHLY;COUNT=1;BYMONTH=2;BYMONTHDAY=30")
            (rrule-test-schedule
              (rrule-test-local 2024 1 1)
              "FREQ=MONTHLY;COUNT=1;BYMONTH=2;BYMONTHDAY=30")
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=MONTHLY;COUNT=1;BYMONTH=2;BYMONTHDAY=30")))
        (signals invalid-rrule (rrule-occurrences schedule))
        (expect
          (rrule-occurrences schedule :max-periods 3)
          :to-equal
          nil))))
  (describe
    "RRULE BYWEEKNO week-year boundaries"
    (it
      "keeps boundary weeks in their RFC week-year"
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=YEARLY;COUNT=2;BYWEEKNO=1;BYDAY=MO")
            :max-periods 2))
        :to-equal
        (list "2024-01-01T09:00:00" "2024-12-30T09:00:00"))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=YEARLY;COUNT=2;BYWEEKNO=-1;BYDAY=MO")
            :max-periods 2))
        :to-equal
        (list "2024-12-23T09:00:00" "2025-12-22T09:00:00"))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=YEARLY;COUNT=1;BYWEEKNO=1;BYDAY=SU;WKST=SU")
            :max-periods 2))
        :to-equal
        (list "2024-12-29T09:00:00"))))

(describe
  "RRULE time filters"
  (it
    "filters hourly periods by BYHOUR before expanding candidates"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule
            2024 1 1 "FREQ=HOURLY;COUNT=1;BYHOUR=10")
          :max-periods 2))
      :to-equal
      '("2024-01-01T10:00:00"))))

(describe
  "RRULE selector compilation"
  (it
    "skips selectors only for yearly direct rules"
    (let ((original (symbol-function (quote cl-date-kit::%compile-rrule-day-selector)))
          (calls 0))
      (unwind-protect
           (progn
             (setf (symbol-function (quote cl-date-kit::%compile-rrule-day-selector))
                   (lambda (rule)
                     (incf calls)
                     (funcall original rule)))
             (expect
               (rrule-test-local-strings
                 (rrule-occurrences
                   (rrule-test-utc-schedule
                     2024 1 1
                     "FREQ=YEARLY;COUNT=6;BYMONTH=2,3;BYMONTHDAY=-1,1,15,31")
                   :max-periods 1))
               :to-equal
               (list "2024-02-01T09:00:00"
                     "2024-02-15T09:00:00"
                     "2024-02-29T09:00:00"
                     "2024-03-01T09:00:00"
                     "2024-03-15T09:00:00"
                     "2024-03-31T09:00:00"))
             (expect calls :to-equal 0)
             (expect
               (rrule-test-local-strings
                 (rrule-occurrences
                   (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=1;BYDAY=MO")
                   :max-periods 1))
               :to-equal
               (list "2024-01-01T09:00:00"))
             (expect calls :to-equal 1))
        (setf (symbol-function (quote cl-date-kit::%compile-rrule-day-selector))
              original)))))
