;;;; src/zoned-date-time.lisp
;;;;
;;;; ZONED-DATE-TIME pairs a LOCAL-DATE-TIME with a ZONE (fixed offset or
;;;; IANA time zone) and the ZONE-OFFSET that local date-time resolved to:
;;;; java.time's ZonedDateTime, Temporal's ZonedDateTime, the type behind
;;;; chrono-tz's DateTime<Tz>. This is the "real-world timestamp" type; the
;;;; others in this library are its building blocks.
(in-package #:cl-date-kit)

(defstruct (zoned-date-time (:constructor %make-zoned-date-time (local zone offset))) (local nil :type local-date-time :read-only t)
  (zone nil :read-only t)
  (offset nil :type zone-offset :read-only t))

(defun zoned-date-time-of-local (local-date-time zone &key (disambiguation :compatible) preferred-offset)
  "Resolves LOCAL-DATE-TIME against ZONE, shifting gap values to a valid wall time."
  (check-type preferred-offset (or null zone-offset))
  (check-type disambiguation (member :compatible :earlier :later :strict))
  (multiple-value-bind (kind first-offset second-offset)
      (%classify-local-date-time local-date-time zone)
    (let ((preferred-zone-offset
           (and
            preferred-offset
            (cond
              ((= (zone-offset-total-seconds preferred-offset)
                  (zone-offset-total-seconds first-offset))
               first-offset)
              ((and
                second-offset
                (= (zone-offset-total-seconds preferred-offset)
                   (zone-offset-total-seconds second-offset)))
               second-offset)))))
      (case kind
        (:normal
         (%make-zoned-date-time local-date-time zone
                                (or preferred-zone-offset first-offset)))
        (:overlap
         (%make-zoned-date-time
          local-date-time zone
          (or preferred-zone-offset
              (ecase disambiguation
                ((:compatible :earlier) first-offset)
                (:later second-offset)
                (:strict
                 (error (quote ambiguous-local-time)
                        :local-date-time local-date-time
                        :zone zone
                        :earlier-offset first-offset
                        :later-offset second-offset))))))
        (:gap
         (ecase disambiguation
           (:strict
            (error (quote nonexistent-local-time)
                   :local-date-time local-date-time
                   :zone zone))
           ((:compatible :later)
            (let ((gap (- (zone-offset-total-seconds second-offset)
                          (zone-offset-total-seconds first-offset))))
              (%make-zoned-date-time
               (local-date-time-plus-seconds local-date-time gap)
               zone second-offset)))
           (:earlier
            (let ((gap (- (zone-offset-total-seconds second-offset)
                          (zone-offset-total-seconds first-offset))))
              (%make-zoned-date-time
               (local-date-time-plus-seconds local-date-time (- gap))
               zone first-offset)))))))))

(defun zoned-date-time-of-strict (local-date-time offset zone)
  "Constructs a ZONED-DATE-TIME only when OFFSET is valid in ZONE."
  (check-type local-date-time local-date-time)
  (check-type offset zone-offset)
  (check-type zone (or time-zone zone-offset))
  (multiple-value-bind (kind first-offset second-offset)
      (%classify-local-date-time local-date-time zone)
    (let* ((offset-seconds (zone-offset-total-seconds offset))
           (resolved-offset
            (case kind
              (:normal
               (and (= offset-seconds
                       (zone-offset-total-seconds first-offset))
                    first-offset))
              (:overlap
               (cond
                 ((= offset-seconds (zone-offset-total-seconds first-offset))
                  first-offset)
                 ((and second-offset
                       (= offset-seconds
                          (zone-offset-total-seconds second-offset)))
                  second-offset)))
              (:gap nil))))
      (if resolved-offset
          (%make-zoned-date-time local-date-time zone resolved-offset)
          (error
           (quote invalid-zoned-date-time-offset)
           :local-date-time local-date-time
           :offset offset
           :zone zone)))))

(defun local-date-time-at-zone (local-date-time zone &key (disambiguation :compatible) preferred-offset)
  "Resolves LOCAL-DATE-TIME in ZONE using DISAMBIGUATION."
  (zoned-date-time-of-local
    local-date-time
    zone
    :disambiguation
    disambiguation
    :preferred-offset
    preferred-offset))

(defun zoned-date-time-of-instant (instant zone)
  (let ((offset (offset-for-instant zone instant)))
    (%make-zoned-date-time (local-date-time-of-instant instant offset) zone offset)))

(defun zoned-date-time-to-instant (zoned-date-time)
  (local-date-time-to-instant
    (zoned-date-time-local zoned-date-time)
    (zoned-date-time-offset zoned-date-time)))

(defun zoned-date-time-to-offset-date-time (zoned-date-time)
  "Snapshots ZONED-DATE-TIME as an OFFSET-DATE-TIME, discarding zone rules."
  (make-offset-date-time
    (zoned-date-time-local zoned-date-time)
    (zoned-date-time-offset zoned-date-time)))

(progn
  (defun zoned-date-time-with-fixed-offset-zone (zoned-date-time)
    "Returns ZONED-DATE-TIME with its resolved offset as a fixed zone."
    (zoned-date-time-of-strict
     (zoned-date-time-local zoned-date-time)
     (zoned-date-time-offset zoned-date-time)
     (zoned-date-time-offset zoned-date-time)))

  (defun %zoned-date-time-with-offset-at-overlap (zoned-date-time position)
  (multiple-value-bind (kind first-offset second-offset)
      (%classify-local-date-time
       (zoned-date-time-local zoned-date-time)
       (zoned-date-time-zone zoned-date-time))
    (if (eq kind :overlap)
        (%make-zoned-date-time
         (zoned-date-time-local zoned-date-time)
         (zoned-date-time-zone zoned-date-time)
         (ecase position
           (:earlier first-offset)
           (:later second-offset)))
        zoned-date-time))))

(defun zoned-date-time-with-earlier-offset-at-overlap (zoned-date-time)
  "Returns ZONED-DATE-TIME at its earlier instant when its local time overlaps."
  (%zoned-date-time-with-offset-at-overlap zoned-date-time :earlier))

(defun zoned-date-time-with-later-offset-at-overlap (zoned-date-time)
  "Returns ZONED-DATE-TIME at its later instant when its local time overlaps."
  (%zoned-date-time-with-offset-at-overlap zoned-date-time :later))

(defun zoned-date-time-of-epoch-second (epoch-second nanosecond zone)
  "Construct a ZONED-DATE-TIME from Unix epoch fields in ZONE."
  (zoned-date-time-of-instant (make-instant epoch-second nanosecond) zone))

(defun zoned-date-time-to-epoch-second (zoned-date-time)
  "Return the Unix epoch-second represented by ZONED-DATE-TIME."
  (instant-epoch-second (zoned-date-time-to-instant zoned-date-time)))

(defun zoned-date-time-date (zoned-date-time)
  "Returns the local calendar date component of ZONED-DATE-TIME."
  (local-date-time-date (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-time (zoned-date-time)
  "Returns the local clock-time component of ZONED-DATE-TIME."
  (local-date-time-time (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-year (zoned-date-time)
  "Returns the local proleptic year component of ZONED-DATE-TIME."
  (local-date-time-year (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-month (zoned-date-time)
  "Returns the local month component of ZONED-DATE-TIME."
  (local-date-time-month (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-day (zoned-date-time)
  "Returns the local day-of-month component of ZONED-DATE-TIME."
  (local-date-time-day (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-hour (zoned-date-time)
  "Returns the local hour component of ZONED-DATE-TIME."
  (local-date-time-hour (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-minute (zoned-date-time)
  "Returns the local minute component of ZONED-DATE-TIME."
  (local-date-time-minute (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-second (zoned-date-time)
  "Returns the local second component of ZONED-DATE-TIME."
  (local-date-time-second (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-nanosecond (zoned-date-time)
  "Returns the local nanosecond component of ZONED-DATE-TIME."
  (local-date-time-nanosecond (zoned-date-time-local zoned-date-time)))

(defun zoned-date-time-with-zone-same-instant (zoned-date-time new-zone)
  "The same absolute INSTANT, re-expressed as a wall-clock reading in NEW-ZONE."
  (zoned-date-time-of-instant
    (zoned-date-time-to-instant zoned-date-time)
    new-zone))

(defun zoned-date-time-with-zone-same-local (zoned-date-time new-zone &key (disambiguation :compatible) preferred-offset)
  "Keeps the local wall-clock fields and resolves them in NEW-ZONE."
  (zoned-date-time-of-local
    (zoned-date-time-local zoned-date-time)
    new-zone
    :disambiguation
    disambiguation
    :preferred-offset
    preferred-offset))

(defun %zoned-date-time-with-local (zoned-date-time local)
  "Resolves LOCAL in the ZONED-DATE-TIME zone, retaining its offset when valid."
  (let* ((zone (zoned-date-time-zone zoned-date-time))
         (old-offset (zoned-date-time-offset zoned-date-time))
         (old-offset-seconds (zone-offset-total-seconds old-offset)))
    (multiple-value-bind (kind first-offset second-offset)
        (%classify-local-date-time local zone)
      (let ((retained-offset
             (case kind
               (:normal
                (and (= old-offset-seconds
                        (zone-offset-total-seconds first-offset))
                     first-offset))
               (:overlap
                (cond
                  ((= old-offset-seconds
                      (zone-offset-total-seconds first-offset))
                   first-offset)
                  ((and second-offset
                        (= old-offset-seconds
                           (zone-offset-total-seconds second-offset)))
                   second-offset)))
               (:gap nil))))
        (if retained-offset
            (%make-zoned-date-time local zone retained-offset)
            (zoned-date-time-of-local local zone))))))

(defun zoned-date-time-with-year (zoned-date-time year)
  "Returns ZONED-DATE-TIME with YEAR, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-year (zoned-date-time-local zoned-date-time) year)))

(defun zoned-date-time-with-month (zoned-date-time month)
  "Returns ZONED-DATE-TIME with MONTH, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-month (zoned-date-time-local zoned-date-time) month)))

(defun zoned-date-time-with-day (zoned-date-time day)
  "Returns ZONED-DATE-TIME with DAY, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-day (zoned-date-time-local zoned-date-time) day)))

(defun zoned-date-time-with-day-of-year (zoned-date-time day-of-year)
  "Returns ZONED-DATE-TIME with DAY-OF-YEAR, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-day-of-year
      (zoned-date-time-local zoned-date-time)
      day-of-year)))

(defun zoned-date-time-with-hour (zoned-date-time hour)
  "Returns ZONED-DATE-TIME with HOUR, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-hour (zoned-date-time-local zoned-date-time) hour)))

(defun zoned-date-time-with-minute (zoned-date-time minute)
  "Returns ZONED-DATE-TIME with MINUTE, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-minute (zoned-date-time-local zoned-date-time) minute)))

(defun zoned-date-time-with-second (zoned-date-time second)
  "Returns ZONED-DATE-TIME with SECOND, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-second (zoned-date-time-local zoned-date-time) second)))

(defun zoned-date-time-with-nanosecond (zoned-date-time nanosecond)
  "Returns ZONED-DATE-TIME with NANOSECOND, resolved in its existing zone."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-with-nanosecond
      (zoned-date-time-local zoned-date-time)
      nanosecond)))

(defun zoned-date-time-plus-duration (zoned-date-time d)
  (zoned-date-time-of-instant
    (instant-plus-duration (zoned-date-time-to-instant zoned-date-time) d)
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-minus-duration (zoned-date-time d)
  (zoned-date-time-plus-duration zoned-date-time (duration-negate d)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro define-zoned-date-time-timeline-unit (unit instant-operation unit-description)
    (let* ((unit-name (symbol-name unit))
           (plus-name (intern (format nil "ZONED-DATE-TIME-PLUS-~A" unit-name)))
           (minus-name (intern (format nil "ZONED-DATE-TIME-MINUS-~A" unit-name))))
      `(progn
        (defun ,plus-name (zoned-date-time ,unit)
          ,(format
            nil
            "Return ZONED-DATE-TIME advanced by signed ~A on the absolute timeline."
            unit-description)
          (zoned-date-time-of-instant
            (,instant-operation (zoned-date-time-to-instant zoned-date-time) ,unit)
            (zoned-date-time-zone zoned-date-time)))
        (defun ,minus-name (zoned-date-time ,unit)
          (,plus-name zoned-date-time (- ,unit)))))))

(progn
  (define-zoned-date-time-timeline-unit nanos instant-plus-nanos "NANOSECONDS")
  (define-zoned-date-time-timeline-unit micros instant-plus-micros "MICROSECONDS")
  (define-zoned-date-time-timeline-unit millis instant-plus-millis "MILLISECONDS")
  (define-zoned-date-time-timeline-unit seconds instant-plus-seconds "SECONDS")
  (define-zoned-date-time-timeline-unit minutes instant-plus-minutes "MINUTES")
  (define-zoned-date-time-timeline-unit hours instant-plus-hours "HOURS"))

(defun zoned-date-time-plus-period (zoned-date-time period)
  "Adjusts local fields by PERIOD while retaining this value's offset when it
remains valid in the target local time."
  (%zoned-date-time-with-local
    zoned-date-time
    (local-date-time-plus-period (zoned-date-time-local zoned-date-time) period)))

(defun zoned-date-time-plus-days (zoned-date-time days)
  "Return ZONED-DATE-TIME with DAYS added on its local calendar."
  (check-type days integer)
  (zoned-date-time-plus-period zoned-date-time (period-of-days days)))

(defun zoned-date-time-minus-days (zoned-date-time days)
  "Return ZONED-DATE-TIME with DAYS subtracted on its local calendar."
  (zoned-date-time-plus-days zoned-date-time (- days)))

(defun zoned-date-time-plus-weeks (zoned-date-time weeks)
  "Return ZONED-DATE-TIME with WEEKS added on its local calendar."
  (check-type weeks integer)
  (zoned-date-time-plus-days zoned-date-time (* weeks 7)))

(defun zoned-date-time-minus-weeks (zoned-date-time weeks)
  "Return ZONED-DATE-TIME with WEEKS subtracted on its local calendar."
  (zoned-date-time-plus-weeks zoned-date-time (- weeks)))

(defun zoned-date-time-plus-months (zoned-date-time months)
  "Return ZONED-DATE-TIME with MONTHS added on its local calendar."
  (check-type months integer)
  (zoned-date-time-plus-period zoned-date-time (period-of-months months)))

(defun zoned-date-time-minus-months (zoned-date-time months)
  "Return ZONED-DATE-TIME with MONTHS subtracted on its local calendar."
  (zoned-date-time-plus-months zoned-date-time (- months)))

(defun zoned-date-time-plus-years (zoned-date-time years)
  "Return ZONED-DATE-TIME with YEARS added on its local calendar."
  (check-type years integer)
  (zoned-date-time-plus-period zoned-date-time (period-of-years years)))

(defun zoned-date-time-minus-years (zoned-date-time years)
  "Return ZONED-DATE-TIME with YEARS subtracted on its local calendar."
  (zoned-date-time-plus-years zoned-date-time (- years)))

(defun zoned-date-time-minus-period (zoned-date-time p)
  (zoned-date-time-plus-period zoned-date-time (period-negate p)))

(defmethod duration-between ((start zoned-date-time) (end zoned-date-time))
  (duration-between
    (zoned-date-time-to-instant start)
    (zoned-date-time-to-instant end)))

(defun zoned-date-time-until (start end)
  "Returns the signed nanosecond-precision DURATION from START to END."
  (duration-between start end))

(defun zoned-date-time-compare (a b)
  "Compares by absolute instant. Two ZONED-DATE-TIMEs in different zones that
name the same instant compare equal."
  (instant-compare (zoned-date-time-to-instant a) (zoned-date-time-to-instant b)))

(defun zoned-date-time= (a b)
  (zerop (zoned-date-time-compare a b)))

(defun zoned-date-time< (a b)
  (minusp (zoned-date-time-compare a b)))

(defun zoned-date-time<= (a b)
  (not (plusp (zoned-date-time-compare a b))))

(defun zoned-date-time> (a b)
  (plusp (zoned-date-time-compare a b)))

(defun zoned-date-time>= (a b)
  (not (minusp (zoned-date-time-compare a b))))

(defun zoned-date-time-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  (zoned-date-time-of-instant (clock-now clock) zone))

(defun local-date-time-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  (zoned-date-time-local (zoned-date-time-now :zone zone :clock clock)))

(defun local-time-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  "Return the current local time in ZONE according to CLOCK."
  (local-date-time-time (local-date-time-now :zone zone :clock clock)))

(defun local-date-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  (local-date-time-date (local-date-time-now :zone zone :clock clock)))

(progn (defun zoned-date-time-truncated-to (zoned-date-time unit) "Returns ZONED-DATE-TIME with its local time truncated down to UNIT.\nWhen the result is ambiguous, retains the original offset when it is valid." (check-type zoned-date-time zoned-date-time) (%zoned-date-time-with-local zoned-date-time (local-date-time-truncated-to (zoned-date-time-local zoned-date-time) unit))) (defun zoned-date-time-rounded-to (zoned-date-time unit &key (mode :half-even)) "Return ZONED-DATE-TIME with its local time rounded to fixed-width UNIT.\n\nMODE is one of :FLOOR, :CEILING, :TOWARD-ZERO, :AWAY-FROM-ZERO, :HALF-UP,\nor :HALF-EVEN (the default). The rounded local time is resolved in the zone;\nwhen ambiguous, the original offset is retained when it remains valid." (check-type zoned-date-time zoned-date-time) (%zoned-date-time-with-local zoned-date-time (local-date-time-rounded-to (zoned-date-time-local zoned-date-time) unit :mode mode))))
