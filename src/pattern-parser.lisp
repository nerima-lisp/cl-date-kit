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
(defun %pattern-invalid-for-expected (string expected)
  "Builds the niladic failure continuation used by the %PATTERN-READ-* family
below: signals DATE-TIME-PARSE-ERROR for STRING against the field-specific
EXPECTED description."
  (lambda ()
    (error (quote date-time-parse-error) :string string :expected expected)))
(defun %pattern-invalid-for-pattern (string pattern)
  "Builds the niladic failure continuation used by the %PATTERN-READ-* family
below: signals via %PATTERN-PARSE-ERROR for STRING against PATTERN's
generic message."
  (lambda ()
    (%pattern-parse-error string pattern)))

(defun %pattern-read-digits (string position width expected on-success invalid)
  (if width (let ((end (+ position width)))
      (funcall on-success (%parse-fixed-integer string position end expected) end))
    (let ((end position))
      (loop while (and (< end (length string)) (digit-char-p (char string end)))
            do (incf end))
      (if (= end position) (funcall invalid)
        (funcall on-success (parse-integer string :start position :end end) end)))))

(defun %pattern-read-numeric-field (string position field width remaining pattern expected on-success invalid)
  "Read a plain numeric pattern field (day-of-X, hour, minute, second, or a
fractional-second/millisecond-of-day count) at POSITION, calling ON-SUCCESS
with (value end-position) on success. When WIDTH is 1 and another field
immediately follows with no literal to bound a greedy digit run, the field
must be exactly one digit. FIELD #\\S always reads exactly WIDTH digits,
since fractional seconds have no narrower single-digit form; every other
field reads a greedy run of digits (or exactly WIDTH of them when WIDTH >
1), via %PATTERN-READ-DIGITS, threading ON-SUCCESS and INVALID through as
its own continuations."
  (if (and
      (= width 1)
      remaining
      (consp (first remaining))
      (eq (first (first remaining)) :field))
    (%pattern-parse-error string pattern)
    (if (char= field #\S) (let ((end (+ position width)))
        (funcall on-success (%parse-fixed-integer string position end expected) end))
      (%pattern-read-digits
        string
        position
        (if (= width 1) nil
          width)
        expected
        on-success
        invalid))))

(defun %pattern-read-year (string position width remaining expected on-success invalid)
  (if (and remaining (consp (first remaining)) (eq (first (first remaining)) :field))
    (if (or
        (< width 4)
        (and (< position (length string)) (member (char string position) (quote (#\+ #\-)))))
      (funcall invalid)
      (let ((end (+ position width)))
        (funcall on-success (%parse-fixed-integer string position end expected) end)))
    (let ((start position))
      (when (and (< position (length string)) (member (char string position) (quote (#\+ #\-))))
        (incf position))
      (%pattern-read-digits string position nil expected
        (lambda (year end)
          (funcall on-success
            (if (and (< start (length string)) (char= (char string start) #\-)) (- year)
              year)
            end))
        invalid))))

(defun %pattern-read-text (string position remaining pattern on-success invalid)
  (declare (ignore pattern))
  (let* ((literal (%pattern-next-literal remaining))
         (end
        (if literal (or
            (search literal string :start2 position)
            (funcall invalid))
          (length string))))
    (if (= end position) (funcall invalid)
      (funcall on-success (subseq string position end) end))))

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
  (%pattern-read-year
    string
    position
    width
    remaining
    expected
    (function values)
    (%pattern-invalid-for-expected string expected)))

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
  (if (< width 3)
    (if (= width 1)
      (if (and remaining (consp (first remaining)) (eq (first (first remaining)) :field))
        (%pattern-parse-error string pattern)
        (%pattern-read-digits string position nil expected (function values)
          (%pattern-invalid-for-expected string expected)))
      (%pattern-read-digits string position width expected (function values)
        (%pattern-invalid-for-expected string expected)))
    (%pattern-read-text string position remaining pattern
      (lambda (text end)
        (let ((month (%date-time-locale-find-month locale text width)))
          (if month (values month end)
            (%pattern-parse-error string pattern))))
      (%pattern-invalid-for-pattern string pattern))))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

(define-pattern-field
  #\Y
  :write
  (%write-pattern-year
    stream
    (local-date-week-based-year
      (%require-pattern-field date pattern field "a date"))
    width)
  :read
  (%pattern-read-year
    string
    position
    width
    remaining
    expected
    (function values)
    (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-text string position remaining pattern
    (lambda (text end)
      (let ((weekday (%date-time-locale-find-weekday locale text width)))
        (if weekday (values weekday end)
          (%pattern-parse-error string pattern))))
    (%pattern-invalid-for-pattern string pattern)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-text string position remaining pattern (function values) (%pattern-invalid-for-pattern string pattern)))

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
  (%pattern-read-text string position remaining pattern (function values) (%pattern-invalid-for-pattern string pattern)))

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
  (%pattern-read-numeric-field string position field width remaining pattern expected (function values) (%pattern-invalid-for-expected string expected)))

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
  (%pattern-read-text string position remaining pattern
    (lambda (text end)
      (let ((meridiem (%date-time-locale-find-meridiem locale text)))
        (unless meridiem
          (%pattern-parse-error string pattern))
        (values meridiem end)))
    (%pattern-invalid-for-pattern string pattern)))

(defun %pattern-parse-parts (string parts position values pattern locale on-success)
  "Walks PARTS (literal strings interleaved with field specs, as produced by
DATE-TIME-FORMATTER-PARTS) against STRING starting at POSITION, threading
the scan position and the accumulated field VALUES forward as an explicit
continuation chain: matching a literal, or reading a field via
%PATTERN-READ-FIELD, calls %PATTERN-PARSE-PARTS on the remaining PARTS as
its own continuation -- step N's continuation IS step N+1's invocation --
mirroring the nested-continuation style PARSE-POSIX-TZ-STRING uses to chain
its own multi-step parse, instead of looping with mutation. Once PARTS is
exhausted, calls ON-SUCCESS with the final VALUES and POSITION."
  (if (null parts)
    (funcall on-success values position)
    (let ((part (first parts)))
      (if (stringp part)
        (let ((end (+ position (length part))))
          (unless (and (<= end (length string)) (string= part string :start2 position :end2 end))
            (%pattern-parse-error string pattern))
          (%pattern-parse-parts string (rest parts) end values pattern locale on-success))
        (let ((field (second part)))
          (when (%pattern-present-p field values)
            (%pattern-parse-error string pattern))
          (multiple-value-bind (value end)
              (%pattern-read-field string position field (third part) (rest parts) pattern locale)
            (%pattern-parse-parts
              string
              (rest parts)
              end
              (cons (list field value (third part)) values)
              pattern
              locale
              on-success)))))))

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
    (%pattern-parse-parts
      string
      (date-time-formatter-parts formatter)
      0
      '()
      (date-time-formatter-pattern formatter)
      (date-time-formatter-locale formatter)
      (lambda (values end-position)
        (unless (= end-position (length string))
          (%pattern-parse-error string (date-time-formatter-pattern formatter)))
        (%pattern-build-value
          string
          (date-time-formatter-pattern formatter)
          values
          disambiguation)))))

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
