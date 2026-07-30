;;;; t/rrule-set-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "RFC 5545 recurrence sets"
  (it
    "merges schedules and RDATEs, removes EXDATEs, and deduplicates instants"
    (let* ((utc (find-time-zone "UTC"))
           (new-york (find-time-zone "America/New_York"))
           (schedule (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;COUNT=3"))
           (rdate (zoned-date-time-of-local (rrule-test-local 2024 1 4) utc))
           (same-instant (zoned-date-time-of-local (rrule-test-local 2024 1 3 4) new-york))
           (exdate (zoned-date-time-of-local (rrule-test-local 2024 1 2) utc))
           (set
          (make-rrule-set
            :schedules
            (vector schedule)
            :rdates
            (vector rdate same-instant)
            :exdates
            (list exdate))))
      (expect
        (rrule-test-local-strings (rrule-set-occurrences set :max-periods 3))
        :to-equal
        (quote ("2024-01-01T09:00:00" "2024-01-03T09:00:00" "2024-01-04T09:00:00")))))
  (it
    "preserves the unbounded schedule limit and iteration early exit"
    (let ((set
          (make-rrule-set
            :schedules
            (list (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY")))))
      (signals invalid-rrule (rrule-set-occurrences set))
      (expect
        (rrule-test-local-strings (rrule-set-occurrences set :max-periods 2))
        :to-equal
        (quote ("2024-01-01T09:00:00" "2024-01-02T09:00:00")))
      (expect
        (let (seen)
          (map-rrule-set-occurrences
            (lambda (occurrence)
              (push (format-local-date-time (zoned-date-time-local occurrence)) seen)
              nil)
            set
            :max-periods
            2)
          (nreverse seen))
        :to-equal
        (quote ("2024-01-01T09:00:00")))))
  (it
    "keeps a stateful schedule source for early exit and complete iteration"
    (let* ((set
          (make-rrule-set
            :schedules
            (list (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY"))))
           (original-source (symbol-function 'cl-date-kit::%rrule-occurrence-source))
           (original-candidates (symbol-function 'cl-date-kit::%rrule-local-candidates))
           (supplied 0))
      (unwind-protect (progn
          (setf (symbol-function 'cl-date-kit::%rrule-occurrence-source) (lambda (schedule max-periods)
              (let ((source (funcall original-source schedule max-periods)))
                (lambda ()
                  (multiple-value-bind (occurrence present-p) (funcall source)
                    (when present-p
                      (incf supplied))
                    (values occurrence present-p))))))
          (map-rrule-set-occurrences
            (lambda (occurrence)
              (declare (ignore occurrence))
              nil)
            set
            :max-periods
            100)
          (expect supplied :to-equal 1)
          (setf (symbol-function 'cl-date-kit::%rrule-occurrence-source) original-source)
          (let ((periods 0))
            (setf (symbol-function 'cl-date-kit::%rrule-local-candidates) (lambda (anchor rule dtstart)
                (incf periods)
                (funcall original-candidates anchor rule dtstart)))
            (expect (length (rrule-set-occurrences set :max-periods 3)) :to-equal 3)
            (expect periods :to-equal 3)))
        (setf (symbol-function 'cl-date-kit::%rrule-occurrence-source) original-source)
        (setf (symbol-function 'cl-date-kit::%rrule-local-candidates) original-candidates))))
  (it
    "validates entries and the recurrence-period bound"
    (signals invalid-rrule (make-rrule-set :schedules #(invalid)))
    (signals invalid-rrule (make-rrule-set :rdates #(invalid)))
    (signals invalid-rrule (make-rrule-set :exdates #(invalid)))
    (signals invalid-rrule (rrule-set-occurrences (make-rrule-set) :max-periods 0)))
  (it
    "rejects scalar collections and non-positive recurrence-period bounds"
    (signals invalid-rrule (make-rrule-set :schedules :invalid))
    (signals invalid-rrule (make-rrule-set :rdates :invalid))
    (signals invalid-rrule (make-rrule-set :exdates :invalid))
    (signals invalid-rrule (rrule-set-occurrences (make-rrule-set) :max-periods -1))
    (signals
      invalid-rrule
      (rrule-set-occurrences (make-rrule-set) :max-periods 1/2)))
  (it
    "supports DO iteration completion and non-local early return"
    (let ((set
          (make-rrule-set
            :rdates
            (list (make-local-date 2024 1 2) (make-local-date 2024 1 1)))))
      (let (seen)
        (expect
          (do-rrule-set-occurrences
            (occurrence set :result :finished)
            (push (format-local-date occurrence) seen))
          :to-equal
          :finished)
        (expect (nreverse seen) :to-equal (quote ("2024-01-01" "2024-01-02"))))
      (let (seen)
        (expect
          (do-rrule-set-occurrences
            (occurrence set :result :finished)
            (push (format-local-date occurrence) seen)
            (return :stopped))
          :to-equal
          :stopped)
        (expect seen :to-equal (quote ("2024-01-01"))))))
  (progn
    (it
      "does not create an RDATE source when no RDATEs are supplied"
      (let* ((set
            (make-rrule-set
              :schedules
              (list (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;COUNT=1"))))
             (original-source
            (symbol-function (find-symbol "%RRULE-SET-LIST-SOURCE" "CL-DATE-KIT")))
             (called nil))
        (unwind-protect (progn
            (setf (symbol-function (find-symbol "%RRULE-SET-LIST-SOURCE" "CL-DATE-KIT")) (lambda (occurrences)
                (setf called t)
                (funcall original-source occurrences)))
            (map-rrule-set-occurrences
              (lambda (occurrence)
                (declare (ignore occurrence))
                t)
              set
              :max-periods
              1)
            (expect called :to-be nil))
          (setf (symbol-function (find-symbol "%RRULE-SET-LIST-SOURCE" "CL-DATE-KIT")) original-source))))
    (it
      "keeps RDATE reader order while reusing normalized occurrences"
      (let* ((set
            (make-rrule-set
              :rdates
              (list
                (make-local-date 2024 1 3)
                (make-local-date 2024 1 1)
                (make-local-date 2024 1 3)
                (make-local-date 2024 1 2))))
             (expected (list "2024-01-01" "2024-01-02" "2024-01-03")))
        (expect
          (mapcar (function format-local-date) (rrule-set-rdates set))
          :to-equal
          (list "2024-01-03" "2024-01-01" "2024-01-03" "2024-01-02"))
        (expect
          (mapcar (function format-local-date) (rrule-set-occurrences set))
          :to-equal
          expected)
        (expect
          (mapcar (function format-local-date) (rrule-set-occurrences set))
          :to-equal
          expected)))))

(progn
  (describe
    "RFC 5545 all-day recurrence sets"
    (it
      "merges all-day schedules and DATE RDATEs while removing DATE EXDATEs"
      (let* ((schedule (rrule-test-schedule (make-local-date 2024 1 2) "FREQ=DAILY;COUNT=3"))
             (set
            (make-rrule-set
              :schedules
              (list schedule)
              :rdates
              (vector (make-local-date 2024 1 4) (make-local-date 2024 1 1))
              :exdates
              (list (make-local-date 2024 1 3)))))
        (expect
          (mapcar #'format-local-date (rrule-set-occurrences set :max-periods 3))
          :to-equal
          (list "2024-01-01" "2024-01-02" "2024-01-04"))))
    (it
      "orders and deduplicates DATE-only RDATEs"
      (let ((set
            (make-rrule-set
              :rdates
              (vector
                (make-local-date 2024 1 3)
                (make-local-date 2024 1 1)
                (make-local-date 2024 1 3)))))
        (expect
          (mapcar #'format-local-date (rrule-set-occurrences set))
          :to-equal
          (list "2024-01-01" "2024-01-03"))))
    (it
      "rejects mixed DATE and ZONED-DATE-TIME values"
      (let* ((date (make-local-date 2024 1 1))
             (zoned
            (zoned-date-time-of-local (rrule-test-local 2024 1 1) (find-time-zone "UTC")))
             (date-schedule (rrule-test-schedule date "FREQ=DAILY;COUNT=1")))
        (signals invalid-rrule (make-rrule-set :rdates (list date zoned)))
        (signals
          invalid-rrule
          (make-rrule-set :schedules (list date-schedule) :rdates (list zoned)))
        (signals
          invalid-rrule
          (make-rrule-set
            :schedules
            (list (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;COUNT=1"))
            :exdates
            (list date))))))
  (describe
    "RFC 5545 floating DATE-TIME recurrence sets"
    (it
      "merges, sorts, deduplicates, and excludes floating occurrences"
      (let* ((schedule
            (rrule-test-schedule (rrule-test-local 2024 1 2 9) "FREQ=DAILY;COUNT=2"))
             (set
            (make-rrule-set
              :schedules
              (list schedule)
              :rdates
              (list
                (rrule-test-local 2024 1 3 9)
                (rrule-test-local 2024 1 1 9)
                (rrule-test-local 2024 1 3 9))
              :exdates
              (list (rrule-test-local 2024 1 2 9)))))
        (expect
          (mapcar #'format-local-date-time (rrule-set-occurrences set :max-periods 2))
          :to-equal
          (list "2024-01-01T09:00:00" "2024-01-03T09:00:00"))))
    (it
      "rejects floating values mixed with DATE or ZONED-DATE-TIME"
      (let* ((floating (rrule-test-local 2024 1 1 9))
             (date (make-local-date 2024 1 1))
             (zoned
            (zoned-date-time-of-local (rrule-test-local 2024 1 1 9) (find-time-zone "UTC")))
             (schedule (rrule-test-schedule floating "FREQ=DAILY;COUNT=1")))
        (signals invalid-rrule (make-rrule-set :rdates (list floating date)))
        (signals invalid-rrule (make-rrule-set :rdates (list floating zoned)))
        (signals
          invalid-rrule
          (make-rrule-set :schedules (list schedule) :exdates (list date)))))))

(describe
  "RRULE set EXDATE membership indexes"
  (it
    "excludes a nontrivial zoned EXDATE collection by instant and preserves deduplication"
    (let* ((utc (find-time-zone "UTC"))
           (new-york (find-time-zone "America/New_York"))
           (schedule (rrule-test-utc-schedule 2024 1 1 "FREQ=DAILY;COUNT=6"))
           (set
          (make-rrule-set
            :schedules
            (list schedule)
            :rdates
            (list (zoned-date-time-of-local (rrule-test-local 2024 1 5) utc))
            :exdates
            (list
              (zoned-date-time-of-local (rrule-test-local 2024 1 2) utc)
              (zoned-date-time-of-local (rrule-test-local 2024 1 3) utc)
              (zoned-date-time-of-local (rrule-test-local 2024 1 3) utc)
              (zoned-date-time-of-local (rrule-test-local 2024 1 4 4) new-york)))))
      (expect
        (rrule-test-local-strings (rrule-set-occurrences set :max-periods 6))
        :to-equal
        (quote ("2024-01-01T09:00:00" "2024-01-05T09:00:00" "2024-01-06T09:00:00")))))
  (it
    "does not exclude floating occurrences with a different nanosecond"
    (let* ((excluded (local-date-time-of 2024 1 1 9 0 0 10))
           (included (local-date-time-of 2024 1 1 9 0 0 11))
           (set (make-rrule-set :rdates (list excluded included) :exdates (list excluded)))
           (occurrences (rrule-set-occurrences set)))
      (expect (length occurrences) :to-equal 1)
      (expect (local-date-time-nanosecond (first occurrences)) :to-equal 11))))

(describe
  "RRULE set empty input"
  (it
    "returns no occurrences without requiring a value type"
    (let ((set (make-rrule-set)))
      (expect (rrule-set-occurrences set) :to-equal nil)
      (expect
        (map-rrule-set-occurrences
          (lambda (occurrence)
            (declare (ignore occurrence))
            t)
          set)
        :to-equal
        t))))

(describe
  "RRULE set k-way merge"
  (it
    "advances every duplicate source before yielding the next occurrence"
    (let* ((rule (make-rrule :frequency :daily :count 2))
           (schedules
          (loop repeat 16
                collect (make-rrule-schedule (make-local-date 2024 1 1) rule)))
           (set (make-rrule-set :schedules schedules)))
      (expect
        (mapcar #'format-local-date (rrule-set-occurrences set :max-periods 2))
        :to-equal
        (list "2024-01-01" "2024-01-02"))))
  (it
    "does not advance duplicate sources after an early callback exit"
    (let* ((rule (make-rrule :frequency :daily :count 2))
           (set
          (make-rrule-set
            :schedules
            (loop repeat 2
                  collect (make-rrule-schedule (make-local-date 2024 1 1) rule))))
           (original-source (symbol-function 'cl-date-kit::%rrule-occurrence-source))
           (supplied 0))
      (unwind-protect (progn
          (setf (symbol-function 'cl-date-kit::%rrule-occurrence-source) (lambda (schedule max-periods)
              (let ((source (funcall original-source schedule max-periods)))
                (lambda ()
                  (multiple-value-bind (occurrence present-p) (funcall source)
                    (when present-p
                      (incf supplied))
                    (values occurrence present-p))))))
          (expect
            (map-rrule-set-occurrences
              (lambda (occurrence)
                (declare (ignore occurrence))
                nil)
              set
              :max-periods
              2)
            :to-equal
            nil)
          (expect supplied :to-equal 2))
        (setf (symbol-function 'cl-date-kit::%rrule-occurrence-source) original-source)))))
