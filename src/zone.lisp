;;;; src/zone.lisp
;;;;
;;;; Named IANA zone resolution backed by TZIF.LISP's parsed rules: java.time's
;;;; ZoneId + ZoneRules. Fixed offsets live in ZONE-OFFSET.LISP, while POSIX
;;;; TZ footer parsing and transition projection live in POSIX-TZ.LISP.
;;;; Resolving a wall-clock LOCAL-DATE-TIME against a TIME-ZONE
;;;; can come back with zero offsets (the local time falls in a
;;;; spring-forward gap and never happened), one (the normal case), or two
;;;; (a fall-back overlap, when the clock repeats itself) -- this is where
;;;; naive date-time arithmetic most often goes wrong in other libraries.
(in-package #:cl-date-kit)

;;; --- Small helpers over TZIF.LISP's data -------------------------------
(defun %tzif-type->offset (ty)
  (%make-zone-offset (tzif-type-utc-offset ty)))

(defun %binary-search-le (vector value)
  "Index of the largest element of the ascending VECTOR that is <= VALUE, or
-1 if every element is greater than VALUE."
  (let ((lo 0)
        (hi (1- (length vector)))
        (result -1))
    (loop while (<= lo hi)
          do (let ((mid (floor (+ lo hi) 2)))
        (if (<= (aref vector mid) value) (progn
            (setf result mid)
            (setf lo (1+ mid)))
          (setf hi (1- mid)))))
    result))

;;; --- IANA time zones ----------------------------------------------------
(defstruct (time-zone (:constructor %make-time-zone (name tzif-data posix-rule))) (name "" :type string :read-only t)
  (tzif-data nil :type tzif-data :read-only t)
  (posix-rule nil :type (or null posix-tz-rule) :read-only t))

(defun %posix-rule-applies-to-local-p (zone naive-seconds)
  "True when NAIVE-SECONDS is safely beyond ZONE's explicit TZif table."
  (let* ((data (time-zone-tzif-data zone))
         (times (tzif-data-transition-times data))
         (count (length times)))
    (or
      (zerop count)
      (let* ((index (1- count))
             (boundary (aref times index))
             (before
            (if (zerop index) (tzif-data-initial-type data)
              (aref (tzif-data-transition-types data) (1- index))))
             (after (aref (tzif-data-transition-types data) index)))
        (>
          naive-seconds
          (max
            (+ boundary (tzif-type-utc-offset before))
            (+ boundary (tzif-type-utc-offset after))))))))

(defun %safe-time-zone-name-p (name)
  "Rejects absolute paths and \"..\" components so FIND-TIME-ZONE cannot be
used to read arbitrary files outside the zoneinfo directory."
  (and
    (stringp name)
    (plusp (length name))
    (char/= (char name 0) #\/)
    (not (search ".." name))))

(defun %candidate-zoneinfo-paths (name)
  (let ((tzdir (sb-ext:posix-getenv "TZDIR")))
    (remove
      nil
      (list
        (and tzdir (plusp (length tzdir)) (concatenate 'string tzdir "/" name))
        (concatenate 'string "/usr/share/zoneinfo/" name)))))

(defun find-time-zone (name)
  "Looks up the IANA time zone NAME (e.g. \"Asia/Tokyo\") under the TZDIR
environment variable, then /usr/share/zoneinfo, parsing its TZif file."
  (unless (%safe-time-zone-name-p name)
    (error (quote time-zone-not-found) :name name))
  (let ((path (find-if (function probe-file) (%candidate-zoneinfo-paths name))))
    (unless path
      (error (quote time-zone-not-found) :name name))
    (let* ((data (parse-tzif-file path))
           (rule
            (and (tzif-data-posix-tz-string data)
                 (parse-posix-tz-string (tzif-data-posix-tz-string data) path))))
      (%make-time-zone name data rule))))

(defun %offset-for-instant-time-zone (zone epoch)
  (let* ((data (time-zone-tzif-data zone))
         (times (tzif-data-transition-times data))
         (n (length times)))
    (if (zerop n) (let ((rule (time-zone-posix-rule zone)))
        (if rule (%make-zone-offset (%offset-from-posix-rule epoch rule))
          (%tzif-type->offset (tzif-data-initial-type data))))
      (let ((idx (%binary-search-le times epoch)))
        (cond
          ((minusp idx) (%tzif-type->offset (tzif-data-initial-type data)))
          ((and (= idx (1- n)) (> epoch (aref times idx)) (time-zone-posix-rule zone))
            (%make-zone-offset (%offset-from-posix-rule epoch (time-zone-posix-rule zone))))
          (t (%tzif-type->offset (aref (tzif-data-transition-types data) idx))))))))

(progn
(defun offset-for-instant (zone instant)
  "The ZONE-OFFSET in force at INSTANT, for either kind of ZONE."
  (etypecase zone
    (zone-offset zone)
    (time-zone (%offset-for-instant-time-zone zone (instant-epoch-second instant)))))

(defun %zone-transition-from-values (epoch-second before after)
  (unless (= before after)
    (%make-zone-transition
      (make-instant epoch-second)
      (%make-zone-offset before)
      (%make-zone-offset after))))

(defun %time-zone-transition-at-index (zone index)
  (let* ((data (time-zone-tzif-data zone))
         (times (tzif-data-transition-times data))
         (types (tzif-data-transition-types data))
         (before (if (zerop index) (tzif-data-initial-type data) (aref types (1- index))))
         (after (aref types index)))
    (%zone-transition-from-values
      (aref times index)
      (tzif-type-utc-offset before)
      (tzif-type-utc-offset after))))

(defun %posix-transition-applies-p (zone epoch-second)
  "True when EPOCH-SECOND is beyond ZONE's explicit TZif transition table."
  (let* ((times (tzif-data-transition-times (time-zone-tzif-data zone)))
         (count (length times)))
    (or (zerop count) (> epoch-second (aref times (1- count))))))

(defun %select-posix-zone-transition (zone instant direction)
  "Selects the nearest footer-rule transition in DIRECTION from INSTANT."
  (let ((rule (time-zone-posix-rule zone)))
    (when rule
      (let* ((epoch-second (instant-epoch-second instant))
             (nanosecond (instant-nanosecond instant))
             (year (local-date-year (local-date-from-epoch-day (floor epoch-second 86400))))
             (candidate nil))
        (loop for transition-year from (1- year) to (1+ year)
              do (dolist (description (%posix-transitions-for-year transition-year rule))
                   (destructuring-bind (boundary before after) description
                     (when (and
                             (%posix-transition-applies-p zone boundary)
                             (ecase direction
                               (:next (> boundary epoch-second))
                               (:previous (or (< boundary epoch-second)
                                              (and (= boundary epoch-second) (plusp nanosecond))))))
                       (let ((transition (%zone-transition-from-values boundary before after)))
                         (when (and transition
                                    (or (null candidate)
                                        (ecase direction
                                          (:next (< boundary (instant-epoch-second (zone-transition-instant candidate))))
                                          (:previous (> boundary (instant-epoch-second (zone-transition-instant candidate)))))))
                           (setf candidate transition)))))))
        candidate))))

(defun zone-transition-gap-p (transition)
  "True when TRANSITION moves the local clock forward."
  (> (zone-offset-total-seconds (zone-transition-offset-after transition))
     (zone-offset-total-seconds (zone-transition-offset-before transition))))

(defun zone-transition-overlap-p (transition)
  "True when TRANSITION moves the local clock backward."
  (< (zone-offset-total-seconds (zone-transition-offset-after transition))
     (zone-offset-total-seconds (zone-transition-offset-before transition))))

(defun next-zone-transition (zone instant)
  "Returns the first offset transition strictly after INSTANT, or NIL."
  (etypecase zone
    (zone-offset nil)
    (time-zone
      (let* ((times (tzif-data-transition-times (time-zone-tzif-data zone)))
             (start (1+ (%binary-search-le times (instant-epoch-second instant))))
             (explicit (loop for index from start below (length times)
                             for transition = (%time-zone-transition-at-index zone index)
                             when transition return transition)))
        (or explicit (%select-posix-zone-transition zone instant :next))))))

(defun previous-zone-transition (zone instant)
  "Returns the last offset transition strictly before INSTANT, or NIL."
  (etypecase zone
    (zone-offset nil)
    (time-zone
      (let* ((times (tzif-data-transition-times (time-zone-tzif-data zone)))
             (epoch-second (instant-epoch-second instant))
             (boundary (if (plusp (instant-nanosecond instant)) epoch-second (1- epoch-second)))
             (explicit (loop for index downfrom (%binary-search-le times boundary) to 0
                             for transition = (%time-zone-transition-at-index zone index)
                             when transition return transition))
             (posix (%select-posix-zone-transition zone instant :previous)))
        (cond
          ((null explicit) posix)
          ((null posix) explicit)
          ((instant< (zone-transition-instant explicit) (zone-transition-instant posix)) posix)
          (t explicit)))))));;; --- Resolving a wall-clock LOCAL-DATE-TIME -----------------------------
(defun %local-date-time->naive-seconds (local-date-time)
  "LOCAL-DATE-TIME's fields read as if they directly WERE epoch seconds --
i.e. as if the wall-clock reading were UTC. Comparing this against a
transition's local reading under each of its bracketing offsets is the
standard trick for detecting gaps and overlaps."
  (+
    (* (local-date-to-epoch-day (local-date-time-date local-date-time)) 86400)
    (local-time-to-second-of-day (local-date-time-time local-date-time))))

(defun %require-zone-offset (offset)
  (unless (zone-offset-p offset)
    (error "OFFSET must be a ZONE-OFFSET: ~S" offset))
  offset)

(defun local-date-time-to-epoch-second (local-date-time offset)
  "Interprets LOCAL-DATE-TIME in fixed OFFSET and returns Unix epoch seconds."
  (-
    (%local-date-time->naive-seconds local-date-time)
    (zone-offset-total-seconds (%require-zone-offset offset))))

(defun local-date-time-of-epoch-second (epoch-second nanosecond offset)
  "Constructs a LOCAL-DATE-TIME by applying fixed OFFSET to Unix fields."
  (unless (integerp epoch-second)
    (error "EPOCH-SECOND must be an integer: ~S" epoch-second))
  (multiple-value-bind (epoch-day second-of-day) (floor
      (+ epoch-second (zone-offset-total-seconds (%require-zone-offset offset)))
      +seconds-per-day+)
    (make-local-date-time
      (local-date-from-epoch-day epoch-day)
      (local-time-of-second-of-day second-of-day nanosecond))))

(defun local-date-time-to-instant (local-date-time offset)
  "Interprets LOCAL-DATE-TIME in fixed OFFSET as an INSTANT."
  (make-instant
    (local-date-time-to-epoch-second local-date-time offset)
    (local-date-time-nanosecond local-date-time)))

(defun local-date-time-of-instant (instant offset)
  "Applies fixed OFFSET to INSTANT and returns the resulting local fields."
  (local-date-time-of-epoch-second
    (instant-epoch-second instant)
    (instant-nanosecond instant)
    offset))

(defun %classify-local-date-time (local-date-time zone)
  "Returns (values KIND OFFSETS). KIND is :NORMAL, :GAP, or :OVERLAP. For
  :NORMAL, OFFSETS is a one-element list. For :GAP, OFFSETS is (BEFORE AFTER),
  the two offsets bracketing the gap -- neither is a valid resolution on its
  own. For :OVERLAP, OFFSETS is (EARLIER LATER), both valid."
  (etypecase zone
    (zone-offset (values :normal (list zone)))
    (time-zone
      (let* ((data (time-zone-tzif-data zone))
             (times (tzif-data-transition-times data))
             (types (tzif-data-transition-types data))
             (count (length times))
             (naive (%local-date-time->naive-seconds local-date-time)))
        (flet ((type-before (index)
                 (if (zerop index) (tzif-data-initial-type data)
                (aref types (1- index)))))
          (loop for index from 0 below
                count
                for boundary = (aref times index)
                for before = (%tzif-type->offset (type-before index))
                for after = (%tzif-type->offset (aref types index))
                for local-before = (+ boundary (zone-offset-total-seconds before))
                for local-after = (+ boundary (zone-offset-total-seconds after))
                do (cond
              ((and (> local-after local-before) (<= local-before naive) (< naive local-after))
                (return-from %classify-local-date-time (values :gap (list before after))))
              ((and (< local-after local-before) (<= local-after naive) (< naive local-before))
                (return-from %classify-local-date-time (values :overlap (list before after)))))))
        (let ((rule (time-zone-posix-rule zone)))
          (when (and rule (%posix-rule-applies-to-local-p zone naive))
            (multiple-value-bind (kind offsets) (%classify-posix-local-date-time naive rule)
              (when kind
                (return-from %classify-local-date-time (values kind offsets))))))
        (let* ((guess (%offset-for-instant-time-zone zone naive))
               (utc (- naive (zone-offset-total-seconds guess))))
          (values :normal (list (%offset-for-instant-time-zone zone utc))))))))

(defun possible-offsets-for-local-date-time (local-date-time zone)
  "The ZONE-OFFSETs LOCAL-DATE-TIME could mean in ZONE: empty if it falls in
 a spring-forward gap, one in the normal case, or two (earlier first) if it
 falls in a fall-back overlap.

For a TIME-ZONE, explicit TZif transitions and its POSIX footer rule are both
considered, so far-future gaps and overlaps are classified as well."
  (multiple-value-bind (kind offsets) (%classify-local-date-time local-date-time zone)
    (if (eq kind :gap) (quote ())
      offsets)))

(defun resolve-local-date-time (local-date-time zone &key (disambiguation :compatible))
  "Resolves LOCAL-DATE-TIME to a single ZONE-OFFSET in ZONE. DISAMBIGUATION:
  :COMPATIBLE (default) -- the offset after a gap; the earlier offset in an overlap.
  :EARLIER -- the offset before a gap; the earlier offset in an overlap.
  :LATER -- the offset after a gap; the later offset in an overlap.
  :STRICT -- signals NONEXISTENT-LOCAL-TIME or AMBIGUOUS-LOCAL-TIME instead of picking one."
  (multiple-value-bind (kind offsets) (%classify-local-date-time local-date-time zone)
    (ecase kind
      (:normal (first offsets))
      (:overlap
        (ecase disambiguation
          ((:compatible :earlier) (first offsets))
          (:later (second offsets))
          (:strict
            (error
              'ambiguous-local-time
              :local-date-time
              local-date-time
              :zone
              zone
              :earlier-offset
              (first offsets)
              :later-offset
              (second offsets)))))
      (:gap
        (ecase disambiguation
          ((:compatible :later) (second offsets))
          (:earlier (first offsets))
          (:strict
            (error 'nonexistent-local-time :local-date-time local-date-time :zone zone)))))))

(progn (defun local-date-of-instant (instant offset) "Applies fixed OFFSET to INSTANT and returns the resulting local date." (local-date-time-date (local-date-time-of-instant instant offset))) (defun local-time-of-instant (instant offset) "Applies fixed OFFSET to INSTANT and returns the resulting local time." (local-date-time-time (local-date-time-of-instant instant offset))))
