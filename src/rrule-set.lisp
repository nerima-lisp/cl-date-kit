;;;; src/rrule-set.lisp
;;;;
;;;; RFC 5545 recurrence-set composition over evaluated RRULE schedules.
(in-package #:cl-date-kit)

(defstruct (rrule-set
    (:constructor %make-rrule-set (schedules rdates normalized-rdates exdates))) (schedules nil :type list :read-only t)
  (rdates nil :type list :read-only t)
  (normalized-rdates nil :type list :read-only t)
  (exdates nil :type list :read-only t))

(defun %rrule-set-value-type (value)
  (cond
    ((zoned-date-time-p value) :zoned-date-time)
    ((local-date-time-p value) :local-date-time)
    ((local-date-p value) :local-date)
    (t nil)))

(defun %rrule-set-copy-date-values (values name)
  (let ((copied-values
        (cond
          ((null values) nil)
          ((listp values) (copy-list values))
          ((vectorp values) (coerce values 'list))
          (t (%invalid-rrule (format nil "~A must be a list or vector" name) values)))))
    (when copied-values
      (let ((value-type (%rrule-set-value-type (first copied-values))))
        (unless (and
            value-type
            (every
              (lambda (value)
                (eq (%rrule-set-value-type value) value-type))
              copied-values))
          (%invalid-rrule (format nil "~A must contain one date value type" name) values))))
    copied-values))

(defun %rrule-set-copy-schedules (values)
  (cond
    ((null values) nil)
    ((listp values)
      (unless (every #'rrule-schedule-p values)
        (%invalid-rrule "SCHEDULES must contain only RRULE-SCHEDULEs" values))
      (copy-list values))
    ((vectorp values) (%rrule-set-copy-schedules (coerce values 'list)))
    (t (%invalid-rrule "SCHEDULES must be a list or vector" values))))

(defun make-rrule-set (&key schedules rdates exdates)
  "Construct an immutable RFC 5545 recurrence set.

SCHEDULES contains RRULE schedules. RDATES adds explicit occurrences and
EXDATES removes matching occurrences after the schedules and explicit dates are
combined. All nonempty inputs must use one value type: ZONED-DATE-TIME,
LOCAL-DATE-TIME, or LOCAL-DATE. Date arguments accept lists or vectors."
  (let ((schedule-values (%rrule-set-copy-schedules schedules))
        (rdate-values (%rrule-set-copy-date-values rdates "RDATES"))
        (exdate-values (%rrule-set-copy-date-values exdates "EXDATES"))
        (value-type nil))
    (labels ((record-value-type (type value)
               (when type
            (if value-type (unless (eq value-type type)
                (%invalid-rrule "RRULE-SET values must all use the same date type" value))
              (setf value-type type)))))
      (dolist (schedule schedule-values)
        (record-value-type
          (%rrule-set-value-type (rrule-schedule-dtstart schedule))
          schedule))
      (dolist (rdate rdate-values)
        (record-value-type (%rrule-set-value-type rdate) rdate))
      (dolist (exdate exdate-values)
        (record-value-type (%rrule-set-value-type exdate) exdate)))
    (%make-rrule-set
      schedule-values
      rdate-values
      (%rrule-set-sort-and-deduplicate (copy-list rdate-values))
      exdate-values)))

(defun %rrule-set-sort-and-deduplicate (occurrences)
  (if (null occurrences) nil
    (let* ((value-type (%rrule-set-value-type (first occurrences)))
           (sorted
          (sort
            occurrences
            (ecase value-type
              (:local-date #'local-date<)
              (:local-date-time #'local-date-time<)
              (:zoned-date-time #'zoned-date-time<))))
           (same-p
          (ecase value-type
            (:local-date #'local-date=)
            (:local-date-time #'local-date-time=)
            (:zoned-date-time #'zoned-date-time=))))
      (loop with previous = nil
            with result = nil
            for occurrence in sorted
            unless (and previous (funcall same-p occurrence previous))
              do (push occurrence result)
            do (setf previous occurrence)
            finally (return (nreverse result))))))

(progn
  (defun %rrule-set-exdate-key (value value-type)
    "Return an allocation-free EXDATE membership key."
    (ecase value-type
      (:local-date (local-date-to-epoch-day value))
      (:local-date-time
        (+
          (* (%local-date-time->naive-seconds value) +nanos-per-second+)
          (local-date-time-nanosecond value)))
      (:zoned-date-time
        (+
          (* (zoned-date-time-to-epoch-second value) +nanos-per-second+)
          (zoned-date-time-nanosecond value)))))
  (defun %rrule-set-schedule-source (schedule max-periods)
    "Return a thunk that supplies one occurrence at a time from SCHEDULE."
    (%rrule-occurrence-source schedule max-periods)))

(defun %rrule-set-list-source (occurrences)
  "Return a thunk that supplies OCCURRENCES in their existing order."
  (let ((remaining occurrences))
    (lambda ()
      (if remaining (values (pop remaining) t)
        (values nil nil)))))

(progn
  (defun %rrule-set-ordering-functions (value-type)
    "Return ordering predicates appropriate for VALUE-TYPE."
    (ecase value-type
      (:local-date (values #'local-date< #'local-date=))
      (:local-date-time (values #'local-date-time< #'local-date-time=))
      (:zoned-date-time (values #'zoned-date-time< #'zoned-date-time=))))
  (defun %rrule-set-occurrence-type (rrule-set)
    "Return RRULE-SET's homogeneous value type, or NIL for an empty set."
    (or
      (and
        (rrule-set-schedules rrule-set)
        (%rrule-set-value-type
          (rrule-schedule-dtstart (first (rrule-set-schedules rrule-set)))))
      (and
        (rrule-set-rdates rrule-set)
        (%rrule-set-value-type (first (rrule-set-rdates rrule-set))))
      (and
        (rrule-set-exdates rrule-set)
        (%rrule-set-value-type (first (rrule-set-exdates rrule-set))))))
  (defun rrule-set-occurrences (rrule-set &key max-periods)
    "Return the occurrences defined by RRULE-SET in chronological order.

MAX-PERIODS bounds generation for every included schedule."
    (let (occurrences)
      (map-rrule-set-occurrences
        (lambda (occurrence)
          (push occurrence occurrences)
          t)
        rrule-set
        :max-periods
        max-periods)
      (nreverse occurrences))))

(defun map-rrule-set-occurrences (function rrule-set &key max-periods)
  "Call FUNCTION for each occurrence in RRULE-SET in chronological order.

Stop when FUNCTION returns NIL and return NIL; otherwise return T. Generation
is a streaming k-way merge, so schedules are not regenerated for each output."
  (check-type rrule-set rrule-set)
  (when (and max-periods
             (not (and (integerp max-periods) (plusp max-periods))))
    (%invalid-rrule ":MAX-PERIODS must be a positive integer" max-periods))
  (let ((value-type (%rrule-set-occurrence-type rrule-set)))
    (if (null value-type)
        t
        (let* ((exdates (rrule-set-exdates rrule-set))
               (exdate-index (and exdates (make-hash-table :test #'equal)))
               (normalized-rdates (rrule-set-normalized-rdates rrule-set))
               (rdate-source
  (and normalized-rdates
       (%rrule-set-list-source normalized-rdates)))
               (schedule-sources
                 (loop for schedule in (rrule-set-schedules rrule-set)
                       collect (%rrule-set-schedule-source schedule max-periods)))
               (sources
                 (coerce (if rdate-source
                             (append schedule-sources (list rdate-source))
                             schedule-sources)
                         'vector))
               (source-count (length sources)))
          (multiple-value-bind (lessp equalp)
              (%rrule-set-ordering-functions value-type)
            (dolist (exdate exdates)
              (setf (gethash (%rrule-set-exdate-key exdate value-type) exdate-index) t))
            ;; The heap can contain at most one head from each input source.
            (let ((heap-occurrences (make-array source-count))
                  (heap-source-indexes
                    (make-array source-count :element-type 'fixnum))
                  (duplicate-source-indexes
                    (make-array source-count :element-type 'fixnum))
                  (heap-size 0))
              (labels ((head-before-p
                           (occurrence source-index other-occurrence other-source-index)
                         (or (funcall lessp occurrence other-occurrence)
                             (and (funcall equalp occurrence other-occurrence)
                                  (< source-index other-source-index))))
                       (heap-push (occurrence source-index)
                         (let ((index heap-size))
                           (incf heap-size)
                           (loop while (plusp index)
                                 for parent = (ash (1- index) -1)
                                 while (head-before-p occurrence source-index
                                                      (aref heap-occurrences parent)
                                                      (aref heap-source-indexes parent))
                                 do (setf (aref heap-occurrences index)
                                          (aref heap-occurrences parent)
                                          (aref heap-source-indexes index)
                                          (aref heap-source-indexes parent)
                                          index parent)
                                 finally (setf (aref heap-occurrences index) occurrence
                                               (aref heap-source-indexes index)
                                               source-index))))
                       (heap-pop ()
                         (let ((head-occurrence (aref heap-occurrences 0))
                               (head-source-index (aref heap-source-indexes 0)))
                           (decf heap-size)
                           (let ((last-occurrence (aref heap-occurrences heap-size))
                                 (last-source-index
                                   (aref heap-source-indexes heap-size)))
                             (unless (zerop heap-size)
                               (let ((index 0))
                                 (loop for left = (1+ (* 2 index))
                                       while (< left heap-size)
                                       for right = (1+ left)
                                       for child =
                                         (if (and (< right heap-size)
                                                  (head-before-p
                                                   (aref heap-occurrences right)
                                                   (aref heap-source-indexes right)
                                                   (aref heap-occurrences left)
                                                   (aref heap-source-indexes left)))
                                             right
                                             left)
                                       while (head-before-p
                                              (aref heap-occurrences child)
                                              (aref heap-source-indexes child)
                                              last-occurrence last-source-index)
                                       do (setf (aref heap-occurrences index)
                                                (aref heap-occurrences child)
                                                (aref heap-source-indexes index)
                                                (aref heap-source-indexes child)
                                                index child)
                                       finally
                                         (setf (aref heap-occurrences index)
                                               last-occurrence
                                               (aref heap-source-indexes index)
                                               last-source-index))))
                             (values head-occurrence head-source-index))))
                       (advance-source (source-index)
                         (let ((next-occurrence
                                 (funcall (aref sources source-index))))
                           (when next-occurrence
                             (heap-push next-occurrence source-index)))))
                (dotimes (source-index source-count)
                  (advance-source source-index))
                (loop until (zerop heap-size)
                      do (multiple-value-bind (occurrence source-index)
                             (heap-pop)
                           (let ((duplicate-count 0))
                             (loop while (and (plusp heap-size)
                                              (funcall equalp occurrence
                                                       (aref heap-occurrences 0)))
                                   do (multiple-value-bind
                                          (ignored duplicate-source-index)
                                          (heap-pop)
                                        (declare (ignore ignored))
                                        (setf (aref duplicate-source-indexes
                                                    duplicate-count)
                                              duplicate-source-index)
                                        (incf duplicate-count)))
                             (unless (and exdate-index
                                      (gethash
                                       (%rrule-set-exdate-key occurrence value-type)
                                       exdate-index))
                               (unless (funcall function occurrence)
                                 (return-from map-rrule-set-occurrences nil)))
                             (dotimes (index duplicate-count)
                               (advance-source
                                (aref duplicate-source-indexes index)))
                             (advance-source source-index))))
                t)))))))

(defmacro do-rrule-set-occurrences ((variable rrule-set &key max-periods result) &body body)
  "Iterate VARIABLE over RRULE-SET occurrences and return RESULT when complete."
  (let ((completion-marker (gensym "COMPLETION-MARKER"))
        (exit-tag (gensym "EXIT-TAG"))
        (body-result (gensym "BODY-RESULT")))
    `(let ((,completion-marker (gensym))
          (,exit-tag (gensym)))
      (catch ,exit-tag
        (map-rrule-set-occurrences
          (lambda (,variable)
            (let ((,body-result
                  (block nil
                    ,@body
                    ,completion-marker)))
              (if (eq ,body-result ,completion-marker) t
                (throw ,exit-tag ,body-result))))
          ,rrule-set
          :max-periods
          ,max-periods)
        ,result))))
