;;;; src/iso8601-amounts.lisp
;;;;
;;;; ISO-8601 amount and interval formatting and parsing.
(in-package #:cl-date-kit)

(defun format-duration (duration)
  "Formats DURATION without losing its nanosecond precision."
  (let* ((total-nanos
        (+ (* (duration-seconds duration) +nanos-per-second+) (duration-nanos duration)))
         (negative (minusp total-nanos))
         (absolute-nanos (abs total-nanos)))
    (multiple-value-bind (whole-seconds nanos) (floor absolute-nanos +nanos-per-second+)
      (multiple-value-bind (hours remainder) (floor whole-seconds 3600)
        (multiple-value-bind (minutes seconds) (floor remainder 60)
          (with-output-to-string (stream)
            (when negative
              (write-char #\- stream))
            (write-string "PT" stream)
            (when (plusp hours)
              (format stream "~DH" hours))
            (when (plusp minutes)
              (format stream "~DM" minutes))
            (cond
              ((and (zerop hours) (zerop minutes) (zerop seconds) (zerop nanos))
                (write-string "0S" stream))
              ((or (plusp seconds) (plusp nanos))
                (if (zerop nanos) (format stream "~DS" seconds)
                  (format
                    stream
                    "~D.~AS"
                    seconds
                    (string-right-trim "0" (format nil "~9,'0D" nanos))))))))))))

(defun parse-duration (string)
  "Parses an ISO 8601 duration of the form [-]P[nD][T[nH][nM][nS]]."
  (unless (and (stringp string) (plusp (length string)))
    (error
      'date-time-parse-error
      :string
      string
      :expected
      "[-]P[nD][T[nH][nM][nS]]"))
  (let* ((negative (char= (char string 0) #\-))
         (pos
        (if negative 1
          0)))
    (unless (and (< pos (length string)) (char-equal (char string pos) #\P))
      (error
        'date-time-parse-error
        :string
        string
        :expected
        "[-]P[nD][T[nH][nM][nS]]"))
    (incf pos)
    (let ((days 0)
          (hours 0)
          (minutes 0)
          (seconds 0)
          (last-rank 0)
          (fraction-seen nil)
          (day-present-p nil)
          (time-designator-p nil))
      (let ((day-end (position #\D string :start pos)))
        (when day-end
          (setf days (%parse-decimal string pos day-end "[-]P[nD][T[nH][nM][nS]]")
                pos (1+ day-end)
                day-present-p t)))
      (when (< pos (length string))
        (unless (char-equal (char string pos) #\T)
          (error
            'date-time-parse-error
            :string
            string
            :expected
            "[-]P[nD][T[nH][nM][nS]]"))
        (setf time-designator-p t)
        (incf pos))
      (when (or
          (and (not day-present-p) (not time-designator-p))
          (and time-designator-p (= pos (length string))))
        (error
          'date-time-parse-error
          :string
          string
          :expected
          "[-]P[nD][T[nH][nM][nS]]"))
      (loop while (< pos (length string))
            do (let* ((unit-pos
              (or
                (position-if
                  (lambda (c)
                    (member c '(#\H #\M #\S) :test #'char-equal))
                  string
                  :start
                  pos)
                (error
                  'date-time-parse-error
                  :string
                  string
                  :expected
                  "[-]P[nD][T[nH][nM][nS]]")))
               (decimal-separator
              (position-if
                (lambda (character)
                  (member character '(#\. #\,)))
                string
                :start
                pos
                :end
                unit-pos))
               (fraction-digits
              (if decimal-separator (- unit-pos decimal-separator 1)
                0))
               (value (%parse-decimal string pos unit-pos "[-]P[nD][T[nH][nM][nS]]"))
               (unit (char-upcase (char string unit-pos)))
               (rank
              (ecase unit
                (#\H 1)
                (#\M 2)
                (#\S 3))))
          (when (or (<= rank last-rank) fraction-seen (> fraction-digits 9))
            (error
              'date-time-parse-error
              :string
              string
              :expected
              "[-]P[nD][T[nH][nM][nS]]"))
          (setf last-rank rank
                fraction-seen (not (null decimal-separator)))
          (ecase unit
            (#\H
              (setf hours value))
            (#\M
              (setf minutes value))
            (#\S
              (setf seconds value)))
          (setf pos (1+ unit-pos))))
      (let* ((total (+ (* days 86400) (* hours 3600) (* minutes 60) seconds))
             (signed-total
            (if negative (- total)
              total)))
        (multiple-value-bind (whole frac) (truncate signed-total)
          (duration-of-seconds whole (* frac +nanos-per-second+)))))))

;;; --- Period ("PnYnMnD") -------------------------------------------------------
(defun format-period (p)
  "Formats P as a canonical ISO 8601 period of the form PnYnMnD."
  (if (period-zero-p p) "P0D"
    (with-output-to-string (s)
      (write-char #\P s)
      (unless (zerop (period-years p))
        (format s "~DY" (period-years p)))
      (unless (zerop (period-months p))
        (format s "~DM" (period-months p)))
      (unless (zerop (period-days p))
        (format s "~DD" (period-days p))))))

(defun %parse-period-integer (string start end expected)
  (let ((sign 1))
    (when (and (< start end) (or (char= (char string start) #\+) (char= (char string start) #\-)))
      (when (char= (char string start) #\-)
        (setf sign -1))
      (incf start))
    (* sign (%parse-fixed-integer string start end expected))))

(defun parse-period (string)
  "Parses an ISO 8601 period of the form PnYnMnD, also accepting nW."
  (unless (and (stringp string) (> (length string) 1))
    (error (quote date-time-parse-error) :string string :expected "PnYnMnD"))
  (let ((pos 0)
        (sign 1))
    (when (or (char= (char string pos) #\+) (char= (char string pos) #\-))
      (when (char= (char string pos) #\-)
        (setf sign -1))
      (incf pos))
    (unless (and (< pos (length string)) (char-equal (char string pos) #\P))
      (error (quote date-time-parse-error) :string string :expected "PnYnMnD"))
    (incf pos)
    (let ((years 0)
          (months 0)
          (days 0)
          (last-rank 0)
          (component-seen nil))
      (loop while (< pos (length string))
            do (let* ((unit-pos
              (or
                (position-if
                  (lambda (c)
                    (or (char-equal c #\Y) (char-equal c #\M) (char-equal c #\W) (char-equal c #\D)))
                  string
                  :start
                  pos)
                (error (quote date-time-parse-error) :string string :expected "PnYnMnD")))
               (value (* sign (%parse-period-integer string pos unit-pos "PnYnMnD")))
               (unit (char-upcase (char string unit-pos)))
               (rank
              (ecase unit
                (#\Y 1)
                (#\M 2)
                (#\W 3)
                (#\D 4))))
          (when (<= rank last-rank)
            (error (quote date-time-parse-error) :string string :expected "PnYnMnD"))
          (setf component-seen t
                last-rank rank)
          (case unit
            (#\Y
              (setf years value))
            (#\M
              (setf months value))
            (#\D (incf days value))
            (#\W (incf days (* value 7))))
          (setf pos (1+ unit-pos))))
      (unless component-seen
        (error (quote date-time-parse-error) :string string :expected "PnYnMnD"))
      (make-period :years years :months months :days days))))

(defun format-interval (interval)
  "Formats INTERVAL as canonical ISO 8601 instant-interval START/END."
  (concatenate
    (quote string)
    (format-instant (interval-start interval))
    "/"
    (format-instant (interval-end interval))))

(defun parse-interval (string)
  "Parses an ISO 8601 interval with instant or non-negative duration endpoints."
  (with-date-time-parse-error
    (string "ISO 8601 interval")
    (unless (stringp string)
      (error (quote date-time-parse-error) :string string :expected "ISO 8601 interval"))
    (let ((separator (position #\/ string)))
      (unless (and separator
                   (= separator (position #\/ string :from-end t))
                   (plusp separator)
                   (< separator (1- (length string))))
        (error (quote date-time-parse-error) :string string :expected "ISO 8601 interval"))
      (let* ((left (subseq string 0 separator))
             (right (subseq string (1+ separator)))
             (left-duration-p (char-equal (char left 0) #\P))
             (right-duration-p (char-equal (char right 0) #\P)))
        (when (and left-duration-p right-duration-p)
          (error (quote date-time-parse-error) :string string :expected "ISO 8601 interval"))
        (cond
          (left-duration-p
           (let ((duration (parse-duration left))
                 (end (parse-instant right)))
             (when (duration-negative-p duration)
               (error (quote date-time-parse-error) :string string :expected "ISO 8601 interval"))
             (make-interval (instant-minus-duration end duration) end)))
          (right-duration-p
           (let ((start (parse-instant left))
                 (duration (parse-duration right)))
             (when (duration-negative-p duration)
               (error (quote date-time-parse-error) :string string :expected "ISO 8601 interval"))
             (make-interval start (instant-plus-duration start duration))))
          (t
           (make-interval (parse-instant left) (parse-instant right))))))))

(defun format-local-date-interval (interval)
  "Formats a LOCAL-DATE-INTERVAL as canonical ISO 8601 YYYY-MM-DD/YYYY-MM-DD."
  (check-type interval local-date-interval)
  (concatenate
    (quote string)
    (format-local-date (local-date-interval-start interval))
    "/"
    (format-local-date (local-date-interval-end interval))))

(defun parse-local-date-interval (string)
  "Parses a half-open ISO 8601 LOCAL-DATE-INTERVAL."
  (with-date-time-parse-error
    (string "ISO 8601 local-date interval")
    (unless (stringp string)
      (error (quote date-time-parse-error) :string string :expected "ISO 8601 local-date interval"))
    (let ((separator (position #\/ string)))
      (unless (and
          separator
          (= separator (position #\/ string :from-end t))
          (plusp separator)
          (< separator (1- (length string))))
        (error (quote date-time-parse-error) :string string :expected "ISO 8601 local-date interval"))
      (make-local-date-interval
        (parse-local-date (subseq string 0 separator))
        (parse-local-date (subseq string (1+ separator)))))))
