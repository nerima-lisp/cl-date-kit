;;;; t/zone-transition-test.lisp
;;;;
;;;; Named-zone offset lookups, DST spring-forward-gap and fall-back-overlap
;;;; resolution, and transition navigation (LOCAL-DATE-TIME-ZONE-TRANSITION,
;;;; NEXT-ZONE-TRANSITION, PREVIOUS-ZONE-TRANSITION,
;;;; TIME-ZONE-TRANSITIONS-BETWEEN). These tests read the real IANA time
;;;; zone database from TZDIR or /usr/share/zoneinfo.
(in-package #:cl-date-kit/test)

(defvar *new-york* nil)

(progn
  (it
    "America/New_York is UTC-5 in January (standard time) and UTC-4 in July (daylight time)"
    (let ((ny (find-time-zone "America/New_York")))
      (expect
        (zone-offset-total-seconds
          (offset-for-instant
            ny
            (zoned-date-time-to-instant
              (zoned-date-time-of-local (local-date-time-of 2024 1 15 12 0 0) ny))))
        :to-be
        -18000)
      (expect
        (zone-offset-total-seconds
          (offset-for-instant
            ny
            (zoned-date-time-to-instant
              (zoned-date-time-of-local (local-date-time-of 2024 7 15 12 0 0) ny))))
        :to-be
        -14400)))
  (it
    "converts instants through a named zone"
    (let* ((ny (find-time-zone "America/New_York"))
           (local (local-date-time-of 2024 7 15 12 0 0))
           (instant (zoned-date-time-to-instant (zoned-date-time-of-local local ny))))
      (expect
        (local-date-time= (local-date-time-of-instant instant ny) local)
        :to-be-truthy))))

(describe "resolving a wall-clock LOCAL-DATE-TIME: the DST spring-forward gap"
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  ;; 2024-03-10 02:00 America/New_York: clocks jump straight to 03:00 EDT.
  ;; 02:00-02:59:59 never happened that day.
  (it "POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME returns no offsets for a time inside the gap"
    (expect (possible-offsets-for-local-date-time (local-date-time-of 2024 3 10 2 30 0) *new-york*)
            :to-equal '()))

  (it "RESOLVE-LOCAL-DATE-TIME signals NONEXISTENT-LOCAL-TIME with :DISAMBIGUATION :STRICT"
    (signals nonexistent-local-time
      (resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) *new-york* :disambiguation :strict)))

  (it "RESOLVE-LOCAL-DATE-TIME with the :COMPATIBLE default resolves to the post-gap (EDT) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) *new-york*))
            :to-be -14400))

  (it "RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION :EARLIER resolves to the pre-gap (EST) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 3 10 2 30 0) *new-york* :disambiguation :earlier))
            :to-be -18000)))

