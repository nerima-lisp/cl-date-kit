(in-package #:cl-date-kit/test)

(describe
  "FIXED-CLOCK"
  (it
    "CLOCK-NOW always returns the instant it was built with"
    (let ((clock (make-fixed-clock (make-instant 42 7))))
      (expect (instant= (clock-now clock) (make-instant 42 7)) :to-be-truthy)
      (expect (instant= (clock-now clock) (make-instant 42 7)) :to-be-truthy)))
  (it
    "ZONED-DATE-TIME-NOW and derived APIs use the supplied non-UTC zone and fixed clock"
    (let* ((clock (make-fixed-clock (make-instant 0 42)))
           (zone (find-time-zone "Asia/Tokyo"))
           (zoned-date-time (zoned-date-time-now :zone zone :clock clock))
           (local-date-time (local-date-time-now :zone zone :clock clock))
           (date (local-date-now :zone zone :clock clock)))
      (expect
        (instant= (zoned-date-time-to-instant zoned-date-time) (make-instant 0 42))
        :to-be-truthy)
      (expect (eq (zoned-date-time-zone zoned-date-time) zone) :to-be-truthy)
      (expect
        (zone-offset-total-seconds (zoned-date-time-offset zoned-date-time))
        :to-be 32400)
      (expect
        (local-date-time=
          (zoned-date-time-local zoned-date-time)
          (local-date-time-of 1970 1 1 9 0 0 42))
        :to-be-truthy)
      (expect
        (local-date-time= local-date-time (zoned-date-time-local zoned-date-time))
        :to-be-truthy)
      (expect (local-date= date (make-local-date 1970 1 1)) :to-be-truthy))))

(progn
  (describe
    "SYSTEM-CLOCK"
    (it
      "CLOCK-NOW returns a recent instant"
      (expect
        (> (instant-epoch-second (clock-now (make-system-clock))) 1700000000)
        :to-be-truthy))
    (it
      "INSTANT-NOW defaults to a system clock"
      (expect (> (instant-epoch-second (instant-now)) 1700000000) :to-be-truthy))
    (it
      "INSTANT-NOW accepts an explicit clock, e.g. a fixed one for deterministic tests"
      (expect
        (instant= (instant-now (make-fixed-clock (instant-epoch))) (instant-epoch))
        :to-be-truthy)))
  (describe
    "DERIVED-CLOCK"
    (it
      "MAKE-OFFSET-CLOCK applies the exact duration to its base"
      (let ((base (make-fixed-clock (make-instant 40 0)))
            (offset (duration-of-millis -500)))
        (expect
          (instant=
            (clock-now (make-offset-clock base offset))
            (make-instant 39 500000000))
          :to-be-truthy)))
    (it
      "MAKE-TICK-CLOCK floors subsecond and negative-epoch instants"
      (expect
        (instant=
          (clock-now
            (make-tick-clock
              (make-fixed-clock (make-instant 12 987654321))
              (duration-of-millis 250)))
          (make-instant 12 750000000))
        :to-be-truthy)
      (expect
        (instant=
          (clock-now
            (make-tick-clock
              (make-fixed-clock (make-instant -1 500000000))
              (duration-of-seconds 1)))
          (make-instant -1 0))
        :to-be-truthy))
    (it
      "derived clocks compose through CLOCK-NOW"
      (let* ((base (make-fixed-clock (make-instant 17 800000000)))
             (tick (make-tick-clock base (duration-of-seconds 1)))
             (clock (make-offset-clock tick (duration-of-seconds 2))))
        (expect (instant= (clock-now clock) (make-instant 19 0)) :to-be-truthy)))
    (it
      "MAKE-TICK-CLOCK rejects nonpositive durations"
      (signals type-error (make-tick-clock (make-system-clock) (duration-zero)))
      (signals
        type-error
        (make-tick-clock (make-system-clock) (duration-of-seconds -1))))
    (it
      "validates duration types and preserves exact tick boundaries"
      (signals type-error (make-offset-clock (make-system-clock) 1))
      (signals type-error (make-tick-clock (make-system-clock) 1))
      (expect
        (instant=
          (clock-now
            (make-tick-clock
              (make-fixed-clock (make-instant 10 500000000))
              (duration-of-millis 250)))
          (make-instant 10 500000000))
        :to-be-truthy)))
  (describe
    "CLOCK CONTEXT"
    (it
      "scopes implicit clocks through the function and macro APIs"
      (let ((clock (make-fixed-clock (make-instant 42 7))))
        (expect
          (eq (call-with-clock clock (function current-clock)) clock)
          :to-be-truthy)
        (with-clock
          (clock)
          (expect (eq (current-clock) clock) :to-be-truthy)
          (expect (instant= (instant-now) (make-instant 42 7)) :to-be-truthy)
          (with-clock
            ((make-fixed-clock (make-instant 99 0)))
            (expect (instant= (instant-now) (make-instant 99 0)) :to-be-truthy))
          (expect (instant= (instant-now) (make-instant 42 7)) :to-be-truthy))))
    (it
      "CALL-WITH-CLOCK requires a function"
      (signals type-error (call-with-clock (make-system-clock) 1)))))
