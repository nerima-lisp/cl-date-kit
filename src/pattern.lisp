;;;; src/pattern.lisp
;;;;
;;;; A deliberately small, locale-independent pattern formatter. A formatter
;;;; is compiled once, then can be reused without re-scanning its pattern.
(in-package #:cl-date-kit)

(defstruct (date-time-formatter
            (:constructor %make-date-time-formatter (pattern parts)))
  (pattern "" :type string :read-only t)
  (parts '() :type list :read-only t))

(defparameter +pattern-fields+ "yMdDYweHmsSXV")

(defun %pattern-field-p (character)
  (and (alpha-char-p character)
       (find character +pattern-fields+ :test #'char=)))

(defun %pattern-error (pattern control &rest arguments)
  (error 'date-time-format-error
         :pattern pattern
         :reason (apply #'format nil control arguments)))

(defun %validate-pattern-field (pattern field width)
  (unless (plusp width)
    (%pattern-error pattern "field ~C has no width" field))
  (when (and (member field '(#\S #\X)) (> width (if (char= field #\S) 9 3)))
    (%pattern-error pattern "field ~C has unsupported width ~D" field width))
  (when (and (member field '(#\M #\d #\w #\e #\H #\m #\s)) (> width 2))
    (%pattern-error pattern "field ~C only supports widths 1 or 2" field))
  (when (and (char= field #\D) (> width 3))
    (%pattern-error pattern "field ~C only supports widths 1 through 3" field))
  (when (and (char= field #\V) (> width 1))
    (%pattern-error pattern "field ~C only supports width 1" field)))

(defun %compile-date-time-pattern (pattern)
  (unless (stringp pattern)
    (%pattern-error pattern "a pattern must be a string"))
  (let ((parts '())
        (length (length pattern))
        (index 0))
    (labels ((add-literal (start end)
               (when (< start end)
                 (push (subseq pattern start end) parts))))
      (loop while (< index length) do
        (let ((character (char pattern index)))
          (cond
            ((and (char= character #\')
                  (< (1+ index) length)
                  (char= (char pattern (1+ index)) #\'))
             (push "'" parts)
             (incf index 2))
            ((char= character #\')
             (let ((literal "")
                   (closed nil))
               (incf index)
               (loop while (< index length) do
                 (if (char= (char pattern index) #\')
                     (if (and (< (1+ index) length)
                              (char= (char pattern (1+ index)) #\'))
                         (progn
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
               (loop while (and (< index length) (char= (char pattern index) character)) do
                 (incf index))
               (%validate-pattern-field pattern character (- index start))
               (push (list :field character (- index start)) parts)))
            ((alpha-char-p character)
             (%pattern-error pattern "unsupported field ~C" character))
            (t
             (let ((start index))
               (loop while (and (< index length)
                                (not (char= (char pattern index) #\'))
                                (not (alpha-char-p (char pattern index)))) do
                 (incf index))
               (add-literal start index))))))
    (nreverse parts))))

(defun make-date-time-formatter (pattern)
  "Compile PATTERN for reuse by FORMAT-DATE-TIME.

Supported fields are y (calendar year), M (month), d (day), D (day of year),
Y (ISO week-based year), w (ISO week), e (ISO weekday), H/m/s (time), S
(fractional nanoseconds), X (ISO offset), and V (IANA zone name). Quote
literals with apostrophes; use two apostrophes for a literal apostrophe."
  (%make-date-time-formatter pattern (%compile-date-time-pattern pattern)))

(defun %format-pattern-number (number width)
  (if (= width 1)
      (princ-to-string number)
      (format nil "~v,'0D" width number)))

(defun %pattern-context (value formatter)
  (cond
    ((local-date-p value) (values value nil nil nil))
    ((local-time-p value) (values nil value nil nil))
    ((local-date-time-p value)
     (values (local-date-time-date value) (local-date-time-time value) nil nil))
    ((offset-date-time-p value)
     (values (offset-date-time-date value) (offset-date-time-time value)
             (offset-date-time-offset value) nil))
    ((zoned-date-time-p value)
     (values (local-date-time-date (zoned-date-time-local value))
             (local-date-time-time (zoned-date-time-local value))
             (zoned-date-time-offset value)
             (zoned-date-time-zone value)))
    ((instant-p value)
     (let ((local (%instant-to-local-date-time value (zone-offset-utc))))
       (values (local-date-time-date local) (local-date-time-time local)
               (zone-offset-utc) nil)))
    (t (%pattern-error (date-time-formatter-pattern formatter)
                       "~S is not a supported temporal value" value))))

(defun %require-pattern-field (value pattern field field-name)
  (or value (%pattern-error pattern "field ~C requires ~A" field field-name)))

(defun %format-pattern-offset (offset width pattern)
  (let ((total (zone-offset-total-seconds offset)))
    (if (zerop total) "Z"
        (multiple-value-bind (sign absolute)
            (if (minusp total) (values "-" (- total)) (values "+" total))
          (multiple-value-bind (hours remainder) (floor absolute 3600)
            (multiple-value-bind (minutes seconds) (floor remainder 60)
              (when (and (not (zerop seconds)) (< width 3))
                (%pattern-error pattern "field X width ~D cannot represent offset seconds" width))
              (ecase width
                (1 (format nil "~A~2,'0D" sign hours))
                (2 (format nil "~A~2,'0D~2,'0D" sign hours minutes))
                (3 (if (zerop seconds)
                       (format nil "~A~2,'0D:~2,'0D" sign hours minutes)
                       (format nil "~A~2,'0D:~2,'0D:~2,'0D" sign hours minutes seconds))))))))))

(defun %format-pattern-field (field width date time offset zone pattern)
  (case field
    (#\y (%format-pattern-number (local-date-year (%require-pattern-field date pattern field "a date")) width))
    (#\M (%format-pattern-number (local-date-month (%require-pattern-field date pattern field "a date")) width))
    (#\d (%format-pattern-number (local-date-day (%require-pattern-field date pattern field "a date")) width))
    (#\D (%format-pattern-number (day-of-year (%require-pattern-field date pattern field "a date")) width))
    (#\Y (%format-pattern-number (local-date-week-based-year (%require-pattern-field date pattern field "a date")) width))
    (#\w (%format-pattern-number (local-date-week-of-week-based-year (%require-pattern-field date pattern field "a date")) width))
    (#\e (%format-pattern-number (%iso-weekday-number (%require-pattern-field date pattern field "a date")) width))
    (#\H (%format-pattern-number (local-time-hour (%require-pattern-field time pattern field "a time")) width))
    (#\m (%format-pattern-number (local-time-minute (%require-pattern-field time pattern field "a time")) width))
    (#\s (%format-pattern-number (local-time-second (%require-pattern-field time pattern field "a time")) width))
    (#\S (subseq (format nil "~9,'0D" (local-time-nanosecond (%require-pattern-field time pattern field "a time"))) 0 width))
    (#\X (%format-pattern-offset (%require-pattern-field offset pattern field "an offset") width pattern))
    (#\V (let ((resolved-zone (%require-pattern-field zone pattern field "an IANA time zone")))
           (if (time-zone-p resolved-zone)
               (time-zone-name resolved-zone)
               (%pattern-error pattern "field V requires an IANA time zone"))))))

(defun format-date-time (formatter value)
  "Format VALUE using compiled DATE-TIME-FORMATTER FORMATTER."
  (unless (date-time-formatter-p formatter)
    (error 'type-error :datum formatter :expected-type 'date-time-formatter))
  (multiple-value-bind (date time offset zone) (%pattern-context value formatter)
    (with-output-to-string (stream)
      (dolist (part (date-time-formatter-parts formatter))
        (if (stringp part)
            (write-string part stream)
            (write-string (%format-pattern-field (second part) (third part) date time offset zone
                                                 (date-time-formatter-pattern formatter))
                          stream))))))

(defun format-date-time-with-pattern (pattern value)
  "Format VALUE with PATTERN without retaining a formatter instance."
  (format-date-time (make-date-time-formatter pattern) value))
