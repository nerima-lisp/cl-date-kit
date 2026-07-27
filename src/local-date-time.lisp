;;;; src/local-date-time.lisp
;;;;
;;;; LOCAL-DATE-TIME pairs a LOCAL-DATE with a LOCAL-TIME: java.time's
;;;; LocalDateTime, Temporal's PlainDateTime. Still no zone -- arithmetic that
;;;; crosses midnight carries into the date, unlike LOCAL-TIME alone.
(in-package #:cl-date-kit)

(defstruct (local-date-time (:constructor %make-local-date-time (date time)))
  (date nil :type local-date :read-only t)
  (time nil :type local-time :read-only t))

(defun make-local-date-time (date time) (%make-local-date-time date time))

(defun local-date-time-of (year month day hour minute second &optional (nanosecond 0))
  (%make-local-date-time (make-local-date year month day) (make-local-time hour minute second nanosecond)))

(defun local-date-time-year (dt) (local-date-year (local-date-time-date dt)))
(defun local-date-time-month (dt) (local-date-month (local-date-time-date dt)))
(defun local-date-time-day (dt) (local-date-day (local-date-time-date dt)))
(defun local-date-time-hour (dt) (local-time-hour (local-date-time-time dt)))
(defun local-date-time-minute (dt) (local-time-minute (local-date-time-time dt)))
(defun local-date-time-second (dt) (local-time-second (local-date-time-time dt)))
(defun local-date-time-nanosecond (dt) (local-time-nanosecond (local-date-time-time dt)))

(defun local-date-time-plus-days (dt n) (%make-local-date-time (local-date-plus-days (local-date-time-date dt) n) (local-date-time-time dt)))
(defun local-date-time-minus-days (dt n) (local-date-time-plus-days dt (- n)))
(defun local-date-time-plus-weeks (dt n) (local-date-time-plus-days dt (* n 7)))
(defun local-date-time-minus-weeks (dt n) (local-date-time-plus-days dt (* n -7)))
(defun local-date-time-plus-months (dt n) (%make-local-date-time (local-date-plus-months (local-date-time-date dt) n) (local-date-time-time dt)))
(defun local-date-time-minus-months (dt n) (local-date-time-plus-months dt (- n)))
(defun local-date-time-plus-years (dt n) (local-date-time-plus-months dt (* n 12)))
(defun local-date-time-minus-years (dt n) (local-date-time-plus-months dt (* n -12)))

(defun %local-date-time-plus-nanos-total (dt delta-nanos)
  "Adds DELTA-NANOS nanoseconds, carrying whole days into the date -- the
piece LOCAL-TIME-PLUS-NANOS deliberately does not do."
  (let* ((day-nanos (* +seconds-per-day+ +nanos-per-second+))
         (time-nanos (+ (* (local-time-to-second-of-day (local-date-time-time dt)) +nanos-per-second+)
                         (local-time-nanosecond (local-date-time-time dt)))))
    (multiple-value-bind (day-delta wrapped) (floor (+ time-nanos delta-nanos) day-nanos)
      (multiple-value-bind (second-of-day nanosecond) (floor wrapped +nanos-per-second+)
        (%make-local-date-time (local-date-plus-days (local-date-time-date dt) day-delta)
                                (local-time-of-second-of-day second-of-day nanosecond))))))

(defun local-date-time-plus-nanos (dt n) (%local-date-time-plus-nanos-total dt n))
(defun local-date-time-minus-nanos (dt n) (%local-date-time-plus-nanos-total dt (- n)))
(defun local-date-time-plus-seconds (dt n) (%local-date-time-plus-nanos-total dt (* n +nanos-per-second+)))
(defun local-date-time-minus-seconds (dt n) (local-date-time-plus-seconds dt (- n)))
(defun local-date-time-plus-minutes (dt n) (local-date-time-plus-seconds dt (* n 60)))
(defun local-date-time-minus-minutes (dt n) (local-date-time-plus-seconds dt (* n -60)))
(defun local-date-time-plus-hours (dt n) (local-date-time-plus-seconds dt (* n 3600)))
(defun local-date-time-minus-hours (dt n) (local-date-time-plus-seconds dt (* n -3600)))

(defun local-date-time-plus-duration (dt d)
  (local-date-time-plus-nanos (local-date-time-plus-seconds dt (duration-seconds d)) (duration-nanos d)))
(defun local-date-time-minus-duration (dt d) (local-date-time-plus-duration dt (duration-negate d)))

(defun local-date-time-plus-period (dt p) (%make-local-date-time (local-date-plus-period (local-date-time-date dt) p) (local-date-time-time dt)))
(defun local-date-time-minus-period (dt p) (%make-local-date-time (local-date-minus-period (local-date-time-date dt) p) (local-date-time-time dt)))

(defun local-date-time-compare (a b)
  (let ((date-cmp (local-date-compare (local-date-time-date a) (local-date-time-date b))))
    (if (zerop date-cmp) (local-time-compare (local-date-time-time a) (local-date-time-time b)) date-cmp)))

(defun local-date-time= (a b) (zerop (local-date-time-compare a b)))
(defun local-date-time< (a b) (minusp (local-date-time-compare a b)))
(defun local-date-time<= (a b) (not (plusp (local-date-time-compare a b))))
(defun local-date-time> (a b) (plusp (local-date-time-compare a b)))
(defun local-date-time>= (a b) (not (minusp (local-date-time-compare a b))))
