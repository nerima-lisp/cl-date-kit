;;;; t/zoned-date-time-test.lisp
;;;; ZonedDateTime construction, DST gap/overlap resolution, accessors, and field/zone withers.
(in-package #:cl-date-kit/test)

(defvar *new-york* nil)

(describe
  "constructing from a local date-time or an instant"
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  (it
    "ZONED-DATE-TIME-OF-LOCAL resolves normal local time"
    (let* ((ldt (local-date-time-of 2024 6 15 12 0 0))
           (zdt (zoned-date-time-of-local
                 ldt *new-york*)))
      (expect (local-date-time= (zoned-date-time-local zdt) ldt) :to-be-truthy)
      (expect (zone-offset-total-seconds (zoned-date-time-offset zdt))
              :to-be -14400)))
  (it
    "ZONED-DATE-TIME-OF-INSTANT is the inverse for a normal instant"
    (let* ((zone *new-york*)
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
    (let* ((zone *new-york*)
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

(describe
  "DST overlap preservation"
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  (it
    "retains a later overlap offset when adding a zero period"
    (let* ((zone *new-york*)
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
    (let* ((new-york *new-york*)
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
    (let* ((new-york *new-york*)
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
        original new-york :disambiguation :strict)))))

(describe
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
             :to-be -18000))))

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
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  (it
    "constructs normal local times and round-trips their instant"
    (let* ((zone *new-york*)
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
    (let* ((zone *new-york*)
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
    (let ((zone *new-york*))
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
           :to-be-truthy))))))

(describe
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
     :to-be -18000))))
