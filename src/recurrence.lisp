;;;; src/recurrence.lisp
;;;;
;;;; Local-calendar recurrences for ZonedDateTime values.

(in-package #:cl-date-kit)

(defstruct (zoned-recurrence
             (:constructor %make-zoned-recurrence
                 (seed frequency interval count until disambiguation)))
  (seed nil :type zoned-date-time :read-only t)
  (frequency nil :type keyword :read-only t)
  (interval nil :type integer :read-only t)
  (count nil :type (or null integer) :read-only t)
  (until nil :type (or null local-date-time) :read-only t)
  (disambiguation nil :type keyword :read-only t))

(defun make-zoned-recurrence (seed &key frequency (interval 1) count until
                               (disambiguation :compatible))
  "Create an immutable local-calendar recurrence starting at SEED."
  (check-type seed zoned-date-time)
  (check-type frequency (member :daily :weekly :monthly :yearly))
  (check-type interval (integer 1 *))
  (check-type count (or null (integer 1 *)))
  (check-type until (or null local-date-time))
  (check-type disambiguation (member :compatible :earlier :later :strict))
  (%make-zoned-recurrence seed frequency interval count until disambiguation))

(defun %zoned-recurrence-local-at (recurrence index)
  "Return occurrence INDEX on RECURRENCE's local calendar, based on its seed."
  (let ((local (zoned-date-time-local (zoned-recurrence-seed recurrence)))
        (amount (* index (zoned-recurrence-interval recurrence))))
    (ecase (zoned-recurrence-frequency recurrence)
      (:daily (local-date-time-plus-days local amount))
      (:weekly (local-date-time-plus-weeks local amount))
      (:monthly (local-date-time-plus-months local amount))
      (:yearly (local-date-time-plus-years local amount)))))

(defun %zoned-recurrence-continues-p (recurrence index local)
  (and (or (null (zoned-recurrence-count recurrence))
           (< index (zoned-recurrence-count recurrence)))
       (or (null (zoned-recurrence-until recurrence))
           (local-date-time<= local (zoned-recurrence-until recurrence)))))

(defun map-zoned-recurrence-occurrences (function recurrence &key limit)
  "Call FUNCTION for each generated occurrence, stopping when it returns NIL.

LIMIT bounds generation even for unbounded recurrences.  Return RECURRENCE when
all generated occurrences are visited, or NIL after an early callback stop."
  (check-type function function)
  (check-type recurrence zoned-recurrence)
  (check-type limit (integer 1 *))
  (loop for index below limit
        for local = (%zoned-recurrence-local-at recurrence index)
        while (%zoned-recurrence-continues-p recurrence index local)
        for occurrence = (if (zerop index)
                             (zoned-recurrence-seed recurrence)
                             (zoned-date-time-of-local
                              local
                              (zoned-date-time-zone
                               (zoned-recurrence-seed recurrence))
                              :disambiguation
                              (zoned-recurrence-disambiguation recurrence)))
        unless (funcall function occurrence)
          do (return nil)
        finally (return recurrence)))

(defun zoned-recurrence-occurrences (recurrence &key limit)
  "Return at most LIMIT generated occurrences of RECURRENCE as a list."
  (check-type recurrence zoned-recurrence)
  (check-type limit (integer 1 *))
  (let ((occurrences '()))
    (map-zoned-recurrence-occurrences
     (lambda (occurrence)
       (push occurrence occurrences)
       t)
     recurrence
     :limit limit)
    (nreverse occurrences)))

(defmacro do-zoned-recurrence-occurrences ((occurrence recurrence &key limit)
                                            &body body)
  "Evaluate BODY for each generated occurrence, stopping when BODY returns NIL."
  `(map-zoned-recurrence-occurrences
    (lambda (,occurrence)
      ,@body)
    ,recurrence
    :limit ,limit))
