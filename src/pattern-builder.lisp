(in-package #:cl-date-kit)

(defun %pattern-value (field values)
  (second (assoc field values)))

(defun %pattern-width (field values)
  (third (assoc field values)))

(defun %pattern-present-p (field values)
  (not (null (assoc field values))))

(defun %pattern-build-date (string pattern values)
  (let ((calendar
        (some
          (lambda (field)
            (%pattern-present-p field values))
          '(#\M #\d)))
        (ordinal (%pattern-present-p #\D values))
        (week
        (some
          (lambda (field)
            (%pattern-present-p field values))
          '(#\Y #\w #\e))))
    (when (> (count-if #'identity (list calendar ordinal week)) 1)
      (%pattern-parse-error string pattern))
    (let ((date
          (cond
            (ordinal
              (unless (and (%pattern-present-p #\y values) (not calendar))
                (%pattern-parse-error string pattern))
              (local-date-of-year-day (%pattern-value #\y values) (%pattern-value #\D values)))
            (week
              (unless (and
                  (%pattern-present-p #\Y values)
                  (%pattern-present-p #\w values)
                  (%pattern-present-p #\e values))
                (%pattern-parse-error string pattern))
              (local-date-of-week-date
                (%pattern-value #\Y values)
                (%pattern-value #\w values)
                (%pattern-value #\e values)))
            (calendar
              (unless (and
                  (%pattern-present-p #\y values)
                  (%pattern-present-p #\M values)
                  (%pattern-present-p #\d values))
                (%pattern-parse-error string pattern))
              (make-local-date
                (%pattern-value #\y values)
                (%pattern-value #\M values)
                (%pattern-value #\d values)))
            (t nil))))
      (when (and
          (%pattern-present-p #\E values)
          (or (not date) (not (eq (%pattern-value #\E values) (day-of-week date)))))
        (%pattern-parse-error string pattern))
      date)))

(defun %pattern-build-time (string pattern values)
  (let ((present
        (some
          (lambda (field)
            (%pattern-present-p field values))
          (list #\H #\h #\m #\s #\S #\a #\A))))
    (when present
      (let ((has-24-hour (%pattern-present-p #\H values))
            (has-12-hour (%pattern-present-p #\h values))
            (has-milli-of-day (%pattern-present-p #\A values))
            (meridiem (%pattern-value #\a values)))
        (when (and
            has-milli-of-day
            (or
              has-24-hour
              has-12-hour
              meridiem
              (%pattern-present-p #\m values)
              (%pattern-present-p #\s values)
              (%pattern-present-p #\S values)))
          (%pattern-parse-error string pattern))
        (when has-milli-of-day
          (return-from
            %pattern-build-time
            (local-time-of-nano-of-day (* (%pattern-value #\A values) 1000000))))
        (unless (or has-24-hour has-12-hour)
          (%pattern-parse-error string pattern))
        (when (and has-24-hour has-12-hour)
          (%pattern-parse-error string pattern))
        (let ((hour
              (if has-12-hour (let ((clock-hour (%pattern-value #\h values)))
                  (unless (and (<= 1 clock-hour) (<= clock-hour 12) meridiem)
                    (%pattern-parse-error string pattern))
                  (if (eq meridiem :am) (if (= clock-hour 12) 0
                      clock-hour)
                    (if (= clock-hour 12) 12
                      (+ clock-hour 12))))
                (%pattern-value #\H values))))
          (when (and
              has-24-hour
              meridiem
              (not
                (eq
                  meridiem
                  (if (< hour 12) :am
                    :pm))))
            (%pattern-parse-error string pattern))
          (make-local-time
            hour
            (or (%pattern-value #\m values) 0)
            (or (%pattern-value #\s values) 0)
            (if (%pattern-present-p #\S values) (* (%pattern-value #\S values) (expt 10 (- 9 (%pattern-width #\S values))))
              0)))))))

(defun %pattern-build-value (string pattern values disambiguation)
  (let* ((date (%pattern-build-date string pattern values))
         (time (%pattern-build-time string pattern values))
         (offset
        (and
          (%pattern-present-p #\X values)
          (parse-zone-offset (%pattern-value #\X values))))
         (zone
        (and
          (%pattern-present-p #\V values)
          (find-time-zone (%pattern-value #\V values)))))
    (when (and zone (not (and date time)))
      (%pattern-parse-error string pattern))
    (when (and offset (not time))
      (%pattern-parse-error string pattern))
    (cond
      (zone
        (let ((local (make-local-date-time date time)))
          (if offset (progn
              (unless (%local-date-time-has-offset-p local zone offset)
                (%pattern-parse-error string pattern))
              (%make-zoned-date-time local zone offset))
            (zoned-date-time-of-local local zone :disambiguation disambiguation))))
      ((and date time offset)
        (make-offset-date-time (make-local-date-time date time) offset))
      ((and date time) (make-local-date-time date time))
      ((and time offset) (make-offset-time time offset))
      (date date)
      (time time)
      (t (%pattern-parse-error string pattern)))))