(describe "resolving a wall-clock LOCAL-DATE-TIME: the DST fall-back overlap"
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  ;; 2024-11-03 America/New_York: clocks fall back from 02:00 EDT to 01:00
  ;; EST, so 01:00-01:59:59 happens twice.
  (it "POSSIBLE-OFFSETS-FOR-LOCAL-DATE-TIME returns the earlier (EDT) offset first, then the later (EST) one"
    (expect (mapcar #'zone-offset-total-seconds
                     (possible-offsets-for-local-date-time (local-date-time-of 2024 11 3 1 30 0) *new-york*))
            :to-equal '(-14400 -18000)))

  (it "RESOLVE-LOCAL-DATE-TIME signals AMBIGUOUS-LOCAL-TIME with :DISAMBIGUATION :STRICT"
    (signals ambiguous-local-time
      (resolve-local-date-time (local-date-time-of 2024 11 3 1 30 0) *new-york* :disambiguation :strict)))

  (it "RESOLVE-LOCAL-DATE-TIME with the :COMPATIBLE default resolves to the earlier (EDT) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 11 3 1 30 0) *new-york*))
            :to-be -14400))

  (it "RESOLVE-LOCAL-DATE-TIME with :DISAMBIGUATION :LATER resolves to the later (EST) offset"
    (expect (zone-offset-total-seconds (resolve-local-date-time (local-date-time-of 2024 11 3 1 30 0) *new-york* :disambiguation :later))
            :to-be -18000))

  (it-each
      ((2024 6 15 12 0 0)
       (2024 11 3 1 30 0)
       (2024 3 10 2 30 0))
      "RESOLVE-LOCAL-DATE-TIME rejects :INVALID disambiguation for ~A-~A-~A ~A:~A:~A"
      (year month day hour minute second)
    (signals type-error
      (resolve-local-date-time
        (local-date-time-of year month day hour minute second)
        *new-york*
        :disambiguation :invalid))))

(describe
  "future TZif footer transition classification"
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  (it
    "resolves a 2100 New York summer local time to the footer daylight offset"
    (let ((ny *new-york*))
      (expect
        (mapcar
          #'zone-offset-total-seconds
          (possible-offsets-for-local-date-time (local-date-time-of 2100 7 1 12 0 0) ny))
        :to-equal
        '(-14400))))
  (it
    "recognizes the 2100 New York spring gap beyond the explicit table"
    (let ((ny *new-york*))
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
    (let ((ny *new-york*))
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
          :strict)))))

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
      '(-14400))))

(describe
  "ZONE-TRANSITION queries"
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  (it
    "returns New York 2024 transitions for local gaps and overlaps"
    (let* ((ny *new-york*)
           (spring
          (local-date-time-zone-transition (local-date-time-of 2024 3 10 2 30 0) ny))
           (fall
          (local-date-time-zone-transition (local-date-time-of 2024 11 3 1 30 0) ny))
           (spring-instant
          (local-date-time-to-instant
            (local-date-time-of 2024 3 10 7 0 0)
            (zone-offset-utc)))
           (fall-instant
          (local-date-time-to-instant
            (local-date-time-of 2024 11 3 6 0 0)
            (zone-offset-utc))))
      (expect (zone-transition-p spring) :to-be-truthy)
      (expect
        (instant= (zone-transition-instant spring) spring-instant)
        :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-before spring))
        :to-be
        -18000)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-after spring))
        :to-be
        -14400)
      (expect (zone-transition-gap-p spring) :to-be-truthy)
      (expect (duration-seconds (zone-transition-duration spring)) :to-be 3600)
      (expect
        (local-date-time=
          (zone-transition-date-time-before spring)
          (local-date-time-of 2024 3 10 2 0 0))
        :to-be-truthy)
      (expect
        (local-date-time=
          (zone-transition-date-time-after spring)
          (local-date-time-of 2024 3 10 3 0 0))
        :to-be-truthy)
      (expect (zone-transition-p fall) :to-be-truthy)
      (expect (instant= (zone-transition-instant fall) fall-instant) :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-before fall))
        :to-be
        -14400)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-after fall))
        :to-be
        -18000)
      (expect (zone-transition-overlap-p fall) :to-be-truthy)
      (expect (duration-seconds (zone-transition-duration fall)) :to-be -3600)
      (expect
        (local-date-time=
          (zone-transition-date-time-before fall)
          (local-date-time-of 2024 11 3 2 0 0))
        :to-be-truthy)
      (expect
        (local-date-time=
          (zone-transition-date-time-after fall)
          (local-date-time-of 2024 11 3 1 0 0))
        :to-be-truthy)))
  (it
    "returns NIL for normal local times and fixed offsets"
    (let ((ny *new-york*))
      (expect
        (local-date-time-zone-transition (local-date-time-of 2024 6 15 12 0 0) ny)
        :to-be
        nil)
      (expect
        (local-date-time-zone-transition
          (local-date-time-of 2024 3 10 2 30 0)
          (zone-offset-utc))
        :to-be
        nil)))
  (it
    "uses the POSIX footer for the 2100 New York spring gap"
    (let* ((ny *new-york*)
           (transition
          (local-date-time-zone-transition (local-date-time-of 2100 3 14 2 30 0) ny))
           (instant
          (local-date-time-to-instant
            (local-date-time-of 2100 3 14 7 0 0)
            (zone-offset-utc))))
      (expect (zone-transition-p transition) :to-be-truthy)
      (expect (instant= (zone-transition-instant transition) instant) :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-before transition))
        :to-be
        -18000)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-after transition))
        :to-be
        -14400)
      (expect (zone-transition-gap-p transition) :to-be-truthy)))
  (it
    "reports New York\x27s 2024 gap and overlap with strict instant boundaries"
    (let* ((ny *new-york*)
           (spring
          (local-date-time-to-instant
            (local-date-time-of 2024 3 10 7 0 0)
            (zone-offset-utc)))
           (fall
          (local-date-time-to-instant
            (local-date-time-of 2024 11 3 6 0 0)
            (zone-offset-utc)))
           (next
          (next-zone-transition ny (make-instant (1- (instant-epoch-second spring)))))
           (previous
          (previous-zone-transition ny (make-instant (instant-epoch-second spring) 1))))
      (expect (zone-transition-p next) :to-be-truthy)
      (expect (instant= (zone-transition-instant next) spring) :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-before next))
        :to-be
        -18000)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-after next))
        :to-be
        -14400)
      (expect (zone-transition-gap-p next) :to-be-truthy)
      (expect (zone-transition-overlap-p next) :to-be-falsy)
      (expect (instant= (zone-transition-instant previous) spring) :to-be-truthy)
      (expect
        (instant= (zone-transition-instant (next-zone-transition ny spring)) fall)
        :to-be-truthy)
      (expect
        (zone-transition-overlap-p (next-zone-transition ny spring))
        :to-be-truthy)))
  (it
    "uses the POSIX footer for future next and previous transitions"
    (let* ((ny *new-york*)
           (start
          (local-date-time-to-instant
            (local-date-time-of 2100 1 1 0 0 0)
            (zone-offset-utc)))
           (summer
          (local-date-time-to-instant
            (local-date-time-of 2100 7 1 0 0 0)
            (zone-offset-utc)))
           (spring
          (local-date-time-to-instant
            (local-date-time-of 2100 3 14 7 0 0)
            (zone-offset-utc)))
           (next (next-zone-transition ny start))
           (previous (previous-zone-transition ny summer)))
      (expect (instant= (zone-transition-instant next) spring) :to-be-truthy)
      (expect (instant= (zone-transition-instant previous) spring) :to-be-truthy)
      (expect (zone-transition-gap-p next) :to-be-truthy)))
  (it
    "returns NIL for fixed-offset zones"
    (let ((utc (zone-offset-utc)))
      (expect (next-zone-transition utc (make-instant 0)) :to-be nil)
      (expect (previous-zone-transition utc (make-instant 0)) :to-be nil)))
  (it
    "falls back to the POSIX footer when no real explicit transition precedes the instant"
    (let* ((same-offset-type (cl-date-kit::make-tzif-type :utc-offset -18000 :dst-p nil))
           (data
          (cl-date-kit::make-tzif-data
            :transition-times
            #(0)
            :transition-types
            (vector same-offset-type)
            :initial-type
            same-offset-type
            :abbreviation-table
            ""
            :posix-tz-string
            "EST5EDT,M3.2.0,M11.1.0"))
           (rule
          (cl-date-kit::parse-posix-tz-string
            "EST5EDT,M3.2.0,M11.1.0"
            "synthetic no-op explicit table"))
           (zone (cl-date-kit::%make-time-zone "Synthetic/NoOpTable" data rule))
           (query
          (local-date-time-to-instant (local-date-time-of 2024 7 15 12 0 0) (zone-offset-utc)))
           (spring
          (local-date-time-to-instant (local-date-time-of 2024 3 10 7 0 0) (zone-offset-utc)))
           (transition (previous-zone-transition zone query)))
      (expect (zone-transition-p transition) :to-be-truthy)
      (expect (instant= (zone-transition-instant transition) spring) :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-before transition))
        :to-be
        -18000)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-after transition))
        :to-be
        -14400))))

