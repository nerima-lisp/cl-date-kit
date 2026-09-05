(in-package #:cl-date-kit)

(defparameter +rrule-frequencies+ '(:secondly :minutely :hourly :daily :weekly :monthly :yearly))

(defparameter +rrule-weekdays+ '(:mo :tu :we :th :fr :sa :su))

(defun %invalid-rrule (reason &optional value)
  (error 'invalid-rrule :reason reason :value value))

(defstruct (rrule-by-day (:constructor %make-rrule-by-day (weekday ordinal))) (weekday nil :type keyword :read-only t)
  (ordinal nil :type (or null integer) :read-only t))

(defun make-rrule-by-day (weekday &optional ordinal)
  "Construct one RFC 5545 BYDAY item.

WEEKDAY is one of :MO through :SU.  ORDINAL is NIL or a nonzero integer from
  -53 through 53."
  (unless (member weekday +rrule-weekdays+)
    (%invalid-rrule "weekday must be one of :MO through :SU" weekday))
  (when ordinal
    (unless (and (integerp ordinal) (<= -53 ordinal 53) (not (zerop ordinal)))
      (%invalid-rrule
        "BYDAY ordinal must be a nonzero integer from -53 through 53"
        ordinal)))
  (%make-rrule-by-day weekday ordinal))

(defstruct (rrule
    (:constructor
      %make-rrule
      (frequency
        interval
        count
        until
        week-start
        by-second
        by-minute
        by-hour
        by-day
        by-month-day
        by-year-day
        by-week-no
        by-month
        by-set-pos))) (frequency nil :type keyword :read-only t)
  (interval 1 :type (integer 1 *) :read-only t)
  (count nil :type (or null (integer 1 *)) :read-only t)
  (until nil :read-only t)
  (week-start :mo :type keyword :read-only t)
  (by-second nil :type list :read-only t)
  (by-minute nil :type list :read-only t)
  (by-hour nil :type list :read-only t)
  (by-day nil :type list :read-only t)
  (by-month-day nil :type list :read-only t)
  (by-year-day nil :type list :read-only t)
  (by-week-no nil :type list :read-only t)
  (by-month nil :type list :read-only t)
  (by-set-pos nil :type list :read-only t))

(defun %rrule-copy-list (value name predicate &key canonicalize)
  "Validate, copy, and optionally canonicalize one RRULE BY* list."
  (labels ((copy-values (values)
             (unless (every predicate values)
          (%invalid-rrule (format nil "~A contains an invalid value" name) values))
             (let ((copy (copy-list values)))
          (if canonicalize (sort (remove-duplicates copy) (function <))
            copy))))
    (cond
      ((null value) nil)
      ((listp value) (copy-values value))
      ((vectorp value) (copy-values (coerce value (quote list))))
      (t (%invalid-rrule (format nil "~A must be a list or vector" name) value)))))

(defun %rrule-integer-range-p (minimum maximum &key (allow-zero t))
  (lambda (value)
    (and
      (integerp value)
      (<= minimum value maximum)
      (or allow-zero (not (zerop value))))))

(defun make-rrule (&key
    frequency
    (interval 1)
    count
    until
    (week-start :mo)
    by-second
    by-minute
    by-hour
    by-day
    by-month-day
    by-year-day
    by-week-no
    by-month
    by-set-pos)
  "Construct an immutable RFC 5545 recurrence rule.

The BY* arguments accept lists or vectors. COUNT and UNTIL are mutually
exclusive, as required by RFC 5545 section 3.3.10."
  (unless (member frequency +rrule-frequencies+)
    (%invalid-rrule "FREQ must be one of the RFC 5545 frequencies" frequency))
  (unless (and (integerp interval) (plusp interval))
    (%invalid-rrule "INTERVAL must be a positive integer" interval))
  (when count
    (unless (and (integerp count) (plusp count))
      (%invalid-rrule "COUNT must be a positive integer" count)))
  (when (and count until)
    (%invalid-rrule "COUNT and UNTIL are mutually exclusive"))
  (when until
    (unless (or (local-date-p until) (local-date-time-p until) (instant-p until))
      (%invalid-rrule "UNTIL must be a local date, local date-time, or instant" until)))
  (unless (member week-start +rrule-weekdays+)
    (%invalid-rrule "WKST must be one of :MO through :SU" week-start))
  (when by-week-no
    (unless (eq frequency :yearly)
      (%invalid-rrule "BYWEEKNO is valid only with FREQ=YEARLY" by-week-no)))
  (let ((by-day-values (%rrule-copy-list by-day "BYDAY" (function rrule-by-day-p))))
    (when (some (function rrule-by-day-ordinal) by-day-values)
      (unless (member frequency '(:monthly :yearly))
        (%invalid-rrule
          "ordinal BYDAY values are valid only with FREQ=MONTHLY or YEARLY"
          by-day-values))
      (when (and (eq frequency :yearly) by-week-no)
        (%invalid-rrule
          "ordinal BYDAY values cannot be combined with BYWEEKNO in a yearly RRULE"
          by-day-values)))
    (%make-rrule
      frequency
      interval
      count
      until
      week-start
      (%rrule-copy-list
        by-second
        "BYSECOND"
        (%rrule-integer-range-p 0 59)
        :canonicalize
        t)
      (%rrule-copy-list
        by-minute
        "BYMINUTE"
        (%rrule-integer-range-p 0 59)
        :canonicalize
        t)
      (%rrule-copy-list
        by-hour
        "BYHOUR"
        (%rrule-integer-range-p 0 23)
        :canonicalize
        t)
      by-day-values
      (%rrule-copy-list
        by-month-day
        "BYMONTHDAY"
        (%rrule-integer-range-p -31 31 :allow-zero nil)
        :canonicalize
        t)
      (%rrule-copy-list
        by-year-day
        "BYYEARDAY"
        (%rrule-integer-range-p -366 366 :allow-zero nil)
        :canonicalize
        t)
      (%rrule-copy-list
        by-week-no
        "BYWEEKNO"
        (%rrule-integer-range-p -53 53 :allow-zero nil)
        :canonicalize
        t)
      (%rrule-copy-list
        by-month
        "BYMONTH"
        (%rrule-integer-range-p 1 12)
        :canonicalize
        t)
      (%rrule-copy-list
        by-set-pos
        "BYSETPOS"
        (%rrule-integer-range-p -366 366 :allow-zero nil)
        :canonicalize
        t))))

(defstruct (rrule-schedule (:constructor %make-rrule-schedule (dtstart rrule))) (dtstart nil :read-only t)
  (rrule nil :type rrule :read-only t))

(defun make-rrule-schedule (dtstart rrule)
  "Pair DTSTART with an RRULE without defining recurrence evaluation policy."
  (unless (or
      (zoned-date-time-p dtstart)
      (local-date-time-p dtstart)
      (local-date-p dtstart))
    (%invalid-rrule
      "DTSTART must be a zoned date-time, local date-time, or local date"
      dtstart))
  (check-type rrule rrule)
  (let ((until (rrule-until rrule)))
    (cond
      ((local-date-p dtstart)
        (when (and until (not (local-date-p until)))
          (%invalid-rrule "a DATE DTSTART requires a local date UNTIL" until))
        (when (member (rrule-frequency rrule) '(:secondly :minutely :hourly))
          (%invalid-rrule "a DATE DTSTART does not support sub-daily FREQ" rrule))
        (when (or (rrule-by-hour rrule) (rrule-by-minute rrule) (rrule-by-second rrule))
          (%invalid-rrule
            "a DATE DTSTART does not support BYHOUR, BYMINUTE, or BYSECOND"
            rrule)))
      ((local-date-time-p dtstart)
        (when (and until (not (local-date-time-p until)))
          (%invalid-rrule "a floating DTSTART requires a local date-time UNTIL" until)))
      (t
        (let* ((zone (zoned-date-time-zone dtstart))
               (utc-dtstart-p
              (or
                (and (zone-offset-p zone) (zerop (zone-offset-total-seconds zone)))
                (and
                  (time-zone-p zone)
                  (member (time-zone-name zone) '("UTC" "Etc/UTC") :test #'string=)))))
          (when until
            (if utc-dtstart-p (unless (instant-p until)
                (%invalid-rrule "a UTC DTSTART requires an instant UNTIL" until))
              (unless (local-date-time-p until)
                (%invalid-rrule "a non-UTC DTSTART requires a local date-time UNTIL" until))))))))
  (%make-rrule-schedule dtstart rrule))
