;;;; src/pattern-parser.lisp
;;;;
;;;; Pattern parsing and temporal value reconstruction for DATE-TIME-FORMATTER.
(in-package #:cl-date-kit)

(defun %pattern-parse-error (string pattern)
  (error
    'date-time-parse-error
    :string
    string
    :expected
    (format nil "input matching pattern ~S" pattern)))

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

(defun %pattern-read-numeric-field (string position field width remaining pattern expected)
  "Read a plain numeric pattern field (day-of-X, hour, minute, second, or a
fractional-second/millisecond-of-day count) at POSITION. When WIDTH is 1 and
another field immediately follows with no literal to bound a greedy digit
run, the field must be exactly one digit. FIELD #\\S always reads exactly
WIDTH digits, since fractional seconds have no narrower single-digit form;
every other field reads a greedy run of digits (or exactly WIDTH of them
when WIDTH > 1)."
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
      expected)))

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
  (funcall
    (pattern-field-spec-reader (%pattern-field-spec pattern field))
    string
    position
    field
    width
    remaining
    pattern
    locale))

(define-pattern-field
  #\y
  :write
  (%write-pattern-year
    stream
    (local-date-year (%require-pattern-field date pattern field "a date"))
    width)
  :read
  (%pattern-read-year string position width remaining expected))

(define-pattern-field
  #\M
  :validate
  (when (> width 4)
    (%pattern-error pattern "field ~C only supports widths 1 through 4" field))
  :write
  (let ((month (local-date-month (%require-pattern-field date pattern field "a date"))))
    (if (< width 3) (%write-pattern-number stream month width)
      (write-string (%date-time-locale-month-name locale month width) stream)))
  :read
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

(define-pattern-field
  #\d
  :validate
  (when (> width 2)
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  :write
  (%write-pattern-number
    stream
    (local-date-day (%require-pattern-field date pattern field "a date"))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\D
  :validate
  (when (> width 3)
    (%pattern-error pattern "field ~C only supports widths 1 through 3" field))
  :write
  (%write-pattern-number
    stream
    (day-of-year (%require-pattern-field date pattern field "a date"))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\Y
  :write
  (%write-pattern-year
    stream
    (local-date-week-based-year
      (%require-pattern-field date pattern field "a date"))
    width)
  :read
  (%pattern-read-year string position width remaining expected))

(define-pattern-field
  #\w
  :validate
  (when (> width 2)
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  :write
  (%write-pattern-number
    stream
    (local-date-week-of-week-based-year
      (%require-pattern-field date pattern field "a date"))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\e
  :validate
  (when (> width 2)
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  :write
  (%write-pattern-number
    stream
    (%iso-weekday-number (%require-pattern-field date pattern field "a date"))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\E
  :validate
  (when (not (member width (list 3 4)))
    (%pattern-error pattern "field ~C only supports widths 3 or 4" field))
  :write
  (write-string
    (%date-time-locale-weekday-name
      locale
      (day-of-week (%require-pattern-field date pattern field "a date"))
      width)
    stream)
  :read
  (multiple-value-bind (text end) (%pattern-read-text string position remaining pattern)
    (let ((weekday (%date-time-locale-find-weekday locale text width)))
      (unless weekday
        (%pattern-parse-error string pattern))
      (values weekday end))))

(define-pattern-field
  #\H
  :validate
  (when (> width 2)
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  :write
  (%write-pattern-number
    stream
    (let ((hour (local-time-hour (%require-pattern-field time pattern field "a time"))))
      (if (char= field #\H) hour
        (if (zerop hour) 12
          (if (> hour 12) (- hour 12)
            hour))))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\h
  :validate
  (when (> width 2)
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  :write
  (%write-pattern-number
    stream
    (let ((hour (local-time-hour (%require-pattern-field time pattern field "a time"))))
      (if (char= field #\H) hour
        (if (zerop hour) 12
          (if (> hour 12) (- hour 12)
            hour))))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\m
  :validate
  (when (> width 2)
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  :write
  (%write-pattern-number
    stream
    (local-time-minute (%require-pattern-field time pattern field "a time"))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\s
  :validate
  (when (> width 2)
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  :write
  (%write-pattern-number
    stream
    (local-time-second (%require-pattern-field time pattern field "a time"))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\S
  :validate
  (when (> width 9)
    (%pattern-error pattern "field ~C has unsupported width ~D" field width))
  :write
  (%write-pattern-number
    stream
    (floor
      (local-time-nanosecond (%require-pattern-field time pattern field "a time"))
      (expt 10 (- 9 width)))
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\X
  :validate
  (when (> width 3)
    (%pattern-error pattern "field ~C has unsupported width ~D" field width))
  :write
  (%write-pattern-offset
    stream
    (%require-pattern-field offset pattern field "an offset")
    width
    pattern)
  :read
  (%pattern-read-text string position remaining pattern))

(define-pattern-field
  #\V
  :validate
  (when (/= width 1)
    (%pattern-error pattern "field ~C only supports width 1" field))
  :write
  (let ((resolved-zone (%require-pattern-field zone pattern field "an IANA time zone")))
    (if (time-zone-p resolved-zone) (write-string (time-zone-name resolved-zone) stream)
      (%pattern-error pattern "field V requires an IANA time zone")))
  :read
  (%pattern-read-text string position remaining pattern))

(define-pattern-field
  #\A
  :write
  (%write-pattern-number
    stream
    (floor
      (local-time-to-nano-of-day (%require-pattern-field time pattern field "a time"))
      1000000)
    width)
  :read
  (%pattern-read-numeric-field string position field width remaining pattern expected))

(define-pattern-field
  #\z
  :validate
  (when (/= width 1)
    (%pattern-error pattern "field ~C only supports width 1" field))
  :write
  (let ((resolved-zone (%require-pattern-field zone pattern field "an IANA time zone"))
        (resolved-instant (%require-pattern-field instant pattern field "an instant")))
    (unless (time-zone-p resolved-zone)
      (%pattern-error pattern "field z requires an IANA time zone"))
    (write-string
      (or
        (zone-state-abbreviation
          (zone-state-for-instant resolved-zone resolved-instant))
        (%pattern-error pattern "field z has no abbreviation for the active zone state"))
      stream))
  :read
  (%pattern-parse-error string pattern))

(define-pattern-field
  #\a
  :validate
  (when (/= width 1)
    (%pattern-error pattern "field ~C only supports width 1" field))
  :write
  (write-string
    (%date-time-locale-meridiem
      locale
      (local-time-hour (%require-pattern-field time pattern field "a time")))
    stream)
  :read
  (multiple-value-bind (text end) (%pattern-read-text string position remaining pattern)
    (let ((meridiem (%date-time-locale-find-meridiem locale text)))
      (unless meridiem
        (%pattern-parse-error string pattern))
      (values meridiem end))))

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

(let ((declared (coerce +pattern-fields+ 'list))
      (registered
      (loop for char being the hash-keys of *pattern-fields*
            collect char)))
  (assert
    (null (set-difference declared registered))
    ()
    "+PATTERN-FIELDS+ declares ~S with no DEFINE-PATTERN-FIELD registration"
    (set-difference declared registered))
  (assert
    (null (set-difference registered declared))
    ()
    "DEFINE-PATTERN-FIELD registered ~S, which +PATTERN-FIELDS+ does not declare"
    (set-difference registered declared)))
