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

(defstruct (instant (:constructor %make-instant (epoch-second nanosecond))) (epoch-second 0 :type integer :read-only t)
  (nanosecond 0 :type (integer 0 999999999) :read-only t))

(defun make-instant (epoch-second &optional (nanosecond 0))
  (multiple-value-bind (extra-seconds normalized-nanos) (floor nanosecond +nanos-per-second+)
    (%make-instant (+ epoch-second extra-seconds) normalized-nanos)))

(defun instant-epoch ()
  (%make-instant 0 0))

(progn
  (defconstant +unix-epoch-universal-time+ 2208988800)
  (defun instant-to-universal-time (instant)
    "Return the Common Lisp universal-time for a whole-second INSTANT.

Signals INSTANT-PRECISION-LOSS when INSTANT has nonzero nanoseconds because
universal time cannot represent subsecond precision."
    (check-type instant instant)
    (unless (zerop (instant-nanosecond instant))
      (error
        (quote instant-precision-loss)
        :instant
        instant
        :representation
        :universal-time))
    (+ (instant-epoch-second instant) +unix-epoch-universal-time+)))

(progn
  (defun instant-of-epoch-nanos (epoch-nanos)
    (check-type epoch-nanos integer)
    (multiple-value-bind (seconds nanos) (floor epoch-nanos 1000000000)
      (%make-instant seconds nanos)))
  (defun instant-of-epoch-second (epoch-second &optional (nanosecond-adjustment 0))
    "Construct an INSTANT from Unix EPOCH-SECOND and a nanosecond adjustment."
    (check-type epoch-second integer)
    (check-type nanosecond-adjustment integer)
    (make-instant epoch-second nanosecond-adjustment)))

(defun instant-of-epoch-millis (epoch-millis)
  "Construct an INSTANT from an integer Unix-epoch millisecond count."
  (check-type epoch-millis integer)
  (multiple-value-bind (seconds millis) (floor epoch-millis 1000)
    (%make-instant seconds (* millis 1000000))))

(defun instant-of-epoch-micros (epoch-micros)
  "Construct an INSTANT from an integer Unix-epoch microsecond count."
  (check-type epoch-micros integer)
  (multiple-value-bind (seconds micros) (floor epoch-micros 1000000)
    (%make-instant seconds (* micros 1000))))

(defun instant-to-epoch-nanos (instant)
  "Return the exact integer Unix-epoch nanosecond count for INSTANT."
  (+ (* (instant-epoch-second instant) 1000000000) (instant-nanosecond instant)))

(defun instant-to-epoch-millis (instant)
  "Return the integer epoch millisecond containing INSTANT.

Sub-millisecond values round down on the UTC timeline."
  (+
    (* (instant-epoch-second instant) 1000)
    (floor (instant-nanosecond instant) 1000000)))

(defun instant-to-epoch-micros (instant)
  "Return the integer epoch microsecond containing INSTANT.

Sub-microsecond values round down on the UTC timeline."
  (+
    (* (instant-epoch-second instant) 1000000)
    (floor (instant-nanosecond instant) 1000)))

(defun instant-at-zone (instant zone)
  "Return a ZONED-DATE-TIME representing INSTANT in ZONE."
  (zoned-date-time-of-instant instant zone))

(defun instant-at-offset (instant offset)
  "Return an OFFSET-DATE-TIME representing INSTANT with OFFSET."
  (offset-date-time-of-instant instant offset))

