;;;; src/duration.lisp
;;;;
;;;; DURATION is an exact elapsed time: java.time's Duration, Rust's
;;;; std::time::Duration (but signed, like java.time), Go's time.Duration.
;;;; Represented as SECONDS (any sign) plus NANOS, always normalized to
;;;; [0, 999999999] and added to SECONDS -- the same split java.time uses, so
;;;; that -0.5s reads as (SECONDS -1, NANOS 500000000).
(in-package #:cl-date-kit)

(defstruct (duration (:constructor %make-duration (seconds nanos)))
  (seconds 0 :type integer :read-only t)
  (nanos 0 :type (integer 0 999999999) :read-only t))

(defconstant +nanos-per-second+ 1000000000)

(defun %normalize-duration (seconds nanos)
  (multiple-value-bind (extra-seconds normalized-nanos) (floor nanos +nanos-per-second+)
    (%make-duration (+ seconds extra-seconds) normalized-nanos)))

(defun duration-of-seconds (seconds &optional (nanos 0))
  "Build a DURATION of SECONDS seconds plus NANOS nanoseconds."
  (%normalize-duration seconds nanos))

(defun duration-of-millis (millis)
  (multiple-value-bind (seconds remainder-millis) (floor millis 1000)
    (%make-duration seconds (* remainder-millis 1000000))))

(defun duration-of-minutes (minutes)
  (%make-duration (* minutes 60) 0))

(defun duration-of-hours (hours)
  (%make-duration (* hours 3600) 0))

(defun duration-of-days (days)
  "Build a DURATION of exactly DAYS * 24 hours -- a fixed-length day, not a
calendar day. Use PERIOD-OF-DAYS when a daylight-saving-aware calendar day is
meant."
  (%make-duration (* days 86400) 0))

(defun duration-zero ()
  (%make-duration 0 0))

(defun duration-plus (a b)
  (%normalize-duration (+ (duration-seconds a) (duration-seconds b))
                        (+ (duration-nanos a) (duration-nanos b))))

(defun duration-negate (d)
  (%normalize-duration (- (duration-seconds d)) (- (duration-nanos d))))

(defun duration-minus (a b)
  (duration-plus a (duration-negate b)))

(defun duration-abs (d)
  (if (duration-negative-p d) (duration-negate d) d))

(defun duration-zero-p (d)
  (and (zerop (duration-seconds d)) (zerop (duration-nanos d))))

(defun duration-negative-p (d)
  (minusp (duration-seconds d)))

(defun duration-positive-p (d)
  (and (not (duration-negative-p d)) (not (duration-zero-p d))))

(defun duration-to-seconds (d)
  "The exact elapsed time in seconds, as a rational."
  (+ (duration-seconds d) (/ (duration-nanos d) +nanos-per-second+)))

(defun duration-compare (a b)
  "-1, 0, or 1 as A is less than, equal to, or greater than B."
  (let ((delta (- (duration-to-seconds a) (duration-to-seconds b))))
    (cond ((minusp delta) -1) ((plusp delta) 1) (t 0))))

(defun duration= (a b) (zerop (duration-compare a b)))
(defun duration< (a b) (minusp (duration-compare a b)))
(defun duration<= (a b) (not (plusp (duration-compare a b))))
(defun duration> (a b) (plusp (duration-compare a b)))
(defun duration>= (a b) (not (minusp (duration-compare a b))))
