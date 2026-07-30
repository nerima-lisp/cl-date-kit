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
  "AVAILABLE-TIME-ZONE-NAMES"
  (it
    "returns sorted, non-empty, duplicate-free names"
    (let ((names (cl-date-kit:available-time-zone-names)))
      (expect names :to-be-truthy)
      (expect
        (every
          (lambda (name)
            (and (stringp name) (plusp (length name))))
          names)
        :to-be-truthy)
      (expect names :to-equal (sort (copy-list names) (function string<)))
      (expect
        (length names)
        :to-be
        (length (remove-duplicates names :test (function string=))))))
  (it
    "resolves representative time zone names"
    (dolist (name (list "UTC" "Asia/Tokyo" "America/New_York"))
      (expect (time-zone-p (find-time-zone name)) :to-be-truthy)))
  (it
    "returns a fresh list after a cached lookup"
    (let* ((first-result (cl-date-kit:available-time-zone-names))
           (first-name (car first-result))
           (second-result (cl-date-kit:available-time-zone-names)))
      (setf (car first-result) "Synthetic/Mutated")
      (expect (eq first-result second-result) :to-be-falsy)
      (expect (car second-result) :to-equal first-name)))
  (it
    "uses the TZDIR environment root when one is configured"
    (let ((tzdir (sb-ext:posix-getenv "TZDIR")))
      (when (and tzdir (plusp (length tzdir)))
        (expect
          (cl-date-kit:available-time-zone-names :tzdir tzdir)
          :to-equal
          (cl-date-kit:available-time-zone-names))))))

