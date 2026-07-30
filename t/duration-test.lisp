;;;; t/duration-test.lisp
(in-package #:cl-date-kit/test)

(describe
  "duration constructors"
  (it
    "DURATION-OF-HOURS converts to seconds"
    (expect (duration-to-seconds (duration-of-hours 1)) :to-be 3600))
  (it
    "DURATION-OF-MILLIS normalizes a negative sub-second remainder into NANOS"
    (expect (duration-to-seconds (duration-of-millis -1500)) :to-be -3/2))
  (it
    "DURATION-ZERO has zero seconds and nanos"
    (expect (duration-zero-p (duration-zero)) :to-be-truthy))
  (it
    "rejects non-integral constructor arguments"
    (dolist (constructor
        (list
          (lambda ()
            (duration-of-nanos 1/2))
          (lambda ()
            (duration-of-seconds 1/2))
          (lambda ()
            (duration-of-seconds 1 1/2))
          (lambda ()
            (duration-of-millis 1/2))
          (lambda ()
            (duration-of-micros 1/2))
          (lambda ()
            (duration-of-minutes 1/2))
          (lambda ()
            (duration-of-hours 1/2))
          (lambda ()
            (duration-of-days 1/2))))
      (signals type-error (funcall constructor)))))

(describe
  "duration arithmetic"
  (it
    "replaces normalized duration fields without mutating the source value"
    (let ((duration (duration-of-nanos -1)))
      (expect
        (duration= (duration-with-seconds duration 3) (duration-of-seconds 3 999999999))
        :to-be-truthy)
      (expect
        (duration=
          (duration-with-nanos duration 123456789)
          (duration-of-seconds -1 123456789))
        :to-be-truthy)
      (expect (duration-seconds duration) :to-be -1)
      (expect (duration-nanos duration) :to-be 999999999)))
  (it
    "rejects non-integral or non-normalized duration field replacements"
    (signals type-error (duration-with-seconds (duration-zero) 1/2))
    (signals type-error (duration-with-nanos (duration-zero) 1/2))
    (signals type-error (duration-with-nanos (duration-zero) -1))
    (signals type-error (duration-with-nanos (duration-zero) 1000000000)))
  (it
    "DURATION-PLUS adds exactly, carrying nanos into seconds"
    (expect
      (duration-to-seconds
        (duration-plus
          (duration-of-seconds 1 700000000)
          (duration-of-seconds 1 700000000)))
      :to-be
      34/10))
  (it
    "DURATION-MINUS is the inverse of DURATION-PLUS"
    (let ((a (duration-of-seconds 5 250000000))
          (b (duration-of-seconds 2 500000000)))
      (expect (duration= (duration-minus (duration-plus a b) b) a) :to-be-truthy)))
  (it
    "adds and subtracts every supported fixed unit"
    (let ((zero (duration-zero)))
      (dolist (entry
          (list
            (list #'duration-plus-nanos #'duration-minus-nanos 1 (duration-of-nanos 1))
            (list #'duration-plus-micros #'duration-minus-micros 1 (duration-of-micros 1))
            (list #'duration-plus-millis #'duration-minus-millis 1 (duration-of-millis 1))
            (list
              #'duration-plus-seconds
              #'duration-minus-seconds
              1
              (duration-of-seconds 1))
            (list
              #'duration-plus-minutes
              #'duration-minus-minutes
              1
              (duration-of-minutes 1))
            (list #'duration-plus-hours #'duration-minus-hours 1 (duration-of-hours 1))
            (list #'duration-plus-days #'duration-minus-days 1 (duration-of-days 1))))
        (destructuring-bind (plus minus amount expected) entry
          (let ((advanced (funcall plus zero amount)))
            (expect (duration= advanced expected) :to-be-truthy)
            (expect (duration= (funcall minus advanced amount) zero) :to-be-truthy))))))
  (it
    "normalizes a negative subsecond result from unit arithmetic"
    (let ((duration (duration-minus-millis (duration-of-nanos 1) 1)))
      (expect (duration-seconds duration) :to-be -1)
      (expect (duration-nanos duration) :to-be 999000001)))
  (it
    "rejects non-integral fixed-unit amounts"
    (dolist (operation
        (list
          #'duration-plus-nanos
          #'duration-plus-micros
          #'duration-plus-millis
          #'duration-plus-seconds
          #'duration-plus-minutes
          #'duration-plus-hours
          #'duration-plus-days
          #'duration-minus-nanos
          #'duration-minus-micros
          #'duration-minus-millis
          #'duration-minus-seconds
          #'duration-minus-minutes
          #'duration-minus-hours
          #'duration-minus-days))
      (signals type-error (funcall operation (duration-zero) 1/2))))
  (it
    "DURATION-NEGATE flips the sign of a fractional duration"
    (expect
      (duration-to-seconds (duration-negate (duration-of-millis 1500)))
      :to-be
      -3/2))
  (it
    "DURATION-ABS is idempotent on an already-positive duration"
    (expect
      (duration= (duration-abs (duration-of-seconds 5)) (duration-of-seconds 5))
      :to-be-truthy))
  (it
    "DURATION-ABS negates a negative duration and fixed-unit arithmetic normalizes signed amounts"
    (expect
      (duration= (duration-abs (duration-of-seconds -5)) (duration-of-seconds 5))
      :to-be-truthy)
    (let ((base (duration-of-nanos 1)))
      (dolist (entry
          (list
            (list #'duration-plus-nanos #'duration-minus-nanos -1)
            (list #'duration-plus-micros #'duration-minus-micros -1)
            (list #'duration-plus-millis #'duration-minus-millis -1)
            (list #'duration-plus-seconds #'duration-minus-seconds -1)
            (list #'duration-plus-minutes #'duration-minus-minutes -1)
            (list #'duration-plus-hours #'duration-minus-hours -1)
            (list #'duration-plus-days #'duration-minus-days -1)))
        (destructuring-bind (plus minus amount) entry
          (let ((advanced (funcall plus base amount)))
            (expect
              (duration= advanced (funcall minus base (- amount)))
              :to-be-truthy)
            (expect (<= 0 (duration-nanos advanced)) :to-be-truthy)
            (expect (< (duration-nanos advanced) 1000000000) :to-be-truthy)))))))

(describe
  "duration predicates and ordering"
  (it
    "DURATION-NEGATIVE-P is true only for a negative duration"
    (expect (duration-negative-p (duration-of-seconds -1)) :to-be-truthy)
    (expect (duration-negative-p (duration-of-seconds 0)) :to-be nil)
    (expect (duration-negative-p (duration-of-seconds 1)) :to-be nil))
  (it
    "DURATION-POSITIVE-P is true only for a positive duration"
    (expect (duration-positive-p (duration-of-seconds 1)) :to-be-truthy)
    (expect (duration-positive-p (duration-of-seconds 0)) :to-be nil))
  (it
      "DURATION< / DURATION> / DURATION= agree with DURATION-COMPARE"
      (expect
        (duration< (duration-of-seconds 1) (duration-of-seconds 2))
        :to-be-truthy)
      (expect
        (duration> (duration-of-seconds 2) (duration-of-seconds 1))
        :to-be-truthy)
      (expect
        (duration= (duration-of-seconds 2) (duration-of-seconds 2))
        :to-be-truthy)
      (expect
        (duration<= (duration-of-seconds 2) (duration-of-seconds 2))
        :to-be-truthy)
      (expect
        (duration>= (duration-of-seconds 2) (duration-of-seconds 2))
        :to-be-truthy))
    (it
      "compares arbitrary-size durations lexicographically"
      (let ((large-seconds (expt 10 100)))
        (dolist
            (comparison
             (list
              (list (duration-of-seconds large-seconds)
                    (duration-of-seconds large-seconds 1)
                    -1)
              (list (duration-of-seconds -1 999999999)
                    (duration-zero)
                    -1)
              (list (duration-of-seconds large-seconds 7)
                    (duration-of-seconds large-seconds 7)
                    0)))
          (expect
            (duration-compare (first comparison) (second comparison))
            :to-be (third comparison))))))

(it
  "signals a structured condition for zero divisors"
  (let* ((duration (duration-of-seconds 1))
         (condition
        (handler-case (duration-divided-by duration 0)
          (invalid-duration-division (signaled)
            signaled))))
    (expect (typep condition (quote invalid-duration-division)) :to-be-truthy)
    (expect (invalid-duration-division-duration condition) :to-be duration)
    (expect (invalid-duration-division-divisor condition) :to-be 0))
  (signals type-error (duration-multiplied-by (duration-of-seconds 1) 1/2)))

(describe
  "duration microsecond conversions"
  (it
    "round-trips integers and truncates fractional microseconds toward zero"
    (dolist (value (list -1501 -1 0 1 1501))
      (expect (duration-to-micros (duration-of-micros value)) :to-be value))
    (expect (duration-to-micros (duration-of-nanos -1501)) :to-be -1)
    (expect (duration-to-micros (duration-of-nanos 1501)) :to-be 1)))

(describe
  "duration component conversions"
  (it "decomposes positive durations into fixed and subsecond parts")
  (it
    "keeps whole-unit parts signed and subsecond parts normalized"
    (let ((duration
           (duration-of-seconds
            (- (+ (* 2 86400) (* 3 3600) (* 4 60) 5))
            678901234)))
      (expect (duration-to-days-part duration) :to-be -2)
      (expect (duration-to-hours-part duration) :to-be -3)
      (expect (duration-to-minutes-part duration) :to-be -4)
      (expect (duration-to-seconds-part duration) :to-be -5)
      (expect (duration-to-millis-part duration) :to-be 678)
      (expect (duration-to-micros-part duration) :to-be 678901)
      (expect (duration-to-nanos-part duration) :to-be 678901234)))
  (it
    "uses the normalized second field for negative subsecond durations"
    (let ((duration (duration-of-nanos -1)))
      (expect (duration-to-days-part duration) :to-be 0)
      (expect (duration-to-hours-part duration) :to-be 0)
      (expect (duration-to-minutes-part duration) :to-be 0)
      (expect (duration-to-seconds-part duration) :to-be -1)
      (expect (duration-to-millis-part duration) :to-be 999)
      (expect (duration-to-micros-part duration) :to-be 999999)
      (expect (duration-to-nanos-part duration) :to-be 999999999))))

(describe
  "duration truncation"
  (it
    "truncates positive durations to a supported fixed unit"
    (expect
      (duration=
       (duration-truncated-to (duration-of-seconds 3661 987654321) :minutes)
       (duration-of-seconds 3660))
      :to-be-truthy))
  (it
    "truncates negative durations toward zero"
    (expect
      (duration=
       (duration-truncated-to (duration-of-nanos -1500123456) :millis)
       (duration-of-millis -1500))
      :to-be-truthy)
    (expect
      (duration=
       (duration-truncated-to (duration-of-nanos -1) :seconds)
       (duration-zero))
      :to-be-truthy))
  (it
    "truncates arbitrary-size durations without composing total nanos"
    (let ((large-seconds (expt 10 100)))
      (expect
        (duration=
         (duration-truncated-to
          (duration-of-seconds large-seconds 999999999)
          :minutes)
         (duration-of-seconds (* (truncate large-seconds 60) 60)))
        :to-be-truthy)))
  (it
    "rejects unsupported truncation units"
    (signals type-error (duration-truncated-to (duration-of-seconds 1) :weeks))))

(progn
  (describe
    "DURATION-BETWEEN generic protocol"
    (it
      "uses local or absolute timelines according to the concrete temporal type"
      (flet ((expect-one-second (start end)
         (expect
          (duration= (duration-between start end) (duration-of-seconds 1))
          :to-be-truthy)))
  (expect-one-second (make-instant 1 0) (make-instant 2 0))
  (expect-one-second (make-local-time 12 0 0) (make-local-time 12 0 1))
  (expect-one-second
   (local-date-time-of 2024 1 1 23 59 59)
   (local-date-time-of 2024 1 2 0 0 0))
  (expect-one-second
   (offset-time-of 9 0 0 0 (zone-offset-of-hours 9))
   (offset-time-of 0 0 1 0 (zone-offset-utc)))
  (expect-one-second
   (cl-date-kit:offset-date-time-of 2024 1 2 0 0 0 0 (zone-offset-of-hours 9))
   (cl-date-kit:offset-date-time-of 2024 1 1 15 0 1 0 (zone-offset-utc)))
  (expect-one-second
   (zoned-date-time-of-local
    (local-date-time-of 2024 1 2 0 0 0)
    (zone-offset-of-hours 9))
   (zoned-date-time-of-local
    (local-date-time-of 2024 1 1 15 0 1)
    (zone-offset-utc))))))
  (describe
   "fixed-unit rounding"
   (it
    "rounds signed values according to directed modes"
    (let ((positive (duration-of-millis 1600))
          (negative (duration-of-millis -1600)))
      (expect (duration= (cl-date-kit:duration-rounded-to positive :seconds :mode :floor)
                         (duration-of-seconds 1)) :to-be-truthy)
      (expect (duration= (cl-date-kit:duration-rounded-to positive :seconds :mode :ceiling)
                         (duration-of-seconds 2)) :to-be-truthy)
      (expect (duration= (cl-date-kit:duration-rounded-to negative :seconds :mode :toward-zero)
                         (duration-of-seconds -1)) :to-be-truthy)
      (expect (duration= (cl-date-kit:duration-rounded-to negative :seconds :mode :away-from-zero)
                         (duration-of-seconds -2)) :to-be-truthy)))
   (it
    "uses the documented tie rules"
    (expect (duration= (cl-date-kit:duration-rounded-to (duration-of-millis 1500) :seconds :mode :half-up)
                       (duration-of-seconds 2)) :to-be-truthy)
    (expect (duration= (cl-date-kit:duration-rounded-to (duration-of-millis -1500) :seconds :mode :half-up)
                       (duration-of-seconds -2)) :to-be-truthy)
    (expect (duration= (cl-date-kit:duration-rounded-to (duration-of-millis 2500) :seconds :mode :half-even)
                       (duration-of-seconds 2)) :to-be-truthy)
    (expect (duration= (cl-date-kit:duration-rounded-to (duration-of-millis -2500) :seconds :mode :half-even)
                       (duration-of-seconds -2)) :to-be-truthy))
   (it
    "preserves exact multiples and rejects invalid modes"
    (dolist (mode (quote (:floor :ceiling :toward-zero :away-from-zero :half-up :half-even)))
      (expect (duration= (cl-date-kit:duration-rounded-to (duration-of-seconds -2) :seconds :mode mode)
                         (duration-of-seconds -2)) :to-be-truthy))
    (signals type-error
      (cl-date-kit:duration-rounded-to (duration-of-seconds 1) :seconds :mode :nearest)))))
