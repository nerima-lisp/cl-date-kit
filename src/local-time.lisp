;;;; src/local-time.lisp
;;;;
;;;; LOCAL-TIME is a wall-clock time of day with no date or zone: java.time's
;;;; LocalTime, Temporal's PlainTime. Like all four reference libraries, leap
;;;; seconds are not modeled -- SECOND always runs 0-59.
(in-package #:cl-date-kit)

(defconstant +seconds-per-day+ 86400)

(defstruct (local-time (:constructor %make-local-time (hour minute second nanosecond)))
  (hour 0 :type (integer 0 23) :read-only t)
  (minute 0 :type (integer 0 59) :read-only t)
  (second 0 :type (integer 0 59) :read-only t)
  (nanosecond 0 :type (integer 0 999999999) :read-only t))

(defun make-local-time (hour minute second &optional (nanosecond 0))
  (unless (and (<= 0 hour 23) (<= 0 minute 59) (<= 0 second 59) (<= 0 nanosecond 999999999))
    (error 'invalid-time :hour hour :minute minute :second second :nanosecond nanosecond))
  (%make-local-time hour minute second nanosecond))

(defun local-time-midnight () (%make-local-time 0 0 0 0))
(defun local-time-noon () (%make-local-time 12 0 0 0))

(defun local-time-to-second-of-day (time)
  (+ (* (local-time-hour time) 3600) (* (local-time-minute time) 60) (local-time-second time)))

(defun local-time-of-second-of-day (second-of-day &optional (nanosecond 0)) (unless (and (integerp second-of-day) (<= 0 second-of-day (1- +seconds-per-day+)) (integerp nanosecond) (<= 0 nanosecond (1- +nanos-per-second+))) (error (quote invalid-time) :hour 0 :minute 0 :second second-of-day :nanosecond nanosecond)) (multiple-value-bind (hour remainder) (floor second-of-day 3600) (multiple-value-bind (minute second) (floor remainder 60) (make-local-time hour minute second nanosecond))))

(defun %local-time-plus-nanos-total (time delta-nanos)
  "Adds DELTA-NANOS nanoseconds to TIME, wrapping around midnight (LocalTime
arithmetic never carries into a date, matching java.time)."
  (let* ((total-nanos (+ (* (local-time-to-second-of-day time) +nanos-per-second+) (local-time-nanosecond time)))
         (day-nanos (* +seconds-per-day+ +nanos-per-second+))
         (wrapped (mod (+ total-nanos delta-nanos) day-nanos)))
    (multiple-value-bind (second-of-day nanosecond) (floor wrapped +nanos-per-second+)
      (local-time-of-second-of-day second-of-day nanosecond))))

(defun local-time-plus-nanos (time n) (%local-time-plus-nanos-total time n))
(defun local-time-minus-nanos (time n) (%local-time-plus-nanos-total time (- n)))
(defun local-time-plus-seconds (time n) (%local-time-plus-nanos-total time (* n +nanos-per-second+)))
(defun local-time-minus-seconds (time n) (local-time-plus-seconds time (- n)))
(defun local-time-plus-minutes (time n) (local-time-plus-seconds time (* n 60)))
(defun local-time-minus-minutes (time n) (local-time-plus-seconds time (* n -60)))
(defun local-time-plus-hours (time n) (local-time-plus-seconds time (* n 3600)))
(defun local-time-minus-hours (time n) (local-time-plus-seconds time (* n -3600)))

(defun local-time-compare (a b)
  (let ((delta (- (+ (* (local-time-to-second-of-day a) +nanos-per-second+) (local-time-nanosecond a))
                   (+ (* (local-time-to-second-of-day b) +nanos-per-second+) (local-time-nanosecond b)))))
    (cond ((minusp delta) -1) ((plusp delta) 1) (t 0))))

(defun local-time= (a b) (zerop (local-time-compare a b)))
(defun local-time< (a b) (minusp (local-time-compare a b)))
(defun local-time<= (a b) (not (plusp (local-time-compare a b))))
(defun local-time> (a b) (plusp (local-time-compare a b)))
(defun local-time>= (a b) (not (minusp (local-time-compare a b))))
