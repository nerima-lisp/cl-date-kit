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

(defun interval-intersection (a b)
  "Return the shared interval of A and B, or NIL when they do not overlap."
  (when (interval-overlaps-p a b)
    (make-interval
      (if (instant> (interval-start a) (interval-start b)) (interval-start a)
        (interval-start b))
      (if (instant< (interval-end a) (interval-end b)) (interval-end a)
        (interval-end b)))))

(progn
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
      (interval-span a b))))

(defun interval-with-start (interval start)
  "Return INTERVAL with START as its new inclusive bound.\n\nSignals INVALID-INTERVAL when START is after the current end."
  (make-interval start (interval-end interval)))

(defun interval-with-end (interval end)
  "Return INTERVAL with END as its new exclusive bound.\n\nSignals INVALID-INTERVAL when END is before the current start."
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
