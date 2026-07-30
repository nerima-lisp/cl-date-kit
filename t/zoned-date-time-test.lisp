;;;; t/zoned-date-time-test.lisp
(in-package #:cl-date-kit/test) (describe "ZonedDateTime fixed-unit arithmetic"
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

(describe
  "constructing from a local date-time or an instant"
  (it
    "ZONED-DATE-TIME-OF-LOCAL resolves normal local time"
    (let* ((ldt (local-date-time-of 2024 6 15 12 0 0))
           (zdt (zoned-date-time-of-local
                 ldt (find-time-zone "America/New_York"))))
      (expect (local-date-time= (zoned-date-time-local zdt) ldt) :to-be-truthy)
      (expect (zone-offset-total-seconds (zoned-date-time-offset zdt))
              :to-be -14400)))
  (it
    "ZONED-DATE-TIME-OF-INSTANT is the inverse for a normal instant"
    (let* ((zone (find-time-zone "America/New_York"))
           (zdt
             (zoned-date-time-of-local
              (local-date-time-of 2024 6 15 12 0 0 123456789)
              zone))
           (instant (zoned-date-time-to-instant zdt))
           (round-trip (zoned-date-time-of-instant instant zone))
           (direct-local (local-date-time-of-instant instant zone)))
      (expect
        (local-date-time=
          (zoned-date-time-local round-trip)
          (zoned-date-time-local zdt))
        :to-be-truthy)
      (expect
        (local-date-time=
          direct-local
          (zoned-date-time-local zdt))
        :to-be-truthy)))
  (it
    "compatible New York spring-gap construction round-trips at 03:30 EDT"
    (let* ((zone (find-time-zone "America/New_York"))
           (zdt (zoned-date-time-of-local (local-date-time-of 2024 3 10 2 30 0) zone))
           (round-trip (zoned-date-time-of-instant (zoned-date-time-to-instant zdt) zone)))
      (expect
        (local-date-time=
          (zoned-date-time-local round-trip)
          (local-date-time-of 2024 3 10 3 30 0))
        :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zoned-date-time-offset round-trip))
        :to-be
        -14400))))

(describe
  "ZONED-DATE-TIME-WITH-ZONE-SAME-INSTANT"
  (it
    "preserves the absolute instant while changing the zone"
    (let* ((ny (find-time-zone "America/New_York"))
           (tokyo (find-time-zone "Asia/Tokyo"))
           (zdt (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) ny))
           (moved (zoned-date-time-with-zone-same-instant zdt tokyo)))
      (expect
        (instant= (zoned-date-time-to-instant zdt) (zoned-date-time-to-instant moved))
        :to-be-truthy)
      (expect (eq (zoned-date-time-zone moved) tokyo) :to-be-truthy))))

(progn
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
      (expect (zoned-date-time= (zoned-date-time-minus-years (zoned-date-time-plus-years ordinary 1) 1) ordinary) :to-be-truthy)))))

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

