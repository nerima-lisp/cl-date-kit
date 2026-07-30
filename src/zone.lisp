;;;; src/zone.lisp
;;;;
;;;; Named IANA zone state, TZDB discovery, and transition navigation backed
;;;; by TZIF.LISP's parsed rules. Fixed offsets live in ZONE-OFFSET.LISP,
;;;; wall-time resolution lives in ZONE-LOCAL.LISP, and POSIX TZ footer
;;;; parsing and transition projection live in POSIX-TZ.LISP.
(in-package #:cl-date-kit)

;;; --- Small helpers over TZIF.LISP's data -------------------------------
(defun %tzif-type->offset (type)
  (or
    (tzif-type-offset-cache type)
    (setf (tzif-type-offset-cache type) (%make-zone-offset (tzif-type-utc-offset type)))))

(defun %binary-search-le (vector value)
  "Index of the largest element of the ascending VECTOR that is <= VALUE, or
-1 if every element is greater than VALUE."
  (declare (type simple-vector vector)
           (type integer value))
  (let ((lo 0)
        (hi (1- (length vector)))
        (result -1))
    (declare (type fixnum lo hi result))
    (loop while (<= lo hi)
          do (let ((mid (ash (+ lo hi) -1)))
        (declare (type fixnum mid))
        (if (<= (aref vector mid) value) (progn
            (setf result mid)
            (setf lo (1+ mid)))
          (setf hi (1- mid)))))
    result))

;;; --- IANA time zones ----------------------------------------------------
(defstruct (time-zone (:constructor %make-time-zone (name tzif-data posix-rule))) (name "" :type string :read-only t)
  (tzif-data nil :type tzif-data :read-only t)
  (posix-rule nil :type (or null posix-tz-rule) :read-only t)
  (local-search-radius nil :type (or null (integer 0 *))))

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
        (and tzdir (plusp (length tzdir)) (concatenate (quote string) tzdir "/" name))
        (concatenate (quote string) "/usr/share/zoneinfo/" name)))))

(defun %zoneinfo-root-namestring (root)
  (handler-case (cond
      ((and (stringp root) (plusp (length root))) root)
      ((pathnamep root) (namestring root))
      (t nil))
    (error ()
      nil)))

(defun %candidate-zoneinfo-roots (tzdir)
  (if tzdir (let ((root (%zoneinfo-root-namestring tzdir)))
      (and root (list root)))
    (let ((environment-tzdir (sb-ext:posix-getenv "TZDIR")))
      (remove
        nil
        (list (%zoneinfo-root-namestring environment-tzdir) "/usr/share/zoneinfo")))))

(defun %zoneinfo-root-pathname (root)
  (when (and (stringp root) (plusp (length root)))
    (let ((pathname
          (ignore-errors
            (truename
              (pathname (concatenate (quote string) (string-right-trim "/" root) "/"))))))
      (and pathname (null (pathname-name pathname)) pathname))))