(progn
  (defun %instant-plus-components (instant seconds nanos)
    "Adds signed second and nanosecond components without intermediate instances."
    (multiple-value-bind (extra-seconds normalized-nanos) (floor (+ (instant-nanosecond instant) nanos) +nanos-per-second+)
      (%make-instant
        (+ (instant-epoch-second instant) seconds extra-seconds)
        normalized-nanos)))
  (defmacro define-instant-fixed-unit-arithmetic (plus-name
      minus-name
      amount
      seconds-factor
      nanos-factor
      plus-documentation
      minus-documentation)
    `(progn
      (defun ,plus-name (instant ,amount)
        ,plus-documentation
        (check-type ,amount integer)
        (%instant-plus-components
          instant
          (* ,amount ,seconds-factor)
          (* ,amount ,nanos-factor)))
      (defun ,minus-name (instant ,amount)
        ,minus-documentation
        (check-type ,amount integer)
        (%instant-plus-components
          instant
          (* (- ,amount) ,seconds-factor)
          (* (- ,amount) ,nanos-factor)))))
  (define-instant-fixed-unit-arithmetic
    instant-plus-nanos
    instant-minus-nanos
    nanos
    0
    1
    "Return INSTANT advanced by the signed integer NANOSECONDS."
    "Return INSTANT moved backward by the signed integer NANOSECONDS.")
  (define-instant-fixed-unit-arithmetic
    instant-plus-micros
    instant-minus-micros
    micros
    0
    1000
    "Return INSTANT advanced by the signed integer MICROSECONDS."
    "Return INSTANT moved backward by the signed integer MICROSECONDS.")
  (define-instant-fixed-unit-arithmetic
    instant-plus-millis
    instant-minus-millis
    millis
    0
    1000000
    "Return INSTANT advanced by the signed integer MILLISECONDS."
    "Return INSTANT moved backward by the signed integer MILLISECONDS.")
  (define-instant-fixed-unit-arithmetic
    instant-plus-seconds
    instant-minus-seconds
    seconds
    1
    0
    "Return INSTANT advanced by the signed integer SECONDS."
    "Return INSTANT moved backward by the signed integer SECONDS.")
  (define-instant-fixed-unit-arithmetic
    instant-plus-minutes
    instant-minus-minutes
    minutes
    60
    0
    "Return INSTANT advanced by the signed integer MINUTES."
    "Return INSTANT moved backward by the signed integer MINUTES.")
  (define-instant-fixed-unit-arithmetic
    instant-plus-hours
    instant-minus-hours
    hours
    3600
    0
    "Return INSTANT advanced by the signed integer HOURS."
    "Return INSTANT moved backward by the signed integer HOURS.")
  (define-instant-fixed-unit-arithmetic
    instant-plus-days
    instant-minus-days
    days
    86400
    0
    "Return INSTANT advanced by the signed integer 24-hour DAYS."
    "Return INSTANT moved backward by the signed integer 24-hour DAYS."))

(progn
  (defun instant-plus-duration (instant d)
    (%instant-plus-components instant (duration-seconds d) (duration-nanos d)))
  (defun instant-minus-duration (instant d)
    (%instant-plus-components
      instant
      (- (duration-seconds d))
      (- (duration-nanos d))))
  (defmethod duration-between ((start instant) (end instant))
    (duration-of-seconds
      (- (instant-epoch-second end) (instant-epoch-second start))
      (- (instant-nanosecond end) (instant-nanosecond start)))))

(defun instant-until (start end)
  "The exact DURATION from START to END."
  (duration-between start end))

(defun instant-compare (a b)
  (cond
    ((< (instant-epoch-second a) (instant-epoch-second b)) -1)
    ((> (instant-epoch-second a) (instant-epoch-second b)) 1)
    ((< (instant-nanosecond a) (instant-nanosecond b)) -1)
    ((> (instant-nanosecond a) (instant-nanosecond b)) 1)
    (t 0)))

(defun instant= (a b)
  (zerop (instant-compare a b)))

(defun instant< (a b)
  (minusp (instant-compare a b)))

(defun instant<= (a b)
  (not (plusp (instant-compare a b))))

(defun instant> (a b)
  (plusp (instant-compare a b)))

(defun instant>= (a b)
  (not (minusp (instant-compare a b))))

(progn
  (defun %instant-truncated-to-unit (instant unit-nanos)
    (let ((seconds (instant-epoch-second instant))
          (nanos (instant-nanosecond instant)))
      (if (<= unit-nanos +nanos-per-second+) (%make-instant seconds (* (floor nanos unit-nanos) unit-nanos))
        (let ((seconds-per-unit (truncate unit-nanos +nanos-per-second+)))
          (%make-instant (* (floor seconds seconds-per-unit) seconds-per-unit) 0)))))
  (defun instant-truncated-to (instant unit)
    "Returns INSTANT truncated down to fixed-width UNIT on the UTC timeline."
    (check-type instant instant)
    (%instant-truncated-to-unit instant (%fixed-unit-nanos unit)))
  (defun instant-rounded-to (instant unit &key (mode :half-even))
    "Return INSTANT rounded to fixed-width UNIT on the UTC timeline.

MODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO,
:HALF-UP, or :HALF-EVEN.  :HALF-EVEN is the default."
    (check-type instant instant)
    (multiple-value-bind (seconds nanos) (floor
        (%round-fixed-unit-nanos
          (+
            (* (instant-epoch-second instant) +nanos-per-second+)
            (instant-nanosecond instant))
          (%fixed-unit-nanos unit)
          mode)
        +nanos-per-second+)
      (make-instant seconds nanos))))
