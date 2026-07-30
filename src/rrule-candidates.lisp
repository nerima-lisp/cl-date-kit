;;;; src/rrule-candidates.lisp
;;;;
;;;; RFC 5545 recurrence expansion for DATE-TIME and DATE DTSTART values.
(in-package #:cl-date-kit)

(defun %rrule-week-one-start (year week-start)
  (let ((january-fourth (make-local-date year 1 4)))
    (%rrule-week-start january-fourth week-start)))

(defun %rrule-week-info (date week-start)
  (let* ((week-start-date (%rrule-week-start date week-start))
         (year (local-date-year (local-date-plus-days week-start-date 3)))
         (first (%rrule-week-one-start year week-start)))
    (values
      year
      (1+
        (floor
          (- (local-date-to-epoch-day week-start-date) (local-date-to-epoch-day first))
          7)))))

(defun %rrule-weeks-in-year (year week-start)
  (multiple-value-bind (week-year week) (%rrule-week-info (make-local-date year 12 28) week-start)
    (if (= week-year year) week
      52)))

(progn
  (defstruct (%rrule-day-selector
              (:constructor %make-rrule-day-selector
                  (month-bits
                   month-day-positive-bits
                   month-day-negative-bits
                   year-day-positive-bits
                   year-day-negative-bits
                   week-no-positive-bits
                   week-no-negative-bits
                   weekday-mask
                   ordinal-weekdays
                   week-start
                   month-scope)))
    month-bits
    month-day-positive-bits
    month-day-negative-bits
    year-day-positive-bits
    year-day-negative-bits
    week-no-positive-bits
    week-no-negative-bits
    weekday-mask
    ordinal-weekdays
    week-start
    month-scope)

  (defvar *rrule-day-selector* nil)

  (defun %rrule-selector-bits (values limit)
    (when values
      (let ((bits (make-array (1+ limit) :element-type 'bit :initial-element 0)))
        (dolist (value values bits)
          (setf (sbit bits value) 1)))))

  (defun %rrule-selector-signed-bits (values limit)
    (let (positive negative)
      (dolist (value values)
        (if (plusp value)
            (setf (sbit (or positive
                               (setf positive
                                     (make-array
                                       (1+ limit)
                                       :element-type 'bit
                                       :initial-element 0)))
                         value)
                  1)
            (setf (sbit (or negative
                               (setf negative
                                     (make-array
                                       (1+ limit)
                                       :element-type 'bit
                                       :initial-element 0)))
                         (- value))
                  1)))
      (values positive negative)))

  (defun %rrule-selector-weekdays (values)
    (let ((mask 0)
          ordinals)
      (dolist (item values)
        (let ((weekday (%rrule-weekday-value (rrule-by-day-weekday item)))
              (ordinal (rrule-by-day-ordinal item)))
          (if ordinal
              (push (cons weekday ordinal) ordinals)
              (setf mask (logior mask (ash 1 weekday))))))
      (values mask (nreverse ordinals))))

  (defun %compile-rrule-day-selector (rule)
    (multiple-value-bind (month-day-positive-bits month-day-negative-bits)
        (%rrule-selector-signed-bits (rrule-by-month-day rule) 31)
      (multiple-value-bind (year-day-positive-bits year-day-negative-bits)
          (%rrule-selector-signed-bits (rrule-by-year-day rule) 366)
        (multiple-value-bind (week-no-positive-bits week-no-negative-bits)
            (%rrule-selector-signed-bits (rrule-by-week-no rule) 53)
          (multiple-value-bind (weekday-mask ordinal-weekdays)
              (%rrule-selector-weekdays (rrule-by-day rule))
            (%make-rrule-day-selector
              (%rrule-selector-bits (rrule-by-month rule) 12)
              month-day-positive-bits
              month-day-negative-bits
              year-day-positive-bits
              year-day-negative-bits
              week-no-positive-bits
              week-no-negative-bits
              weekday-mask
              ordinal-weekdays
              (rrule-week-start rule)
              (or (eq (rrule-frequency rule) :monthly)
                  (and (eq (rrule-frequency rule) :yearly)
                       (rrule-by-month rule)))))))))

  (defmacro %rrule-selector-index-matches-p
      (positive-bits negative-bits index length)
    `(or
       (and ,positive-bits (= (sbit ,positive-bits ,index) 1))
       (and ,negative-bits
            (= (sbit ,negative-bits (1+ (- ,length ,index))) 1)))))

(defun %rrule-weekday-ordinal-p (date weekday ordinal month-scope)
  "Return whether DATE is the requested positive or negative weekday ordinal."
  (let* ((year (local-date-year date))
         (scope-length
        (if month-scope (length-of-month year (local-date-month date))
          (local-date-length-of-year date)))
         (scope-index
        (if month-scope (local-date-day date)
          (day-of-year date)))
         (first-index
        (1+
          (mod
            (-
              weekday
              (day-of-week-value
                (day-of-week
                  (if month-scope (make-local-date year (local-date-month date) 1)
                    (make-local-date year 1 1)))))
            7)))
         (ordinal-from-start (1+ (floor (- scope-index first-index) 7)))
         (occurrences (1+ (floor (- scope-length first-index) 7))))
    (=
      ordinal-from-start
      (if (plusp ordinal) ordinal
        (+ occurrences ordinal 1)))))

(defun %rrule-day-matches-p (date selector period-year)
  (let* ((year (local-date-year date))
         (month (local-date-month date))
         (month-length (length-of-month year month))
         (year-length (local-date-length-of-year date))
         (date-weekday (day-of-week-value (day-of-week date)))
         (month-bits (%rrule-day-selector-month-bits selector))
         (month-day-positive-bits
           (%rrule-day-selector-month-day-positive-bits selector))
         (month-day-negative-bits
           (%rrule-day-selector-month-day-negative-bits selector))
         (year-day-positive-bits
           (%rrule-day-selector-year-day-positive-bits selector))
         (year-day-negative-bits
           (%rrule-day-selector-year-day-negative-bits selector))
         (week-no-positive-bits
           (%rrule-day-selector-week-no-positive-bits selector))
         (week-no-negative-bits
           (%rrule-day-selector-week-no-negative-bits selector))
         (ordinal-weekdays (%rrule-day-selector-ordinal-weekdays selector)))
    (and
      (or (null month-bits) (= (sbit month-bits month) 1))
      (or
        (and (null month-day-positive-bits) (null month-day-negative-bits))
        (%rrule-selector-index-matches-p
          month-day-positive-bits
          month-day-negative-bits
          (local-date-day date)
          month-length))
      (or
        (and (null year-day-positive-bits) (null year-day-negative-bits))
        (%rrule-selector-index-matches-p
          year-day-positive-bits
          year-day-negative-bits
          (day-of-year date)
          year-length))
      (or
        (and (null week-no-positive-bits) (null week-no-negative-bits))
        (multiple-value-bind
            (week-year week)
            (%rrule-week-info date (%rrule-day-selector-week-start selector))
          (and
            (= week-year period-year)
            (%rrule-selector-index-matches-p
              week-no-positive-bits
              week-no-negative-bits
              week
              (%rrule-weeks-in-year
                period-year
                (%rrule-day-selector-week-start selector))))))
      (or
        (and (zerop (%rrule-day-selector-weekday-mask selector))
             (null ordinal-weekdays))
        (logbitp date-weekday (%rrule-day-selector-weekday-mask selector))
        (loop
          for (weekday . ordinal) in ordinal-weekdays
          thereis
          (and
            (= date-weekday weekday)
            (%rrule-weekday-ordinal-p
              date
              weekday
              ordinal
              (%rrule-day-selector-month-scope selector))))))))




(progn
  (defun %rrule-yearly-direct-p (rule)
    (and (eq (rrule-frequency rule) :yearly)
         (null (rrule-by-week-no rule))
         (null (rrule-by-year-day rule))
         (null (rrule-by-day rule))))

  (defun %rrule-map-yearly-direct-date-components
      (rule dtstart period-year visitor)
    "Call VISITOR for direct YEARLY candidates in date order."
    (let* ((by-month (rrule-by-month rule))
           (by-month-day (rrule-by-month-day rule))
           (months (cond
                     (by-month by-month)
                     (by-month-day (quote (1 2 3 4 5 6 7 8 9 10 11 12)))
                     (t (list (local-date-time-month dtstart)))))
           (month-days (or by-month-day
                           (list (local-date-time-day dtstart)))))
      (if (and by-month-day
               (not (every (function plusp) by-month-day)))
          (loop for month in months
                do (let* ((month-length (length-of-month period-year month))
                          (days (make-array (1+ month-length)
                                            :element-type (quote bit)
                                            :initial-element 0)))
                     (dolist (month-day month-days)
                       (let ((day (if (minusp month-day)
                                      (+ month-length month-day 1)
                                      month-day)))
                         (when (<= 1 day month-length)
                           (setf (sbit days day) 1))))
                     (loop for day from 1 to month-length
                           when (= (sbit days day) 1)
                             do (funcall visitor period-year month day))))
          (loop for month in months
                for month-length = (length-of-month period-year month)
                do (loop for month-day in month-days
                         for day = (if (minusp month-day)
                                       (+ month-length month-day 1)
                                       month-day)
                         when (<= 1 day month-length)
                           do (funcall visitor period-year month day))))))

  (defun %rrule-yearly-direct-dates (rule dtstart period-year)
    "Generate yearly candidates when no week, year-day, or weekday selector applies."
    (let ((candidates nil))
      (%rrule-map-yearly-direct-date-components
       rule dtstart period-year
       (lambda (year month day)
         (push (make-local-date year month day) candidates)))
      (nreverse candidates))))

  (defun %rrule-period-dates (anchor rule dtstart &optional visitor)
  (let* ((frequency (rrule-frequency rule))
         (period-year (local-date-time-year anchor))
         (selector (or *rrule-day-selector*
                       (%compile-rrule-day-selector rule))))
    (if (%rrule-yearly-direct-p rule)
        (if visitor
            (%rrule-map-yearly-direct-date-components
             rule dtstart period-year
             (lambda (year month day)
               (funcall visitor (make-local-date year month day))))
            (%rrule-yearly-direct-dates rule dtstart period-year))
        (let* ((date (local-date-time-date anchor))
               (week-number-year-p (and (eq frequency :yearly) (rrule-by-week-no rule)))
               (default-yearly-month-p
                 (and (eq frequency :yearly)
                      (null (rrule-by-month rule))
                      (null (rrule-by-day rule))
                      (null (rrule-by-year-day rule))
                      (null (rrule-by-week-no rule))))
               (default-month-day-p
                 (and (member frequency (quote (:monthly :yearly)))
                      (null (rrule-by-month-day rule))
                      (null (rrule-by-day rule))
                      (null (rrule-by-year-day rule))
                      (null (rrule-by-week-no rule))))
               (default-weekly-day-p
                 (and (eq frequency :weekly)
                      (null (rrule-by-day rule))))
               (start
                 (if week-number-year-p
                     (%rrule-week-one-start period-year (rrule-week-start rule))
                     (ecase frequency
                       ((:secondly :minutely :hourly :daily) date)
                       (:weekly (%rrule-week-start date (rrule-week-start rule)))
                       (:monthly (make-local-date (local-date-year date) (local-date-month date) 1))
                       (:yearly (make-local-date period-year 1 1)))))
               (end
                 (if week-number-year-p
                     (local-date-minus-days
                       (%rrule-week-one-start (1+ period-year) (rrule-week-start rule))
                       1)
                     (ecase frequency
                       ((:secondly :minutely :hourly :daily) date)
                       (:weekly (local-date-plus-days start 6))
                       (:monthly
                         (make-local-date
                           (local-date-year date)
                           (local-date-month date)
                           (length-of-month (local-date-year date) (local-date-month date))))
                       (:yearly (make-local-date period-year 12 31))))))
          (let ((candidates nil))
            (loop for current = start then (local-date-plus-days current 1)
                  while (local-date<= current end)
                  when (and
                         (%rrule-day-matches-p current selector period-year)
                         (or
                           (not
                             default-yearly-month-p)
                           (= (local-date-month current) (local-date-time-month dtstart)))
                         (or
                           (not
                             default-month-day-p)
                           (= (local-date-day current) (local-date-time-day dtstart)))
                         (or
                           (not default-weekly-day-p)
                           (=
                             (day-of-week-value (day-of-week current))
                             (day-of-week-value
                               (day-of-week (local-date-time-date dtstart))))))
                    do (if visitor
                           (funcall visitor current)
                           (push current candidates)))
            (unless visitor
              (nreverse candidates)))))))

(defun %rrule-anchor-at (start rule period-index)
  "Compute a period from DTSTART, rather than from the preceding period.
This avoids calendar clamping drift for rules such as DTSTART=January 31."
  (let ((amount (* period-index (rrule-interval rule))))
    (ecase (rrule-frequency rule)
      (:secondly (local-date-time-plus-seconds start amount))
      (:minutely (local-date-time-plus-minutes start amount))
      (:hourly (local-date-time-plus-hours start amount))
      (:daily (local-date-time-plus-days start amount))
      (:weekly (local-date-time-plus-weeks start amount))
      (:monthly (local-date-time-plus-months start amount))
      (:yearly (local-date-time-plus-years start amount)))))

(defun %rrule-local-within-until-p (local until)
  (cond
    ((null until) t)
    ((local-date-time-p until) (local-date-time<= local until))
    (t t)))

(defun %rrule-resolve-local (local zone)
  (multiple-value-bind (kind first-offset)
      (%classify-local-date-time local zone)
    (unless (eq kind :gap)
      (%make-zoned-date-time local zone first-offset))))

(defun %rrule-date-occurrence-source (start rule max-periods)
  "Return a stateful source of DATE occurrences for START and RULE."
  (let ((until (rrule-until rule))
        (count (rrule-count rule))
        (emitted 0)
        (period-index 0)
        (candidates nil)
        (exhausted nil)
        (start-local
        (local-date-time-of
          (local-date-year start)
          (local-date-month start)
          (local-date-day start)
          0
          0
          0)))
    (when (and (null until) (null max-periods))
      (%invalid-rrule
        "RRULE schedules without UNTIL require a positive :MAX-PERIODS"
        start))
    (lambda ()
      (loop (when (or exhausted (and count (>= emitted count)))
          (setf exhausted t)
          (return (values nil nil))) (when candidates
          (let ((occurrence (local-date-time-date (pop candidates))))
            (when (and
                (local-date>= occurrence start)
                (or (null until) (local-date<= occurrence until)))
              (incf emitted)
              (return (values occurrence t))))) (unless candidates
          (when (and max-periods (>= period-index max-periods))
            (setf exhausted t)
            (return (values nil nil)))
          (let ((anchor (%rrule-anchor-at start-local rule period-index)))
            (when (and until (local-date> (local-date-time-date anchor) until))
              (setf exhausted t)
              (return (values nil nil)))
            (incf period-index)
            (setf candidates (%rrule-selected-local-candidates anchor rule start-local))))))))


(defun %rrule-local-candidates (anchor rule dtstart &optional visitor)
  "Return ordered local DATE-TIME candidates, or visit raw components."
  (let* ((frequency (rrule-frequency rule))
         (rank (position frequency +rrule-frequencies+))
         (by-hour (rrule-by-hour rule))
         (by-minute (rrule-by-minute rule))
         (by-second (rrule-by-second rule))
         ;; A BY part at or below the frequency filters the anchor once.
         (hour-filter (and (< rank 3) by-hour))
         (minute-filter (and (< rank 2) by-minute))
         (second-filter (and (< rank 1) by-second))
         (anchor-hour (local-date-time-hour anchor))
         (anchor-minute (local-date-time-minute anchor))
         (anchor-second (local-date-time-second anchor))
         (hours (if (>= rank 3) (or by-hour (list anchor-hour)) (list anchor-hour)))
         (minutes (if (>= rank 2) (or by-minute (list anchor-minute)) (list anchor-minute)))
         (seconds (if (>= rank 1) (or by-second (list anchor-second)) (list anchor-second)))
         (anchor-time-allowed-p
           (and (or (null hour-filter) (member anchor-hour hour-filter))
                (or (null minute-filter) (member anchor-minute minute-filter))
                (or (null second-filter) (member anchor-second second-filter)))))
    (when anchor-time-allowed-p
      (let ((candidates nil)
            (nanosecond (local-date-time-nanosecond anchor)))
        (labels ((emit-date (year month day)
                   (loop for hour in hours
                         do (loop for minute in minutes
                                  do (loop for second in seconds
                                           do (if visitor
                                                  (funcall visitor year month day hour minute second)
                                                  (push (local-date-time-of
                                                         year month day hour minute second nanosecond)
                                                        candidates)))))))
          (if (%rrule-yearly-direct-p rule)
              (%rrule-map-yearly-direct-date-components
               rule dtstart (local-date-time-year anchor) (function emit-date))
              (if visitor
                  (%rrule-period-dates
                   anchor rule dtstart
                   (lambda (date)
                     (emit-date (local-date-year date)
                                (local-date-month date)
                                (local-date-day date))))
                  (loop for date in (%rrule-period-dates anchor rule dtstart)
                        do (emit-date (local-date-year date)
                                      (local-date-month date)
                                      (local-date-day date)))))
          (unless visitor (nreverse candidates)))))))



(defun %rrule-selected-local-candidates (anchor rule dtstart)
  (let ((positions (rrule-by-set-pos rule)))
    (if (null positions)
        (%rrule-local-candidates anchor rule dtstart)
        (let* ((maximum-positive
                 (loop for position in positions
                       when (plusp position) maximize position))
               (minimum-negative
                 (loop with minimum = nil
                       for position in positions
                       when (minusp position)
                         do (setf minimum
                                  (if minimum
                                      (min minimum position)
                                      position))
                       finally (return minimum)))
               (positive-positions
                 (make-array (1+ (or maximum-positive 0)) :initial-element nil))
               (ring-length (abs (or minimum-negative 0)))
               (ring-years (make-array ring-length))
               (ring-months (make-array ring-length))
               (ring-days (make-array ring-length))
               (ring-times (make-array ring-length))
               (positive-candidates nil)
               (candidate-count 0)
               (nanosecond (local-date-time-nanosecond anchor)))
          (dolist (position positions)
            (when (plusp position)
              (setf (aref positive-positions position) t)))
          (%rrule-local-candidates
           anchor rule dtstart
           (lambda (year month day hour minute second)
             (incf candidate-count)
             (when (and maximum-positive
                        (<= candidate-count maximum-positive)
                        (aref positive-positions candidate-count))
               (push (local-date-time-of
                      year month day hour minute second nanosecond)
                     positive-candidates))
             (when minimum-negative
               (let ((index (mod (1- candidate-count) ring-length)))
                 (setf (aref ring-years index) year
                       (aref ring-months index) month
                       (aref ring-days index) day
                       (aref ring-times index)
                       (+ (* hour 3600) (* minute 60) second))))))
          (let ((selected (nreverse positive-candidates)))
            (dolist (position positions)
              (when (and (minusp position)
                         (>= candidate-count (- position)))
                (let* ((index (mod (+ candidate-count position) ring-length))
                       (year (aref ring-years index))
                       (month (aref ring-months index))
                       (day (aref ring-days index))
                       (seconds-of-day (aref ring-times index)))
                  (multiple-value-bind (hour remainder) (floor seconds-of-day 3600)
                    (multiple-value-bind (minute second) (floor remainder 60)
                      (push (local-date-time-of
                             year month day hour minute second nanosecond)
                            selected))))))
            (sort (remove-duplicates selected :test (function local-date-time=))
                  (function local-date-time<)))))))


(progn
  (defun %rrule-local-date-time-occurrence-source (start rule max-periods)
    "Return a stateful source of floating LOCAL-DATE-TIME occurrences."
    (let ((until (rrule-until rule))
          (count (rrule-count rule))
          (emitted 0)
          (period-index 0)
          (candidates nil)
          (exhausted nil))
      (when (and (null until) (null max-periods))
        (%invalid-rrule
          "RRULE schedules without UNTIL require a positive :MAX-PERIODS"
          start))
      (lambda ()
        (loop (when (or exhausted (and count (>= emitted count)))
            (setf exhausted t)
            (return (values nil nil))) (when candidates
            (let ((occurrence (pop candidates)))
              (when (and
                  (local-date-time>= occurrence start)
                  (%rrule-local-within-until-p occurrence until))
                (incf emitted)
                (return (values occurrence t))))) (unless candidates
            (when (and max-periods (>= period-index max-periods))
              (setf exhausted t)
              (return (values nil nil)))
            (let ((anchor (%rrule-anchor-at start rule period-index)))
              (when (and until (local-date-time> anchor until))
                (setf exhausted t)
                (return (values nil nil)))
              (incf period-index)
              (setf candidates (%rrule-selected-local-candidates anchor rule start))))))))
  (defun %rrule-zoned-occurrence-source (start rule max-periods)
    "Return a stateful source of ZONED-DATE-TIME occurrences.
Nonexistent local candidates are skipped; overlaps use the earlier instant."
    (let* ((zone (zoned-date-time-zone start))
           (start-local (zoned-date-time-local start))
           (until (rrule-until rule))
           (count (rrule-count rule))
           (emitted 0)
           (period-index 0)
           (candidates nil)
           (exhausted nil))
      (when (and (null until) (null max-periods))
        (%invalid-rrule
          "RRULE schedules without UNTIL require a positive :MAX-PERIODS"
          start))
      (labels ((past-until-p (local)
                 (cond
              ((null until) nil)
              ((local-date-time-p until) (local-date-time> local until))
              (t
                (let ((occurrence (%rrule-resolve-local local zone)))
                  (and occurrence (instant> (zoned-date-time-to-instant occurrence) until)))))))
        (lambda ()
          (loop (when (or exhausted (and count (>= emitted count)))
              (setf exhausted t)
              (return (values nil nil))) (when candidates
              (let* ((local (pop candidates))
                     (occurrence
                    (and (local-date-time>= local start-local) (%rrule-resolve-local local zone))))
                (when (and occurrence (not (past-until-p local)))
                  (incf emitted)
                  (return (values occurrence t))))) (unless candidates
              (when (and max-periods (>= period-index max-periods))
                (setf exhausted t)
                (return (values nil nil)))
              (let ((anchor (%rrule-anchor-at start-local rule period-index)))
                (when (past-until-p anchor)
                  (setf exhausted t)
                  (return (values nil nil)))
                (incf period-index)
                (setf candidates (%rrule-selected-local-candidates anchor rule start-local)))))))))
  (defun %rrule-occurrence-source (schedule max-periods)
    "Select the recurrence source for SCHEDULE's DTSTART value type."
    (let* ((start (rrule-schedule-dtstart schedule))
           (rule (rrule-schedule-rrule schedule))
           (selector (unless (%rrule-yearly-direct-p rule)
                     (%compile-rrule-day-selector rule)))
           (source
             (cond
               ((local-date-p start)
                (%rrule-date-occurrence-source start rule max-periods))
               ((local-date-time-p start)
                (%rrule-local-date-time-occurrence-source start rule max-periods))
               ((zoned-date-time-p start)
                (%rrule-zoned-occurrence-source start rule max-periods))
               (t (%invalid-rrule "unsupported DTSTART type" start)))))
      (lambda ()
        (let ((*rrule-day-selector* selector))
          (funcall source)))))
  (defun map-rrule-occurrences (function schedule &key max-periods)
    "Call FUNCTION for each occurrence of SCHEDULE, stopping when it returns NIL.
Schedules without UNTIL require a positive MAX-PERIODS limit on evaluated
frequency periods.  Returns NIL when exhausted or stopped."
    (check-type schedule rrule-schedule)
    (when (and max-periods (not (and (integerp max-periods) (plusp max-periods))))
      (%invalid-rrule ":MAX-PERIODS must be a positive integer" max-periods))
    (let ((source (%rrule-occurrence-source schedule max-periods)))
      (loop (multiple-value-bind (occurrence present-p) (funcall source)
          (unless present-p
            (return nil))
          (unless (funcall function occurrence)
            (return nil)))))))

(defun rrule-occurrences (schedule &key max-periods)
  "Return all occurrences of SCHEDULE as a list.
Schedules without UNTIL require a positive MAX-PERIODS limit on evaluated
frequency periods."
  (let (result)
    (map-rrule-occurrences
      (lambda (occurrence)
        (push occurrence result)
        t)
      schedule
      :max-periods
      max-periods)
    (nreverse result)))

(defmacro do-rrule-occurrences ((variable schedule &key max-periods result) &body body)
  "Iterate VARIABLE over SCHEDULE occurrences.
Schedules without UNTIL require a positive :MAX-PERIODS; :RESULT is returned
when iteration completes.  RETURN exits the iteration."
  (let ((completion-marker (gensym "COMPLETION-MARKER"))
        (exit-tag (gensym "EXIT-TAG"))
        (body-result (gensym "BODY-RESULT")))
    `(let ((,completion-marker (gensym))
           (,exit-tag (gensym)))
       (catch ,exit-tag
         (map-rrule-occurrences
          (lambda (,variable)
            (let ((,body-result
                   (block nil
                     ,@body
                     ,completion-marker)))
              (if (eq ,body-result ,completion-marker)
                  t
                  (throw ,exit-tag ,body-result))))
          ,schedule
          :max-periods ,max-periods)
         ,result))))

(defun %rrule-weekday-value (weekday)
  (ecase weekday
    (:mo 1)
    (:tu 2)
    (:we 3)
    (:th 4)
    (:fr 5)
    (:sa 6)
    (:su 7)))