(defun %tzif-file-p (path)
  (handler-case (with-open-file (stream path :direction :input :element-type (quote (unsigned-byte 8)))
      (and
        (eql (read-byte stream nil nil) #x54)
        (eql (read-byte stream nil nil) #x5a)
        (eql (read-byte stream nil nil) #x69)
        (eql (read-byte stream nil nil) #x66)))
    (error ()
      nil)))

(defun %excluded-zoneinfo-name-p (name)
  (let ((name-length (length name)))
    (or
      (string= name "localtime")
      (string= name "posixrules")
      (and (>= name-length 6) (string= name "posix/" :end1 6 :end2 6))
      (and (>= name-length 6) (string= name "right/" :end1 6 :end2 6)))))

(progn
  (defvar *available-time-zone-names-cache* (make-hash-table :test (function equal)))
  (defvar *available-time-zone-names-cache-lock* (sb-thread:make-mutex :name "cl-date-kit time-zone names cache"))
  (defun %available-time-zone-names-under-root (root)
    (let ((directory (%zoneinfo-root-pathname root)))
      (when directory
        (let ((key (namestring directory)))
          (multiple-value-bind (cached present-p) (sb-thread:with-mutex
              (*available-time-zone-names-cache-lock*)
              (gethash key *available-time-zone-names-cache*))
            (if present-p (copy-list cached)
              (let ((names
                    (loop for path in (directory (merge-pathnames #P"**/*" directory))
                          for name = (namestring (enough-namestring path directory))
                          when (and
                        (%safe-time-zone-name-p name)
                        (not (%excluded-zoneinfo-name-p name))
                        (%tzif-file-p path))
                            collect name)))
                (sb-thread:with-mutex
                  (*available-time-zone-names-cache-lock*)
                  (multiple-value-bind (cached present-p) (gethash key *available-time-zone-names-cache*)
                    (if present-p (copy-list cached)
                      (progn
                        (setf (gethash key *available-time-zone-names-cache*) names)
                        (copy-list names)))))))))))))

(defun available-time-zone-names (&key tzdir)
  "Returns a fresh, string<-sorted list of IANA names found in TZif files.
When TZDIR is supplied, only that directory is searched.  Otherwise the
TZDIR environment variable and the standard zoneinfo directory are searched."
  (sort
    (remove-duplicates
      (loop for root in (%candidate-zoneinfo-roots tzdir)
            append (%available-time-zone-names-under-root root))
      :test
      (function string=))
    (function string<)))

(progn
  (defparameter +tzdata-version-line-limit+ 128)
  (defun %read-bounded-line (stream)
    "Reads one metadata line from STREAM without retaining more than the configured limit.\nReturns the line and true when it is complete; returns NIL and NIL when too long."
    (check-type stream stream)
    (let ((output (make-string-output-stream))
          (length 0))
      (loop for character = (read-char stream nil nil)
            do (cond
          ((null character) (return (values (get-output-stream-string output) t)))
          ((char= character #\Newline)
            (return (values (get-output-stream-string output) t)))
          ((>= length +tzdata-version-line-limit+) (return (values nil nil)))
          (t
            (write-char character output)
            (incf length)))))))

(defun %iana-tzdata-release-p (value)
  (and
    (stringp value)
    (= (length value) 5)
    (loop for index below 4
          always (digit-char-p (char value index)))
    (char<= #\a (char value 4) #\z)))

(defun %iana-tzdata-release-token (value)
  (when (and (stringp value) (>= (length value) 5))
    (let ((token (subseq value 0 5)))
      (and (%iana-tzdata-release-p token) token))))

(progn
  (defstruct (zone-state
      (:constructor %make-zone-state (offset abbreviation daylight-saving-p))) (offset nil :type zone-offset :read-only t)
    (abbreviation nil :type (or null string) :read-only t)
    (daylight-saving-p nil :type boolean :read-only t))
  (defun %tzif-type->state (data type)
    (let* ((table (tzif-data-abbreviation-table data))
           (start (tzif-type-abbreviation-index type))
           (end (and (< start (length table)) (position #\Null table :start start))))
      (%make-zone-state
        (%tzif-type->offset type)
        (and end (subseq table start end))
        (tzif-type-dst-p type))))
  (defun %posix-rule->state (epoch rule)
    (multiple-value-bind (offset abbreviation daylight-saving-p) (%posix-state-values-at-instant epoch rule)
      (%make-zone-state (%make-zone-offset offset) abbreviation daylight-saving-p)))
  (defun %time-zone-type-for-instant (zone epoch)
    (let* ((data (time-zone-tzif-data zone))
           (times (tzif-data-transition-times data))
           (n (length times)))
      (if (zerop n) (and (null (time-zone-posix-rule zone)) (tzif-data-initial-type data))
        (let ((index (%binary-search-le times epoch)))
          (cond
            ((minusp index) (tzif-data-initial-type data))
            ((and (= index (1- n)) (> epoch (aref times index)) (time-zone-posix-rule zone))
              nil)
            (t (aref (tzif-data-transition-types data) index)))))))
  (defun %time-zone-offset-for-instant (zone epoch)
    (let ((type (%time-zone-type-for-instant zone epoch)))
      (if type (%tzif-type->offset type)
        (%make-zone-offset
          (nth-value 0 (%posix-state-values-at-instant epoch (time-zone-posix-rule zone)))))))
  (defun %time-zone-state-for-instant (zone epoch)
    (let ((data (time-zone-tzif-data zone))
          (type (%time-zone-type-for-instant zone epoch)))
      (if type (%tzif-type->state data type)
        (%posix-rule->state epoch (time-zone-posix-rule zone))))))

(progn
  (defun zone-state-for-instant (zone instant)
    "The offset, abbreviation, and daylight-saving flag in force at INSTANT."
    (etypecase zone
      (zone-offset (%make-zone-state zone nil nil))
      (time-zone (%time-zone-state-for-instant zone (instant-epoch-second instant)))))
  (defun offset-for-instant (zone instant)
    "The ZONE-OFFSET in force at INSTANT, for either kind of ZONE."
    (etypecase zone
      (zone-offset zone)
      (time-zone (%time-zone-offset-for-instant zone (instant-epoch-second instant))))))

(defun %time-zone-database-version-from-version-file (path)
  (handler-case (with-open-file (stream path :direction :input)
      (multiple-value-bind (line complete-p) (%read-bounded-line stream)
        (when complete-p
          (let ((version (string-trim (list #\Space #\Tab #\Return) line)))
            (and (%iana-tzdata-release-p version) version)))))
    (error ()
      nil)))

(defun %tzdata-version-from-line (line)
  "Returns the leading IANA release token from a tzdata.zi version line."
  (let ((prefix "# version "))
    (when (and
        (stringp line)
        (<= (length prefix) (length line))
        (string= prefix line :end2 (length prefix)))
      (%iana-tzdata-release-token (subseq line (length prefix))))))

(defun %time-zone-database-version-from-tzdata-zi (path)
  (handler-case (with-open-file (stream path :direction :input)
      (multiple-value-bind (line complete-p) (%read-bounded-line stream)
        (and complete-p (%tzdata-version-from-line line))))
    (error ()
      nil)))

(defun %time-zone-database-version-under-root (root)
  (handler-case (let ((directory (%zoneinfo-root-pathname root)))
      (when directory
        (or
          (%time-zone-database-version-from-version-file
            (merge-pathnames #P"+VERSION" directory))
          (%time-zone-database-version-from-tzdata-zi
            (merge-pathnames #P"tzdata.zi" directory)))))
    (error ()
      nil)))

(defun time-zone-database-version (&key tzdir)
  "Returns the IANA tzdata release recorded under TZDIR, or NIL.
When TZDIR is supplied, only that directory is examined.  Otherwise the
TZDIR environment variable and the standard zoneinfo directory are searched."
  (handler-case (loop for root in (%candidate-zoneinfo-roots tzdir)
          for version = (%time-zone-database-version-under-root root)
          when version
            return version)
    (error ()
      nil)))

(progn
  (defvar *time-zone-cache* (make-hash-table :test (function equal)))
  (defvar *time-zone-cache-lock* (sb-thread:make-mutex :name "cl-date-kit time-zone cache"))
  (defun %time-zone-cache-key (name path)
    (list (copy-seq name) (namestring path)))
  (defun find-time-zone (name)
    "Looks up the IANA time zone NAME (e.g. \"Asia/Tokyo\") under the TZDIR
environment variable, then /usr/share/zoneinfo, parsing its TZif file."
    (unless (%safe-time-zone-name-p name)
      (error (quote time-zone-not-found) :name name))
    (let ((path (find-if (function probe-file) (%candidate-zoneinfo-paths name))))
      (unless path
        (error (quote time-zone-not-found) :name name))
      (let ((key (%time-zone-cache-key name path)))
        (or
          (sb-thread:with-mutex (*time-zone-cache-lock*) (gethash key *time-zone-cache*))
          (let* ((data (parse-tzif-file path))
                 (rule
                (and
                  (tzif-data-posix-tz-string data)
                  (parse-posix-tz-string (tzif-data-posix-tz-string data) path)))
                 (candidate (%make-time-zone name data rule)))
            (sb-thread:with-mutex
              (*time-zone-cache-lock*)
              (or
                (gethash key *time-zone-cache*)
                (setf (gethash key *time-zone-cache*) candidate)))))))))

(progn
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
           (before
          (if (zerop index) (tzif-data-initial-type data)
            (aref types (1- index))))
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
                      (:previous
                        (or
                          (< boundary epoch-second)
                          (and (= boundary epoch-second) (plusp nanosecond))))))
                  (let ((transition (%zone-transition-from-values boundary before after)))
                    (when (and
                        transition
                        (or
                          (null candidate)
                          (ecase direction
                            (:next (< boundary (instant-epoch-second (zone-transition-instant candidate))))
                            (:previous
                              (> boundary (instant-epoch-second (zone-transition-instant candidate)))))))
                      (setf candidate transition)))))))
          candidate))))
  (defun zone-transition-gap-p (transition)
    "True when TRANSITION moves the local clock forward."
    (>
      (zone-offset-total-seconds (zone-transition-offset-after transition))
      (zone-offset-total-seconds (zone-transition-offset-before transition))))
  (progn
    (defun zone-transition-overlap-p (transition)
      "True when TRANSITION moves the local clock backward."
      (<
        (zone-offset-total-seconds (zone-transition-offset-after transition))
        (zone-offset-total-seconds (zone-transition-offset-before transition))))
    (defun zone-transition-duration (transition)
      "Returns TRANSITION's duration as offset-after minus offset-before."
      (duration-of-seconds
        (-
          (zone-offset-total-seconds (zone-transition-offset-after transition))
          (zone-offset-total-seconds (zone-transition-offset-before transition))))))
  (defun next-zone-transition (zone instant)
    "Returns the first offset transition strictly after INSTANT, or NIL."
    (etypecase zone
      (zone-offset nil)
      (time-zone
        (let* ((times (tzif-data-transition-times (time-zone-tzif-data zone)))
               (start (1+ (%binary-search-le times (instant-epoch-second instant))))
               (explicit
              (loop for index from start below (length times)
                    for transition = (%time-zone-transition-at-index zone index)
                    when transition
                      return transition)))
          (or explicit (%select-posix-zone-transition zone instant :next))))))
  (defun time-zone-transitions-between (zone start end)
    "Returns ordered offset transitions in ZONE whose instants are in [START, END).

ZONE may be a TIME-ZONE or a fixed ZONE-OFFSET. START and END must be
INSTANTs, and END must be strictly later than START."
    (check-type zone (or zone-offset time-zone))
    (check-type start instant)
    (check-type end instant)
    (when (instant>= start end)
      (error 'invalid-interval :start start :end end))
    (let ((cursor (instant-minus-nanos start 1)))
      (loop for transition = (next-zone-transition zone cursor)
            while (and transition (instant< (zone-transition-instant transition) end))
            collect transition
            do (setf cursor (zone-transition-instant transition)))))
  (defun previous-zone-transition (zone instant)
    "Returns the last offset transition strictly before INSTANT, or NIL."
    (etypecase zone
      (zone-offset nil)
      (time-zone
        (let* ((times (tzif-data-transition-times (time-zone-tzif-data zone)))
               (epoch-second (instant-epoch-second instant))
               (boundary
              (if (plusp (instant-nanosecond instant)) epoch-second
                (1- epoch-second)))
               (explicit
              (loop for index downfrom (%binary-search-le times boundary) to 0
                    for transition = (%time-zone-transition-at-index zone index)
                    when transition
                      return transition))
               (posix (%select-posix-zone-transition zone instant :previous)))
          (cond
            ((null explicit) posix)
            ((null posix) explicit)
            ((instant< (zone-transition-instant explicit) (zone-transition-instant posix))
              posix)
            (t explicit))))))) ;;; --- Resolving a wall-clock LOCAL-DATE-TIME -----------------------------
