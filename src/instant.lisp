;;;; src/instant.lisp
;;;;
;;;; INSTANT is an absolute point on the UTC timeline: java.time's Instant,
;;;; Temporal's Instant, the value inside Go's time.Time and Rust's
;;;; SystemTime. Represented as EPOCH-SECOND (signed, seconds since the Unix
;;;; epoch 1970-01-01T00:00:00Z) plus NANOSECOND in [0, 999999999], the same
;;;; split DURATION uses. Using the Unix epoch rather than CL's native
;;;; 1900-01-01 universal-time epoch keeps every INSTANT-EPOCH-SECOND
;;;; directly comparable with every other modern language's timestamps.
(in-package #:cl-date-kit)

(defstruct (instant (:constructor %make-instant (epoch-second nanosecond)))
  (epoch-second 0 :type integer :read-only t)
  (nanosecond 0 :type (integer 0 999999999) :read-only t))

(defun make-instant (epoch-second &optional (nanosecond 0))
  (multiple-value-bind (extra-seconds normalized-nanos) (floor nanosecond +nanos-per-second+)
    (%make-instant (+ epoch-second extra-seconds) normalized-nanos)))

(defun instant-epoch () (%make-instant 0 0))

(defun instant-plus-duration (instant d)
  (make-instant (+ (instant-epoch-second instant) (duration-seconds d))
                (+ (instant-nanosecond instant) (duration-nanos d))))

(defun instant-minus-duration (instant d) (instant-plus-duration instant (duration-negate d)))

(defun instant-until (start end)
  "The exact DURATION from START to END."
  (duration-of-seconds (- (instant-epoch-second end) (instant-epoch-second start))
                        (- (instant-nanosecond end) (instant-nanosecond start))))

(defun instant-compare (a b)
  (let ((delta (- (+ (* (instant-epoch-second a) +nanos-per-second+) (instant-nanosecond a))
                   (+ (* (instant-epoch-second b) +nanos-per-second+) (instant-nanosecond b)))))
    (cond ((minusp delta) -1) ((plusp delta) 1) (t 0))))

(defun instant= (a b) (zerop (instant-compare a b)))
(defun instant< (a b) (minusp (instant-compare a b)))
(defun instant<= (a b) (not (plusp (instant-compare a b))))
(defun instant> (a b) (plusp (instant-compare a b)))
(defun instant>= (a b) (not (minusp (instant-compare a b))))
