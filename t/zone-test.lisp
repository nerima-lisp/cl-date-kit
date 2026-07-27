;;;; t/zone-test.lisp
;;;;
;;;; These tests read the real IANA time zone database from TZDIR or
;;;; /usr/share/zoneinfo. flake.nix points TZDIR at nixpkgs' `tzdata` package
;;;; so `nix flake check` does not depend on the host's copy.
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
    (signals invalid-zone-offset (zone-offset-of-hms -5 30 0))))

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
        :to-be-truthy))))

(describe
  "FIND-TIME-ZONE"
  (it
    "signals TIME-ZONE-NOT-FOUND for a name with no matching TZif file"
    (signals time-zone-not-found (find-time-zone "Nonexistent/Zone")))
  (it
    "signals TIME-ZONE-NOT-FOUND instead of reading outside the zoneinfo directory"
    (signals time-zone-not-found (find-time-zone "../../../../etc/passwd")))
  (it
    "signals TIME-ZONE-NOT-FOUND for an absolute path"
    (signals time-zone-not-found (find-time-zone "/etc/passwd")))
  (it
    "TIME-ZONE-NAME echoes back the requested IANA name"
    (expect (time-zone-name (find-time-zone "Asia/Tokyo")) :to-equal "Asia/Tokyo")))