(progn (describe
  "DST overlap preservation"
  (it
    "retains a later overlap offset when adding a zero period"
    (let* ((zone (find-time-zone "America/New_York"))
           (original
            (zoned-date-time-of-local
             (local-date-time-of 2024 11 3 1 30 0)
             zone
             :disambiguation
             :later))
           (result (zoned-date-time-plus-period original (make-period))))
      (expect (zoned-date-time= result original) :to-be-truthy)
      (expect
       (zone-offset-total-seconds (zoned-date-time-offset result))
       :to-be
       -18000)))
  (it
    "with-zone-same-local preserves fields and re-resolves the instant"
    (let* ((new-york (find-time-zone "America/New_York"))
           (tokyo (find-time-zone "Asia/Tokyo"))
           (original
            (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) new-york))
           (result (zoned-date-time-with-zone-same-local original tokyo)))
      (expect
       (local-date-time=
        (zoned-date-time-local result)
        (zoned-date-time-local original))
       :to-be-truthy)
      (expect (zoned-date-time< result original) :to-be-truthy)))
  (it
    "with-zone-same-local delegates overlap resolution options"
    (let* ((new-york (find-time-zone "America/New_York"))
           (utc (find-time-zone "UTC"))
           (original
            (zoned-date-time-of-local
             (local-date-time-of 2024 11 3 1 30 0)
             utc))
           (preferred
            (zoned-date-time-with-zone-same-local
             original
             new-york
             :preferred-offset (zone-offset-of-hours -5))))
      (expect
       (zone-offset-total-seconds (zoned-date-time-offset preferred))
       :to-be
       -18000)
      (signals ambiguous-local-time
       (zoned-date-time-with-zone-same-local
        original new-york :disambiguation :strict))))) (describe
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
      -18000))))(describe
  "ZonedDateTime field replacement"
  (it
   "replaces local fields while retaining the zone and source value"
   (let* ((zone (find-time-zone "UTC"))
          (value
           (zoned-date-time-of-local
            (local-date-time-of 2024 2 29 12 34 56 123456789)
            zone))
          (result
           (cl-date-kit:zoned-date-time-with-nanosecond
            (cl-date-kit:zoned-date-time-with-second
             (cl-date-kit:zoned-date-time-with-minute
              (cl-date-kit:zoned-date-time-with-hour
               (cl-date-kit:zoned-date-time-with-day-of-year
                (cl-date-kit:zoned-date-time-with-day
                 (cl-date-kit:zoned-date-time-with-month
                  (cl-date-kit:zoned-date-time-with-year value 2023)
                  3)
                 15)
                200)
               1)
              2)
             3)
            4)))
     (expect (eq (zoned-date-time-zone result) zone) :to-be-truthy)
     (expect
      (local-date-time=
       (zoned-date-time-local result)
       (local-date-time-of 2023 7 19 1 2 3 4))
      :to-be-truthy)
     (expect
      (local-date-time=
       (zoned-date-time-local value)
       (local-date-time-of 2024 2 29 12 34 56 123456789))
      :to-be-truthy)))
  (it
   "retains the valid offset in an overlap and resolves a gap compatibly"
   (let* ((zone (find-time-zone "America/New_York"))
          (overlap
           (zoned-date-time-of-local
            (local-date-time-of 2024 11 3 1 30 0)
            zone
            :disambiguation
            :later))
          (same-local (cl-date-kit:zoned-date-time-with-minute overlap 0))
          (before-gap
           (zoned-date-time-of-local
            (local-date-time-of 2024 3 10 1 30 0)
            zone))
          (gap-resolved
           (cl-date-kit:zoned-date-time-with-hour before-gap 2)))
     (expect
      (zone-offset-total-seconds (zoned-date-time-offset same-local))
      :to-be
      -18000)
     (expect
      (local-date-time=
       (zoned-date-time-local gap-resolved)
       (local-date-time-of 2024 3 10 3 30 0))
      :to-be-truthy)
     (expect
      (zone-offset-total-seconds (zoned-date-time-offset gap-resolved))
      :to-be
      -14400)))
  (it
   "validates replacement field values"
   (let ((value
          (zoned-date-time-of-local
           (local-date-time-of 2024 1 1 0 0 0)
           (find-time-zone "UTC"))))
     (expect
      (lambda ()
        (cl-date-kit:zoned-date-time-with-minute value 60))
      :to-throw
      (quote invalid-time))))
  (it
   "exposes local date, time, and fields without changing an overlap value"
   (let* ((zone (find-time-zone "America/New_York"))
          (value
           (zoned-date-time-of-local
            (local-date-time-of 2024 11 3 1 30 45 123456789)
            zone
            :disambiguation :later)))
     (expect (local-date= (zoned-date-time-date value)
                           (make-local-date 2024 11 3))
             :to-be-truthy)
     (expect (local-time= (zoned-date-time-time value)
                           (make-local-time 1 30 45 123456789))
             :to-be-truthy)
     (expect (list (zoned-date-time-year value)
                   (zoned-date-time-month value)
                   (zoned-date-time-day value)
                   (zoned-date-time-hour value)
                   (zoned-date-time-minute value)
                   (zoned-date-time-second value)
                   (zoned-date-time-nanosecond value))
             :to-equal
             (list 2024 11 3 1 30 45 123456789))
     (expect (zone-offset-total-seconds (zoned-date-time-offset value))
             :to-be -18000)))))

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

