(in-package #:cl-date-kit/test)

(describe
  "ZONE-OFFSET"
  (it
    "ZONE-OFFSET-OF-HOURS and ZONE-OFFSET-OF-HMS compute total seconds"
    (expect (zone-offset-total-seconds (zone-offset-of-hours 9)) :to-be 32400)
    (expect (zone-offset-total-seconds (zone-offset-of-hms -5 -30 0)) :to-be -19800)
    (expect (zone-offset-total-seconds (zone-offset-of-hms 5 30 45)) :to-be 19845))
  (it
    "ZONE-OFFSET-UTC is zero"
    (expect (zone-offset-total-seconds (zone-offset-utc)) :to-be 0))
  (it
    "a ZONE-OFFSETs OFFSET-FOR-INSTANT is itself"
    (let ((offset (zone-offset-of-hours 9)))
      (expect (eq offset (offset-for-instant offset (make-instant 0))) :to-be-truthy)))
  (it
    "rejects offsets outside +/-18:00 and with mixed signs"
    (expect (zone-offset-total-seconds (zone-offset-of-hms 18 0 0)) :to-be 64800)
    (signals invalid-zone-offset (zone-offset-of-hours 19))
    (signals invalid-zone-offset (zone-offset-of-hours -19))
    (signals invalid-zone-offset (zone-offset-of-hms 18 1 0))
    (signals invalid-zone-offset (zone-offset-of-hms -18 -1 0))
    (signals invalid-zone-offset (zone-offset-of-hms 5 -30 0))
    (signals invalid-zone-offset (zone-offset-of-hms -5 30 0)))
  (it
    "rejects non-integral HMS components"
    (signals invalid-zone-offset (zone-offset-of-hms 1/2 0 0))
    (signals invalid-zone-offset (zone-offset-of-hms 0 1/2 0))
    (signals invalid-zone-offset (zone-offset-of-hms 0 0 1/2)))
  (it
    "rejects out-of-range and internally mixed minute and second components"
    (signals invalid-zone-offset (zone-offset-of-hms 0 60 0))
    (signals invalid-zone-offset (zone-offset-of-hms 0 0 -60))
    (signals invalid-zone-offset (zone-offset-of-hms 0 1 -1)))
  (it
    "returns false for opposite inclusive offset comparisons"
    (let ((west (zone-offset-of-hours -5))
          (east (zone-offset-of-hours 9)))
      (expect (zone-offset<= east west) :to-be-falsy)
      (expect (zone-offset>= west east) :to-be-falsy))))

(describe
  "fixed-offset LOCAL-DATE-TIME conversions"
  (it
    "maps a local epoch reading in UTC+09:00 to Unix epoch seconds"
    (expect
      (local-date-time-to-epoch-second
        (local-date-time-of 1970 1 1 9 0 0)
        (zone-offset-of-hours 9))
      :to-be
      0))
  (it
    "normalizes negative epoch seconds across the local day boundary"
    (expect
      (local-date-time=
        (local-date-time-of-epoch-second -1 7 (zone-offset-of-hours 9))
        (local-date-time-of 1970 1 1 8 59 59 7))
      :to-be-truthy))
  (it
    "round-trips an instant and its nanosecond precision through a fixed offset"
    (let* ((offset (zone-offset-of-hms -3 -30 0))
           (instant (make-instant -1 123456789))
           (local (local-date-time-of-instant instant offset)))
      (expect
        (local-date-time= local (local-date-time-of 1969 12 31 20 29 59 123456789))
        :to-be-truthy)
      (expect
        (instant= (local-date-time-to-instant local offset) instant)
        :to-be-truthy)))
  (it
    "signals TYPE-ERROR for incorrect fixed-offset converter input types"
    (let ((local-date-time (local-date-time-of 1970 1 1 0 0 0))
          (offset (zone-offset-utc)))
      (signals type-error (local-date-time-to-epoch-second 0 offset))
      (signals type-error (local-date-time-to-epoch-second local-date-time 0))
      (signals type-error (local-date-time-of-epoch-second 0.5 0 offset))
      (signals type-error (local-date-time-of-epoch-second 0 0 0))
      (signals type-error (local-date-time-to-instant 0 offset)))))

(describe
  "ZONE-OFFSET-OF-TOTAL-SECONDS"
  (it
    "constructs offsets without exposing component normalization"
    (expect
      (zone-offset-total-seconds (zone-offset-of-total-seconds 19845))
      :to-be
      19845)
    (expect
      (zone-offset-total-seconds (zone-offset-of-total-seconds -19845))
      :to-be
      -19845)
    (expect
      (zone-offset-total-seconds (zone-offset-of-total-seconds 64800))
      :to-be
      64800))
  (it
    "rejects non-integral and out-of-range offsets"
    (signals invalid-zone-offset (zone-offset-of-total-seconds 1/2))
    (signals invalid-zone-offset (zone-offset-of-total-seconds 64801))
    (signals invalid-zone-offset (zone-offset-of-total-seconds -64801))))

(describe
  "ZONE-OFFSET comparison"
  (it
    "compares offsets by their total seconds"
    (let ((west (zone-offset-of-hours -5))
          (east (zone-offset-of-hours 9)))
      (expect (zone-offset-compare west east) :to-be -1)
      (expect (zone-offset= west (zone-offset-of-total-seconds -18000)) :to-be-truthy)
      (expect (zone-offset< west east) :to-be-truthy)
      (expect (zone-offset<= west west) :to-be-truthy)
      (expect (zone-offset> east west) :to-be-truthy)
      (expect (zone-offset>= east east) :to-be-truthy))))
