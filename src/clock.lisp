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

(defstruct (fixed-clock (:constructor make-fixed-clock (instant))) (instant nil :type instant :read-only t))

(defmethod clock-now ((clock fixed-clock))
  (fixed-clock-instant clock))

(progn
  (defparameter *system-clock* (make-system-clock))
  (defvar *clock* nil)

  (defun current-clock ()
    "Return the dynamically scoped clock, or the shared system clock."
    (or *clock* *system-clock*))

  (defun call-with-clock (clock function)
    "Call FUNCTION while CLOCK provides the implicit current time."
    (check-type function function)
    (let ((*clock* clock))
      (funcall function)))

  (defmacro with-clock ((clock) &body body)
    "Evaluate BODY with CLOCK as the dynamically scoped current clock."
    `(call-with-clock ,clock (lambda () ,@body)))

  (defun instant-now (&optional (clock (current-clock)))
    (clock-now clock))

  (defstruct (offset-clock (:constructor %make-offset-clock (base-clock offset)))
    (base-clock nil :read-only t)
    (offset nil :type duration :read-only t))

  (defun make-offset-clock (base-clock offset)
    "Return a clock that applies OFFSET to BASE-CLOCK."
    (check-type offset duration)
    (%make-offset-clock base-clock offset))

  (defmethod clock-now ((clock offset-clock))
    (instant-plus-duration
      (clock-now (offset-clock-base-clock clock))
      (offset-clock-offset clock)))

  (defstruct (tick-clock (:constructor %make-tick-clock (base-clock duration)))
    (base-clock nil :read-only t)
    (duration nil :type duration :read-only t))

  (defun make-tick-clock (base-clock duration)
    "Return a clock that rounds BASE-CLOCK down to positive fixed DURATION ticks."
    (check-type duration duration)
    (unless (duration-positive-p duration)
      (error
        (quote type-error)
        :datum duration
        :expected-type (quote (satisfies duration-positive-p))))
    (%make-tick-clock base-clock duration))

  (defun %truncate-instant-to-duration (instant duration)
    (let* ((tick-nanos (duration-to-nanos duration))
           (total-nanos
             (+
               (* (instant-epoch-second instant) +nanos-per-second+)
               (instant-nanosecond instant)))
           (truncated-nanos (* (floor total-nanos tick-nanos) tick-nanos)))
      (multiple-value-bind (seconds nanos)
          (floor truncated-nanos +nanos-per-second+)
        (make-instant seconds nanos))))

  (defmethod clock-now ((clock tick-clock))
    (%truncate-instant-to-duration
      (clock-now (tick-clock-base-clock clock))
      (tick-clock-duration clock)))
)