(describe "ZONED-DATE-TIME overlap offset selectors"
  (it "selects either instant without changing the local fields"
    (let* ((zone (find-time-zone "America/New_York"))
           (local (local-date-time-of 2024 11 3 1 30 0))
           (later (zoned-date-time-of-local local zone :disambiguation :later))
           (earlier (cl-date-kit:zoned-date-time-with-earlier-offset-at-overlap later))
           (selected-later (cl-date-kit:zoned-date-time-with-later-offset-at-overlap earlier)))
      (expect (zone-offset-total-seconds (zoned-date-time-offset earlier)) :to-be -14400)
      (expect (zone-offset-total-seconds (zoned-date-time-offset selected-later)) :to-be -18000)
      (expect (local-date-time= (zoned-date-time-local earlier) local) :to-be-truthy)
      (expect (local-date-time= (zoned-date-time-local selected-later) local) :to-be-truthy)
      (expect (instant< (zoned-date-time-to-instant earlier)
                        (zoned-date-time-to-instant selected-later))
              :to-be-truthy)))
  (it "returns the original value outside an overlap"
    (let* ((zone (find-time-zone "America/New_York"))
           (value (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) zone)))
      (expect (eq (cl-date-kit:zoned-date-time-with-earlier-offset-at-overlap value) value)
              :to-be-truthy)
      (expect (eq (cl-date-kit:zoned-date-time-with-later-offset-at-overlap value) value)
              :to-be-truthy))))

(describe
  "ZONED-DATE-TIME-OF-STRICT"
  (it
    "constructs normal local times and round-trips their instant"
    (let* ((zone (find-time-zone "America/New_York"))
           (local (local-date-time-of 2024 6 15 12 0 0))
           (value
             (cl-date-kit:zoned-date-time-of-strict
              local
              (zone-offset-of-hours -4)
              zone))
           (round-trip
             (zoned-date-time-of-instant
              (zoned-date-time-to-instant value)
              zone)))
      (expect (local-date-time= (zoned-date-time-local value) local)
              :to-be-truthy)
      (expect (zone-offset-total-seconds (zoned-date-time-offset value))
              :to-be -14400)
      (expect (local-date-time= (zoned-date-time-local round-trip) local)
              :to-be-truthy)
      (expect (zone-offset-total-seconds (zoned-date-time-offset round-trip))
              :to-be -14400)))
  (it
    "accepts both valid offsets in a New York overlap"
    (let* ((zone (find-time-zone "America/New_York"))
           (local (local-date-time-of 2024 11 3 1 30 0))
           (earlier
             (cl-date-kit:zoned-date-time-of-strict
              local
              (zone-offset-of-hours -4)
              zone))
           (later
             (cl-date-kit:zoned-date-time-of-strict
              local
              (zone-offset-of-hours -5)
              zone)))
      (expect (zone-offset-total-seconds (zoned-date-time-offset earlier))
              :to-be -14400)
      (expect (zone-offset-total-seconds (zoned-date-time-offset later))
              :to-be -18000)
      (expect (instant< (zoned-date-time-to-instant earlier)
                        (zoned-date-time-to-instant later))
              :to-be-truthy)))
  (it
    "rejects mismatches and gaps"
    (let ((zone (find-time-zone "America/New_York")))
      (signals cl-date-kit:invalid-zoned-date-time-offset
        (cl-date-kit:zoned-date-time-of-strict
         (local-date-time-of 2024 6 15 12 0 0)
         (zone-offset-of-hours -5)
         zone))
      (signals cl-date-kit:invalid-zoned-date-time-offset
        (cl-date-kit:zoned-date-time-of-strict
         (local-date-time-of 2024 3 10 2 30 0)
         (zone-offset-of-hours -5)
         zone))
      (signals cl-date-kit:invalid-zoned-date-time-offset
        (cl-date-kit:zoned-date-time-of-strict
         (local-date-time-of 2024 11 3 1 30 0)
         (zone-offset-of-hours -6)
         zone))))
  (it
    "accepts a fixed-offset zone"
    (let* ((zone (zone-offset-of-hours 9))
           (local (local-date-time-of 2024 6 15 12 0 0))
           (value
             (cl-date-kit:zoned-date-time-of-strict
              local
              (zone-offset-of-hours 9)
              zone)))
      (expect (eq (zoned-date-time-zone value) zone) :to-be-truthy)
      (expect (eq (zoned-date-time-offset value) zone) :to-be-truthy)
      (expect (local-date-time= (zoned-date-time-local value) local)
              :to-be-truthy))))

