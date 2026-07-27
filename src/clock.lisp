;;;; src/clock.lisp
;;;;
;;;; CLOCK is a boundary protocol for where "now" comes from: java.time's
;;;; Clock, the fake-clock convention used for testing in Go and elsewhere.
;;;; It is the one place in CL-DATE-KIT that dispatches with DEFGENERIC --
;;;; every other type in this library is a plain DEFSTRUCT with named
;;;; functions, matching how the rest of nerima-lisp is written, but swapping
;;;; the source of "now" for a fixed value in tests is exactly the kind of
;;;; boundary CL-BOUNDARY-KIT's protocols exist for.
(in-package #:cl-date-kit)

(defgeneric clock-now (clock)
  (:documentation "The current INSTANT according to CLOCK."))

(defstruct system-clock)

(defmethod clock-now ((clock system-clock))
  (declare (ignore clock))
  (multiple-value-bind (epoch-second microsecond) (sb-ext:get-time-of-day)
    (make-instant epoch-second (* microsecond 1000))))

(defstruct (fixed-clock (:constructor make-fixed-clock (instant)))
  (instant nil :type instant :read-only t))

(defmethod clock-now ((clock fixed-clock))
  (fixed-clock-instant clock))

(defun instant-now (&optional (clock (make-system-clock)))
  (clock-now clock))
