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

(defun zoned-date-time-of-local (local-date-time zone &key (disambiguation :compatible))
  "Resolves LOCAL-DATE-TIME against ZONE, shifting gap values to a valid wall time."
  (multiple-value-bind (kind offsets) (%classify-local-date-time local-date-time zone)
    (case kind
      (:normal (%make-zoned-date-time local-date-time zone (first offsets)))
      (:overlap
        (%make-zoned-date-time
          local-date-time
          zone
          (resolve-local-date-time local-date-time zone :disambiguation disambiguation)))
      (:gap
        (ecase disambiguation
          (:strict (resolve-local-date-time local-date-time zone :disambiguation :strict))
          ((:compatible :later)
            (let ((gap
                  (-
                    (zone-offset-total-seconds (second offsets))
                    (zone-offset-total-seconds (first offsets)))))
              (%make-zoned-date-time
                (local-date-time-plus-seconds local-date-time gap)
                zone
                (second offsets))))
          (:earlier
            (let ((gap
                  (-
                    (zone-offset-total-seconds (second offsets))
                    (zone-offset-total-seconds (first offsets)))))
              (%make-zoned-date-time
                (local-date-time-plus-seconds local-date-time (- gap))
                zone
                (first offsets)))))))))

(defun local-date-time-at-zone (local-date-time zone &key (disambiguation :compatible))
  "Resolves LOCAL-DATE-TIME in ZONE using DISAMBIGUATION."
  (zoned-date-time-of-local local-date-time zone :disambiguation disambiguation))

(defun zoned-date-time-of-instant (instant zone)
  (let ((offset (offset-for-instant zone instant)))
    (%make-zoned-date-time (local-date-time-of-instant instant offset) zone offset)))

(defun zoned-date-time-to-instant (zoned-date-time)
  (local-date-time-to-instant
    (zoned-date-time-local zoned-date-time)
    (zoned-date-time-offset zoned-date-time)))

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

(progn
  (defun zoned-date-time-with-zone-same-local (zoned-date-time new-zone &key (disambiguation :compatible))
    "Keeps the local wall-clock fields and resolves them in NEW-ZONE."
    (zoned-date-time-of-local
     (zoned-date-time-local zoned-date-time)
     new-zone
     :disambiguation
     disambiguation))

  (defun %zoned-date-time-with-local (zoned-date-time local)
    "Resolves LOCAL in the ZONED-DATE-TIME zone, retaining its offset when valid."
    (let* ((zone (zoned-date-time-zone zoned-date-time))
           (old-offset (zoned-date-time-offset zoned-date-time))
           (retained-offset
            (find
             (zone-offset-total-seconds old-offset)
             (possible-offsets-for-local-date-time local zone)
             :key #'zone-offset-total-seconds)))
      (if retained-offset
          (%make-zoned-date-time local zone retained-offset)
          (zoned-date-time-of-local local zone))))

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
      nanosecond))))(defun zoned-date-time-plus-duration (zoned-date-time d)
  (zoned-date-time-of-instant
    (instant-plus-duration (zoned-date-time-to-instant zoned-date-time) d)
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-minus-duration (zoned-date-time d)
  (zoned-date-time-plus-duration zoned-date-time (duration-negate d)))



(defun zoned-date-time-plus-nanos (zoned-date-time nanos)
  "Return ZONED-DATE-TIME advanced by signed NANOSECONDS on the absolute timeline."
  (zoned-date-time-of-instant
    (instant-plus-nanos (zoned-date-time-to-instant zoned-date-time) nanos)
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-plus-micros (zoned-date-time micros)
  "Return ZONED-DATE-TIME advanced by signed MICROSECONDS on the absolute timeline."
  (zoned-date-time-of-instant
    (instant-plus-micros (zoned-date-time-to-instant zoned-date-time) micros)
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-plus-millis (zoned-date-time millis)
  "Return ZONED-DATE-TIME advanced by signed MILLISECONDS on the absolute timeline."
  (zoned-date-time-of-instant
    (instant-plus-millis (zoned-date-time-to-instant zoned-date-time) millis)
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-plus-seconds (zoned-date-time seconds)
  "Return ZONED-DATE-TIME advanced by signed SECONDS on the absolute timeline."
  (zoned-date-time-of-instant
    (instant-plus-seconds (zoned-date-time-to-instant zoned-date-time) seconds)
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-plus-minutes (zoned-date-time minutes)
  "Return ZONED-DATE-TIME advanced by signed MINUTES on the absolute timeline."
  (zoned-date-time-of-instant
    (instant-plus-seconds (zoned-date-time-to-instant zoned-date-time) (* minutes 60))
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-plus-hours (zoned-date-time hours)
  "Return ZONED-DATE-TIME advanced by signed HOURS on the absolute timeline."
  (zoned-date-time-of-instant
    (instant-plus-seconds (zoned-date-time-to-instant zoned-date-time) (* hours 3600))
    (zoned-date-time-zone zoned-date-time)))

(defun zoned-date-time-minus-nanos (zoned-date-time nanos)
  (zoned-date-time-plus-nanos zoned-date-time (- nanos)))

(defun zoned-date-time-minus-micros (zoned-date-time micros)
  (zoned-date-time-plus-micros zoned-date-time (- micros)))

(defun zoned-date-time-minus-millis (zoned-date-time millis)
  (zoned-date-time-plus-millis zoned-date-time (- millis)))

(defun zoned-date-time-minus-seconds (zoned-date-time seconds)
  (zoned-date-time-plus-seconds zoned-date-time (- seconds)))

(defun zoned-date-time-minus-minutes (zoned-date-time minutes)
  (zoned-date-time-plus-minutes zoned-date-time (- minutes)))

(defun zoned-date-time-minus-hours (zoned-date-time hours)
  (zoned-date-time-plus-hours zoned-date-time (- hours)))

(defun zoned-date-time-plus-period (zoned-date-time period)
  "Adjusts local fields by PERIOD while retaining this value's offset when it
remains valid in the target local time."
  (%zoned-date-time-with-local
   zoned-date-time
   (local-date-time-plus-period (zoned-date-time-local zoned-date-time) period)))

(progn
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
    (zoned-date-time-plus-period zoned-date-time (period-negate p)))) (defmethod duration-between ((start zoned-date-time) (end zoned-date-time))
  (duration-between (zoned-date-time-to-instant start)
                    (zoned-date-time-to-instant end)))

(defun zoned-date-time-until (start end)
  "Returns the signed nanosecond-precision DURATION from START to END."
  (duration-between start end))(defun zoned-date-time-compare (a b)
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

(defun zoned-date-time-now (&key (zone (zone-offset-utc)) (clock (make-system-clock)))
  (zoned-date-time-of-instant (clock-now clock) zone))

(defun local-date-time-now (&key (zone (zone-offset-utc)) (clock (make-system-clock)))
  (zoned-date-time-local (zoned-date-time-now :zone zone :clock clock)))

(defun local-date-now (&key (zone (zone-offset-utc)) (clock (make-system-clock)))
  (local-date-time-date (local-date-time-now :zone zone :clock clock))) (defun zoned-date-time-truncated-to (zoned-date-time unit)
  "Returns ZONED-DATE-TIME with its local time truncated down to UNIT.
When the result is ambiguous, retains the original offset when it is valid."
  (check-type zoned-date-time zoned-date-time)
  (%zoned-date-time-with-local
   zoned-date-time
   (local-date-time-truncated-to
    (zoned-date-time-local zoned-date-time)
    unit)))
