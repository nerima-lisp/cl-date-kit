;;;; src/pattern.lisp
;;;;
;;;; A deliberately small, locale-independent pattern formatter. A formatter
;;;; is compiled once, then can be reused without re-scanning its pattern.
(in-package #:cl-date-kit)

(defstruct (date-time-formatter
    (:constructor %make-date-time-formatter (pattern parts locale))) (pattern "" :type string :read-only t)
  (parts '() :type list :read-only t)
  (locale (find-date-time-locale :en) :type date-time-locale :read-only t))

(defparameter +pattern-fields+ "yMdDYweEHhmsSXVAza")

(defun %pattern-field-p (character)
  (and (alpha-char-p character) (find character +pattern-fields+ :test #'char=)))

(defun %pattern-error (pattern control &rest arguments)
  (error
    'date-time-format-error
    :pattern
    pattern
    :reason
    (apply #'format nil control arguments)))

(defun %validate-pattern-field (pattern field width)
  (unless (plusp width)
    (%pattern-error pattern "field ~C has no width" field))
  (when (and
      (member field (list #\S #\X))
      (>
        width
        (if (char= field #\S) 9
          3)))
    (%pattern-error pattern "field ~C has unsupported width ~D" field width))
  (when (and (char= field #\M) (> width 4))
    (%pattern-error pattern "field ~C only supports widths 1 through 4" field))
  (when (and (char= field #\E) (not (member width (list 3 4))))
    (%pattern-error pattern "field ~C only supports widths 3 or 4" field))
  (when (and (member field (list #\a #\V #\z)) (/= width 1))
    (%pattern-error pattern "field ~C only supports width 1" field))
  (when (and (member field (list #\d #\w #\e #\H #\h #\m #\s)) (> width 2))
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  (when (and (char= field #\D) (> width 3))
    (%pattern-error pattern "field ~C only supports widths 1 through 3" field)))

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
  (case field
    (#\y
      (%write-pattern-year
        stream
        (local-date-year (%require-pattern-field date pattern field "a date"))
        width))
    (#\M
      (let ((month (local-date-month (%require-pattern-field date pattern field "a date"))))
        (if (< width 3) (%write-pattern-number stream month width)
          (write-string (%date-time-locale-month-name locale month width) stream))))
    (#\d
      (%write-pattern-number
        stream
        (local-date-day (%require-pattern-field date pattern field "a date"))
        width))
    (#\D
      (%write-pattern-number
        stream
        (day-of-year (%require-pattern-field date pattern field "a date"))
        width))
    (#\Y
      (%write-pattern-year
        stream
        (local-date-week-based-year
          (%require-pattern-field date pattern field "a date"))
        width))
    (#\w
      (%write-pattern-number
        stream
        (local-date-week-of-week-based-year
          (%require-pattern-field date pattern field "a date"))
        width))
    (#\e
      (%write-pattern-number
        stream
        (%iso-weekday-number (%require-pattern-field date pattern field "a date"))
        width))
    (#\E
      (write-string
        (%date-time-locale-weekday-name
          locale
          (day-of-week (%require-pattern-field date pattern field "a date"))
          width)
        stream))
    ((#\H #\h)
      (%write-pattern-number
        stream
        (let ((hour (local-time-hour (%require-pattern-field time pattern field "a time"))))
          (if (char= field #\H) hour
            (if (zerop hour) 12
              (if (> hour 12) (- hour 12)
                hour))))
        width))
    (#\m
      (%write-pattern-number
        stream
        (local-time-minute (%require-pattern-field time pattern field "a time"))
        width))
    (#\s
      (%write-pattern-number
        stream
        (local-time-second (%require-pattern-field time pattern field "a time"))
        width))
    (#\a
      (write-string
        (%date-time-locale-meridiem
          locale
          (local-time-hour (%require-pattern-field time pattern field "a time")))
        stream))
    (#\S
      (%write-pattern-number
        stream
        (floor
          (local-time-nanosecond (%require-pattern-field time pattern field "a time"))
          (expt 10 (- 9 width)))
        width))
    (#\A
      (%write-pattern-number
        stream
        (floor
          (local-time-to-nano-of-day (%require-pattern-field time pattern field "a time"))
          1000000)
        width))
    (#\X
      (%write-pattern-offset
        stream
        (%require-pattern-field offset pattern field "an offset")
        width
        pattern))
    (#\V
      (let ((resolved-zone (%require-pattern-field zone pattern field "an IANA time zone")))
        (if (time-zone-p resolved-zone) (write-string (time-zone-name resolved-zone) stream)
          (%pattern-error pattern "field V requires an IANA time zone"))))
    (#\z
      (let ((resolved-zone (%require-pattern-field zone pattern field "an IANA time zone"))
            (resolved-instant (%require-pattern-field instant pattern field "an instant")))
        (unless (time-zone-p resolved-zone)
          (%pattern-error pattern "field z requires an IANA time zone"))
        (write-string
          (or
            (zone-state-abbreviation
              (zone-state-for-instant resolved-zone resolved-instant))
            (%pattern-error pattern "field z has no abbreviation for the active zone state"))
          stream)))))

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
