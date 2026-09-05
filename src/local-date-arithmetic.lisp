(in-package #:cl-date-kit)

(defun local-date-plus-days (date n)
  (local-date-from-epoch-day (+ (local-date-to-epoch-day date) n)))

(defun local-date-plus-weeks (date n)
  (local-date-plus-days date (* n 7)))

(defun %clamp-day (year month day)
  (min day (length-of-month year month)))

(defun local-date-plus-months (date n)
  "Adds N months. When the target month is shorter than DATE's day-of-month,
the result clamps to the last day of the target month."
  (multiple-value-bind (extra-years month0) (floor (+ (1- (local-date-month date)) n) 12)
    (let ((year (+ (local-date-year date) extra-years))
          (month (1+ month0)))
      (%make-local-date year month (%clamp-day year month (local-date-day date))))))

(defun local-date-plus-years (date n)
  (local-date-plus-months date (* n 12)))

(defmacro define-local-date-inverse (minus-name plus-name)
  "Define MINUS-NAME as DATE moved by negated integral N via PLUS-NAME."
  `(defun ,minus-name (date n)
     (,plus-name date (- n))))

(define-local-date-inverse local-date-minus-days local-date-plus-days)

(define-local-date-inverse local-date-minus-weeks local-date-plus-weeks)

(define-local-date-inverse local-date-minus-months local-date-plus-months)

(define-local-date-inverse local-date-minus-years local-date-plus-years)

(defun local-date-plus-period (date p)
  (local-date-plus-days
    (local-date-plus-months date (+ (* (period-years p) 12) (period-months p)))
    (period-days p)))

(defun local-date-minus-period (date p)
  (local-date-plus-period date (period-negate p)))

(defun local-date-until (start end)
  "The PERIOD from START to END, as whole years, then whole months, then
remaining days."
  (let ((total-months
        (-
          (+ (* (local-date-year end) 12) (1- (local-date-month end)))
          (+ (* (local-date-year start) 12) (1- (local-date-month start)))))
        (days (- (local-date-day end) (local-date-day start))))
    (cond
      ((and (plusp total-months) (minusp days))
        (decf total-months)
        (setf days (-
            (local-date-to-epoch-day end)
            (local-date-to-epoch-day (local-date-plus-months start total-months)))))
      ((and (minusp total-months) (plusp days))
        (incf total-months)
        (decf days (length-of-month (local-date-year end) (local-date-month end)))))
    (multiple-value-bind (years months) (truncate total-months 12)
      (make-period :years years :months months :days days))))

(defun period-between (start end)
  "Return the calendar PERIOD from LOCAL-DATE START to LOCAL-DATE END.

This is the discoverable type-oriented spelling of LOCAL-DATE-UNTIL."
  (local-date-until start end))

(defun local-date-with-year (date year)
  "Returns DATE with YEAR, clamping its day to the target year when needed."
  (local-date-plus-years date (- year (local-date-year date))))

(defun local-date-with-month (date month)
  "Returns DATE with MONTH, clamping its day to the target month when needed."
  (let ((year (local-date-year date)))
    (unless (and (integerp month) (<= 1 month 12))
      (error 'invalid-date :year year :month month :day (local-date-day date)))
    (%make-local-date year month (%clamp-day year month (local-date-day date)))))

(defun local-date-with-day (date day)
  "Returns DATE with DAY, signalling INVALID-DATE when it is invalid for its month."
  (make-local-date (local-date-year date) (local-date-month date) day))

(defun local-date-with-day-of-year (date day-of-year)
  "Returns DATE with DAY-OF-YEAR in its current year."
  (local-date-of-year-day (local-date-year date) day-of-year))

(defun local-date-first-day-of-month (date)
  "Returns the first calendar day in DATE's month."
  (%make-local-date (local-date-year date) (local-date-month date) 1))

(defun local-date-last-day-of-month (date)
  "Returns the final calendar day in DATE's month."
  (%make-local-date
    (local-date-year date)
    (local-date-month date)
    (length-of-month (local-date-year date) (local-date-month date))))

(defun local-date-first-day-of-year (date)
  "Returns January 1 in DATE's calendar year."
  (%make-local-date (local-date-year date) 1 1))

(defun local-date-last-day-of-year (date)
  "Returns December 31 in DATE's calendar year."
  (%make-local-date (local-date-year date) 12 31))
