(in-package #:cl-date-kit)

(defstruct (date-time-formatter
    (:constructor %make-date-time-formatter (pattern parts locale))) (pattern "" :type string :read-only t)
  (parts '() :type list :read-only t)
  (locale (find-date-time-locale :en) :type date-time-locale :read-only t))

(defparameter +pattern-fields+ "yMdDYweEHhmsSXVAza")

(defstruct (pattern-field-spec (:constructor %make-pattern-field-spec)) "The complete definition of one pattern field: its character, its width rule, and the writer/reader that implement it. Both WRITER and READER are mandatory, so a field can never be registered for validation without also being registered for formatting and parsing."
  (char
    (error "a pattern field spec requires a character")
    :type
    character
    :read-only
    t)
  (validate nil :type (or null function) :read-only t)
  (writer
    (error "a pattern field spec requires a writer")
    :type
    function
    :read-only
    t)
  (reader
    (error "a pattern field spec requires a reader")
    :type
    function
    :read-only
    t))

(defparameter *pattern-fields* (make-hash-table :test #'eql)
  "Maps a pattern field character to its complete PATTERN-FIELD-SPEC. Populated exclusively by DEFINE-PATTERN-FIELD, so every field's width rule, writer, and reader live together at one call site instead of three independently maintained per-field dispatches.")

(defmacro define-pattern-field (char &key validate write read)
  "Register CHAR's complete pattern field definition in *PATTERN-FIELDS*: its
width rule (VALIDATE, a form evaluated as (PATTERN FIELD WIDTH) that should
signal via %PATTERN-ERROR when WIDTH is unsupported), its WRITE clause (a
form evaluated as (STREAM FIELD WIDTH DATE TIME OFFSET ZONE INSTANT PATTERN
LOCALE) that writes to STREAM), and its READ clause (a form evaluated as
(STRING POSITION FIELD WIDTH REMAINING PATTERN LOCALE EXPECTED) that returns
(VALUES value end-position)). Wrap a clause in PROGN when it needs more than
one form.

WRITE and READ are mandatory: this macro errors at macroexpansion time if
either is omitted, so a field can never be accepted by +PATTERN-FIELDS+ and
%VALIDATE-PATTERN-FIELD while silently doing nothing when formatted or
parsed -- the exact shape of bug this table exists to prevent."
  (unless write
    (error "DEFINE-PATTERN-FIELD ~S: a :write clause is required" char))
  (unless read
    (error "DEFINE-PATTERN-FIELD ~S: a :read clause is required" char))
  `(setf (gethash ,char *pattern-fields*) (%make-pattern-field-spec
      :char
      ,char
      :validate
      (lambda (pattern field width)
        (declare (ignorable pattern field width))
        ,validate)
      :writer
      (lambda (stream field width date time offset zone instant pattern locale)
        (declare (ignorable stream field width date time offset zone instant pattern locale))
        ,write)
      :reader
      (lambda (string position field width remaining pattern locale)
        (declare (ignorable string position field width remaining pattern locale))
        (let ((expected (format nil "field ~C in pattern ~S" field pattern)))
          (declare (ignorable expected))
          ,read)))))

(defun %pattern-field-p (character)
  (and
    (alpha-char-p character)
    (nth-value 1 (gethash character *pattern-fields*))))

(defun %pattern-error (pattern control &rest arguments)
  (error
    'date-time-format-error
    :pattern
    pattern
    :reason
    (apply #'format nil control arguments)))

(defun %pattern-field-spec (pattern field)
  "Look up FIELD's complete PATTERN-FIELD-SPEC, or signal a format error if
FIELD was never registered via DEFINE-PATTERN-FIELD."
  (or
    (gethash field *pattern-fields*)
    (%pattern-error pattern "unsupported field ~C" field)))

(defun %validate-pattern-field (pattern field width)
  (unless (plusp width)
    (%pattern-error pattern "field ~C has no width" field))
  (funcall
    (pattern-field-spec-validate (%pattern-field-spec pattern field))
    pattern
    field
    width))

(defun %compile-date-time-pattern (pattern)
  (unless (stringp pattern)
    (%pattern-error pattern "a pattern must be a string"))
  (let ((parts '())
        (length (length pattern))
        (index 0))
    (labels ((add-literal (start end)
               (when (< start end)
            (push (subseq pattern start end) parts))))
      (loop while (< index length)
            do (let ((character (char pattern index)))
          (cond
            ((and
                (char= character #\')
                (< (1+ index) length)
                (char= (char pattern (1+ index)) #\'))
              (push "'" parts)
              (incf index 2))
            ((char= character #\')
              (let ((literal "")
                    (closed nil))
                (incf index)
                (loop while (< index length)
                      do (if (char= (char pattern index) #\') (if (and (< (1+ index) length) (char= (char pattern (1+ index)) #\')) (progn
                        (setf literal (concatenate 'string literal "'"))
                        (incf index 2))
                      (progn
                        (incf index)
                        (setf closed t)
                        (return)))
                    (progn
                      (setf literal (concatenate 'string literal (string (char pattern index))))
                      (incf index))))
                (unless closed
                  (%pattern-error pattern "unterminated quoted literal"))
                (push literal parts)))
            ((%pattern-field-p character)
              (let ((start index))
                (loop while (and (< index length) (char= (char pattern index) character))
                      do (incf index))
                (%validate-pattern-field pattern character (- index start))
                (push (list :field character (- index start)) parts)))
            ((alpha-char-p character)
              (%pattern-error pattern "unsupported field ~C" character))
            (t
              (let ((start index))
                (loop while (and
                    (< index length)
                    (not (char= (char pattern index) #\'))
                    (not (alpha-char-p (char pattern index))))
                      do (incf index))
                (add-literal start index))))))
      (nreverse parts))))

(defun make-date-time-formatter (pattern &key (locale :en))
  "Compile PATTERN into a reusable formatter for LOCALE.

Supported fields are y (year), M (month), d (day), D (day of year), Y (week
based year), w (week number), e (weekday), E (weekday name), H (24-hour
clock), h (12-hour clock), m (minute), s (second), S (fraction), A
(millisecond of day), a (AM/PM), X (ISO offset), V (IANA zone name), and z
(active IANA zone abbreviation).
Textual fields use LOCALE. Literal text is quoted with single quotes; doubled
quotes produce one quote."
  (let ((locale-object (find-date-time-locale locale)))
    (%make-date-time-formatter
      pattern
      (%compile-date-time-pattern pattern)
      locale-object)))

(defun %write-pattern-number (stream number width)
  (if (= width 1) (princ number stream)
    (format stream "~v,'0D" width number)))

(defun %write-pattern-year (stream year width)
  "Writes calendar and ISO week-based years with ISO signed expansion."
  (if (and (>= width 4) (or (minusp year) (> year 9999))) (format
      stream
      "~A~v,'0D"
      (if (minusp year) "-"
        "+")
      (max 4 width)
      (abs year))
    (%write-pattern-number stream year width)))

(defun %require-pattern-field (value pattern field field-name)
  (or value (%pattern-error pattern "field ~C requires ~A" field field-name)))

(defun %write-pattern-offset (stream offset width pattern)
  (let ((total (zone-offset-total-seconds offset)))
    (if (zerop total) (write-char #\Z stream)
      (multiple-value-bind (sign absolute) (if (minusp total) (values #\- (- total))
          (values #\+ total))
        (multiple-value-bind (hours remainder) (floor absolute 3600)
          (multiple-value-bind (minutes seconds) (floor remainder 60)
            (when (and (not (zerop seconds)) (< width 3))
              (%pattern-error
                pattern
                "field X width ~D cannot represent offset seconds"
                width))
            (ecase width
              (1 (format stream "~C~2,'0D" sign hours))
              (2 (format stream "~C~2,'0D~2,'0D" sign hours minutes))
              (3
                (if (zerop seconds) (format stream "~C~2,'0D:~2,'0D" sign hours minutes)
                  (format stream "~C~2,'0D:~2,'0D:~2,'0D" sign hours minutes seconds))))))))))

(defun %write-pattern-field (stream field width date time offset zone instant pattern locale)
  (funcall
    (pattern-field-spec-writer (%pattern-field-spec pattern field))
    stream
    field
    width
    date
    time
    offset
    zone
    instant
    pattern
    locale))

(defun %pattern-context (value formatter zone)
  (cond
    ((local-date-p value) (values value nil nil nil nil))
    ((local-time-p value) (values nil value nil nil nil))
    ((offset-time-p value)
      (values nil (offset-time-time value) (offset-time-offset value) nil nil))
    ((local-date-time-p value)
      (values (local-date-time-date value) (local-date-time-time value) nil nil nil))
    ((offset-date-time-p value)
      (values
        (offset-date-time-date value)
        (offset-date-time-time value)
        (offset-date-time-offset value)
        nil
        nil))
    ((zoned-date-time-p value)
      (values
        (local-date-time-date (zoned-date-time-local value))
        (local-date-time-time (zoned-date-time-local value))
        (zoned-date-time-offset value)
        (zoned-date-time-zone value)
        (zoned-date-time-to-instant value)))
    ((instant-p value)
      (let* ((resolved-zone (or zone (zone-offset-utc)))
             (offset
            (if (time-zone-p resolved-zone) (offset-for-instant resolved-zone value)
              resolved-zone))
             (local
            (local-date-time-of-epoch-second
              (instant-epoch-second value)
              (instant-nanosecond value)
              offset)))
        (values
          (local-date-time-date local)
          (local-date-time-time local)
          offset
          resolved-zone
          value)))
    (t
      (%pattern-error
        (date-time-formatter-pattern formatter)
        "~S is not a supported temporal value"
        value))))

(defun format-date-time (formatter value &key zone)
  "Format VALUE using compiled DATE-TIME-FORMATTER FORMATTER.

When VALUE is an INSTANT, ZONE selects the zone used to derive local fields."
  (unless (date-time-formatter-p formatter)
    (error 'type-error :datum formatter :expected-type 'date-time-formatter))
  (when (and zone (not (instant-p value)))
    (%pattern-error
      (date-time-formatter-pattern formatter)
      "the :ZONE option is only supported for INSTANT values"))
  (multiple-value-bind (date time offset resolved-zone instant) (%pattern-context value formatter zone)
    (with-output-to-string (stream)
      (dolist (part (date-time-formatter-parts formatter))
        (if (stringp part) (write-string part stream)
          (%write-pattern-field
            stream
            (second part)
            (third part)
            date
            time
            offset
            resolved-zone
            instant
            (date-time-formatter-pattern formatter)
            (date-time-formatter-locale formatter)))))))

(defun format-date-time-with-pattern (pattern value &key (locale :en) zone)
  "Format VALUE with PATTERN and LOCALE without retaining a formatter instance."
  (format-date-time
    (make-date-time-formatter pattern :locale locale)
    value
    :zone
    zone))