(progn (progn (progn
  (describe
   "ZONED-DATE-TIME-TO-OFFSET-DATE-TIME"
   (it
    "snapshots local fields and resolved offsets, including both New York overlap choices"
    (let* ((zone (find-time-zone "America/New_York"))
           (overlap (local-date-time-of 2024 11 3 1 30 45 123456789))
           (cases
             (list
              (list
               (zoned-date-time-of-local
                (local-date-time-of 2024 6 15 12 0 45 123456789)
                zone)
               -14400)
              (list
               (zoned-date-time-of-local
                overlap
                zone
                :preferred-offset (zone-offset-of-hours -4))
               -14400)
              (list
               (zoned-date-time-of-local
                overlap
                zone
                :preferred-offset (zone-offset-of-hours -5))
               -18000))))
      (dolist (case cases)
        (destructuring-bind (source expected-offset) case
          (let ((snapshot
                  (cl-date-kit:zoned-date-time-to-offset-date-time source)))
            (expect
             (local-date-time=
              (cl-date-kit:offset-date-time-local-date-time snapshot)
              (zoned-date-time-local source))
             :to-be-truthy)
            (expect
             (zone-offset-total-seconds
              (cl-date-kit:offset-date-time-offset snapshot))
             :to-be expected-offset)
            (expect
             (instant=
              (cl-date-kit:offset-date-time-to-instant snapshot)
              (zoned-date-time-to-instant source))
             :to-be-truthy)))))))

  (describe
   "ZONED-DATE-TIME-WITH-FIXED-OFFSET-ZONE"
   (it
    "preserves local fields, offset, and instant for normal and overlap values"
    (let* ((zone (find-time-zone "America/New_York"))
           (overlap (local-date-time-of 2024 11 3 1 30 45 123456789))
           (cases
             (list
              (zoned-date-time-of-local
               (local-date-time-of 2024 6 15 12 0 45 123456789)
               zone)
              (zoned-date-time-of-local
               overlap
               zone
               :preferred-offset (zone-offset-of-hours -4))
              (zoned-date-time-of-local
               overlap
               zone
               :preferred-offset (zone-offset-of-hours -5)))))
      (dolist (source cases)
        (let ((fixed
                (cl-date-kit:zoned-date-time-with-fixed-offset-zone source)))
          (expect
           (local-date-time=
            (zoned-date-time-local fixed)
            (zoned-date-time-local source))
           :to-be-truthy)
          (expect
           (eq (zoned-date-time-zone fixed)
               (zoned-date-time-offset fixed))
           :to-be-truthy)
          (expect
           (zone-offset-total-seconds
            (zoned-date-time-offset fixed))
           :to-be
           (zone-offset-total-seconds
            (zoned-date-time-offset source)))
          (expect
           (instant=
            (zoned-date-time-to-instant fixed)
            (zoned-date-time-to-instant source))
           :to-be-truthy))))))) (progn (describe "ZonedDateTime fixed-unit rounding" (it "re-resolves an ambiguous local result while retaining a valid offset" (let* ((zone (find-time-zone "America/New_York")) (source (zoned-date-time-of-local (local-date-time-of 2024 11 3 1 30 0) zone :preferred-offset (zone-offset-of-hours -5))) (rounded (zoned-date-time-rounded-to source :hours :mode :floor))) (expect (local-date-time-hour (zoned-date-time-local rounded)) :to-be 1) (expect (zone-offset-total-seconds (zoned-date-time-offset rounded)) :to-be -18000)))) (describe
 "LOCAL-DATE-TIME-AT-ZONE"
 (it
  "forwards preferred offsets when resolving a DST overlap"
  (let* ((zone (find-time-zone "America/New_York"))
         (local (local-date-time-of 2024 11 3 1 30 0))
         (resolved
           (cl-date-kit:local-date-time-at-zone
            local
            zone
            :preferred-offset (zone-offset-of-hours -5))))
    (expect
     (local-date-time= (zoned-date-time-local resolved) local)
     :to-be-truthy)
    (expect
     (zone-offset-total-seconds (zoned-date-time-offset resolved))
     :to-be -18000)))))) (describe "ZonedDateTime instant comparisons" (it "orders equal, earlier, and later instants for inclusive comparisons" (let* ((utc (find-time-zone "UTC")) (new-york (find-time-zone "America/New_York")) (value (zoned-date-time-of-local (local-date-time-of 2024 6 15 12 0 0) utc)) (same-instant (zoned-date-time-of-instant (zoned-date-time-to-instant value) new-york)) (before (zoned-date-time-minus-seconds value 1)) (after (zoned-date-time-plus-seconds value 1))) (expect (zoned-date-time<= value same-instant) :to-be-truthy) (expect (zoned-date-time<= value after) :to-be-truthy) (expect (zoned-date-time<= value before) :to-be-falsy) (expect (zoned-date-time>= value same-instant) :to-be-truthy) (expect (zoned-date-time>= value before) :to-be-truthy) (expect (zoned-date-time>= value after) :to-be-falsy)))))
