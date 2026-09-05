(in-package #:cl-date-kit)

(defun %rrule-split (string delimiter)
  (let ((start 0)
        (parts nil))
    (loop for position = (position delimiter string :start start)
          do (push (subseq string start position) parts)
          while position
          do (setf start (1+ position)))
    (nreverse parts)))

(defun %rrule-parse-integer (string description)
  (labels ((invalid ()
             (%invalid-rrule (format nil "invalid ~A value" description) string)))
    (unless (and
        (plusp (length string))
        (if (member (char string 0) '(#\+ #\-)) (and (> (length string) 1) (every #'digit-char-p (subseq string 1)))
          (every #'digit-char-p string)))
      (invalid))
    (handler-case (parse-integer string :junk-allowed nil)
      (parse-error ()
        (invalid)))))

(defun %rrule-parse-list (value parser)
  (let ((items (%rrule-split value #\,)))
    (when (member "" items :test #'string=)
      (%invalid-rrule "RRULE list contains an empty item" value))
    (mapcar parser items)))

(defun %rrule-weekday (token)
  (let ((weekday (intern (string-upcase token) :keyword)))
    (unless (member weekday +rrule-weekdays+)
      (%invalid-rrule "invalid RFC 5545 weekday" token))
    weekday))

(defun %rrule-parse-by-day (token)
  (unless (>= (length token) 2)
    (%invalid-rrule "invalid BYDAY value" token))
  (let* ((weekday-start (- (length token) 2))
         (ordinal-text (subseq token 0 weekday-start)))
    (make-rrule-by-day
      (%rrule-weekday (subseq token weekday-start))
      (unless (string= ordinal-text "")
        (%rrule-parse-integer ordinal-text "BYDAY ordinal")))))

(defun %rrule-fixed-integer (string start end description)
  (let ((part (subseq string start end)))
    (unless (every #'digit-char-p part)
      (%invalid-rrule (format nil "invalid ~A value" description) string))
    (parse-integer part)))

(defun %rrule-parse-until (value)
  (cond
    ((and (= (length value) 8) (every #'digit-char-p value))
      (make-local-date
        (%rrule-fixed-integer value 0 4 "UNTIL")
        (%rrule-fixed-integer value 4 6 "UNTIL")
        (%rrule-fixed-integer value 6 8 "UNTIL")))
    (t
      (let* ((length (length value))
             (utc-p (and (plusp length) (char= (char value (1- length)) #\Z)))
             (body
            (if utc-p (subseq value 0 (1- length))
              value)))
        (unless (= (length body) 15)
          (%invalid-rrule "UNTIL must be RFC 5545 DATE or DATE-TIME" value))
        (unless (char= (char body 8) #\T)
          (%invalid-rrule "UNTIL DATE-TIME must include T" value))
        (let ((local
              (local-date-time-of
                (%rrule-fixed-integer body 0 4 "UNTIL")
                (%rrule-fixed-integer body 4 6 "UNTIL")
                (%rrule-fixed-integer body 6 8 "UNTIL")
                (%rrule-fixed-integer body 9 11 "UNTIL")
                (%rrule-fixed-integer body 11 13 "UNTIL")
                (%rrule-fixed-integer body 13 15 "UNTIL"))))
          (if utc-p (zoned-date-time-to-instant
              (zoned-date-time-of-local local (find-time-zone "UTC")))
            local))))))

(defun %rrule-format-until (until)
  (labels ((format-basic-local-date-time (local)
             (format
          nil
          "~4,'0D~2,'0D~2,'0DT~2,'0D~2,'0D~2,'0D"
          (local-date-time-year local)
          (local-date-time-month local)
          (local-date-time-day local)
          (local-date-time-hour local)
          (local-date-time-minute local)
          (local-date-time-second local))))
    (cond
      ((local-date-p until)
        (format
          nil
          "~4,'0D~2,'0D~2,'0D"
          (local-date-year until)
          (local-date-month until)
          (local-date-day until)))
      ((local-date-time-p until) (format-basic-local-date-time until))
      ((instant-p until)
        (let ((local
              (zoned-date-time-local
                (zoned-date-time-of-instant until (find-time-zone "UTC")))))
          (format nil "~AZ" (format-basic-local-date-time local))))
      (t
        (%invalid-rrule "UNTIL must be a local date, local date-time, or instant" until)))))

(defun parse-rrule (string)
  "Parse a complete RFC 5545 RRULE value (without an RRULE: prefix)."
  (unless (stringp string)
    (%invalid-rrule "RRULE must be a string" string))
  (let ((arguments nil)
        (seen (make-hash-table :test #'equal)))
    (dolist (clause (%rrule-split string #\;))
      (let ((equals (position #\= clause)))
        (unless (and equals (plusp equals) (< (1+ equals) (length clause)))
          (%invalid-rrule "invalid RRULE clause" clause))
        (let ((name (string-upcase (subseq clause 0 equals)))
              (value (subseq clause (1+ equals))))
          (when (gethash name seen)
            (%invalid-rrule "duplicate RRULE clause" name))
          (setf (gethash name seen) t)
          (push
            (cons
              name
              (cond
                ((string= name "FREQ")
                  (let ((frequency (intern (string-upcase value) :keyword)))
                    (unless (member frequency +rrule-frequencies+)
                      (%invalid-rrule "invalid FREQ value" value))
                    frequency))
                ((string= name "INTERVAL") (%rrule-parse-integer value name))
                ((string= name "COUNT") (%rrule-parse-integer value name))
                ((string= name "UNTIL") (%rrule-parse-until value))
                ((string= name "WKST") (%rrule-weekday value))
                ((string= name "BYSECOND")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                ((string= name "BYMINUTE")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                ((string= name "BYHOUR")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                ((string= name "BYDAY") (%rrule-parse-list value #'%rrule-parse-by-day))
                ((string= name "BYMONTHDAY")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                ((string= name "BYYEARDAY")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                ((string= name "BYWEEKNO")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                ((string= name "BYMONTH")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                ((string= name "BYSETPOS")
                  (%rrule-parse-list
                    value
                    (lambda (item)
                      (%rrule-parse-integer item name))))
                (t (%invalid-rrule "unknown RRULE clause" name))))
            arguments))))
    (unless (gethash "FREQ" seen)
      (%invalid-rrule "RRULE requires a FREQ clause" string))
    (flet ((argument (name)
             (cdr (assoc name arguments :test #'string=))))
      (make-rrule
        :frequency
        (argument "FREQ")
        :interval
        (or (argument "INTERVAL") 1)
        :count
        (argument "COUNT")
        :until
        (argument "UNTIL")
        :week-start
        (or (argument "WKST") :mo)
        :by-second
        (argument "BYSECOND")
        :by-minute
        (argument "BYMINUTE")
        :by-hour
        (argument "BYHOUR")
        :by-day
        (argument "BYDAY")
        :by-month-day
        (argument "BYMONTHDAY")
        :by-year-day
        (argument "BYYEARDAY")
        :by-week-no
        (argument "BYWEEKNO")
        :by-month
        (argument "BYMONTH")
        :by-set-pos
        (argument "BYSETPOS")))))

(defun %rrule-format-list (items formatter)
  (format nil "~{~A~^,~}" (mapcar formatter items)))

(defun %rrule-format-by-day (item)
  (format
    nil
    "~@[~D~]~A"
    (rrule-by-day-ordinal item)
    (string-upcase (symbol-name (rrule-by-day-weekday item)))))

(defun format-rrule (rrule &optional stream)
  "Format RRULE as its canonical RFC 5545 property-value string."
  (check-type rrule rrule)
  (let ((clauses
        (list
          (format nil "FREQ=~A" (string-upcase (symbol-name (rrule-frequency rrule)))))))
    (flet ((add (name value &optional (present-p value))
             (when present-p
            (setf clauses (append clauses (list (format nil "~A=~A" name value)))))))
      (add "INTERVAL" (rrule-interval rrule) (/= (rrule-interval rrule) 1))
      (add "COUNT" (rrule-count rrule))
      (when (rrule-until rrule)
        (add "UNTIL" (%rrule-format-until (rrule-until rrule))))
      (add
        "WKST"
        (string-upcase (symbol-name (rrule-week-start rrule)))
        (not (eq (rrule-week-start rrule) :mo)))
      (add
        "BYSECOND"
        (%rrule-format-list (rrule-by-second rrule) #'princ-to-string)
        (rrule-by-second rrule))
      (add
        "BYMINUTE"
        (%rrule-format-list (rrule-by-minute rrule) #'princ-to-string)
        (rrule-by-minute rrule))
      (add
        "BYHOUR"
        (%rrule-format-list (rrule-by-hour rrule) #'princ-to-string)
        (rrule-by-hour rrule))
      (add
        "BYDAY"
        (%rrule-format-list (rrule-by-day rrule) #'%rrule-format-by-day)
        (rrule-by-day rrule))
      (add
        "BYMONTHDAY"
        (%rrule-format-list (rrule-by-month-day rrule) #'princ-to-string)
        (rrule-by-month-day rrule))
      (add
        "BYYEARDAY"
        (%rrule-format-list (rrule-by-year-day rrule) #'princ-to-string)
        (rrule-by-year-day rrule))
      (add
        "BYWEEKNO"
        (%rrule-format-list (rrule-by-week-no rrule) #'princ-to-string)
        (rrule-by-week-no rrule))
      (add
        "BYMONTH"
        (%rrule-format-list (rrule-by-month rrule) #'princ-to-string)
        (rrule-by-month rrule))
      (add
        "BYSETPOS"
        (%rrule-format-list (rrule-by-set-pos rrule) #'princ-to-string)
        (rrule-by-set-pos rrule)))
    (let ((result (format nil "~{~A~^;~}" clauses)))
      (if stream (progn
          (write-string result stream)
          rrule)
        result))))
