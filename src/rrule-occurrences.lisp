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

(defun %rrule-run-occurrence-source (rule
    max-periods
    anchor-start
    invalid-value
    &key
    candidates-for-anchor
    at-or-after-start-p
    resolve-candidate
    anchor-past-until-p
    occurrence-past-until-p)
  "Drive the next-occurrence state machine shared by %RRULE-DATE-,
%RRULE-LOCAL-DATE-TIME-, and %RRULE-ZONED-OCCURRENCE-SOURCE.

ANCHOR-START feeds %RRULE-ANCHOR-AT to compute each period's anchor.
CANDIDATES-FOR-ANCHOR returns one period's ordered raw candidates. Each
popped candidate is tested by AT-OR-AFTER-START-P and, only when that holds,
passed to RESOLVE-CANDIDATE, which may return NIL to skip an unresolvable
candidate (a ZONED-DATE-TIME candidate falling in a DST gap). ANCHOR-PAST-
UNTIL-P and OCCURRENCE-PAST-UNTIL-P (given the raw candidate and its
resolved occurrence) stop the source once UNTIL is exceeded. INVALID-VALUE
is reported when neither UNTIL nor MAX-PERIODS bounds the source."
  (let ((until (rrule-until rule))
        (count (rrule-count rule))
        (emitted 0)
        (period-index 0)
        (candidates nil)
        (exhausted nil))
    (when (and (null until) (null max-periods))
      (%invalid-rrule
        "RRULE schedules without UNTIL require a positive :MAX-PERIODS"
        invalid-value))
    (lambda ()
      (loop (when (or exhausted (and count (>= emitted count)))
          (setf exhausted t)
          (return (values nil nil))) (when candidates
          (let* ((candidate (pop candidates))
                 (occurrence
                (and
                  (funcall at-or-after-start-p candidate)
                  (funcall resolve-candidate candidate))))
            (when (and occurrence (not (funcall occurrence-past-until-p candidate occurrence)))
              (incf emitted)
              (return (values occurrence t))))) (unless candidates
          (when (and max-periods (>= period-index max-periods))
            (setf exhausted t)
            (return (values nil nil)))
          (let ((anchor (%rrule-anchor-at anchor-start rule period-index)))
            (when (funcall anchor-past-until-p anchor)
              (setf exhausted t)
              (return (values nil nil)))
            (incf period-index)
            (setf candidates (funcall candidates-for-anchor anchor))))))))

(defun %rrule-date-occurrence-source (start rule max-periods)
  "Return a stateful source of DATE occurrences for START and RULE."
  (let ((until (rrule-until rule))
        (start-local
        (local-date-time-of
          (local-date-year start)
          (local-date-month start)
          (local-date-day start)
          0
          0
          0)))
    (%rrule-run-occurrence-source
      rule
      max-periods
      start-local
      start
      :candidates-for-anchor
      (lambda (anchor)
        (%rrule-selected-date-candidates anchor rule start-local))
      :at-or-after-start-p
      (lambda (candidate)
        (local-date>= candidate start))
      :resolve-candidate
      (function identity)
      :anchor-past-until-p
      (lambda (anchor)
        (and until (local-date> (local-date-time-date anchor) until)))
      :occurrence-past-until-p
      (lambda (candidate occurrence)
        (declare (ignore candidate))
        (and until (local-date> occurrence until))))))

(progn
  (defun %rrule-local-date-time-occurrence-source (start rule max-periods)
    "Return a stateful source of floating LOCAL-DATE-TIME occurrences."
    (let ((until (rrule-until rule)))
      (%rrule-run-occurrence-source
        rule
        max-periods
        start
        start
        :candidates-for-anchor
        (lambda (anchor)
          (%rrule-selected-local-candidates anchor rule start))
        :at-or-after-start-p
        (lambda (candidate)
          (local-date-time>= candidate start))
        :resolve-candidate
        (function identity)
        :anchor-past-until-p
        (lambda (anchor)
          (and until (local-date-time> anchor until)))
        :occurrence-past-until-p
        (lambda (candidate occurrence)
          (declare (ignore candidate))
          (not (%rrule-local-within-until-p occurrence until))))))
  (defun %rrule-zoned-occurrence-source (start rule max-periods)
    "Return a stateful source of ZONED-DATE-TIME occurrences.
Nonexistent local candidates are skipped; overlaps use the earlier instant."
    (let* ((zone (zoned-date-time-zone start))
           (start-local (zoned-date-time-local start))
           (until (rrule-until rule)))
      (labels ((past-until-p (local &optional occurrence)
                 (cond
              ((null until) nil)
              ((local-date-time-p until) (local-date-time> local until))
              (t
                (let ((resolved (or occurrence (%rrule-resolve-local local zone))))
                  (and resolved (instant> (zoned-date-time-to-instant resolved) until)))))))
        (%rrule-run-occurrence-source
          rule
          max-periods
          start-local
          start
          :candidates-for-anchor
          (lambda (anchor)
            (%rrule-selected-local-candidates anchor rule start-local))
          :at-or-after-start-p
          (lambda (candidate)
            (local-date-time>= candidate start-local))
          :resolve-candidate
          (lambda (candidate)
            (%rrule-resolve-local candidate zone))
          :anchor-past-until-p
          (function past-until-p)
          :occurrence-past-until-p
          (function past-until-p)))))
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
