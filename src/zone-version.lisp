;;;; src/zone-version.lisp
;;;;
;;;; Parsing and comparing IANA tzdata release version strings, read from a
;;;; zoneinfo directory's +VERSION or tzdata.zi file. ZONE.LISP owns zoneinfo
;;;; directory discovery; this file only interprets what it finds there.
(in-package #:cl-date-kit)

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
