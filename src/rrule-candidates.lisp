;;;; src/rrule-candidates.lisp
;;;;
;;;; RFC 5545 recurrence expansion for DATE-TIME and DATE DTSTART values.
(in-package #:cl-date-kit)

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
  (or (null until) (local-date-time<= local until)))

(defun %rrule-resolve-local (local zone)
  (multiple-value-bind (kind first-offset) (%classify-local-date-time local zone)
    (unless (eq kind :gap)
      (%make-zoned-date-time local zone first-offset))))

(progn
  (defun %rrule-date-candidates (anchor rule dtstart &optional visitor)
    "Return ordered DATE candidates, or call VISITOR for each DATE."
    (if visitor (%rrule-period-dates anchor rule dtstart visitor)
      (let ((candidates nil))
        (%rrule-period-dates
          anchor
          rule
          dtstart
          (lambda (date)
            (push date candidates)))
        (nreverse candidates))))
  (defun %rrule-merge-date-candidates (left right)
    "Merge sorted DATE candidate lists, retaining one of each date."
    (let ((result nil))
      (loop (cond
          ((null left) (return (nreconc result right)))
          ((null right) (return (nreconc result left)))
          ((local-date< (car left) (car right)) (push (pop left) result))
          ((local-date< (car right) (car left)) (push (pop right) result))
          (t
            (push (pop left) result)
            (pop right))))))
  (defun %rrule-selected-date-candidates (anchor rule dtstart)
    (let ((positions (rrule-by-set-pos rule)))
      (if (null positions) (%rrule-date-candidates anchor rule dtstart)
        (let ((maximum-positive nil)
              (minimum-negative nil))
          (dolist (position positions)
            (cond
              ((plusp position)
                (setf maximum-positive (if maximum-positive (max maximum-positive position)
                    position)))
              ((minusp position)
                (setf minimum-negative (if minimum-negative (min minimum-negative position)
                    position)))))
          (let* ((positive-positions
                (make-array
                  (1+ (or maximum-positive 0))
                  :element-type
                  (quote bit)
                  :initial-element
                  0))
                 (ring-length (abs (or minimum-negative 0)))
                 (negative-positions
                (make-array (1+ ring-length) :element-type (quote bit) :initial-element 0))
                 (ring-dates (make-array ring-length))
                 (positive-candidates nil)
                 (candidate-count 0))
            (dolist (position positions)
              (cond
                ((plusp position)
                  (setf (aref positive-positions position) 1))
                ((minusp position)
                  (setf (aref negative-positions (- position)) 1))))
            (%rrule-date-candidates
              anchor
              rule
              dtstart
              (lambda (date)
                (incf candidate-count)
                (when (and
                    maximum-positive
                    (<= candidate-count maximum-positive)
                    (= (aref positive-positions candidate-count) 1))
                  (push date positive-candidates))
                (when minimum-negative
                  (setf (aref ring-dates (mod (1- candidate-count) ring-length)) date))))
            (let ((negative-candidates nil))
              (dolist (position positions)
                (when (and
                    (minusp position)
                    (= (aref negative-positions (- position)) 1)
                    (>= candidate-count (- position)))
                  (setf (aref negative-positions (- position)) 0)
                  (push
                    (aref ring-dates (mod (+ candidate-count position) ring-length))
                    negative-candidates)))
              (%rrule-merge-date-candidates
                (nreverse positive-candidates)
                (nreverse negative-candidates))))))))
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
            (let ((occurrence (pop candidates)))
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
              (setf candidates (%rrule-selected-date-candidates anchor rule start-local)))))))))

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
              (%rrule-period-dates anchor rule dtstart nil (function emit-date)))
          (unless visitor (nreverse candidates)))))))

