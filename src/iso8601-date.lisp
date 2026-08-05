(in-package #:cl-date-kit)

;;; Shared parsing support ---------------------------------------------------
(defun %parse-fixed-integer (string start end expected)
  (unless (and
      (<= 0 start end (length string))
      (< start end)
      (loop for index from start below
            end
            always (digit-char-p (char string index))))
    (error 'date-time-parse-error :string string :expected expected))
  (parse-integer string :start start :end end))

(defun %parse-decimal (string start end expected)
  "Parses a possibly-fractional decimal number in STRING[START,END) as a rational."
  (let ((decimal-separator
        (position-if
          (lambda (character)
            (member character '(#\. #\,)))
          string
          :start
          start
          :end
          end)))
    (if decimal-separator (let ((next-separator
            (position-if
              (lambda (character)
                (member character '(#\. #\,)))
              string
              :start
              (1+ decimal-separator)
              :end
              end)))
        (when next-separator
          (error 'date-time-parse-error :string string :expected expected))
        (+
          (%parse-fixed-integer string start decimal-separator expected)
          (let ((fraction (subseq string (1+ decimal-separator) end)))
            (/
              (%parse-fixed-integer fraction 0 (length fraction) expected)
              (expt 10 (length fraction))))))
      (%parse-fixed-integer string start end expected))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defmacro with-date-time-parse-error ((string expected) &body body)
    `(handler-case (progn
        ,@body)
      (date-time-parse-error (condition)
        (error condition))
      (cl-date-kit-error ()
        (error 'date-time-parse-error :string ,string :expected ,expected))
      (error ()
        (error 'date-time-parse-error :string ,string :expected ,expected)))))

;;; LocalDate ---------------------------------------------------------------
(progn
  (defun %write-iso-year (year stream)
    (cond
      ((minusp year) (format stream "-~4,'0D" (abs year)))
      ((<= year 9999) (format stream "~4,'0D" year))
      (t (format stream "+~4,'0D" year))))
  (defun %format-iso-year (year)
    (with-output-to-string (stream)
      (%write-iso-year year stream)))
  (defun %write-local-date (date stream)
    (%write-iso-year (local-date-year date) stream)
    (format stream "-~2,'0D-~2,'0D" (local-date-month date) (local-date-day date)))
  (defun format-local-date (date)
    "Formats DATE as the canonical ISO 8601 extended calendar-date form YYYY-MM-DD."
    (with-output-to-string (stream)
      (%write-local-date date stream))))

(defun format-local-date-ordinal (date)
  "Formats DATE as an ISO 8601 ordinal date: YYYY-DDD."
  (format
    nil
    "~A-~3,'0D"
    (%format-iso-year (local-date-year date))
    (day-of-year date)))

(defun format-local-date-week-date (date)
  "Formats DATE as an ISO 8601 week date: YYYY-Www-D."
  (format
    nil
    "~A-W~2,'0D-~D"
    (%format-iso-year (local-date-week-based-year date))
    (local-date-week-of-week-based-year date)
    (%iso-weekday-number date)))

(defun %digits-p (string start end)
  (and
    (<= 0 start end (length string))
    (loop for index from start below
          end
          always (digit-char-p (char string index)))))

(defun %parse-local-date-calendar (string basic-p on-success)
  (funcall on-success
    (make-local-date
      (%parse-fixed-integer string 0 4 "ISO 8601 calendar date")
      (%parse-fixed-integer
        string
        (if basic-p 4
          5)
        (if basic-p 6
          7)
        "ISO 8601 calendar date")
      (%parse-fixed-integer
        string
        (if basic-p 6
          8)
        (if basic-p 8
          10)
        "ISO 8601 calendar date"))))

(defun %parse-local-date-ordinal (string basic-p on-success)
  (funcall on-success
    (local-date-of-year-day
      (%parse-fixed-integer string 0 4 "ISO 8601 ordinal date")
      (%parse-fixed-integer
        string
        (if basic-p 4
          5)
        (if basic-p 7
          8)
        "ISO 8601 ordinal date"))))

(defun %parse-local-date-week-date (string basic-p on-success)
  (funcall on-success
    (local-date-of-week-date
      (%parse-fixed-integer string 0 4 "ISO 8601 week date")
      (%parse-fixed-integer
        string
        (if basic-p 5
          6)
        (if basic-p 7
          8)
        "ISO 8601 week date")
      (%parse-fixed-integer
        string
        (if basic-p 7
          9)
        (if basic-p 8
          10)
        "ISO 8601 week date"))))

(progn
  (defun %signed-expanded-year-end (string)
    (when (and (>= (length string) 6) (member (char string 0) '(#\+ #\-)))
      (let ((year-end (position #\- string :start 1)))
        (when (and year-end (>= year-end 5) (%digits-p string 1 year-end))
          year-end))))
  (defun %signed-extended-calendar-date-p (string)
    (let ((year-end (%signed-expanded-year-end string)))
      (and
        year-end
        (= (length string) (+ year-end 6))
        (char= (char string (+ year-end 3)) #\-)
        (%digits-p string (1+ year-end) (+ year-end 3))
        (%digits-p string (+ year-end 4) (+ year-end 6)))))
  (defun %parse-signed-extended-calendar-date (string on-success)
    (let ((year-end (%signed-expanded-year-end string)))
      (funcall on-success
        (make-local-date
          (parse-integer string :end year-end)
          (%parse-fixed-integer
            string
            (1+ year-end)
            (+ year-end 3)
            "ISO 8601 calendar date")
          (%parse-fixed-integer
            string
            (+ year-end 4)
            (+ year-end 6)
            "ISO 8601 calendar date")))))
  (defun %signed-extended-ordinal-date-p (string)
    (let ((year-end (%signed-expanded-year-end string)))
      (and
        year-end
        (= (length string) (+ year-end 4))
        (%digits-p string (1+ year-end) (+ year-end 4)))))
  (defun %parse-signed-extended-ordinal-date (string on-success)
    (let ((year-end (%signed-expanded-year-end string)))
      (funcall on-success
        (local-date-of-year-day
          (parse-integer string :end year-end)
          (%parse-fixed-integer
            string
            (1+ year-end)
            (+ year-end 4)
            "ISO 8601 ordinal date")))))
  (defun %signed-extended-week-date-p (string)
    (let ((year-end (%signed-expanded-year-end string)))
      (and
        year-end
        (= (length string) (+ year-end 6))
        (member (char string (1+ year-end)) '(#\W #\w))
        (char= (char string (+ year-end 4)) #\-)
        (%digits-p string (+ year-end 2) (+ year-end 4))
        (%digits-p string (+ year-end 5) (+ year-end 6)))))
  (defun %parse-signed-extended-week-date (string on-success)
    (let ((year-end (%signed-expanded-year-end string)))
      (funcall on-success
        (local-date-of-week-date
          (parse-integer string :end year-end)
          (%parse-fixed-integer string (+ year-end 2) (+ year-end 4) "ISO 8601 week date")
          (%parse-fixed-integer string (+ year-end 5) (+ year-end 6) "ISO 8601 week date")))))
  (defun %extended-calendar-date-p (string)
    (and
      (= (length string) 10)
      (char= (char string 4) #\-)
      (char= (char string 7) #\-)
      (%digits-p string 0 4)
      (%digits-p string 5 7)
      (%digits-p string 8 10))))

(defun %basic-calendar-date-p (string)
  (and (= (length string) 8) (%digits-p string 0 8)))

(defun %extended-ordinal-date-p (string)
  (and
    (= (length string) 8)
    (char= (char string 4) #\-)
    (%digits-p string 0 4)
    (%digits-p string 5 8)))

(defun %basic-ordinal-date-p (string)
  (and (= (length string) 7) (%digits-p string 0 7)))

(defun %extended-week-date-p (string)
  (and
    (= (length string) 10)
    (char= (char string 4) #\-)
    (member (char string 5) '(#\W #\w))
    (char= (char string 8) #\-)
    (%digits-p string 0 4)
    (%digits-p string 6 8)
    (%digits-p string 9 10)))

(defun %basic-week-date-p (string)
  (and
    (= (length string) 8)
    (member (char string 4) '(#\W #\w))
    (%digits-p string 0 4)
    (%digits-p string 5 8)))

(defun parse-local-date (string)
  "Parses an ISO 8601 calendar, ordinal, or week date in extended or basic notation."
  (with-date-time-parse-error
    (string "ISO 8601 calendar, ordinal, or week date")
    (unless (stringp string)
      (error 'date-time-parse-error :string string :expected "ISO 8601 date"))
    (cond
      ((%signed-extended-calendar-date-p string)
        (%parse-signed-extended-calendar-date string (function identity)))
      ((%signed-extended-ordinal-date-p string)
        (%parse-signed-extended-ordinal-date string (function identity)))
      ((%signed-extended-week-date-p string)
        (%parse-signed-extended-week-date string (function identity)))
      ((%extended-calendar-date-p string) (%parse-local-date-calendar string nil (function identity)))
      ((%basic-calendar-date-p string) (%parse-local-date-calendar string t (function identity)))
      ((%extended-ordinal-date-p string) (%parse-local-date-ordinal string nil (function identity)))
      ((%basic-ordinal-date-p string) (%parse-local-date-ordinal string t (function identity)))
      ((%extended-week-date-p string) (%parse-local-date-week-date string nil (function identity)))
      ((%basic-week-date-p string) (%parse-local-date-week-date string t (function identity)))
      (t (error 'date-time-parse-error :string string :expected "ISO 8601 date")))))

(defun parse-local-date-ordinal (string)
  "Parses the canonical ISO 8601 ordinal date form YYYY-DDD."
  (with-date-time-parse-error
    (string "YYYY-DDD")
    (unless (and
        (stringp string)
        (or (%extended-ordinal-date-p string) (%signed-extended-ordinal-date-p string)))
      (error 'date-time-parse-error :string string :expected "YYYY-DDD"))
    (if (%signed-extended-ordinal-date-p string) (%parse-signed-extended-ordinal-date string (function identity))
      (%parse-local-date-ordinal string nil (function identity)))))

(defun parse-local-date-week-date (string)
  "Parses the canonical ISO 8601 week-date form YYYY-Www-D."
  (with-date-time-parse-error
    (string "YYYY-Www-D")
    (unless (and
        (stringp string)
        (or (%extended-week-date-p string) (%signed-extended-week-date-p string)))
      (error 'date-time-parse-error :string string :expected "YYYY-Www-D"))
    (if (%signed-extended-week-date-p string) (%parse-signed-extended-week-date string (function identity))
      (%parse-local-date-week-date string nil (function identity)))))

