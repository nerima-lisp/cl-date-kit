;;;; t/zoned-date-time-arithmetic-test.lisp
;;;; ZonedDateTime plus/minus arithmetic, truncation/rounding, comparisons, and absolute-field round-trips.
(in-package #:cl-date-kit/test)

(describe "ZonedDateTime fixed-unit arithmetic"
  (it "uses elapsed time across the DST spring-forward gap"
    (let* ((new-york (find-time-zone "America/New_York"))
           (before (zoned-date-time-of-local
                    (local-date-time-of 2024 3 10 1 59 59 999500000)
                    new-york))
           (after (zoned-date-time-plus-millis before 1)))
      (expect (local-date-time=
               (zoned-date-time-local after)
               (local-date-time-of 2024 3 10 3 0 0 500000))
              :to-be-truthy)
      (expect (zone-offset-total-seconds (zoned-date-time-offset after))
              :to-be -14400)))

  (it "uses elapsed time across the DST fall-back overlap"
    (let* ((new-york (find-time-zone "America/New_York"))
           (before (zoned-date-time-of-local
                    (local-date-time-of 2024 11 3 1 59 59 999500000)
                    new-york
                    :preferred-offset (zone-offset-of-hours -4)))
           (after (zoned-date-time-plus-millis before 1)))
      (expect (local-date-time=
               (zoned-date-time-local after)
               (local-date-time-of 2024 11 3 1 0 0 500000))
              :to-be-truthy)
      (expect (zone-offset-total-seconds (zoned-date-time-offset after))
              :to-be -18000)))

  (it "reverses every fixed unit"
    (let* ((zone (find-time-zone "UTC"))
           (value (zoned-date-time-of-local
                   (local-date-time-of 2024 1 1 0 0 0 500000)
                   zone)))
      (expect (zoned-date-time=
               (zoned-date-time-minus-hours
                (zoned-date-time-plus-hours value 1) 1)
               value)
              :to-be-truthy)
      (expect (zoned-date-time=
               (zoned-date-time-minus-minutes
                (zoned-date-time-plus-minutes value 1) 1)
               value)
              :to-be-truthy)
      (expect (zoned-date-time=
               (zoned-date-time-minus-seconds
                (zoned-date-time-plus-seconds value 1) 1)
               value)
              :to-be-truthy)
      (expect (zoned-date-time=
               (zoned-date-time-minus-millis
                (zoned-date-time-plus-millis value 1) 1)
               value)
              :to-be-truthy)
      (expect (zoned-date-time=
               (zoned-date-time-minus-micros
                (zoned-date-time-plus-micros value 1) 1)
               value)
              :to-be-truthy)
      (expect (zoned-date-time=
               (zoned-date-time-minus-nanos
                (zoned-date-time-plus-nanos value 1) 1)
               value)
              :to-be-truthy))))

(describe "duration and period arithmetic"
  (it "ZONED-DATE-TIME-PLUS-DURATION adds exact elapsed time, crossing the DST gap correctly"
    ;; 2024-03-10 01:30 EST + 2 hours of *elapsed* time lands at 04:30 EDT
    ;; (not 03:30), because 02:00-02:59 does not exist to add time through.
    (let* ((ny (find-time-zone "America/New_York"))
           (before (zoned-date-time-of-local (local-date-time-of 2024 3 10 1 30 0) ny :disambiguation :earlier))
           (after (zoned-date-time-plus-duration before (duration-of-hours 2))))
      (expect (local-date-time= (zoned-date-time-local after) (local-date-time-of 2024 3 10 4 30 0)) :to-be-truthy)))

  (it "ZONED-DATE-TIME-PLUS-PERIOD adjusts the wall clock by a full day, not by 24 hours of elapsed time"
    ;; Noon EST on March 9 to noon EDT on March 10 spans the spring-forward
    ;; transition (2024-03-10 02:00 local), so only 23 hours actually elapse.
    (let* ((ny (find-time-zone "America/New_York"))
           (before (zoned-date-time-of-local (local-date-time-of 2024 3 9 12 0 0) ny))
           (after (zoned-date-time-plus-period before (period-of-days 1))))
      (expect (local-date-time= (zoned-date-time-local after) (local-date-time-of 2024 3 10 12 0 0)) :to-be-truthy)
      (expect (duration-to-seconds (instant-until (zoned-date-time-to-instant before) (zoned-date-time-to-instant after))) :to-be (* 23 3600))))

  (it "ZONED-DATE-TIME-MINUS-DURATION/PERIOD are the inverse of their PLUS counterparts"
    (let* ((ny (find-time-zone "America/New_York")) (zdt (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) ny)))
      (expect (zoned-date-time= (zoned-date-time-minus-duration (zoned-date-time-plus-duration zdt (duration-of-hours 3)) (duration-of-hours 3)) zdt) :to-be-truthy)
      (expect (local-date-time= (zoned-date-time-local (zoned-date-time-minus-period (zoned-date-time-plus-period zdt (period-of-days 5)) (period-of-days 5)))
                                 (zoned-date-time-local zdt))
              :to-be-truthy))))

