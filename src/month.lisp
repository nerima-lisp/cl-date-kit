;;;; src/month.lisp
(in-package #:cl-date-kit)

(defparameter *iso-month-names* #(:january
    :february
    :march
    :april
    :may
    :june
    :july
    :august
    :september
    :october
    :november
    :december)
  "ISO-8601 month keywords ordered from January through December.")

(defparameter *common-year-month-lengths* #(31 28 31 30 31 30 31 31 30 31 30 31)
  "Month lengths for a common proleptic-Gregorian year.")

(defparameter *leap-year-month-lengths* #(31 29 31 30 31 30 31 31 30 31 30 31)
  "Month lengths for a leap proleptic-Gregorian year.")

(defparameter *common-year-first-days* #(1 32 60 91 121 152 182 213 244 274 305 335)
  "One-based day-of-year for the first day of each common-year month.")

(defparameter *leap-year-first-days* #(1 32 61 92 122 153 183 214 245 275 306 336)
  "One-based day-of-year for the first day of each leap-year month.")

(defun month-value (month)
  "Return the ISO-8601 number for MONTH, from 1 for :JANUARY through 12 for :DECEMBER."
  (let ((index (position month *iso-month-names*)))
    (if index
        (1+ index)
        (error 'invalid-month :value month))))

(defun month-from-value (value)
  "Return the ISO month keyword for integral VALUE in the range 1 through 12."
  (if (and (integerp value) (<= 1 value 12)) (aref *iso-month-names* (1- value))
    (error 'invalid-month :value value)))

(defun %month-index (month)
  (1- (month-value month)))

(defun month-length (month leap-year-p)
  "Return MONTH's length in a leap or common proleptic-Gregorian year."
  (check-type leap-year-p boolean)
  (aref
    (if leap-year-p *leap-year-month-lengths*
      *common-year-month-lengths*)
    (%month-index month)))

(defun month-min-length (month)
  "Return the smallest possible proleptic-Gregorian length of MONTH."
  (aref *common-year-month-lengths* (%month-index month)))

(defun month-max-length (month)
  "Return the largest possible proleptic-Gregorian length of MONTH."
  (aref *leap-year-month-lengths* (%month-index month)))

(defun month-first-day-of-year (month leap-year-p)
  "Return the one-based day-of-year on which MONTH begins."
  (check-type leap-year-p boolean)
  (aref
    (if leap-year-p *leap-year-first-days*
      *common-year-first-days*)
    (%month-index month)))

(defun month-quarter-of-year (month)
  "Return MONTH's ISO calendar quarter, from 1 through 4."
  (1+ (floor (%month-index month) 3)))

(defun month-first-month-of-quarter (month)
  "Return the ISO month keyword starting MONTH's calendar quarter."
  (month-from-value (1+ (* 3 (floor (%month-index month) 3)))))

(defun month-plus (month months)
  "Return MONTH moved by integral MONTHS, wrapping within the ISO year."
  (check-type months integer)
  (month-from-value (1+ (mod (+ (%month-index month) months) 12))))

(defun month-minus (month months)
  "Return MONTH moved backward by integral MONTHS, wrapping within the ISO year."
  (check-type months integer)
  (month-plus month (- months)))

(defun month-from-local-date (date)
  "Return DATE's ISO month keyword."
  (month-from-value (local-date-month date)))

(defun month-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  "Return the current ISO month in ZONE according to CLOCK."
  (month-from-local-date (local-date-now :zone zone :clock clock)))