(describe
  "TIME-ZONE-TRANSITIONS-BETWEEN"
  (before-each (setf *new-york* (find-time-zone "America/New_York")))
  (it
    "returns ordered New York 2024 DST transitions"
    (let* ((ny *new-york*)
           (start
          (local-date-time-to-instant
            (local-date-time-of 2024 1 1 0 0 0)
            (zone-offset-utc)))
           (end
          (local-date-time-to-instant
            (local-date-time-of 2025 1 1 0 0 0)
            (zone-offset-utc)))
           (spring
          (local-date-time-to-instant
            (local-date-time-of 2024 3 10 7 0 0)
            (zone-offset-utc)))
           (fall
          (local-date-time-to-instant
            (local-date-time-of 2024 11 3 6 0 0)
            (zone-offset-utc)))
           (transitions (time-zone-transitions-between ny start end)))
      (expect (length transitions) :to-be 2)
      (expect
        (instant= (zone-transition-instant (first transitions)) spring)
        :to-be-truthy)
      (expect
        (instant= (zone-transition-instant (second transitions)) fall)
        :to-be-truthy)
      (expect (mapcar #'zone-transition-gap-p transitions) :to-equal '(t nil))))
  (it
    "uses a half-open range with exact and nanosecond boundaries"
    (let* ((ny *new-york*)
           (spring
          (local-date-time-to-instant
            (local-date-time-of 2024 3 10 7 0 0)
            (zone-offset-utc)))
           (fall
          (local-date-time-to-instant
            (local-date-time-of 2024 11 3 6 0 0)
            (zone-offset-utc)))
           (at-start (time-zone-transitions-between ny spring fall))
           (before-end
          (time-zone-transitions-between
            ny
            (make-instant (1- (instant-epoch-second spring)))
            spring))
           (after-start
          (time-zone-transitions-between
            ny
            (make-instant (instant-epoch-second spring) 1)
            fall)))
      (expect (length at-start) :to-be 1)
      (expect
        (instant= (zone-transition-instant (first at-start)) spring)
        :to-be-truthy)
      (expect before-end :to-be nil)
      (expect after-start :to-be nil)))
  (it
    "returns NIL for fixed-offset and no-DST zones"
    (let ((start
          (local-date-time-to-instant
            (local-date-time-of 2024 1 1 0 0 0)
            (zone-offset-utc)))
          (end
          (local-date-time-to-instant
            (local-date-time-of 2025 1 1 0 0 0)
            (zone-offset-utc))))
      (expect (time-zone-transitions-between (zone-offset-utc) start end) :to-be nil)
      (expect
        (time-zone-transitions-between (find-time-zone "Asia/Tokyo") start end)
        :to-be
        nil)))
  (it
    "validates zones and non-empty interval endpoints"
    (let ((start (make-instant 0))
          (end (make-instant 1)))
      (signals type-error (time-zone-transitions-between 0 start end))
      (signals type-error (time-zone-transitions-between (zone-offset-utc) 0 end))
      (signals type-error (time-zone-transitions-between (zone-offset-utc) start 0))
      (signals
        invalid-interval
        (time-zone-transitions-between (zone-offset-utc) start start))
      (signals
        invalid-interval
        (time-zone-transitions-between (zone-offset-utc) end start))))
  (it
    "uses the POSIX footer after explicit TZif transitions"
    (let* ((ny *new-york*)
           (start
          (local-date-time-to-instant
            (local-date-time-of 2100 1 1 0 0 0)
            (zone-offset-utc)))
           (end
          (local-date-time-to-instant
            (local-date-time-of 2101 1 1 0 0 0)
            (zone-offset-utc)))
           (spring
          (local-date-time-to-instant
            (local-date-time-of 2100 3 14 7 0 0)
            (zone-offset-utc)))
           (fall
          (local-date-time-to-instant
            (local-date-time-of 2100 11 7 6 0 0)
            (zone-offset-utc)))
           (transitions (time-zone-transitions-between ny start end)))
      (expect (length transitions) :to-be 2)
      (expect
        (instant= (zone-transition-instant (first transitions)) spring)
        :to-be-truthy)
      (expect
        (instant= (zone-transition-instant (second transitions)) fall)
        :to-be-truthy))))

(describe
  "bounded explicit TZif local-time lookup"
  (it
    "finds a transition across the zone maximum offset window"
    (let* ((before-type (cl-date-kit::make-tzif-type :utc-offset -43200 :dst-p nil))
           (after-type (cl-date-kit::make-tzif-type :utc-offset 43200 :dst-p nil))
           (data
          (cl-date-kit::make-tzif-data
            :transition-times
            #(0)
            :transition-types
            (vector after-type)
            :initial-type
            before-type
            :abbreviation-table
            ""
            :posix-tz-string
            nil))
           (zone (cl-date-kit::%make-time-zone "Synthetic/Dateline" data nil))
           (local-date-time (local-date-time-of 1970 1 1 0 0 0))
           (transition (local-date-time-zone-transition local-date-time zone)))
      (expect
        (possible-offsets-for-local-date-time local-date-time zone)
        :to-equal
        (quote ()))
      (expect (zone-transition-p transition) :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-before transition))
        :to-be
        -43200)
      (expect
        (zone-offset-total-seconds (zone-transition-offset-after transition))
        :to-be
        43200)
      (expect (zone-transition-gap-p transition) :to-be-truthy))))