(describe "OFFSET-FOR-INSTANT on real time zones"
  (it "Asia/Tokyo has been a fixed UTC+9 with no DST since 1951"
    (expect (zone-offset-total-seconds (offset-for-instant (find-time-zone "Asia/Tokyo") (make-instant 1700000000))) :to-be 32400))

  (it "America/New_York is UTC-5 in January (standard time) and UTC-4 in July (daylight time)"
    (let ((ny (find-time-zone "America/New_York")))
      (expect (zone-offset-total-seconds (offset-for-instant ny (zoned-date-time-to-instant (zoned-date-time-of-local (local-date-time-of 2024 1 15 12 0 0) ny))))
              :to-be -18000)
      (expect (zone-offset-total-seconds (offset-for-instant ny (zoned-date-time-to-instant (zoned-date-time-of-local (local-date-time-of 2024 7 15 12 0 0) ny))))
              :to-be -14400)))

  (it "uses a POSIX TZ footer even when a TZif has no explicit transitions"
    (let* ((rule (cl-date-kit::parse-posix-tz-string "EST5EDT,M3.2.0/2,M11.1.0/2"))
           (initial (cl-date-kit::make-tzif-type :utc-offset -18000 :dst-p nil))
           (data (cl-date-kit::make-tzif-data :transition-times #() :transition-types #() :initial-type initial :posix-tz-string "EST5EDT,M3.2.0/2,M11.1.0/2"))
           (zone (cl-date-kit::%make-time-zone "Synthetic/EST" data rule)))
      (expect (zone-offset-total-seconds (offset-for-instant zone (zoned-date-time-to-instant (zoned-date-time-of-local (local-date-time-of 2024 1 15 12 0 0) (zone-offset-utc))))) :to-be -18000)
      (expect (zone-offset-total-seconds (offset-for-instant zone (zoned-date-time-to-instant (zoned-date-time-of-local (local-date-time-of 2024 7 15 12 0 0) (zone-offset-utc))))) :to-be -14400)))

  (it "falls back to the POSIX TZ footer rule for a date beyond the explicit transition table"
    ;; Europe/London: BST (UTC+1) runs from the last Sunday of March to the
    ;; last Sunday of October. 2100-07-01 is far beyond any real zic table.
    (let ((london (find-time-zone "Europe/London")))
      (expect (zone-offset-total-seconds
               (offset-for-instant london (zoned-date-time-to-instant (zoned-date-time-of-local (local-date-time-of 2100 7 1 12 0 0) (zone-offset-of-hours 0)))))
              :to-be 3600))))

(describe "resolving a wall-clock LOCAL-DATE-TIME: the DST spring-forward gap"
  ;; 2024-03-10 02:00 America/New_York: clocks jump straight to 03:00 EDT.
  ;; 02:00-02:59:59 never happened that day.
  (it "POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME returns no offsets for a time inside the gap"
    (expect (possible-offsets-for-local-date-time (local-date-time-of 2024 3 10 2 30 0) (find-time-zone "America/New_York"))
            :to-equal '()))

  (it "RESOLVE-LOCAL-DATE-TIME signals NONEXISTENT-LOCAL-TIME with :DISAMBIGUATION :STRICT"
    (signals nonexistent-local-time
      (resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) (find-time-zone "America/New_York") :disambiguation :strict)))

  (it "RESOLVE-LOCAL-DATE-TIME with the :COMPATIBLE default resolves to the post-gap (EDT) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) (find-time-zone "America/New_York")))
            :to-be -14400))

  (it "RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION :EARLIER resolves to the pre-gap (EST) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) (find-time-zone "America/New_York") :disambiguation :earlier))
            :to-be -18000)))

(describe "resolving a wall-clock LOCAL-DATE-TIME: the DST fall-back overlap"
  ;; 2024-11-03 America/New_York: clocks fall back from 02:00 EDT to 01:00
  ;; EST, so 01:00-01:59:59 happens twice.
  (it "POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME returns the earlier (EDT) offset first, then the later (EST) one"
    (expect (mapcar #'zone-offset-total-seconds
                     (possible-offsets-for-local-date-time (local-date-time-of 2024 11 3 1 30 0) (find-time-zone "America/New_York")))
            :to-equal '(-14400 -18000)))

  (it "RESOLVE-LOCAL-DATE-TIME signals AMBIGUOUS-LOCAL-TIME with :DISAMBIGUATION :STRICT"
    (signals ambiguous-local-time
      (resolve-local-date-time (local-date-time-of 2024 11 3 1 30 0) (find-time-zone "America/New_York") :disambiguation :strict)))

  (it "RESOLVE-LOCAL-DATE-TIME with the :COMPATIBLE default resolves to the earlier (EDT) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 11 3 1 30 0) (find-time-zone "America/New_York")))
            :to-be -14400))

  (it "RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION :LATER resolves to the later (EST) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 11 3 1 30 0) (find-time-zone "America/New_York") :disambiguation :later))
            :to-be -18000)))

(describe
  "future TZif footer transition classification"
  (it
    "recognizes the 2100 New York spring gap beyond the explicit table"
    (let ((ny (find-time-zone "America/New_York")))
      (expect
        (possible-offsets-for-local-date-time (local-date-time-of 2100 3 14 2 30 0) ny)
        :to-equal
        '())
      (signals
        nonexistent-local-time
        (resolve-local-date-time
          (local-date-time-of 2100 3 14 2 30 0)
          ny
          :disambiguation
          :strict))))
  (it
    "recognizes the 2100 New York fall overlap beyond the explicit table"
    (let ((ny (find-time-zone "America/New_York")))
      (expect
        (mapcar
          #'zone-offset-total-seconds
          (possible-offsets-for-local-date-time (local-date-time-of 2100 11 7 1 30 0) ny))
        :to-equal
        '(-14400 -18000))
      (signals
        ambiguous-local-time
        (resolve-local-date-time
          (local-date-time-of 2100 11 7 1 30 0)
          ny
          :disambiguation
          :strict))))) (describe "TZif block validation" (it "rejects a truncated block before field access" (signals
      malformed-tzif
      (cl-date-kit::%parse-tzif-block
        #()
        0
        (cl-date-kit::make-%tzif-header :typecnt 1 :charcnt 1)
        4
        "truncated-block"))) (it
    "rejects a transition type index outside the type table"
    (signals
      malformed-tzif
      (cl-date-kit::%parse-tzif-block
        #(0 0 0 0 1 0 0 0 0 0 0)
        0
        (cl-date-kit::make-%tzif-header :timecnt 1 :typecnt 1)
        4
        "invalid-type-index"))) (it
    "rejects non-monotonic transition times"
    (signals
      malformed-tzif
      (cl-date-kit::%parse-tzif-block
        #(0 0 0 2 0 0 0 1 0 0 0 0 0 0 0 0)
        0
        (cl-date-kit::make-%tzif-header :timecnt 2 :typecnt 1)
        4
        "unordered-transitions"))) (it
    "rejects incompatible transition-indicator counts"
    (signals
      malformed-tzif
      (cl-date-kit::%parse-tzif-block
        #()
        0
        (cl-date-kit::make-%tzif-header :typecnt 1 :isstdcnt 2)
        4
        "invalid-indicators"))))

(progn
  (describe
    "POSIX TZ calendar rule forms"
    (it
      "excludes leap day in Jn rules"
      (let ((rule (cl-date-kit::parse-posix-tz-string "STD0DST,J60/2,J300/2")))
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+ (* (local-date-to-epoch-day (make-local-date 2024 2 29)) 86400) (* 2 3600))
            rule)
          :to-be
          0)
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+ (* (local-date-to-epoch-day (make-local-date 2024 3 1)) 86400) (* 2 3600))
            rule)
          :to-be
          3600)))
    (it
      "counts leap day in zero-based n rules"
      (let ((rule (cl-date-kit::parse-posix-tz-string "STD0DST,59/2,300/2")))
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+ (* (local-date-to-epoch-day (make-local-date 2024 2 28)) 86400) (* 2 3600))
            rule)
          :to-be
          0)
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+ (* (local-date-to-epoch-day (make-local-date 2024 2 29)) 86400) (* 2 3600))
            rule)
          :to-be
          3600)))
    (it
      "accepts signed multi-day transition times"
      (let ((rule (cl-date-kit::parse-posix-tz-string "STD0DST,M3.5.0/26,M10.5.0/-2")))
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+
              (* (local-date-to-epoch-day (make-local-date 2024 4 1)) 86400)
              (* 1 3600)
              59
              60)
            rule)
          :to-be
          0)
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+ (* (local-date-to-epoch-day (make-local-date 2024 4 1)) 86400) (* 2 3600))
            rule)
          :to-be
          3600)))
    (it
      "uses UTC for u, g, and z suffixes"
      (dolist (suffix '("u" "g" "z"))
        (let ((rule
              (cl-date-kit::parse-posix-tz-string
                (format nil "EST5EDT,M3.2.0/2~A,M11.1.0/2~A" suffix suffix))))
          (expect
            (cl-date-kit::%offset-from-posix-rule
              (+
                (* (local-date-to-epoch-day (make-local-date 2024 3 10)) 86400)
                (* 1 3600)
                59
                60)
              rule)
            :to-be
            -18000)
          (expect
            (cl-date-kit::%offset-from-posix-rule
              (+ (* (local-date-to-epoch-day (make-local-date 2024 3 10)) 86400) (* 2 3600))
              rule)
            :to-be
            -14400))))
    (it
      "uses standard time for s suffixes"
      (let ((rule (cl-date-kit::parse-posix-tz-string "EST5EDT,M3.2.0/2s,M11.1.0/2s")))
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+
              (* (local-date-to-epoch-day (make-local-date 2024 3 10)) 86400)
              (* 6 3600)
              59
              60)
            rule)
          :to-be
          -18000)
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+ (* (local-date-to-epoch-day (make-local-date 2024 3 10)) 86400) (* 7 3600))
            rule)
          :to-be
          -14400)
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+
              (* (local-date-to-epoch-day (make-local-date 2024 11 3)) 86400)
              (* 6 3600)
              59
              60)
            rule)
          :to-be
          -14400)
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (+ (* (local-date-to-epoch-day (make-local-date 2024 11 3)) 86400) (* 7 3600))
            rule)
          :to-be
          -18000))))
  (describe
    "a normal (non-gap, non-overlap) local time resolves to exactly one offset"
    (it
      "resolves noon in mid-summer to the single daylight-time offset"
      (expect
        (mapcar
          #'zone-offset-total-seconds
          (possible-offsets-for-local-date-time
            (local-date-time-of 2024 6 15 12 0 0)
            (find-time-zone "America/New_York")))
        :to-equal
        '(-14400)))))(progn
  (describe
    "TZif POSIX footer framing"
    (it
      "returns NIL for a valid empty footer"
      (expect
        (cl-date-kit::%parse-posix-tz-string #(10 10) 0 "empty-footer")
        :to-be
        nil))
    (it
      "rejects a footer without its opening newline"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-posix-tz-string #(74 83 84 45 57 10) 0 "missing-open")))
    (it
      "rejects a footer without its closing newline"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-posix-tz-string #(10 74 83 84 45 57) 0 "missing-close")))
    (it
      "rejects bytes after the closing newline"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-posix-tz-string #(10 74 83 84 45 57 10 0) 0 "trailing-byte"))))
  (describe
    "ZONE-TRANSITION queries"
    (it
      "reports New York\x27s 2024 gap and overlap with strict instant boundaries"
      (let* ((ny (find-time-zone "America/New_York"))
             (spring (local-date-time-to-instant (local-date-time-of 2024 3 10 7 0 0) (zone-offset-utc)))
             (fall (local-date-time-to-instant (local-date-time-of 2024 11 3 6 0 0) (zone-offset-utc)))
             (next (next-zone-transition ny (make-instant (1- (instant-epoch-second spring)))))
             (previous (previous-zone-transition ny (make-instant (instant-epoch-second spring) 1))))
        (expect (zone-transition-p next) :to-be-truthy)
        (expect (instant= (zone-transition-instant next) spring) :to-be-truthy)
        (expect (zone-offset-total-seconds (zone-transition-offset-before next)) :to-be -18000)
        (expect (zone-offset-total-seconds (zone-transition-offset-after next)) :to-be -14400)
        (expect (zone-transition-gap-p next) :to-be-truthy)
        (expect (zone-transition-overlap-p next) :to-be-falsy)
        (expect (instant= (zone-transition-instant previous) spring) :to-be-truthy)
        (expect (instant= (zone-transition-instant (next-zone-transition ny spring)) fall) :to-be-truthy)
        (expect (zone-transition-overlap-p (next-zone-transition ny spring)) :to-be-truthy)))
    (it
      "uses the POSIX footer for future next and previous transitions"
      (let* ((ny (find-time-zone "America/New_York"))
             (start (local-date-time-to-instant (local-date-time-of 2100 1 1 0 0 0) (zone-offset-utc)))
             (summer (local-date-time-to-instant (local-date-time-of 2100 7 1 0 0 0) (zone-offset-utc)))
             (spring (local-date-time-to-instant (local-date-time-of 2100 3 14 7 0 0) (zone-offset-utc)))
             (next (next-zone-transition ny start))
             (previous (previous-zone-transition ny summer)))
        (expect (instant= (zone-transition-instant next) spring) :to-be-truthy)
        (expect (instant= (zone-transition-instant previous) spring) :to-be-truthy)
        (expect (zone-transition-gap-p next) :to-be-truthy)))
    (it
      "returns NIL for fixed-offset zones"
      (let ((utc (zone-offset-utc)))
        (expect (next-zone-transition utc (make-instant 0)) :to-be nil)
        (expect (previous-zone-transition utc (make-instant 0)) :to-be nil)))))
