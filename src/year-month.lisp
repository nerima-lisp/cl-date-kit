(in-package #:cl-date-kit)

(defstruct (year-month (:constructor %make-year-month (year month)))
  (year 0 :type integer :read-only t)
  (month 1 :type (integer 1 12) :read-only t))

(defun make-year-month (year month)
  "Constructs a YEAR-MONTH from an integral proleptic Gregorian YEAR and MONTH."
  (unless (and (integerp year) (integerp month) (<= 1 month 12))
    (error 'invalid-year-month :year year :month month))
  (%make-year-month year month))

(defun year-month-of (year month)
  "Convenience constructor for MAKE-YEAR-MONTH."
  (make-year-month year month))

(defun year-month-from-local-date (date)
  "Drops DATE's day-of-month and returns its YEAR-MONTH."
  (%make-year-month (local-date-year date) (local-date-month date)))

(defun year-month-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  "Returns the current YEAR-MONTH in ZONE according to CLOCK."
  (year-month-from-local-date (local-date-now :zone zone :clock clock)))

(defun year-month-to-proleptic-month (value)
  "Returns VALUE's signed month index, where year 0 / January is 0."
  (+ (* (year-month-year value) 12) (1- (year-month-month value))))

(defun year-month-from-proleptic-month (month-index)
  "Constructs a YEAR-MONTH from a signed proleptic MONTH-INDEX."
  (unless (integerp month-index)
    (error 'invalid-year-month :year month-index :month month-index))
  (multiple-value-bind (year month-zero) (floor month-index 12)
    (%make-year-month year (1+ month-zero))))

(defun year-month-length-of-month (value)
  "Returns the number of days in the calendar month of VALUE."
  (length-of-month (year-month-year value) (year-month-month value)))

(defun year-month-leap-year-p (value)
  "Returns true when VALUE occurs in a proleptic Gregorian leap year."
  (leap-year-p (year-month-year value)))

(defun year-month-length-of-year (value)
  "Returns the number of days in VALUE's calendar year."
  (if (year-month-leap-year-p value) 366 365))

(defun year-month-valid-day-p (value day)
  "Returns true when integral DAY occurs in the calendar month of VALUE."
  (and (integerp day)
       (<= 1 day (year-month-length-of-month value))))

(defun year-month-at-day (value day)
  "Combines VALUE with DAY, signaling INVALID-DATE when it is not valid."
  (make-local-date (year-month-year value) (year-month-month value) day))

(defun year-month-at-end-of-month (value)
  "Returns the final LOCAL-DATE in VALUE's month."
  (year-month-at-day value (year-month-length-of-month value)))

(defun year-month-plus-months (value months)
  "Adds integral MONTHS to VALUE using a signed proleptic month index."
  (unless (integerp months)
    (error 'invalid-year-month :year months :month months))
  (year-month-from-proleptic-month
   (+ (year-month-to-proleptic-month value) months)))

(defun year-month-minus-months (value months)
  "Subtracts integral MONTHS from VALUE."
  (unless (integerp months)
    (error 'invalid-year-month :year months :month months))
  (year-month-plus-months value (- months)))

(defun year-month-plus-years (value years)
  "Adds integral YEARS to VALUE."
  (unless (integerp years)
    (error 'invalid-year-month :year years :month years))
  (year-month-plus-months value (* years 12)))

(defun year-month-minus-years (value years)
  "Subtracts integral YEARS from VALUE."
  (unless (integerp years)
    (error 'invalid-year-month :year years :month years))
  (year-month-plus-months value (* years -12)))

(defun year-month-until (start end)
  "Returns the signed count of whole calendar months from START to END."
  (- (year-month-to-proleptic-month end)
     (year-month-to-proleptic-month start)))

(defun year-month-compare (a b)
  "Returns -1, 0, or 1 according to A's month ordering relative to B."
  (let ((delta (- (year-month-to-proleptic-month a)
                  (year-month-to-proleptic-month b))))
    (cond ((minusp delta) -1) ((plusp delta) 1) (t 0))))

(define-ordering-operators year-month year-month-compare)

(defun year-month-with-year (value year)
  "Returns VALUE with YEAR replaced."
  (make-year-month year (year-month-month value)))

(defun year-month-with-month (value month)
  "Returns VALUE with MONTH replaced."
  (make-year-month (year-month-year value) month))