(describe "calendar-unit arithmetic"
  (it "ZONED-DATE-TIME-PLUS-DAYS follows the local calendar across a DST gap"
    (let* ((ny (find-time-zone "America/New_York"))
           (before (zoned-date-time-of-local (local-date-time-of 2024 3 9 12 0 0) ny))
           (after (zoned-date-time-plus-days before 1)))
      (expect (local-date-time= (zoned-date-time-local after) (local-date-time-of 2024 3 10 12 0 0)) :to-be-truthy)
      (expect (duration-to-seconds (instant-until (zoned-date-time-to-instant before) (zoned-date-time-to-instant after))) :to-be (* 23 3600))))

  (it "calendar-unit helpers preserve period semantics and inverse operations"
    (let* ((utc (find-time-zone "UTC"))
           (value (zoned-date-time-of-local (local-date-time-of 2024 1 31 10 15 0) utc))
           (ordinary (zoned-date-time-of-local (local-date-time-of 2024 1 15 10 15 0) utc))
           (month-later (zoned-date-time-plus-months value 1))
           (year-later (zoned-date-time-plus-years value 1)))
      (expect (local-date-time= (zoned-date-time-local month-later) (local-date-time-of 2024 2 29 10 15 0)) :to-be-truthy)
      (expect (local-date-time= (zoned-date-time-local year-later) (local-date-time-of 2025 1 31 10 15 0)) :to-be-truthy)
      (expect (zoned-date-time= (zoned-date-time-minus-days (zoned-date-time-plus-days ordinary 5) 5) ordinary) :to-be-truthy)
      (expect (zoned-date-time= (zoned-date-time-minus-weeks (zoned-date-time-plus-weeks ordinary 3) 3) ordinary) :to-be-truthy)
      (expect (zoned-date-time= (zoned-date-time-minus-months (zoned-date-time-plus-months ordinary 3) 3) ordinary) :to-be-truthy)
      (expect (zoned-date-time= (zoned-date-time-minus-years (zoned-date-time-plus-years ordinary 1) 1) ordinary) :to-be-truthy))))

(describe
  "ordering compares by absolute instant"
  (it
  "orders absolute instants across zones and DST overlaps"
  (let* ((ny (find-time-zone "America/New_York"))
         (tokyo (find-time-zone "Asia/Tokyo"))
         (zdt (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) ny)))
    (expect
     (zoned-date-time= zdt (zoned-date-time-with-zone-same-instant zdt tokyo))
     :to-be-truthy))
  (let* ((zone (find-time-zone "America/New_York"))
         (local (local-date-time-of 2024 11 3 1 30 0))
         (earlier (zoned-date-time-of-local local zone :disambiguation :earlier))
         (later (zoned-date-time-of-local local zone :disambiguation :later)))
    (expect (zoned-date-time> later earlier) :to-be-truthy)
    (expect (zoned-date-time<= later earlier) :to-be-falsy)
    (expect (zoned-date-time>= earlier later) :to-be-falsy)))
  (it
    "ZONED-DATE-TIME-UNTIL follows elapsed time across a DST transition"
    (let* ((new-york (find-time-zone "America/New_York"))
           (start (zoned-date-time-of-local
                   (local-date-time-of 2024 3 10 1 30 0)
                   new-york))
           (end (zoned-date-time-of-local
                 (local-date-time-of 2024 3 10 3 30 0)
                 new-york))
           (duration (zoned-date-time-until start end)))
      (expect (duration-to-seconds duration) :to-be 3600))))

