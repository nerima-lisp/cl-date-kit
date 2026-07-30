(in-package #:cl-date-kit)

(defstruct (interval (:constructor %make-interval (start end))) (start nil :type instant :read-only t) (end nil :type instant :read-only t))

(defun make-interval (start end)
  "Construct the half-open UTC interval [START, END).\n\nSTART and END must be INSTANT values. Empty intervals are valid; an END before\nSTART signals INVALID-INTERVAL."
  (check-type start instant)
  (check-type end instant)
  (when (instant> start end)
    (error 'invalid-interval :start start :end end))
  (%make-interval start end))

(defun interval-empty-p (interval)
  "Whether INTERVAL has no instants."
  (instant= (interval-start interval) (interval-end interval)))

(defun interval-duration (interval)
  "The exact non-negative elapsed DURATION covered by INTERVAL."
  (duration-between (interval-start interval) (interval-end interval)))

(defun interval-contains-p (interval instant)
  "Whether INSTANT belongs to the half-open [START, END) bounds of INTERVAL."
  (and
    (instant<= (interval-start interval) instant)
    (instant< instant (interval-end interval))))

(defun interval-encloses-p (outer inner)
  "Whether OUTER contains every instant in INNER."
  (and
    (instant<= (interval-start outer) (interval-start inner))
    (instant<= (interval-end inner) (interval-end outer))))

(defun interval-overlaps-p (a b)
  "Whether non-empty intervals A and B share at least one instant."
  (and
    (instant< (interval-start a) (interval-end b))
    (instant< (interval-start b) (interval-end a))))

(defun interval-abuts-p (a b)
  "Whether A and B meet at exactly one endpoint without overlapping."
  (or
    (instant= (interval-end a) (interval-start b))
    (instant= (interval-end b) (interval-start a))))

(defun interval-connected-p (a b)
  "Whether A and B overlap or abut without a positive gap."
  (or (interval-overlaps-p a b) (interval-abuts-p a b)))

(defun interval-before-p (a b)
  "Whether A ends at or before the inclusive start bound of B."
  (instant<= (interval-end a) (interval-start b)))

(defun interval-after-p (a b)
  "Whether A starts at or after the exclusive end bound of B."
  (instant>= (interval-start a) (interval-end b)))

(defun interval-intersection (a b)
  "Return the shared interval of A and B, or NIL when they do not overlap."
  (when (interval-overlaps-p a b)
    (make-interval
      (if (instant> (interval-start a) (interval-start b)) (interval-start a)
        (interval-start b))
      (if (instant< (interval-end a) (interval-end b)) (interval-end a)
        (interval-end b)))))

(defun interval-span (a b)
  "Return the smallest interval enclosing A and B, including any gap."
  (make-interval
    (if (instant< (interval-start a) (interval-start b)) (interval-start a)
      (interval-start b))
    (if (instant> (interval-end a) (interval-end b)) (interval-end a)
      (interval-end b))))

(defun interval-union (a b)
  "Return the contiguous union of A and B, or NIL when a positive gap separates them.

Empty intervals are preserved by the set semantics: an empty interval within or
at the boundary of another interval does not prevent a union."
  (unless (interval-gap a b)
    (interval-span a b)))

(defun interval-with-start (interval start)
  "Return INTERVAL with START as its new inclusive bound.\n\nSignals INVALID-INTERVAL when START is after the current end."
  (make-interval start (interval-end interval)))

(defun interval-with-end (interval end)
  "Return INTERVAL with END as its new exclusive bound.

Signals INVALID-INTERVAL when END is before the current start."
  (make-interval (interval-start interval) end))

(defun interval-difference (interval removed)
  "Return the ordered non-empty portions of INTERVAL outside REMOVED.\n\nThe result is a list containing zero, one, or two half-open intervals."
  (let ((shared (interval-intersection interval removed)))
    (if (and shared (not (interval-empty-p shared)))
      (remove
        nil
        (list
          (when (instant< (interval-start interval) (interval-start shared))
            (make-interval (interval-start interval) (interval-start shared)))
          (when (instant< (interval-end shared) (interval-end interval))
            (make-interval (interval-end shared) (interval-end interval)))))
      (unless (interval-empty-p interval)
        (list interval)))))

(defun interval-gap (a b)
    "Return the open separation between disjoint A and B, or NIL otherwise."
    (cond
      ((instant< (interval-end a) (interval-start b))
       (make-interval (interval-end a) (interval-start b)))
      ((instant< (interval-end b) (interval-start a))
       (make-interval (interval-end b) (interval-start a)))))

  (defstruct (local-date-interval (:constructor %make-local-date-interval (start end)))
    (start nil :type local-date :read-only t)
    (end nil :type local-date :read-only t))

  (defun make-local-date-interval (start end)
    "Construct the half-open local-date interval [START, END).

START and END must be LOCAL-DATE values. Empty intervals are valid; an END
before START signals INVALID-INTERVAL."
    (check-type start local-date)
    (check-type end local-date)
    (when (local-date> start end)
      (error 'invalid-interval :start start :end end))
    (%make-local-date-interval start end))

  (defun local-date-interval-empty-p (interval)
    "Whether INTERVAL contains no calendar dates."
    (local-date= (local-date-interval-start interval)
                 (local-date-interval-end interval)))

(defun map-local-date-interval (function interval)
  "Call FUNCTION for each date in INTERVAL, stopping when it returns NIL.

Dates are supplied in ascending order from the inclusive start through the
exclusive end.  Returns NIL when exhausted or stopped."
  (check-type interval local-date-interval)
  (loop
    for date = (local-date-interval-start interval)
      then (local-date-plus-days date 1)
    while (local-date< date (local-date-interval-end interval))
    unless (funcall function date)
      do (return nil)
    finally (return nil)))

(defmacro do-local-date-interval ((variable interval &key result) &body body)
  "Iterate VARIABLE over INTERVAL in ascending date order.

RESULT is returned after normal completion; RETURN exits the iteration."
  `(block nil
     (map-local-date-interval
      (lambda (,variable)
        ,@body
        t)
      ,interval)
     ,result))

  (defun local-date-interval-contains-p (interval date)
    "Whether DATE belongs to the half-open [START, END) bounds of INTERVAL."
    (check-type date local-date)
    (and (local-date<= (local-date-interval-start interval) date)
         (local-date< date (local-date-interval-end interval))))

  (defun local-date-interval-encloses-p (outer inner)
    "Whether OUTER contains every calendar date in INNER."
    (and (local-date<= (local-date-interval-start outer)
                          (local-date-interval-start inner))
         (local-date<= (local-date-interval-end inner)
                          (local-date-interval-end outer))))

  (defun local-date-interval-overlaps-p (a b)
    "Whether non-empty intervals A and B share at least one calendar date."
    (and (local-date< (local-date-interval-start a) (local-date-interval-end b))
         (local-date< (local-date-interval-start b) (local-date-interval-end a))))

  (defun local-date-interval-abuts-p (a b)
    "Whether A and B meet at exactly one endpoint without overlapping."
    (or (local-date= (local-date-interval-end a)
                     (local-date-interval-start b))
        (local-date= (local-date-interval-end b)
                     (local-date-interval-start a))))

  (defun local-date-interval-connected-p (a b)
    "Whether A and B overlap or abut without a positive gap."
    (or (local-date-interval-overlaps-p a b)
        (local-date-interval-abuts-p a b)))

  (defun local-date-interval-before-p (a b)
    "Whether A ends at or before the inclusive start bound of B."
    (local-date<= (local-date-interval-end a)
                  (local-date-interval-start b)))

  (defun local-date-interval-after-p (a b)
    "Whether A starts at or after the exclusive end bound of B."
    (local-date>= (local-date-interval-start a)
                  (local-date-interval-end b)))

  (defun local-date-interval-intersection (a b)
    "Return the shared interval of A and B, or NIL when they do not overlap."
    (when (local-date-interval-overlaps-p a b)
      (make-local-date-interval
       (if (local-date> (local-date-interval-start a)
                         (local-date-interval-start b))
           (local-date-interval-start a)
           (local-date-interval-start b))
       (if (local-date< (local-date-interval-end a)
                         (local-date-interval-end b))
           (local-date-interval-end a)
           (local-date-interval-end b)))))

  (defun local-date-interval-span (a b)
    "Return the smallest interval enclosing A and B, including any gap."
    (make-local-date-interval
     (if (local-date< (local-date-interval-start a)
                       (local-date-interval-start b))
         (local-date-interval-start a)
         (local-date-interval-start b))
     (if (local-date> (local-date-interval-end a)
                       (local-date-interval-end b))
         (local-date-interval-end a)
         (local-date-interval-end b))))

  (defun local-date-interval-union (a b)
    "Return the contiguous union of A and B, or NIL when a positive gap separates them."
    (unless (local-date-interval-gap a b)
      (local-date-interval-span a b)))

  (defun local-date-interval-with-start (interval start)
    "Return INTERVAL with START as its new inclusive bound."
    (make-local-date-interval start (local-date-interval-end interval)))

  (defun local-date-interval-with-end (interval end)
    "Return INTERVAL with END as its new exclusive bound."
    (make-local-date-interval (local-date-interval-start interval) end))

  (defun local-date-interval-difference (interval removed)
    "Return the ordered non-empty portions of INTERVAL outside REMOVED."
    (let ((shared (local-date-interval-intersection interval removed)))
      (if (and shared (not (local-date-interval-empty-p shared)))
          (remove nil
                  (list
                   (when (local-date< (local-date-interval-start interval)
                                      (local-date-interval-start shared))
                     (make-local-date-interval (local-date-interval-start interval)
                                               (local-date-interval-start shared)))
                   (when (local-date< (local-date-interval-end shared)
                                      (local-date-interval-end interval))
                     (make-local-date-interval (local-date-interval-end shared)
                                               (local-date-interval-end interval)))))
          (unless (local-date-interval-empty-p interval)
            (list interval)))))

  (defun local-date-interval-gap (a b)
    "Return the open separation between disjoint A and B, or NIL otherwise."
    (cond
      ((local-date< (local-date-interval-end a) (local-date-interval-start b))
       (make-local-date-interval (local-date-interval-end a)
                                 (local-date-interval-start b)))
      ((local-date< (local-date-interval-end b) (local-date-interval-start a))
       (make-local-date-interval (local-date-interval-end b)
                                 (local-date-interval-start a)))))

  (defun local-date-interval-length-in-days (interval)
    "Return the non-negative number of dates covered by INTERVAL."
    (- (local-date-to-epoch-day (local-date-interval-end interval))
       (local-date-to-epoch-day (local-date-interval-start interval))))
