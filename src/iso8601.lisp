;;;; src/iso8601.lisp
;;;;
;;;; ISO-8601 / RFC-3339 formatting and parsing for every type in this
;;;; library. Formatters emit canonical extended forms; parsers also accept
;;;; ISO 8601 basic calendar, ordinal-date, and week-date forms where a date
;;;; is syntactically permitted.
(in-package #:cl-date-kit)

;;; --- LocalTime -------------------------------------------------------------
(progn
  (defun %write-local-time (time stream)
    (if (zerop (local-time-nanosecond time)) (format
        stream
        "~2,'0D:~2,'0D:~2,'0D"
        (local-time-hour time)
        (local-time-minute time)
        (local-time-second time))
      (format
        stream
        "~2,'0D:~2,'0D:~2,'0D.~9,'0D"
        (local-time-hour time)
        (local-time-minute time)
        (local-time-second time)
        (local-time-nanosecond time))))
  (defun format-local-time (time)
    (with-output-to-string (stream)
      (%write-local-time time stream))))

(defun parse-local-time (string)
  (with-date-time-parse-error
    (string "HH:MM:SS[.nnnnnnnnn] or HHMMSS[.nnnnnnnnn]")
    (let* ((length (and (stringp string) (length string)))
           (extended-p
          (and
            length
            (>= length 8)
            (char= (char string 2) #\:)
            (char= (char string 5) #\:)
            (or
              (= length 8)
              (and
                (<= 10 length 18)
                (char= (char string 8) #\.)
                (loop for index from 9 below length
                      always (digit-char-p (char string index)))))))
           (basic-p
          (and
            length
            (>= length 6)
            (loop for index from 0 below 6
                  always (digit-char-p (char string index)))
            (or
              (= length 6)
              (and
                (<= 8 length 16)
                (char= (char string 6) #\.)
                (loop for index from 7 below length
                      always (digit-char-p (char string index))))))))
      (unless (or extended-p basic-p)
        (error
          (quote date-time-parse-error)
          :string
          string
          :expected
          "HH:MM:SS[.nnnnnnnnn] or HHMMSS[.nnnnnnnnn]"))
      (if extended-p (make-local-time
          (%parse-fixed-integer string 0 2 "HH:MM:SS")
          (%parse-fixed-integer string 3 5 "HH:MM:SS")
          (%parse-fixed-integer string 6 8 "HH:MM:SS")
          (if (= length 8) 0
            (*
              (%parse-fixed-integer string 9 length "HH:MM:SS.nnnnnnnnn")
              (expt 10 (- 18 length)))))
        (make-local-time
          (%parse-fixed-integer string 0 2 "HHMMSS")
          (%parse-fixed-integer string 2 4 "HHMMSS")
          (%parse-fixed-integer string 4 6 "HHMMSS")
          (if (= length 6) 0
            (*
              (%parse-fixed-integer string 7 length "HHMMSS.nnnnnnnnn")
              (expt 10 (- 16 length)))))))))

;;; --- LocalDateTime ---------------------------------------------------------
(progn
  (defun %write-local-date-time (date-time stream)
    (%write-local-date (local-date-time-date date-time) stream)
    (write-char #\T stream)
    (%write-local-time (local-date-time-time date-time) stream))
  (defun format-local-date-time (dt)
    (with-output-to-string (stream)
      (%write-local-date-time dt stream))))

(defun parse-local-date-time (string)
  (with-date-time-parse-error
    (string "YYYY-MM-DDTHH:MM:SS")
    (let ((sep (or (position #\T string) (position #\t string))))
      (unless sep
        (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SS"))
      (make-local-date-time
        (parse-local-date (subseq string 0 sep))
        (parse-local-time (subseq string (1+ sep)))))))

(defun %parse-local-date-time-and-offset (string)
  (unless (stringp string)
    (error
      (quote date-time-parse-error)
      :string
      string
      :expected
      "YYYY-MM-DDTHH:MM:SS[Z|+HH[:MM[:SS]]|+HHMM[SS]]"))
  (let ((t-pos (or (position #\T string) (position #\t string))))
    (unless t-pos
      (error
        (quote date-time-parse-error)
        :string
        string
        :expected
        "YYYY-MM-DDTHH:MM:SS[Z|+HH[:MM[:SS]]|+HHMM[SS]]"))
    (let ((offset-start
          (position-if
            (lambda (character)
              (or
                (char= character #\+)
                (char= character #\-)
                (char= character #\Z)
                (char= character #\z)))
            string
            :start
            (1+ t-pos))))
      (unless offset-start
        (error
          (quote date-time-parse-error)
          :string
          string
          :expected
          "YYYY-MM-DDTHH:MM:SS[Z|+HH[:MM[:SS]]|+HHMM[SS]]"))
      (values
        (parse-local-date-time (subseq string 0 offset-start))
        (parse-zone-offset string offset-start (length string))))))

;;; --- Instant ---------------------------------------------------------------
(defun format-instant (instant)
  (with-output-to-string (stream)
    (%write-local-date-time
      (local-date-time-of-instant instant (zone-offset-utc))
      stream)
    (write-char #\Z stream)))

(progn
  (defun %parse-canonical-utc-instant (string)
    "Parse canonical YYYY-MM-DDTHH:MM:SSZ without intermediate date-time values."
    (when (and
        (stringp string)
        (= (length string) 20)
        (char= (char string 4) #\-)
        (char= (char string 7) #\-)
        (char= (char string 10) #\T)
        (char= (char string 13) #\:)
        (char= (char string 16) #\:)
        (char= (char string 19) #\Z))
      (with-date-time-parse-error
        (string "YYYY-MM-DDTHH:MM:SSZ")
        (labels ((digit-at (index)
                   (or
                (digit-char-p (char string index))
                (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SSZ")))
                 (two-digits-at (index)
                   (+ (* 10 (digit-at index)) (digit-at (1+ index)))))
          (let* ((year
                (+ (* 1000 (digit-at 0)) (* 100 (digit-at 1)) (* 10 (digit-at 2)) (digit-at 3)))
                 (month (two-digits-at 5))
                 (day (two-digits-at 8))
                 (hour (two-digits-at 11))
                 (minute (two-digits-at 14))
                 (second (two-digits-at 17)))
            (unless (and (<= 1 month 12) (<= 1 day (length-of-month year month)))
              (error 'invalid-date :year year :month month :day day))
            (unless (and (<= 0 hour 23) (<= 0 minute 59) (<= 0 second 59))
              (error 'invalid-time :hour hour :minute minute :second second :nanosecond 0))
            (%make-instant
              (+
                (* (%days-from-civil year month day) +seconds-per-day+)
                (* hour 3600)
                (* minute 60)
                second)
              0))))))
  (defun parse-instant (string)
    (or
      (%parse-canonical-utc-instant string)
      (multiple-value-bind (local-date-time offset) (%parse-local-date-time-and-offset string)
        (local-date-time-to-instant local-date-time offset)))))

;;; --- ZoneOffset --------------------------------------------------------------
(progn
  (defun %write-zone-offset (offset stream)
    (let ((total (zone-offset-total-seconds offset)))
      (if (zerop total) (write-char #\Z stream)
        (multiple-value-bind (sign absolute) (if (minusp total) (values "-" (- total))
            (values "+" total))
          (multiple-value-bind (hours remainder) (floor absolute 3600)
            (multiple-value-bind (minutes seconds) (floor remainder 60)
              (if (zerop seconds) (format stream "~A~2,'0D:~2,'0D" sign hours minutes)
                (format stream "~A~2,'0D:~2,'0D:~2,'0D" sign hours minutes seconds))))))))
  (defun format-zone-offset (offset)
    (with-output-to-string (stream)
      (%write-zone-offset offset stream))))

(defun parse-zone-offset (string &optional (start 0) end)
  "Parses an ISO 8601 UTC offset in UTC, extended, or basic notation."
  (let ((end (or end (and (stringp string) (length string)))))
    (labels ((error-string ()
               (if (and (stringp string) (zerop start) (= end (length string))) string
            (if (stringp string) (subseq string start end)
              string)))
             (invalid-input ()
               (error
            'date-time-parse-error
            :string
            (error-string)
            :expected
            "Z or +HH[:MM[:SS]] or +HHMM[SS]"))
             (digits-at-p (indices)
               (every
            (lambda (index)
              (digit-char-p (char string (+ start index))))
            indices))
             (parse-components (sign
            hours-start
            hours-end
            &optional
            minutes-start
            minutes-end
            seconds-start
            seconds-end)
               (zone-offset-of-hms
            (*
              sign
              (%parse-fixed-integer
                string
                (+ start hours-start)
                (+ start hours-end)
                "ISO 8601 zone offset"))
            (*
              sign
              (if minutes-start (%parse-fixed-integer
                  string
                  (+ start minutes-start)
                  (+ start minutes-end)
                  "ISO 8601 zone offset")
                0))
            (*
              sign
              (if seconds-start (%parse-fixed-integer
                  string
                  (+ start seconds-start)
                  (+ start seconds-end)
                  "ISO 8601 zone offset")
                0)))))
      (if (stringp string) (let ((length (- end start)))
          (cond
            ((and (= length 1) (char-equal (char string start) #\Z)) (zone-offset-utc))
            ((and (>= length 3) (member (char string start) '(#\+ #\-)))
              (let ((sign
                    (if (char= (char string start) #\-) -1
                      1)))
                (handler-case (cond
                    ((and (= length 3) (digits-at-p '(1 2))) (parse-components sign 1 3))
                    ((and (= length 5) (digits-at-p '(1 2 3 4))) (parse-components sign 1 3 3 5))
                    ((and
                        (= length 6)
                        (char= (char string (+ start 3)) #\:)
                        (digits-at-p '(1 2 4 5)))
                      (parse-components sign 1 3 4 6))
                    ((and (= length 7) (digits-at-p '(1 2 3 4 5 6)))
                      (parse-components sign 1 3 3 5 5 7))
                    ((and
                        (= length 9)
                        (char= (char string (+ start 3)) #\:)
                        (char= (char string (+ start 6)) #\:)
                        (digits-at-p '(1 2 4 5 7 8)))
                      (parse-components sign 1 3 4 6 7 9))
                    (t (invalid-input)))
                  (invalid-zone-offset ()
                    (invalid-input)))))
            (t (invalid-input))))
        (invalid-input)))))

;;; --- OffsetDateTime ---------------------------------------------------------
(defun format-offset-date-time (offset-date-time)
  (with-output-to-string (stream)
    (%write-local-date-time
      (offset-date-time-local-date-time offset-date-time)
      stream)
    (%write-zone-offset (offset-date-time-offset offset-date-time) stream)))

(defun parse-offset-date-time (string)
  "Parses an ISO 8601 local date-time with a required numeric or UTC offset."
  (multiple-value-bind (local-date-time offset) (%parse-local-date-time-and-offset string)
    (make-offset-date-time local-date-time offset)))

;;; --- OffsetTime -------------------------------------------------------------
(defun format-offset-time (offset-time)
  (with-output-to-string (stream)
    (%write-local-time (offset-time-local-time offset-time) stream)
    (%write-zone-offset (offset-time-offset offset-time) stream)))

(defun parse-offset-time (string)
  "Parses an ISO 8601 local time with a required numeric or UTC offset."
  (unless (stringp string)
    (error
      (quote date-time-parse-error)
      :string
      string
      :expected
      "HH:MM:SS[Z|+HH[:MM[:SS]]|+HHMM[SS]]"))
  (let ((offset-start
        (position-if
          (lambda (character)
            (or
              (char= character #\Z)
              (char= character #\z)
              (char= character #\+)
              (char= character #\-)))
          string
          :start
          0)))
    (unless offset-start
      (error
        (quote date-time-parse-error)
        :string
        string
        :expected
        "HH:MM:SS[Z|+HH[:MM[:SS]]|+HHMM[SS]]"))
    (make-offset-time
      (parse-local-time (subseq string 0 offset-start))
      (parse-zone-offset string offset-start (length string)))))

;;; --- ZonedDateTime -----------------------------------------------------------
(defun format-zoned-date-time (zoned-date-time)
  (concatenate
    'string
    (format-local-date-time (zoned-date-time-local zoned-date-time))
    (format-zone-offset (zoned-date-time-offset zoned-date-time))
    (if (time-zone-p (zoned-date-time-zone zoned-date-time)) (concatenate
        'string
        "["
        (time-zone-name (zoned-date-time-zone zoned-date-time))
        "]")
      "")))

;;; --- Duration ("PT..." -- java.time's Duration.toString style) --------------
(defun parse-zoned-date-time (string)
  "Parses an ISO 8601 local date-time with an explicit offset and optional zone.
When a zone suffix is present, its rules must admit the explicit offset."
  (unless (stringp string)
    (error
      'date-time-parse-error
      :string
      string
      :expected
      "YYYY-MM-DDTHH:MM:SS+HH:MM[Zone/Id]"))
  (let* ((t-pos (or (position #\T string) (position #\t string)))
         (open-bracket (position #\[ string))
         (close-bracket (position #\] string))
         (length (length string)))
    (unless (and
        t-pos
        (or
          (and (null open-bracket) (null close-bracket))
          (and
            open-bracket
            close-bracket
            (> close-bracket (1+ open-bracket))
            (= close-bracket (1- length)))))
      (error
        'date-time-parse-error
        :string
        string
        :expected
        "YYYY-MM-DDTHH:MM:SS+HH:MM[Zone/Id]"))
    (let* ((offset-end (or open-bracket length))
           (sign-pos
          (position-if
            (lambda (character)
              (member character '(#\+ #\- #\Z #\z)))
            string
            :start
            (1+ t-pos)
            :end
            offset-end)))
      (unless sign-pos
        (error
          'date-time-parse-error
          :string
          string
          :expected
          "YYYY-MM-DDTHH:MM:SS+HH:MM[Zone/Id]"))
      (let* ((local (parse-local-date-time (subseq string 0 sign-pos)))
             (offset (parse-zone-offset string sign-pos offset-end))
             (zone
            (if open-bracket (handler-case (find-time-zone (subseq string (1+ open-bracket) close-bracket))
                (cl-date-kit-error ()
                  (error 'date-time-parse-error :string string :expected "known Zone/Id")))
              offset)))
        (when open-bracket
          (unless (%local-date-time-has-offset-p local zone offset)
            (error
              'date-time-parse-error
              :string
              string
              :expected
              "offset valid for Zone/Id")))
        (%make-zoned-date-time local zone offset)))))