(progn
  (defun %rrule-merge-local-candidates (left right)
    "Merge sorted candidate lists, retaining one value for each local date-time."
    (let ((result nil))
      (loop (cond
          ((null left) (return (nreconc result right)))
          ((null right) (return (nreconc result left)))
          ((local-date-time< (car left) (car right)) (push (pop left) result))
          ((local-date-time< (car right) (car left)) (push (pop right) result))
          (t
            (push (pop left) result)
            (pop right))))))
  (defun %rrule-selected-local-candidates (anchor rule dtstart)
    (let ((positions (rrule-by-set-pos rule)))
      (if (null positions) (%rrule-local-candidates anchor rule dtstart)
        (let ((maximum-positive nil)
              (minimum-negative nil))
          (dolist (position positions)
            (cond
              ((plusp position)
                (setf maximum-positive (if maximum-positive (max maximum-positive position)
                    position)))
              ((minusp position)
                (setf minimum-negative (if minimum-negative (min minimum-negative position)
                    position)))))
          (let* ((positive-positions
                (make-array
                  (1+ (or maximum-positive 0))
                  :element-type
                  (quote bit)
                  :initial-element
                  0))
                 (ring-length (abs (or minimum-negative 0)))
                 (negative-positions
                (make-array (1+ ring-length) :element-type (quote bit) :initial-element 0))
                 (ring-years (make-array ring-length))
                 (ring-months (make-array ring-length))
                 (ring-days (make-array ring-length))
                 (ring-times (make-array ring-length))
                 (positive-candidates nil)
                 (candidate-count 0)
                 (nanosecond (local-date-time-nanosecond anchor)))
            (dolist (position positions)
              (cond
                ((plusp position)
                  (setf (aref positive-positions position) 1))
                ((minusp position)
                  (setf (aref negative-positions (- position)) 1))))
            (%rrule-local-candidates
              anchor
              rule
              dtstart
              (lambda (year month day hour minute second)
                (incf candidate-count)
                (when (and
                    maximum-positive
                    (<= candidate-count maximum-positive)
                    (= (aref positive-positions candidate-count) 1))
                  (push
                    (local-date-time-of year month day hour minute second nanosecond)
                    positive-candidates))
                (when minimum-negative
                  (let ((index (mod (1- candidate-count) ring-length)))
                    (setf (aref ring-years index) year
                          (aref ring-months index) month
                          (aref ring-days index) day
                          (aref ring-times index) (+ (* hour 3600) (* minute 60) second))))))
            (let ((negative-candidates nil))
              (dolist (position positions)
                (when (and
                    (minusp position)
                    (= (aref negative-positions (- position)) 1)
                    (>= candidate-count (- position)))
                  (setf (aref negative-positions (- position)) 0)
                  (let* ((index (mod (+ candidate-count position) ring-length))
                         (year (aref ring-years index))
                         (month (aref ring-months index))
                         (day (aref ring-days index))
                         (seconds-of-day (aref ring-times index)))
                    (multiple-value-bind (hour remainder) (floor seconds-of-day 3600)
                      (multiple-value-bind (minute second) (floor remainder 60)
                        (push
                          (local-date-time-of year month day hour minute second nanosecond)
                          negative-candidates))))))
              (%rrule-merge-local-candidates
                (nreverse positive-candidates)
                (nreverse negative-candidates)))))))))

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
      (labels ((past-until-p (local &optional occurrence)
                 (cond
              ((null until) nil)
              ((local-date-time-p until) (local-date-time> local until))
              (t
                (let ((resolved (or occurrence (%rrule-resolve-local local zone))))
                  (and resolved (instant> (zoned-date-time-to-instant resolved) until)))))))
        (lambda ()
          (loop (when (or exhausted (and count (>= emitted count)))
              (setf exhausted t)
              (return (values nil nil))) (when candidates
              (let* ((local (pop candidates))
                     (occurrence
                    (and (local-date-time>= local start-local) (%rrule-resolve-local local zone))))
                (when (and occurrence (not (past-until-p local occurrence)))
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
           (selector
          (unless (%rrule-yearly-direct-p rule)
            (%compile-rrule-day-selector rule)))
           (source
          (cond
            ((local-date-p start) (%rrule-date-occurrence-source start rule max-periods))
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
              (if (eq ,body-result ,completion-marker) t
                (throw ,exit-tag ,body-result))))
          ,schedule
          :max-periods
          ,max-periods)
        ,result))))