(defun %call-with-temporary-tzdir (function)
  (let ((directory
        (merge-pathnames
          (format
            nil
            "cl-date-kit-tzdir-~36R-~36R/"
            (get-universal-time)
            (random most-positive-fixnum))
          #P"/tmp/")))
    (ensure-directories-exist directory)
    (unwind-protect (funcall function directory)
      (ignore-errors (delete-file (merge-pathnames #P"+VERSION" directory)))
      (ignore-errors (delete-file (merge-pathnames #P"tzdata.zi" directory)))
      (ignore-errors (sb-ext:delete-directory directory)))))

(defun %write-temporary-tzdir-file (directory name content)
  (with-open-file (stream
      (merge-pathnames name directory)
      :direction
      :output
      :if-exists
      :supersede)
    (write-string content stream)))

(describe
  "TIME-ZONE-DATABASE-VERSION"
  (it
    "trims whitespace around the +VERSION release"
    (%call-with-temporary-tzdir
      (lambda (tzdir)
        (%write-temporary-tzdir-file
          tzdir
          #P"+VERSION"
          (format nil " ~C2025b~C~%" #\Tab #\Return))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-equal "2025b"))))
  (it
    "falls back to tzdata.zi when +VERSION is absent or invalid"
    (%call-with-temporary-tzdir
      (lambda (tzdir)
        (%write-temporary-tzdir-file
          tzdir
          #P"tzdata.zi"
          (format nil "# version 2025b~%"))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-equal "2025b")
        (%write-temporary-tzdir-file tzdir #P"+VERSION" (format nil "not-a-release~%"))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-equal "2025b"))))
  (it
    "returns NIL when neither version source is valid"
    (%call-with-temporary-tzdir
      (lambda (tzdir)
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-be nil)
        (%write-temporary-tzdir-file tzdir #P"+VERSION" (format nil "not-a-release~%"))
        (%write-temporary-tzdir-file
          tzdir
          #P"tzdata.zi"
          (format nil "# version invalid~%"))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-be nil)))))

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
            :to-be -18000))

  (it "RESOLVE-LOCAL-DATE-TIME rejects invalid disambiguation consistently"
    (let ((zone (find-time-zone "America/New_York")))
      (dolist (local (list (local-date-time-of 2024 6 15 12 0 0)
                           (local-date-time-of 2024 11 3 1 30 0)
                           (local-date-time-of 2024 3 10 2 30 0)))
        (signals type-error
          (resolve-local-date-time local zone :disambiguation :invalid))))))

(describe
  "future TZif footer transition classification"
  (it
    "resolves a 2100 New York summer local time to the footer daylight offset"
    (let ((ny (find-time-zone "America/New_York")))
      (expect
        (mapcar
          #'zone-offset-total-seconds
          (possible-offsets-for-local-date-time (local-date-time-of 2100 7 1 12 0 0) ny))
        :to-equal
        '(-14400))))
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
          :strict)))))

(progn
  (describe
    "TZif block validation"
    (it
      "rejects a truncated block before field access"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #()
          0
          (cl-date-kit::make-%tzif-header :typecnt 1 :charcnt 1)
          4
          "truncated-block")))
    (it
      "rejects an excessive transition count before allocation"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #()
          0
          (cl-date-kit::make-%tzif-header
            :timecnt
            (1+ cl-date-kit::+maximum-tzif-time-count+)
            :typecnt
            1)
          4
          "excessive-timecnt")))
    (it
      "rejects an excessive leap-second count before allocation"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #()
          0
          (cl-date-kit::make-%tzif-header
            :leapcnt
            (1+ cl-date-kit::+maximum-tzif-leap-count+)
            :typecnt
            1)
          4
          "excessive-leapcnt")))
    (it
      "rejects excessive abbreviation bytes before allocation"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #()
          0
          (cl-date-kit::make-%tzif-header
            :charcnt
            (1+ cl-date-kit::+maximum-tzif-character-count+)
            :typecnt
            1)
          4
          "excessive-charcnt")))
    (it
      "rejects a transition type index outside the type table"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #(0 0 0 0 1 0 0 0 0 0 0)
          0
          (cl-date-kit::make-%tzif-header :timecnt 1 :typecnt 1)
          4
          "invalid-type-index")))
    (it
      "rejects non-monotonic transition times"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #(0 0 0 2 0 0 0 1 0 0 0 0 0 0 0 0)
          0
          (cl-date-kit::make-%tzif-header :timecnt 2 :typecnt 1)
          4
          "unordered-transitions")))
    (it
      "rejects incompatible transition-indicator counts"
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #()
          0
          (cl-date-kit::make-%tzif-header :typecnt 1 :isstdcnt 2)
          4
          "invalid-indicators"))))
  (defun %make-tzif-header-bytes (version time-count type-count character-count)
    (let ((header
          (make-array 44 :element-type (quote (unsigned-byte 8)) :initial-element 0)))
      (replace header #(84 90 105 102))
      (setf (aref header 4) version)
      (flet ((write-u32 (offset value)
               (dotimes (index 4)
              (setf (aref header (+ offset index)) (ldb (byte 8 (* 8 (- 3 index))) value)))))
        (write-u32 32 time-count)
        (write-u32 36 type-count)
        (write-u32 40 character-count))
      header))
  (defun %concatenate-tzif-octets (&rest parts)
    (apply (function concatenate) (quote (vector (unsigned-byte 8))) parts))
  (defun %parse-synthetic-tzif-file (bytes)
    (let ((path
          (make-pathname
            :name
            (format
              nil
              "cl-date-kit-tzif-~36R-~36R"
              (get-universal-time)
              (random most-positive-fixnum))
            :type
            "tzif"
            :defaults
            #P"/tmp/")))
      (unwind-protect (progn
          (with-open-file (stream
              path
              :direction
              :output
              :if-exists
              :error
              :element-type
              (quote (unsigned-byte 8)))
            (write-sequence bytes stream))
          (cl-date-kit::parse-tzif-file path))
        (ignore-errors (delete-file path)))))
  (describe
    "TZif file validation"
    (it
      "rejects an invalid magic number through the file parser"
      (signals malformed-tzif (%parse-synthetic-tzif-file #(66 90 105 102))))
    (it
      "rejects a header whose declared block is truncated"
      (signals
        malformed-tzif
        (%parse-synthetic-tzif-file (%make-tzif-header-bytes 0 0 1 1))))
    (it
      "rejects non-monotonic transition timestamps"
      (signals
        malformed-tzif
        (%parse-synthetic-tzif-file
          (%concatenate-tzif-octets
            (%make-tzif-header-bytes 0 2 1 1)
            #(0 0 0 2 0 0 0 1 0 0 0 0 0 0 0 0 0)))))
    (it
      "rejects a transition type index outside the declared type table"
      (signals
        malformed-tzif
        (%parse-synthetic-tzif-file
          (%concatenate-tzif-octets
            (%make-tzif-header-bytes 0 1 1 1)
            #(0 0 0 0 1 0 0 0 0 0 0 0)))))
    (it
      "rejects a type record with an invalid DST flag"
      (signals
        malformed-tzif
        (%parse-synthetic-tzif-file
          (%concatenate-tzif-octets
            (%make-tzif-header-bytes 0 1 1 1)
            #(0 0 0 0 0 0 0 0 0 2 0 0)))))
    (it
      "rejects an unterminated type abbreviation"
      (signals
        malformed-tzif
        (%parse-synthetic-tzif-file
          (%concatenate-tzif-octets (%make-tzif-header-bytes 0 0 1 1) #(0 0 0 0 0 0 65)))))
    (it
      "rejects a v2 file with a malformed POSIX footer"
      (signals
        malformed-tzif
        (%parse-synthetic-tzif-file
          (%concatenate-tzif-octets
            (%make-tzif-header-bytes 2 0 1 1)
            #(0 0 0 0 0 0 0)
            (%make-tzif-header-bytes 2 0 1 1)
            #(0 0 0 0 0 0 0)
            #(88)))))))

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
          3600))
      (let* ((rule (cl-date-kit::parse-posix-tz-string "STD0DST,M1.1.0/-167,M6.1.0/2"))
             (start
            (cl-date-kit::%posix-transition-instant
              2025
              (cl-date-kit::posix-tz-rule-dst-start rule)
              (cl-date-kit::posix-tz-rule-std-utc-offset rule)
              (cl-date-kit::posix-tz-rule-std-utc-offset rule))))
        (expect (cl-date-kit::%offset-from-posix-rule (1- start) rule) :to-be 0)
        (expect (cl-date-kit::%offset-from-posix-rule start rule) :to-be 3600)
        (expect
          (cl-date-kit::%offset-from-posix-rule (+ start (* 35 3600)) rule)
          :to-be
          3600))
      (let ((rule (cl-date-kit::parse-posix-tz-string "STD0DST,M12.5.0/167,M12.5.0/166")))
        (expect
          (cl-date-kit::%offset-from-posix-rule
            (* (local-date-to-epoch-day (make-local-date 2025 1 1)) 86400)
            rule)
          :to-be
          3600)))
    (progn
      (it
        "uses UTC for u, g, and z suffixes"
        (dolist (suffix (quote ("u" "g" "z")))
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
        "caches POSIX transitions by rule and year"
        (let* ((rule (cl-date-kit::parse-posix-tz-string "EST5EDT,M3.2.0,M11.1.0"))
               (first (cl-date-kit::%posix-transitions-for-year 2100 rule))
               (second (cl-date-kit::%posix-transitions-for-year 2100 rule)))
          (expect (eq first second) :to-be-truthy)
          (expect (length first) :to-be 2))))
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
        '(-14400)))))

(progn
  (describe
    "TZif POSIX footer framing and grammar"
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
        (cl-date-kit::%parse-posix-tz-string
          #(10 74 83 84 45 57 10 0)
          0
          "trailing-byte")))
    (it
      "normalizes malformed POSIX grammar to MALFORMED-TZIF"
      (dolist (footer
          (list
            ""
            "EST"
            "EST5:99"
            "<EST5"
            "EST5EDT"
            "EST5EDT,M3.2.0/2"
            "EST5EDT,M3.2.x/2,M11.1.0/2"
            "EST5EDT,M3.2.0/2,M11.1.0/2/extra"
            "EST5EDT,M3.2.0/2,M11.1.0/2,ignored"))
        (signals
          malformed-tzif
          (cl-date-kit::parse-posix-tz-string footer "invalid-footer"))))
    (it
      "accepts bracketed POSIX abbreviations with signed names"
      (let ((rule (cl-date-kit::parse-posix-tz-string "<+03>-3" "bracketed-footer")))
        (expect (cl-date-kit::posix-tz-rule-std-utc-offset rule) :to-be 10800))))
  (describe
    "ZONE-TRANSITION queries"
    (it
      "returns New York 2024 transitions for local gaps and overlaps"
      (let* ((ny (find-time-zone "America/New_York"))
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
      (let ((ny (find-time-zone "America/New_York")))
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
      (let* ((ny (find-time-zone "America/New_York"))
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
      (let* ((ny (find-time-zone "America/New_York"))
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
      (let* ((ny (find-time-zone "America/New_York"))
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
        (expect (previous-zone-transition utc (make-instant 0)) :to-be nil)))))

(describe
  "TIME-ZONE-TRANSITIONS-BETWEEN"
  (it
    "returns ordered New York 2024 DST transitions"
    (let* ((ny (find-time-zone "America/New_York"))
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
    (let* ((ny (find-time-zone "America/New_York"))
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
    (let* ((ny (find-time-zone "America/New_York"))
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

(progn
  (it
    "projects components without constructing an intermediate local date-time"
    (let ((original (symbol-function 'cl-date-kit:local-date-time-of-instant))
          (calls 0)
          (instant (make-instant 1710054000 987654321))
          (zone (find-time-zone "America/New_York")))
      (unwind-protect (progn
          (setf (symbol-function 'cl-date-kit:local-date-time-of-instant) (lambda (&rest arguments)
              (incf calls)
              (apply original arguments)))
          (expect
            (local-date= (local-date-of-instant instant zone) (make-local-date 2024 3 10))
            :to-be-truthy)
          (expect
            (local-time=
              (local-time-of-instant instant zone)
              (make-local-time 3 0 0 987654321))
            :to-be-truthy)
          (expect calls :to-be 0))
        (setf (symbol-function 'cl-date-kit:local-date-time-of-instant) original))))
  (it
    "projects New York instants across the 2024 DST spring-forward boundary"
    (let* ((new-york (find-time-zone "America/New_York"))
           (before (make-instant 1710053999 123456789))
           (after (make-instant 1710054000 987654321)))
      (expect
        (local-date-time=
          (local-date-time-of-instant before new-york)
          (local-date-time-of 2024 3 10 1 59 59 123456789))
        :to-be-truthy)
      (expect
        (local-date-time=
          (local-date-time-of-instant after new-york)
          (local-date-time-of 2024 3 10 3 0 0 987654321))
        :to-be-truthy)
      (expect
        (local-date=
          (local-date-of-instant before new-york)
          (make-local-date 2024 3 10))
        :to-be-truthy)
      (expect
        (local-date= (local-date-of-instant after new-york) (make-local-date 2024 3 10))
        :to-be-truthy)
      (expect
        (local-time=
          (local-time-of-instant before new-york)
          (make-local-time 1 59 59 123456789))
        :to-be-truthy)
      (expect
        (local-time=
          (local-time-of-instant after new-york)
          (make-local-time 3 0 0 987654321))
        :to-be-truthy))))

(describe
  "ZONE-STATE-FOR-INSTANT"
  (it
    "reports New York standard and daylight states at exact transition boundaries"
    (let* ((ny (find-time-zone "America/New_York"))
           (winter
          (zone-state-for-instant
            ny
            (local-date-time-to-instant
              (local-date-time-of 2024 1 15 12 0 0)
              (zone-offset-utc))))
           (summer
          (zone-state-for-instant
            ny
            (local-date-time-to-instant
              (local-date-time-of 2024 7 15 12 0 0)
              (zone-offset-utc))))
           (before (zone-state-for-instant ny (make-instant 1710053999)))
           (at (zone-state-for-instant ny (make-instant 1710054000))))
      (expect (zone-offset-total-seconds (zone-state-offset winter)) :to-be -18000)
      (expect (zone-state-abbreviation winter) :to-equal "EST")
      (expect (zone-state-daylight-saving-p winter) :to-be-falsy)
      (expect (zone-offset-total-seconds (zone-state-offset summer)) :to-be -14400)
      (expect (zone-state-abbreviation summer) :to-equal "EDT")
      (expect (zone-state-daylight-saving-p summer) :to-be-truthy)
      (expect (zone-state-abbreviation before) :to-equal "EST")
      (expect (zone-state-abbreviation at) :to-equal "EDT")))
  (it
    "returns a metadata-free state for fixed offsets and preserves offset equivalence"
    (let* ((offset (zone-offset-of-hours 9))
           (instant (make-instant 0))
           (state (zone-state-for-instant offset instant)))
      (expect
        (zone-offset= (zone-state-offset state) (offset-for-instant offset instant))
        :to-be-truthy)
      (expect (zone-state-abbreviation state) :to-be nil)
      (expect (zone-state-daylight-saving-p state) :to-be-falsy)))
  (it
    "uses footer POSIX names, including bracketed abbreviations"
    (let* ((type
          (cl-date-kit::make-tzif-type :utc-offset 10800 :dst-p nil :abbreviation-index 0))
           (data
          (cl-date-kit::make-tzif-data
            :transition-times
            #()
            :transition-types
            #()
            :initial-type
            type
            :abbreviation-table
            "+03"
            :posix-tz-string
            "<+03>-3"))
           (rule (cl-date-kit::parse-posix-tz-string "<+03>-3" "test footer"))
           (zone (cl-date-kit::%make-time-zone "test" data rule))
           (state (zone-state-for-instant zone (make-instant 0))))
      (expect (zone-offset-total-seconds (zone-state-offset state)) :to-be 10800)
      (expect (zone-state-abbreviation state) :to-equal "+03")
      (expect (zone-state-daylight-saving-p state) :to-be-falsy)))
  (it
    "keeps offset-for-instant equivalent to the selected state through the POSIX footer"
    (let* ((ny (find-time-zone "America/New_York"))
           (instant
          (local-date-time-to-instant
            (local-date-time-of 2100 7 1 0 0 0)
            (zone-offset-utc))))
      (expect
        (zone-offset=
          (offset-for-instant ny instant)
          (zone-state-offset (zone-state-for-instant ny instant)))
        :to-be-truthy)
      (expect
        (zone-state-abbreviation (zone-state-for-instant ny instant))
        :to-equal
        "EDT")
      (expect
        (zone-state-daylight-saving-p (zone-state-for-instant ny instant))
        :to-be-truthy))))

(progn
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
  (describe
    "local time resolution lookup reuse"
    (it
      "avoids a TZif lookup after explicit transition classification"
      (let* ((zone (find-time-zone "America/New_York"))
             (local-date-time (local-date-time-of 2024 1 15 12 0 0))
             (original (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)))
             (calls 0))
        (unwind-protect (progn
            (setf (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)) (lambda (time-zone epoch)
                (incf calls)
                (funcall original time-zone epoch)))
            (expect
              (zone-offset-total-seconds (resolve-local-date-time local-date-time zone))
              :to-be
              -18000)
            (expect calls :to-equal 0))
          (setf (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)) original))))
    (it
      "retains the TZif lookup at the final explicit transition"
      (let* ((before-type (cl-date-kit::make-tzif-type :utc-offset 3600 :dst-p nil))
             (after-type (cl-date-kit::make-tzif-type :utc-offset 3600 :dst-p nil))
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
             (zone (cl-date-kit::%make-time-zone "Synthetic/Terminal" data nil))
             (local-date-time (local-date-time-of 1970 1 2 0 0 0))
             (original (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)))
             (calls 0))
        (unwind-protect (progn
            (setf (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)) (lambda (time-zone epoch)
                (incf calls)
                (funcall original time-zone epoch)))
            (expect
              (zone-offset-total-seconds (resolve-local-date-time local-date-time zone))
              :to-be
              3600)
            (expect calls :to-equal 1))
          (setf (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)) original))))
    (it
      "uses the POSIX footer when the TZif table has no transitions"
      (let* ((initial-type (cl-date-kit::make-tzif-type :utc-offset 10800 :dst-p nil))
             (data
            (cl-date-kit::make-tzif-data
              :transition-times
              #()
              :transition-types
              #()
              :initial-type
              initial-type
              :abbreviation-table
              ""
              :posix-tz-string
              "<+04>-4"))
             (rule (cl-date-kit::parse-posix-tz-string "<+04>-4" "synthetic footer"))
             (zone (cl-date-kit::%make-time-zone "Synthetic/Footer" data rule))
             (local-date-time (local-date-time-of 2100 1 2 0 0 0))
             (original (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)))
             (calls 0))
        (unwind-protect (progn
            (setf (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)) (lambda (time-zone epoch)
                (incf calls)
                (funcall original time-zone epoch)))
            (expect
              (zone-offset-total-seconds (resolve-local-date-time local-date-time zone))
              :to-be
              14400)
            (expect calls :to-equal 1))
          (setf (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)) original))))))

(defun %make-tzif-characterization-block (time-width)
  (let* ((times
        (if (= time-width 4) #(-1 100)
          #(-1 4294967296)))
         (bytes
        (make-array
          (+ (* 2 time-width) 2 12 8 4)
          :element-type
          '(unsigned-byte 8)
          :initial-element
          0))
         (position 0))
    (labels ((write-signed (value width)
               (dotimes (index width)
            (setf (aref bytes (+ position index)) (ldb (byte 8 (* 8 (- width index 1))) value)))
               (incf position width))
             (write-u8 (value)
               (setf (aref bytes position) value)
               (incf position)))
      (dolist (time (coerce times 'list))
        (write-signed time time-width))
      (write-u8 1)
      (write-u8 0)
      (write-signed 3600 4)
      (write-u8 0)
      (write-u8 0)
      (write-signed 7200 4)
      (write-u8 1)
      (write-u8 4)
      (dolist (octet '(83 84 68 0 68 83 84 0))
        (write-u8 octet))
      (write-u8 0)
      (write-u8 1)
      (write-u8 1)
      (write-u8 0))
    (values bytes times)))

(describe
  "TZif block characterization"
  (it
    "parses 32-bit and 64-bit transitions, initial type, indicators, and abbreviations"
    (dolist (time-width '(4 8))
      (multiple-value-bind (bytes expected-times) (%make-tzif-characterization-block time-width)
        (let ((header
              (cl-date-kit::make-%tzif-header
                :timecnt
                2
                :typecnt
                2
                :charcnt
                8
                :isstdcnt
                2
                :isutcnt
                2)))
          (multiple-value-bind (times transition-types initial-type abbreviations end) (cl-date-kit::%parse-tzif-block bytes 0 header time-width "synthetic")
            (expect (aref times 0) :to-be (aref expected-times 0))
            (expect (aref times 1) :to-be (aref expected-times 1))
            (expect end :to-be (length bytes))
            (expect (cl-date-kit::tzif-type-utc-offset initial-type) :to-be 3600)
            (expect (cl-date-kit::tzif-type-dst-p initial-type) :to-be-falsy)
            (expect abbreviations :to-equal (format nil "STD~CDST~C" #\Null #\Null))
            (let* ((data
                  (cl-date-kit::make-tzif-data
                    :transition-times
                    times
                    :transition-types
                    transition-types
                    :initial-type
                    initial-type
                    :abbreviation-table
                    abbreviations))
                   (zone (cl-date-kit::%make-time-zone "Synthetic/TZif" data nil))
                   (first-transition (aref times 0))
                   (second-transition (aref times 1)))
              (expect
                (zone-state-abbreviation
                  (zone-state-for-instant zone (make-instant (1- first-transition))))
                :to-equal
                "STD")
              (expect
                (zone-state-abbreviation
                  (zone-state-for-instant zone (make-instant first-transition)))
                :to-equal
                "DST")
              (expect
                (zone-state-abbreviation
                  (zone-state-for-instant zone (make-instant second-transition)))
                :to-equal
                "STD"))))))))
