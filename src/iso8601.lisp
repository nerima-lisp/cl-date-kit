;;;; src/iso8601.lisp
;;;;
;;;; ISO-8601 / RFC-3339 formatting and parsing for every type in this
;;;; library. Only the canonical extended forms are supported (the ones
;;;; every reference library defaults to: "YYYY-MM-DD", "HH:MM:SS[.nnn]",
;;;; the "T"-separated combination, a "Z" or "+HH:MM" offset, and java.time's
;;;; "[Zone/Id]" suffix for zoned values) -- not the full ISO-8601 grammar's
;;;; basic-format, week-date, or ordinal-date variants.
(in-package #:cl-date-kit)

(defun %parse-fixed-integer (string start end expected)
  (handler-case (parse-integer string :start start :end end)
    (error () (error 'date-time-parse-error :string string :expected expected))))

(defun %parse-decimal (string start end expected)
  "Parses a possibly-fractional decimal number in STRING[START,END) as a rational."
  (let ((dot (position #\. string :start start :end end)))
    (if dot
        (+ (%parse-fixed-integer string start dot expected)
           (let ((frac (subseq string (1+ dot) end)))
             (if (plusp (length frac)) (/ (%parse-fixed-integer frac 0 (length frac) expected) (expt 10 (length frac))) 0)))
        (%parse-fixed-integer string start end expected))))

;;; --- LocalDate -----------------------------------------------------------

(defun format-local-date (date)
  (format nil "~4,'0D-~2,'0D-~2,'0D" (local-date-year date) (local-date-month date) (local-date-day date)))

(defun parse-local-date (string)
  (unless (and (= (length string) 10) (char= (char string 4) #\-) (char= (char string 7) #\-))
    (error 'date-time-parse-error :string string :expected "YYYY-MM-DD"))
  (make-local-date (%parse-fixed-integer string 0 4 "YYYY-MM-DD")
                    (%parse-fixed-integer string 5 7 "YYYY-MM-DD")
                    (%parse-fixed-integer string 8 10 "YYYY-MM-DD")))

;;; --- LocalTime -------------------------------------------------------------

(defun format-local-time (time)
  (if (zerop (local-time-nanosecond time))
      (format nil "~2,'0D:~2,'0D:~2,'0D" (local-time-hour time) (local-time-minute time) (local-time-second time))
      (format nil "~2,'0D:~2,'0D:~2,'0D.~9,'0D"
              (local-time-hour time) (local-time-minute time) (local-time-second time) (local-time-nanosecond time))))

(defun parse-local-time (string) (let ((length (and (stringp string) (length string)))) (unless (and length (or (= length 8) (and (<= 10 length 18) (char= (char string 8) #\.) (loop for index from 9 below length always (digit-char-p (char string index))))) (char= (char string 2) #\:) (char= (char string 5) #\:)) (error (quote date-time-parse-error) :string string :expected "HH:MM:SS[.nnnnnnnnn]")) (make-local-time (%parse-fixed-integer string 0 2 "HH:MM:SS") (%parse-fixed-integer string 3 5 "HH:MM:SS") (%parse-fixed-integer string 6 8 "HH:MM:SS") (if (= length 8) 0 (* (%parse-fixed-integer string 9 length "HH:MM:SS.nnnnnnnnn") (expt 10 (- 18 length)))))))

;;; --- LocalDateTime ---------------------------------------------------------

(defun format-local-date-time (dt)
  (concatenate 'string (format-local-date (local-date-time-date dt)) "T" (format-local-time (local-date-time-time dt))))

(defun parse-local-date-time (string)
  (let ((sep (or (position #\T string) (position #\t string))))
    (unless sep (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SS"))
    (make-local-date-time (parse-local-date (subseq string 0 sep)) (parse-local-time (subseq string (1+ sep))))))

;;; --- Instant ---------------------------------------------------------------

(defun format-instant (instant)
  (concatenate 'string (format-local-date-time (%instant-to-local-date-time instant (zone-offset-utc))) "Z"))

(defun parse-instant (string) (unless (stringp string) (error (quote date-time-parse-error) :string string :expected "YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]")) (let ((t-pos (or (position #\T string) (position #\t string)))) (unless t-pos (error (quote date-time-parse-error) :string string :expected "YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]")) (let ((offset-start (position-if (lambda (character) (member character (list #\+ #\- #\Z #\z))) string :start (1+ t-pos)))) (unless offset-start (error (quote date-time-parse-error) :string string :expected "YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]")) (%local-date-time-to-instant (parse-local-date-time (subseq string 0 offset-start)) (%parse-zone-offset (subseq string offset-start))))))

;;; --- ZoneOffset --------------------------------------------------------------

(defun %format-zone-offset (offset)
  (let ((total (zone-offset-total-seconds offset)))
    (if (zerop total)
        "Z"
        (multiple-value-bind (sign absolute) (if (minusp total) (values "-" (- total)) (values "+" total))
          (multiple-value-bind (hours remainder) (floor absolute 3600)
            (multiple-value-bind (minutes seconds) (floor remainder 60)
              (if (zerop seconds)
                  (format nil "~A~2,'0D:~2,'0D" sign hours minutes)
                  (format nil "~A~2,'0D:~2,'0D:~2,'0D" sign hours minutes seconds))))))))

(defun %parse-zone-offset (string) (cond ((and (stringp string) (= (length string) 1) (char-equal (char string 0) #\Z)) (zone-offset-utc)) ((and (stringp string) (member (length string) (list 6 9)) (member (char string 0) (list #\+ #\-)) (char= (char string 3) #\:) (or (= (length string) 6) (char= (char string 6) #\:)) (loop for index in (if (= (length string) 6) (list 1 2 4 5) (list 1 2 4 5 7 8)) always (digit-char-p (char string index)))) (let ((sign (if (char= (char string 0) #\-) -1 1))) (zone-offset-of-hms (* sign (%parse-fixed-integer string 1 3 "+HH:MM")) (* sign (%parse-fixed-integer string 4 6 "+HH:MM")) (if (= (length string) 9) (* sign (%parse-fixed-integer string 7 9 "+HH:MM:SS")) 0)))) (t (error (quote date-time-parse-error) :string string :expected "Z or +HH:MM[:SS]"))))

;;; --- ZonedDateTime -----------------------------------------------------------

(defun format-zoned-date-time (zoned-date-time)
  (concatenate 'string
               (format-local-date-time (zoned-date-time-local zoned-date-time))
               (%format-zone-offset (zoned-date-time-offset zoned-date-time))
               (if (time-zone-p (zoned-date-time-zone zoned-date-time))
                   (concatenate 'string "[" (time-zone-name (zoned-date-time-zone zoned-date-time)) "]")
                   "")))



;;; --- Duration ("PT..." -- java.time's Duration.toString style) --------------

(defun parse-zoned-date-time (string)
  "Parses an ISO 8601 local date-time with an explicit offset and optional zone.
When a zone suffix is present, its rules must admit the explicit offset."
  (unless (stringp string)
    (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SS+HH:MM[Zone/Id]"))
  (let* ((t-pos (or (position #\T string) (position #\t string)))
         (open-bracket (position #\[ string))
         (close-bracket (position #\] string))
         (length (length string)))
    (unless (and t-pos
                 (or (and (null open-bracket) (null close-bracket))
                     (and open-bracket close-bracket
                          (> close-bracket (1+ open-bracket))
                          (= close-bracket (1- length)))))
      (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SS+HH:MM[Zone/Id]"))
    (let* ((offset-end (or open-bracket length))
           (sign-pos (position-if (lambda (character)
                                    (member character '(#\+ #\- #\Z #\z)))
                                  string
                                  :start (1+ t-pos)
                                  :end offset-end)))
      (unless sign-pos
        (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SS+HH:MM[Zone/Id]"))
      (let* ((local (parse-local-date-time (subseq string 0 sign-pos)))
             (offset (%parse-zone-offset (subseq string sign-pos offset-end)))
             (zone (if open-bracket
                       (find-time-zone (subseq string (1+ open-bracket) close-bracket))
                       offset)))
        (when open-bracket
          (unless (some (lambda (candidate)
                          (= (zone-offset-total-seconds candidate)
                             (zone-offset-total-seconds offset)))
                        (possible-offsets-for-local-date-time local zone))
            (error 'date-time-parse-error :string string :expected "offset valid for Zone/Id")))
        (%make-zoned-date-time local zone offset)))))

(defun format-duration (d)
  (let* ((total-seconds (duration-to-seconds d))
         (negative (minusp total-seconds))
         (absolute (abs total-seconds)))
    (multiple-value-bind (hours remainder-1) (truncate absolute 3600)
      (multiple-value-bind (minutes seconds) (truncate remainder-1 60)
        (with-output-to-string (s)
          (when negative (write-char #\- s))
          (write-string "PT" s)
          (when (plusp hours) (format s "~DH" hours))
          (when (plusp minutes) (format s "~DM" minutes))
          (cond
            ((and (zerop hours) (zerop minutes) (zerop seconds)) (write-string "0S" s))
            ((not (zerop seconds))
             (if (integerp seconds) (format s "~DS" seconds) (format s "~FS" (float seconds 1.0d0))))))))))

(defun parse-duration (string)
  (let* ((negative (char= (char string 0) #\-))
         (pos (if negative 1 0)))
    (unless (and (< (1+ pos) (length string)) (char-equal (char string pos) #\P) (char-equal (char string (1+ pos)) #\T))
      (error 'date-time-parse-error :string string :expected "[-]PT[nH][nM][nS]"))
    (incf pos 2)
    (let ((hours 0) (minutes 0) (seconds 0))
      (loop while (< pos (length string))
            do (let* ((unit-pos (or (position-if (lambda (c) (member c '(#\H #\M #\S) :test #'char-equal)) string :start pos)
                                     (error 'date-time-parse-error :string string :expected "[-]PT[nH][nM][nS]")))
                      (value (%parse-decimal string pos unit-pos "[-]PT[nH][nM][nS]"))
                      (unit (char-upcase (char string unit-pos))))
                 (ecase unit (#\H (setf hours value)) (#\M (setf minutes value)) (#\S (setf seconds value)))
                 (setf pos (1+ unit-pos))))
      (let* ((total (+ (* hours 3600) (* minutes 60) seconds))
             (signed-total (if negative (- total) total)))
        (multiple-value-bind (whole frac) (truncate signed-total)
          (duration-of-seconds whole (round (* frac +nanos-per-second+))))))))

;;; --- Period ("PnYnMnD") -------------------------------------------------------

(defun format-period (p)
  (if (period-zero-p p)
      "P0D"
      (with-output-to-string (s)
        (write-char #\P s)
        (unless (zerop (period-years p)) (format s "~DY" (period-years p)))
        (unless (zerop (period-months p)) (format s "~DM" (period-months p)))
        (unless (zerop (period-days p)) (format s "~DD" (period-days p))))))

(defun parse-period (string)
  (unless (and (plusp (length string)) (char-equal (char string 0) #\P))
    (error 'date-time-parse-error :string string :expected "PnYnMnD"))
  (let ((pos 1) (years 0) (months 0) (days 0))
    (loop while (< pos (length string))
          do (let* ((unit-pos (or (position-if (lambda (c) (member c '(#\Y #\M #\D #\W) :test #'char-equal)) string :start pos)
                                   (error 'date-time-parse-error :string string :expected "PnYnMnD")))
                    (value (%parse-fixed-integer string pos unit-pos "PnYnMnD"))
                    (unit (char-upcase (char string unit-pos))))
               (case unit
                 (#\Y (setf years value))
                 (#\M (setf months value))
                 (#\D (setf days value))
                 (#\W (incf days (* value 7))))
               (setf pos (1+ unit-pos))))
    (make-period :years years :months months :days days)))

(defmacro with-date-time-parse-error ((string expected) &body body) `(handler-case (progn ,@body) (date-time-parse-error (condition) (error condition)) (cl-date-kit-error () (error (quote date-time-parse-error) :string ,string :expected ,expected)) (error () (error (quote date-time-parse-error) :string ,string :expected ,expected))))
