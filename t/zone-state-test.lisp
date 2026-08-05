;;;; t/zone-state-test.lisp
;;;;
;;;; Projecting an instant into local wall-clock components and zone state
;;;; (ZONE-STATE-FOR-INSTANT, LOCAL-DATE-OF-INSTANT, LOCAL-TIME-OF-INSTANT),
;;;; plus the internal lookup-reuse optimizations around
;;;; RESOLVE-LOCAL-DATE-TIME. These tests read the real IANA time zone
;;;; database from TZDIR or /usr/share/zoneinfo.
(in-package #:cl-date-kit/test)

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
    "returns the initial TZif type's state when the transition table is empty and there is no POSIX rule"
    (let* ((initial-type
          (cl-date-kit::make-tzif-type :utc-offset 7200 :dst-p nil :abbreviation-index 0))
           (data
          (cl-date-kit::make-tzif-data
            :transition-times
            #()
            :transition-types
            #()
            :initial-type
            initial-type
            :abbreviation-table
            (coerce (list #\X #\Y #\Z #\Null) 'string)
            :posix-tz-string
            nil))
           (zone (cl-date-kit::%make-time-zone "Synthetic/NoRule" data nil))
           (state (zone-state-for-instant zone (make-instant 0))))
      (expect (zone-offset-total-seconds (zone-state-offset state)) :to-be 7200)
      (expect (zone-state-abbreviation state) :to-equal "XYZ")
      (expect (zone-state-daylight-saving-p state) :to-be-falsy)))
  (it
    "returns a NIL abbreviation when the abbreviation index is at or beyond the abbreviation table's length"
    (let* ((type
          (cl-date-kit::make-tzif-type :utc-offset 3600 :dst-p nil :abbreviation-index 10))
           (data
          (cl-date-kit::make-tzif-data
            :transition-times
            #()
            :transition-types
            #()
            :initial-type
            type
            :abbreviation-table
            "ABC"
            :posix-tz-string
            nil))
           (state (cl-date-kit::%tzif-type->state data type)))
      (expect (zone-offset-total-seconds (zone-state-offset state)) :to-be 3600)
      (expect (zone-state-abbreviation state) :to-be nil)))
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
        (setf (symbol-function (quote cl-date-kit::%time-zone-type-for-instant)) original)))))