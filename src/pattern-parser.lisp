;;;; src/pattern-parser.lisp
;;;;
;;;; Pattern parsing and temporal value reconstruction for DATE-TIME-FORMATTER.
(in-package #:cl-date-kit)

(defun %pattern-parse-error (string pattern)
  (error 'date-time-parse-error
         :string string
         :expected (format nil "input matching pattern ~S" pattern)))
(defun %pattern-next-literal (parts)
  (find-if #'stringp parts))
(defun %pattern-read-digits (string position width expected)
  (if width (let ((end (+ position width)))
      (values (%parse-fixed-integer string position end expected) end))
    (let ((end position))
      (loop while (and (< end (length string)) (digit-char-p (char string end)))
            do (incf end))
      (when (= end position)
        (error 'date-time-parse-error :string string :expected expected))
      (values (parse-integer string :start position :end end) end))))
(defun %pattern-read-year (string position width remaining expected)
  (if (and remaining (consp (first remaining)) (eq (first (first remaining)) :field)) (progn
      (when (or
          (< width 4)
          (and (< position (length string)) (member (char string position) '(#\+ #\-))))
        (error 'date-time-parse-error :string string :expected expected))
      (let ((end (+ position width)))
        (values (%parse-fixed-integer string position end expected) end)))
    (let ((start position))
      (when (and (< position (length string)) (member (char string position) '(#\+ #\-)))
        (incf position))
      (multiple-value-bind (year end) (%pattern-read-digits string position nil expected)
        (values
          (if (and (< start (length string)) (char= (char string start) #\-)) (- year)
            year)
          end)))))
(defun %pattern-read-text (string position remaining pattern)
  (let ((literal (%pattern-next-literal remaining)))
    (let ((end
          (if literal (or
              (search literal string :start2 position)
              (%pattern-parse-error string pattern))
            (length string))))
      (when (= end position)
        (%pattern-parse-error string pattern))
      (values (subseq string position end) end))))
(defun %pattern-read-field (string position field width remaining pattern locale)
  (let ((expected (format nil "field ~C in pattern ~S" field pattern)))
    (case field
      ((#\y #\Y) (%pattern-read-year string position width remaining expected))
      ((#\X #\V) (%pattern-read-text string position remaining pattern))
      (#\z (%pattern-parse-error string pattern))
      (#\M
        (if (< width 3) (if (= width 1) (progn
              (when (and remaining (consp (first remaining)) (eq (first (first remaining)) :field))
                (%pattern-parse-error string pattern))
              (%pattern-read-digits string position nil expected))
            (%pattern-read-digits string position width expected))
          (multiple-value-bind (text end) (%pattern-read-text string position remaining pattern)
            (let ((month (%date-time-locale-find-month locale text width)))
              (unless month
                (%pattern-parse-error string pattern))
              (values month end)))))
      (#\E
        (multiple-value-bind (text end) (%pattern-read-text string position remaining pattern)
          (let ((weekday (%date-time-locale-find-weekday locale text width)))
            (unless weekday
              (%pattern-parse-error string pattern))
            (values weekday end))))
      (#\a
        (multiple-value-bind (text end) (%pattern-read-text string position remaining pattern)
          (let ((meridiem (%date-time-locale-find-meridiem locale text)))
            (unless meridiem
              (%pattern-parse-error string pattern))
            (values meridiem end))))
      (t
        (when (and
            (= width 1)
            remaining
            (consp (first remaining))
            (eq (first (first remaining)) :field))
          (%pattern-parse-error string pattern))
        (if (char= field #\S) (let ((end (+ position width)))
            (values (%parse-fixed-integer string position end expected) end))
          (%pattern-read-digits
            string
            position
            (if (= width 1) nil
              width)
            expected))))))
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
          (list #\H #\h #\m #\s #\S #\a))))
    (when present
      (let ((has-24-hour (%pattern-present-p #\H values))
            (has-12-hour (%pattern-present-p #\h values))
            (meridiem (%pattern-value #\a values)))
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
         (offset (and (%pattern-present-p #\X values)
                      (parse-zone-offset (%pattern-value #\X values))))
         (zone (and (%pattern-present-p #\V values)
                    (find-time-zone (%pattern-value #\V values)))))
    (when (and zone (not (and date time)))
      (%pattern-parse-error string pattern))
    (when (and offset (not time))
      (%pattern-parse-error string pattern))
    (cond
      (zone
       (let ((local (make-local-date-time date time)))
         (if offset
             (progn
               (unless (%local-date-time-has-offset-p local zone offset)
                 (%pattern-parse-error string pattern))
               (%make-zoned-date-time local zone offset))
             (zoned-date-time-of-local
              local zone :disambiguation disambiguation))))
      ((and date time offset)
       (make-offset-date-time (make-local-date-time date time) offset))
      ((and date time)
       (make-local-date-time date time))
      ((and time offset)
       (make-offset-time time offset))
      (date date)
      (time time)
      (t (%pattern-parse-error string pattern)))))
(defun parse-date-time (formatter string &key (disambiguation :compatible))
  "Parse STRING using compiled DATE-TIME-FORMATTER FORMATTER.

Textual English month, weekday, and AM/PM fields are case-insensitive. A
weekday name and AM/PM marker must agree with the reconstructed date and H
(hour-of-day) field, respectively."
  (unless (date-time-formatter-p formatter)
    (error 'type-error :datum formatter :expected-type 'date-time-formatter))
  (with-date-time-parse-error
    (string
      (format nil "input matching pattern ~S" (date-time-formatter-pattern formatter)))
    (unless (stringp string)
      (%pattern-parse-error string (date-time-formatter-pattern formatter)))
    (let ((position 0)
          (values '())
          (parts (date-time-formatter-parts formatter)))
      (loop for tail on parts
            for part = (first tail)
            do (if (stringp part) (let ((end (+ position (length part))))
            (unless (and (<= end (length string)) (string= part string :start2 position :end2 end))
              (%pattern-parse-error string (date-time-formatter-pattern formatter)))
            (setf position end))
          (let ((field (second part)))
            (when (%pattern-present-p field values)
              (%pattern-parse-error string (date-time-formatter-pattern formatter)))
            (multiple-value-bind (value end) (%pattern-read-field
                string
                position
                field
                (third part)
                (rest tail)
                (date-time-formatter-pattern formatter)
                (date-time-formatter-locale formatter))
              (push (list field value (third part)) values)
              (setf position end)))))
      (unless (= position (length string))
        (%pattern-parse-error string (date-time-formatter-pattern formatter)))
      (%pattern-build-value
        string
        (date-time-formatter-pattern formatter)
        values
        disambiguation))))
(defun parse-date-time-with-pattern (pattern string &key (disambiguation :compatible) (locale :en))
  "Parse STRING with PATTERN and LOCALE without retaining a formatter instance."
  (parse-date-time
    (make-date-time-formatter pattern :locale locale)
    string
    :disambiguation
    disambiguation))
