;;;; t/posix-tz-test.lisp
;;;;
;;;; Low-level TZif binary block/file parsing and validation, and POSIX-TZ
;;;; footer string parsing/projection. These tests operate on synthetic
;;;; byte blocks and POSIX-TZ strings, not the real IANA time zone database.
(in-package #:cl-date-kit/test)

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
          "invalid-indicators")))
    (it-each
        ((0) (257))
        "rejects a type count of ~A outside 1-256"
        (typecnt)
      (signals
        malformed-tzif
        (cl-date-kit::%parse-tzif-block
          #()
          0
          (cl-date-kit::make-%tzif-header :typecnt typecnt)
          4
          "invalid-typecnt")))
    (it
      "falls back to the first type when every type is DST"
      (let ((bytes #(0 0 0 0 0 0 0 14 16 1 0 68 83 84 0))
            (header
            (cl-date-kit::make-%tzif-header
              :timecnt
              1
              :typecnt
              1
              :charcnt
              4
              :isstdcnt
              0
              :isutcnt
              0)))
        (multiple-value-bind (times transition-types initial-type) (cl-date-kit::%parse-tzif-block bytes 0 header 4 "all-dst")
          (declare (ignore times transition-types))
          (expect (cl-date-kit::tzif-type-utc-offset initial-type) :to-be 3600)
          (expect (cl-date-kit::tzif-type-dst-p initial-type) :to-be-truthy)))))
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
            #(88)))))
    (it
      "rejects a file that exceeds the maximum supported size"
      (signals
        malformed-tzif
        (%parse-synthetic-tzif-file
          (make-array
            (1+ cl-date-kit::+maximum-tzif-file-size+)
            :element-type
            (quote (unsigned-byte 8))
            :initial-element
            0))))
    (it
      "parses a version-0 file without reading a POSIX footer"
      (let* ((header (%make-tzif-header-bytes 0 1 1 4))
             (block-bytes #(0 0 0 0 0 0 0 14 16 1 0 68 83 84 0))
             (data (%parse-synthetic-tzif-file (%concatenate-tzif-octets header block-bytes))))
        (expect (cl-date-kit::tzif-data-posix-tz-string data) :to-be nil)
        (expect
          (cl-date-kit::tzif-type-utc-offset (cl-date-kit::tzif-data-initial-type data))
          :to-be
          3600)))))

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
    (it-each
        (("u") ("g") ("z"))
        "uses UTC for the ~A suffix"
        (suffix)
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
          -14400)))
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
  (it-each
      (("")
       ("EST")
       ("EST5:99")
       ("<EST5")
       ("EST5EDT")
       ("EST5EDT,M3.2.0/2")
       ("EST5EDT,M3.2.x/2,M11.1.0/2")
       ("EST5EDT,M3.2.0/2,M11.1.0/2/extra")
       ("EST5EDT,M3.2.0/2,M11.1.0/2,ignored")
       (",EST5,M3.2.0/2")
       ("5")
       ("AB5")
       ("EST+")
       ("EST5:6:7:8")
       ("EST5,M3.2.0/2,M11.1.0/2")
       ("EST5EDT6x,M3.2.0/2,M11.1.0/2")
       ("EST5EDT,M3.2.0/x,M11.1.0/2")
       ("EST5EDT,M3.2.0/200,M11.1.0/2")
       ("EST5EDT,M3.2.0/2wx,M11.1.0/2")
       ("EST5EDT,M3.2.0/,M11.1.0/2")
       ("EST5EDT,M3.2/2,M11.1.0/2")
       ("EST5EDT,M13.2.0/2,M11.1.0/2")
       ("EST5EDT,J366/2,M11.1.0/2")
       ("EST5EDT,366/2,M11.1.0/2"))
      "normalizes ~S to MALFORMED-TZIF"
      (footer)
    (signals
      malformed-tzif
      (cl-date-kit::parse-posix-tz-string footer "invalid-footer")))
  (it
    "accepts bracketed POSIX abbreviations with signed names"
    (let ((rule (cl-date-kit::parse-posix-tz-string "<+03>-3" "bracketed-footer")))
      (expect (cl-date-kit::posix-tz-rule-std-utc-offset rule) :to-be 10800)))
  (it
    "parses an hour:minute:second UTC offset"
    (let ((rule (cl-date-kit::parse-posix-tz-string "EST5:30:15")))
      (expect (cl-date-kit::posix-tz-rule-std-utc-offset rule) :to-be -19815)))
  (it
    "rejects an empty transition time reached directly"
    (signals
      malformed-tzif
      (cl-date-kit::%parse-posix-rule-time
        ""
        (lambda (seconds mode) (declare (ignore seconds mode)))
        (lambda (control &rest arguments)
          (error
            (quote malformed-tzif)
            :path
            "direct-empty-transition-time"
            :reason
            (apply (function format) nil control arguments)))))))

(describe
  "POSIX TZ transition time precision"
  (it
    "honors a minute component in a transition time"
    (let* ((rule (cl-date-kit::parse-posix-tz-string "EST5EDT,M3.2.0/2:30,M11.1.0/2"))
           (start
          (cl-date-kit::%posix-transition-instant
            2024
            (cl-date-kit::posix-tz-rule-dst-start rule)
            (cl-date-kit::posix-tz-rule-std-utc-offset rule)
            (cl-date-kit::posix-tz-rule-std-utc-offset rule))))
      (expect (cl-date-kit::%offset-from-posix-rule (1- start) rule) :to-be -18000)
      (expect (cl-date-kit::%offset-from-posix-rule start rule) :to-be -14400)))
  (it
    "honors a second component in a transition time"
    (let* ((rule (cl-date-kit::parse-posix-tz-string "EST5EDT,M3.2.0/2:30:45,M11.1.0/2"))
           (start
          (cl-date-kit::%posix-transition-instant
            2024
            (cl-date-kit::posix-tz-rule-dst-start rule)
            (cl-date-kit::posix-tz-rule-std-utc-offset rule)
            (cl-date-kit::posix-tz-rule-std-utc-offset rule))))
      (expect (cl-date-kit::%offset-from-posix-rule (1- start) rule) :to-be -18000)
      (expect (cl-date-kit::%offset-from-posix-rule start rule) :to-be -14400)))
  (it
    "treats an explicit w suffix the same as the default wall-clock basis"
    (let* ((explicit (cl-date-kit::parse-posix-tz-string "EST5EDT,M3.2.0/2w,M11.1.0/2w"))
           (default (cl-date-kit::parse-posix-tz-string "EST5EDT,M3.2.0/2,M11.1.0/2"))
           (explicit-start
          (cl-date-kit::%posix-transition-instant
            2024
            (cl-date-kit::posix-tz-rule-dst-start explicit)
            (cl-date-kit::posix-tz-rule-std-utc-offset explicit)
            (cl-date-kit::posix-tz-rule-std-utc-offset explicit)))
           (default-start
          (cl-date-kit::%posix-transition-instant
            2024
            (cl-date-kit::posix-tz-rule-dst-start default)
            (cl-date-kit::posix-tz-rule-std-utc-offset default)
            (cl-date-kit::posix-tz-rule-std-utc-offset default))))
      (expect explicit-start :to-be default-start)
      (expect (cl-date-kit::%offset-from-posix-rule (1- explicit-start) explicit) :to-be -18000)
      (expect (cl-date-kit::%offset-from-posix-rule explicit-start explicit) :to-be -14400))))

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
  (it-each
      ((4) (8))
      "parses ~A-bit transitions, initial type, indicators, and abbreviations"
      (time-width)
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
              "STD")))))))