(describe
  "fixed-unit truncation"
  (it
   "retains a valid later offset in a daylight-saving overlap"
   (let* ((zone (find-time-zone "America/New_York"))
          (original
           (zoned-date-time-of-local
            (local-date-time-of 2024 11 3 1 30 45 123456789)
            zone
            :disambiguation
            :later))
          (result (cl-date-kit:zoned-date-time-truncated-to original :hours)))
     (expect
      (local-date-time=
       (zoned-date-time-local result)
       (local-date-time-of 2024 11 3 1 0 0))
      :to-be-truthy)
     (expect
      (zone-offset-total-seconds (zoned-date-time-offset result))
      :to-be
      -18000))))

(describe "ZonedDateTime epoch-second conversions"
  (it-each
      ((-1 999999999 "UTC")
       (1710055800 123456789 "America/New_York"))
      "round-trips absolute fields through ~A"
      (seconds nanosecond zone-name)
    (let* ((zone (find-time-zone zone-name))
           (value (cl-date-kit:zoned-date-time-of-epoch-second seconds nanosecond zone)))
      (expect (cl-date-kit:zoned-date-time-to-epoch-second value) :to-be seconds)
      (expect (zoned-date-time-nanosecond value) :to-be nanosecond)
      (expect (eq (zoned-date-time-zone value) zone) :to-be-truthy))))

(describe "ZonedDateTime fixed-unit rounding" (it "re-resolves an ambiguous local result while retaining a valid offset" (let* ((zone (find-time-zone "America/New_York")) (source (zoned-date-time-of-local (local-date-time-of 2024 11 3 1 30 0) zone :preferred-offset (zone-offset-of-hours -5))) (rounded (zoned-date-time-rounded-to source :hours :mode :floor))) (expect (local-date-time-hour (zoned-date-time-local rounded)) :to-be 1) (expect (zone-offset-total-seconds (zoned-date-time-offset rounded)) :to-be -18000))))

(describe "ZonedDateTime instant comparisons" (it "orders equal, earlier, and later instants for inclusive comparisons" (let* ((utc (find-time-zone "UTC")) (new-york (find-time-zone "America/New_York")) (value (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) utc)) (same-instant (zoned-date-time-of-instant (zoned-date-time-to-instant value) new-york)) (before (zoned-date-time-minus-seconds value 1)) (after (zoned-date-time-plus-seconds value 1))) (expect (zoned-date-time<= value same-instant) :to-be-truthy) (expect (zoned-date-time<= value after) :to-be-truthy) (expect (zoned-date-time<= value before) :to-be-falsy) (expect (zoned-date-time>= value same-instant) :to-be-truthy) (expect (zoned-date-time>= value before) :to-be-truthy) (expect (zoned-date-time>= value after) :to-be-falsy))))

(describe
  "NOW constructor defaults"
  (it
    "ZONED-DATE-TIME-NOW, LOCAL-DATE-TIME-NOW, LOCAL-TIME-NOW, and LOCAL-DATE-NOW default to ZONE-OFFSET-UTC and the dynamically scoped CURRENT-CLOCK"
    (with-clock
      ((make-fixed-clock (make-instant 100 0)))
      (let ((zoned-date-time (zoned-date-time-now)))
        (expect
          (zone-offset= (zoned-date-time-offset zoned-date-time) (zone-offset-utc))
          :to-be-truthy)
        (expect
          (instant= (zoned-date-time-to-instant zoned-date-time) (make-instant 100 0))
          :to-be-truthy))
      (expect
        (local-date-time= (local-date-time-now) (local-date-time-of 1970 1 1 0 1 40))
        :to-be-truthy)
      (expect (local-time= (local-time-now) (local-time-of 0 1 40)) :to-be-truthy)
      (expect (local-date= (local-date-now) (make-local-date 1970 1 1)) :to-be-truthy))))

(describe
  "ZonedDateTime rounding mode default"
  (it
    "ZONED-DATE-TIME-ROUNDED-TO defaults to :HALF-EVEN, not :HALF-UP"
    (let* ((zone (find-time-zone "UTC"))
           (value (zoned-date-time-of-local (local-date-time-of 2024 6 1 12 30 0) zone)))
      (expect
        (local-date-time-hour (zoned-date-time-local (zoned-date-time-rounded-to value :hours)))
        :to-be
        12)
      (expect
        (local-date-time-hour
          (zoned-date-time-local (zoned-date-time-rounded-to value :hours :mode :half-up)))
        :to-be
        13))))
