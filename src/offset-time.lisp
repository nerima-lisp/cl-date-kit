;;;; src/offset-time.lisp
;;;;
;;;; OFFSET-TIME pairs a LOCAL-TIME with a fixed UTC offset.  It intentionally
;;;; has no date, so it cannot identify an INSTANT by itself.
(in-package #:cl-date-kit)

(defstruct (offset-time
            (:constructor %make-offset-time (local-time offset)))
  (local-time nil :type local-time :read-only t)
  (offset nil :type zone-offset :read-only t))

(defun make-offset-time (local-time offset)
  (check-type local-time local-time)
  (check-type offset zone-offset)
  (%make-offset-time local-time offset))

(defun offset-time-of (hour minute second &optional (nanosecond 0) (offset (zone-offset-utc)))
  (make-offset-time (make-local-time hour minute second nanosecond) offset))

(defun offset-time-of-instant (instant offset)
  (make-offset-time
   (local-date-time-time (%instant-to-local-date-time instant offset))
   offset))

(defun offset-time-time (offset-time)
  (offset-time-local-time offset-time))

(defun offset-time-hour (offset-time)
  (local-time-hour (offset-time-local-time offset-time)))

(defun offset-time-minute (offset-time)
  (local-time-minute (offset-time-local-time offset-time)))

(defun offset-time-second (offset-time)
  (local-time-second (offset-time-local-time offset-time)))

(defun offset-time-nanosecond (offset-time)
  (local-time-nanosecond (offset-time-local-time offset-time)))

(defun offset-time-with-offset-same-instant (offset-time offset)
  "Changes OFFSET while preserving the equivalent UTC time of day."
  (make-offset-time
   (local-time-plus-seconds
    (offset-time-local-time offset-time)
    (- (zone-offset-total-seconds offset)
       (zone-offset-total-seconds (offset-time-offset offset-time))))
   offset))

(defun offset-time-with-offset-same-local (offset-time offset)
  (make-offset-time (offset-time-local-time offset-time) offset))

(defun offset-time-plus-duration (offset-time duration)
  (make-offset-time
   (local-time-plus-nanos (offset-time-local-time offset-time)
                          (duration-to-nanos duration))
   (offset-time-offset offset-time)))

(defun offset-time-minus-duration (offset-time duration)
  (offset-time-plus-duration offset-time (duration-negate duration)))

(defun %offset-time-utc-time (offset-time)
  (local-time-minus-seconds
   (offset-time-local-time offset-time)
   (zone-offset-total-seconds (offset-time-offset offset-time))))

(defun offset-time-compare (a b)
  "Orders by UTC time of day, then local time to retain a total ordering."
  (let ((utc-comparison
         (local-time-compare (%offset-time-utc-time a) (%offset-time-utc-time b))))
    (if (zerop utc-comparison)
        (local-time-compare (offset-time-local-time a) (offset-time-local-time b))
        utc-comparison)))

(defun offset-time= (a b)
  (zerop (offset-time-compare a b)))

(defun offset-time< (a b)
  (minusp (offset-time-compare a b)))

(defun offset-time<= (a b)
  (not (plusp (offset-time-compare a b))))

(defun offset-time> (a b)
  (plusp (offset-time-compare a b)))

(defun offset-time>= (a b)
  (not (minusp (offset-time-compare a b))))

(defun offset-time-now (&key (offset (zone-offset-utc)) (clock (make-system-clock)))
  (offset-time-of-instant (clock-now clock) offset))
