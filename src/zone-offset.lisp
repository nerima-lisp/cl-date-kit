;;;; Fixed UTC-offset and time-zone transition value types.

(in-package #:cl-date-kit)

;;; --- Fixed offsets -----------------------------------------------------
(defstruct (zone-offset (:constructor %make-zone-offset (total-seconds))) (total-seconds 0 :type integer :read-only t))

(defstruct (zone-transition (:constructor %make-zone-transition (instant offset-before offset-after)))
  (instant nil :type instant :read-only t)
  (offset-before nil :type zone-offset :read-only t)
  (offset-after nil :type zone-offset :read-only t))

(defun zone-offset-of-hours (hours)
  (zone-offset-of-hms hours 0 0))

(defun zone-offset-of-hms (hours minutes seconds)
  "Constructs a validated ISO-8601 UTC offset in the inclusive range -18:00 to +18:00."
  (flet ((invalid ()
           (error
          (quote invalid-zone-offset)
          :hours
          hours
          :minutes
          minutes
          :seconds
          seconds)))
    (unless (and
        (integerp hours)
        (integerp minutes)
        (integerp seconds)
        (<= -18 hours 18)
        (<= -59 minutes 59)
        (<= -59 seconds 59)
        (or (zerop hours) (zerop minutes) (= (signum hours) (signum minutes)))
        (or (zerop hours) (zerop seconds) (= (signum hours) (signum seconds)))
        (or (zerop minutes) (zerop seconds) (= (signum minutes) (signum seconds))))
      (invalid))
    (when (and (= (abs hours) 18) (or (not (zerop minutes)) (not (zerop seconds))))
      (invalid))
    (%make-zone-offset (+ (* hours 3600) (* minutes 60) seconds))))

(defun zone-offset-of-total-seconds (total-seconds) "Constructs a validated ISO-8601 UTC offset from TOTAL-SECONDS in the inclusive range -64800 to +64800." (unless (integerp total-seconds) (error (quote invalid-zone-offset) :hours total-seconds :minutes 0 :seconds 0)) (let ((sign (signum total-seconds))) (multiple-value-bind (hours remainder) (floor (abs total-seconds) 3600) (multiple-value-bind (minutes seconds) (floor remainder 60) (zone-offset-of-hms (* sign hours) (* sign minutes) (* sign seconds))))))

(defun zone-offset-utc ()
  (%make-zone-offset 0))

(progn (defun zone-offset-compare (a b) "-1, 0, or 1 as fixed offset A is less than, equal to, or greater than B." (let ((delta (- (zone-offset-total-seconds a) (zone-offset-total-seconds b)))) (cond ((minusp delta) -1) ((plusp delta) 1) (t 0)))) (defun zone-offset= (a b) (zerop (zone-offset-compare a b))) (defun zone-offset< (a b) (minusp (zone-offset-compare a b))) (defun zone-offset<= (a b) (not (plusp (zone-offset-compare a b)))) (defun zone-offset> (a b) (plusp (zone-offset-compare a b))) (defun zone-offset>= (a b) (not (minusp (zone-offset-compare a b)))))
