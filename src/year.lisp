;;;; src/year.lisp
;; A proleptic Gregorian calendar year with no month, day, time, or zone.

(in-package #:cl-date-kit)

(defstruct (year (:constructor %make-year (value)))
  (value 0 :type integer :read-only t))

(defun make-year (value)
  "Constructs a YEAR from an integral proleptic Gregorian VALUE."
  (unless (integerp value)
    (error 'invalid-year :value value))
  (%make-year value))

(defun year-of (value)
  "Convenience constructor for MAKE-YEAR."
  (make-year value))

(defun year-from-local-date (date)
  "Drops DATE's month and day and returns its YEAR."
  (%make-year (local-date-year date)))

(defun year-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  "Returns the current YEAR in ZONE according to CLOCK."
  (year-from-local-date (local-date-now :zone zone :clock clock)))

(defun year-from-year-month (value)
  "Drops VALUE's month and returns its YEAR."
  (%make-year (year-month-year value)))

(defun year-leap-p (value)
  "Returns true when VALUE is a leap year in the proleptic Gregorian calendar."
  (leap-year-p (year-value value)))

(defun year-length (value)
  "Returns 365 or 366 according to whether VALUE is a leap year."
  (if (year-leap-p value) 366 365))

(defun year-valid-month-day-p (value month-day)
  "Returns true when MONTH-DAY occurs in the calendar year of VALUE."
  (check-type month-day month-day)
  (month-day-valid-year-p month-day (year-value value)))

(defun year-at-month (value month)
  "Combines VALUE with MONTH as a YEAR-MONTH."
  (make-year-month (year-value value) month))

(defun year-at-month-day (value month-day)
  "Combines VALUE with MONTH-DAY, clamping February 29 in non-leap years."
  (month-day-at-year month-day (year-value value)))

(defun year-at-day (value day-of-year)
  "Combines VALUE with DAY-OF-YEAR as a LOCAL-DATE."
  (local-date-of-year-day (year-value value) day-of-year))

(defun year-plus-years (value years)
  "Adds integral YEARS to VALUE."
  (unless (integerp years)
    (error 'invalid-year :value years))
  (%make-year (+ (year-value value) years)))

(defun year-minus-years (value years)
  "Subtracts integral YEARS from VALUE."
  (unless (integerp years)
    (error 'invalid-year :value years))
  (year-plus-years value (- years)))

(defun year-until (start end)
  "Returns the signed number of calendar years from START to END."
  (- (year-value end) (year-value start)))

(defun year-compare (a b)
  "Returns -1, 0, or 1 according to A's ordering relative to B."
  (let ((delta (- (year-value a) (year-value b))))
    (cond ((minusp delta) -1) ((plusp delta) 1) (t 0))))

(defun year= (a b) (zerop (year-compare a b)))
(defun year< (a b) (minusp (year-compare a b)))
(defun year<= (a b) (not (plusp (year-compare a b))))
(defun year> (a b) (plusp (year-compare a b)))
(defun year>= (a b) (not (minusp (year-compare a b))))
