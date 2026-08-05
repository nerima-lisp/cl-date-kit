(in-package #:cl-date-kit)

;;; YearMonth ---------------------------------------------------------------
(defun format-year-month (value)
  "Formats VALUE as the canonical ISO 8601 year-month form YYYY-MM."
  (format
    nil
    "~A-~2,'0D"
    (%format-iso-year (year-month-year value))
    (year-month-month value)))

(progn
  (defun %signed-extended-year-month-p (string)
    (let ((year-end (%signed-expanded-year-end string)))
      (and
        year-end
        (= (length string) (+ year-end 3))
        (%digits-p string (1+ year-end) (+ year-end 3)))))
  (defun %parse-signed-extended-year-month (string on-success)
    (let ((year-end (%signed-expanded-year-end string)))
      (funcall on-success
        (make-year-month
          (parse-integer string :end year-end)
          (%parse-fixed-integer string (1+ year-end) (+ year-end 3) "ISO 8601 year-month")))))
  (defun %extended-year-month-p (string)
    (and
      (= (length string) 7)
      (char= (char string 4) #\-)
      (%digits-p string 0 4)
      (%digits-p string 5 7))))

(defun %basic-year-month-p (string)
  (and (= (length string) 6) (%digits-p string 0 6)))

(defun parse-year-month (string)
  "Parses an ISO 8601 extended (YYYY-MM) or basic (YYYYMM) year-month."
  (with-date-time-parse-error
    (string "ISO 8601 year-month")
    (unless (stringp string)
      (error 'date-time-parse-error :string string :expected "ISO 8601 year-month"))
    (cond
      ((%signed-extended-year-month-p string)
        (%parse-signed-extended-year-month string (function identity)))
      ((%extended-year-month-p string)
        (make-year-month
          (%parse-fixed-integer string 0 4 "ISO 8601 year-month")
          (%parse-fixed-integer string 5 7 "ISO 8601 year-month")))
      ((%basic-year-month-p string)
        (make-year-month
          (%parse-fixed-integer string 0 4 "ISO 8601 year-month")
          (%parse-fixed-integer string 4 6 "ISO 8601 year-month")))
      (t
        (error 'date-time-parse-error :string string :expected "ISO 8601 year-month")))))

;;; MonthDay ----------------------------------------------------------------
(defun format-month-day (value)
  "Formats VALUE as the canonical ISO 8601 month-day form --MM-DD."
  (format nil "--~2,'0D-~2,'0D" (month-day-month value) (month-day-day value)))

(defun %extended-month-day-p (string)
  (and
    (= (length string) 7)
    (string= string "--" :end1 2 :end2 2)
    (char= (char string 4) #\-)
    (%digits-p string 2 4)
    (%digits-p string 5 7)))

(defun %basic-month-day-p (string)
  (and
    (= (length string) 6)
    (string= string "--" :end1 2 :end2 2)
    (%digits-p string 2 6)))

(defun parse-month-day (string)
  "Parses an ISO 8601 extended (--MM-DD) or basic (--MMDD) month-day."
  (with-date-time-parse-error
    (string "ISO 8601 month-day")
    (unless (stringp string)
      (error 'date-time-parse-error :string string :expected "ISO 8601 month-day"))
    (cond
      ((%extended-month-day-p string)
        (make-month-day
          (%parse-fixed-integer string 2 4 "ISO 8601 month-day")
          (%parse-fixed-integer string 5 7 "ISO 8601 month-day")))
      ((%basic-month-day-p string)
        (make-month-day
          (%parse-fixed-integer string 2 4 "ISO 8601 month-day")
          (%parse-fixed-integer string 4 6 "ISO 8601 month-day")))
      (t (error 'date-time-parse-error :string string :expected "ISO 8601 month-day")))))

;;; Year --------------------------------------------------------------------
(defun format-year (value)
  "Formats VALUE as a four-digit or signed expanded ISO 8601 year."
  (let ((number (year-value value)))
    (cond
      ((minusp number) (format nil "-~4,'0D" (abs number)))
      ((<= number 9999) (format nil "~4,'0D" number))
      (t (format nil "+~4,'0D" number)))))

(defun %iso-year-string-p (string)
  (or
    (and (= (length string) 4) (%digits-p string 0 4))
    (and
      (>= (length string) 5)
      (member (char string 0) '(#\+ #\-))
      (%digits-p string 1 (length string)))))

(defun parse-year (string)
  "Parses a four-digit or signed expanded ISO 8601 proleptic year."
  (with-date-time-parse-error
    (string "ISO 8601 year")
    (unless (and (stringp string) (%iso-year-string-p string))
      (error 'date-time-parse-error :string string :expected "ISO 8601 year"))
    (make-year (parse-integer string))))
