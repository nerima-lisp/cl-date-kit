;;;; t/rrule-occurrences-test.lisp -- RRULE occurrence expansion: frequency cadence, BY* part
;;;; filtering, COUNT-only limits, BYWEEKNO, and time filters.
(in-package #:cl-date-kit/test)

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
            (rrule-occurrences
              (rrule-test-utc-schedule 2024 1 1 source hour minute second)
              :max-periods
              3))
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
            "FREQ=DAILY;COUNT=3;BYHOUR=9;BYMINUTE=15;BYSECOND=30")
          :max-periods
          3))
      :to-equal
      '("2024-01-01T09:15:30" "2024-01-02T09:15:30" "2024-01-03T09:15:30"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;COUNT=3;BYDAY=-1MO")
          :max-periods
          3))
      :to-equal
      '("2024-01-29T09:00:00" "2024-02-26T09:00:00" "2024-03-25T09:00:00"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;COUNT=3;BYMONTHDAY=-1")
          :max-periods
          3))
      :to-equal
      '("2024-01-31T09:00:00" "2024-02-29T09:00:00" "2024-03-31T09:00:00"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=2;BYYEARDAY=-1")
          :max-periods
          2))
      :to-equal
      '("2024-12-31T09:00:00" "2025-12-31T09:00:00"))
    (progn
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 1 31 "FREQ=YEARLY;COUNT=2;BYMONTH=2,3")
            :max-periods
            2))
        :to-equal
        (quote ("2024-03-31T09:00:00" "2025-03-31T09:00:00")))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=YEARLY;COUNT=12;BYMONTH=2,3;BYMONTHDAY=-1,1,15,31")
            :max-periods
            2))
        :to-equal
        (quote
          ("2024-02-01T09:00:00"
            "2024-02-15T09:00:00"
            "2024-02-29T09:00:00"
            "2024-03-01T09:00:00"
            "2024-03-15T09:00:00"
            "2024-03-31T09:00:00"
            "2025-02-01T09:00:00"
            "2025-02-15T09:00:00"
            "2025-02-28T09:00:00"
            "2025-03-01T09:00:00"
            "2025-03-15T09:00:00"
            "2025-03-31T09:00:00"))))
    (progn
      (expect
        (rrule-occurrences
          (rrule-test-utc-schedule
            2024
            1
            1
            "FREQ=YEARLY;BYMONTH=1;BYMONTHDAY=1,-31;BYSETPOS=2")
          :max-periods
          1)
        :to-equal
        nil)
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=YEARLY;COUNT=1;BYMONTH=1;BYMONTHDAY=-1,1;BYSETPOS=1")
            :max-periods
            1))
        :to-equal
        (quote ("2024-01-01T09:00:00"))))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=2;BYMONTH=2;BYMONTHDAY=-1")
          :max-periods
          2))
      :to-equal
      '("2024-02-29T09:00:00" "2025-02-28T09:00:00"))
    (progn
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2023 1 1 "FREQ=YEARLY;COUNT=2;BYMONTH=2;BYMONTHDAY=29")
            :max-periods
            6))
        :to-equal
        (quote ("2024-02-29T09:00:00" "2028-02-29T09:00:00")))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=3;BYMONTHDAY=2")
            :max-periods
            1))
        :to-equal
        (quote ("2024-01-02T09:00:00" "2024-02-02T09:00:00" "2024-03-02T09:00:00")))))
  (it
    "filters SECONDLY candidates by BYMINUTE and BYSECOND, rather than expanding them"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=SECONDLY;COUNT=1;BYMINUTE=1;BYSECOND=30" 0 0 0)
          :max-periods
          100))
      :to-equal
      '("2024-01-01T00:01:30"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=SECONDLY;COUNT=2;BYSECOND=3,7" 0 0 0)
          :max-periods
          10))
      :to-equal
      '("2024-01-01T00:00:03" "2024-01-01T00:00:07")))
  (progn
    (it
      "evaluates ordinal BYDAY across yearly and monthly scopes"
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=3;BYDAY=-1MO")
            :max-periods
            3))
        :to-equal
        (quote ("2024-12-30T09:00:00" "2025-12-29T09:00:00" "2026-12-28T09:00:00")))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=3;BYMONTH=2;BYDAY=-1MO")
            :max-periods
            3))
        :to-equal
        (quote ("2024-02-26T09:00:00" "2025-02-24T09:00:00" "2026-02-23T09:00:00")))
      (expect
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=MONTHLY;BYDAY=6MO")
          :max-periods
          12)
        :to-equal
        nil))
    (it
      "applies BYSETPOS after filtering, deduplicating, and sorting"
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=MONTHLY;COUNT=3;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1")
            :max-periods
            3))
        :to-equal
        '("2024-01-31T09:00:00" "2024-02-29T09:00:00" "2024-03-29T09:00:00"))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=DAILY;COUNT=2;BYHOUR=9,10;BYSETPOS=2,1,2")
            :max-periods
            2))
        :to-equal
        '("2024-01-01T09:00:00" "2024-01-01T10:00:00"))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=DAILY;COUNT=4;BYHOUR=9,10;BYSETPOS=-1,1")
            :max-periods
            2))
        :to-equal
        '("2024-01-01T09:00:00"
          "2024-01-01T10:00:00"
          "2024-01-02T09:00:00"
          "2024-01-02T10:00:00"))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=DAILY;COUNT=4;BYHOUR=9,10,11;BYSETPOS=-2,-1")
            :max-periods
            2))
        :to-equal
        '("2024-01-01T10:00:00"
          "2024-01-01T11:00:00"
          "2024-01-02T10:00:00"
          "2024-01-02T11:00:00"))
      (expect
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;COUNT=1;BYSETPOS=-2")
          :max-periods
          2)
        :to-equal
        nil)
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule 2024 1 31 "FREQ=MONTHLY;COUNT=4;BYMONTHDAY=31")
            :max-periods
            7))
        :to-equal
        '("2024-01-31T09:00:00"
          "2024-03-31T09:00:00"
          "2024-05-31T09:00:00"
          "2024-07-31T09:00:00"))
      (expect
        (rrule-occurrences
          (rrule-test-utc-schedule
            2024
            1
            1
            "FREQ=DAILY;UNTIL=20240103T090000Z;BYSETPOS=2")
          :max-periods
          3)
        :to-equal
        nil)
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=DAILY;COUNT=2;BYHOUR=9,10,11;BYSETPOS=3,-3")
            :max-periods
            1))
        :to-equal
        '("2024-01-01T09:00:00" "2024-01-01T11:00:00"))
      (expect
        (rrule-test-local-strings
          (rrule-occurrences
            (rrule-test-utc-schedule
              2024
              1
              1
              "FREQ=DAILY;COUNT=1;BYHOUR=9,10,11;BYSETPOS=2,-2")
            :max-periods
            1))
        :to-equal
        '("2024-01-01T10:00:00"))))
  (it
    "uses WKST to choose two-week periods"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 1997 8 5 "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU")
          :max-periods
          2))
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
            "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=SU")
          :max-periods
          3))
      :to-equal
      '("1997-08-05T09:00:00"
        "1997-08-17T09:00:00"
        "1997-08-19T09:00:00"
        "1997-08-31T09:00:00"))))

(describe
  "RRULE COUNT-only period limits"
  (it
    "requires a bound when filters make COUNT-only schedules unsatisfiable"
    (dolist (schedule
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
      (expect (rrule-occurrences schedule :max-periods 3) :to-equal nil))))

(describe
  "RRULE BYWEEKNO week-year boundaries"
  (it
    "keeps boundary weeks in their RFC week-year"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=2;BYWEEKNO=1;BYDAY=MO")
          :max-periods
          2))
      :to-equal
      (list "2024-01-01T09:00:00" "2024-12-30T09:00:00"))
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=YEARLY;COUNT=2;BYWEEKNO=-1;BYDAY=MO")
          :max-periods
          2))
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
          :max-periods
          2))
      :to-equal
      (list "2024-12-29T09:00:00"))))

(describe
  "RRULE time filters"
  (it
    "filters hourly periods by BYHOUR before expanding candidates"
    (expect
      (rrule-test-local-strings
        (rrule-occurrences
          (rrule-test-utc-schedule 2024 1 1 "FREQ=HOURLY;COUNT=1;BYHOUR=10")
          :max-periods
          2))
      :to-equal
      '("2024-01-01T10:00:00"))))
