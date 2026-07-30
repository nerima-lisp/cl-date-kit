;;;; src/month-day.lisp
;;;;
;;;; MONTH-DAY is a month and day without a year.  It models annual calendar
;;;; events such as birthdays and renewal dates, including February 29.

(in-package #:cl-date-kit)

(defstruct (month-day (:constructor %make-month-day (month day)))
  (month 1 :type (integer 1 12) :read-only t)
  (day 1 :type (integer 1 31) :read-only t))

(defun %month-day-valid-p (month day)
  (and (integerp month)
       (integerp day)
       (<= 1 month 12)
       (<= 1 day (length-of-month 2000 month))))

(defun make-month-day (month day)
  "Constructs a MONTH-DAY from MONTH and DAY, permitting February 29."
  (unless (%month-day-valid-p month day)
    (error 'invalid-month-day :month month :day day))
  (%make-month-day month day))

(defun month-day-of (month day)
  "Convenience constructor for MAKE-MONTH-DAY."
  (make-month-day month day))

(defun month-day-from-local-date (date)
  "Drops DATE's year and returns its MONTH-DAY."
  (%make-month-day (local-date-month date) (local-date-day date)))

(defun month-day-now (&key (zone (zone-offset-utc)) (clock (current-clock)))
  "Returns the current MONTH-DAY in ZONE according to CLOCK."
  (month-day-from-local-date (local-date-now :zone zone :clock clock)))

(defun month-day-valid-year-p (value year)
  "Returns true when VALUE occurs in the integral proleptic Gregorian YEAR."
  (and (integerp year)
       (<= (month-day-day value)
           (length-of-month year (month-day-month value)))))

(defun month-day-at-year (value year)
  "Combines VALUE with YEAR, clamping February 29 to February 28 if needed."
  (unless (integerp year)
    (error 'invalid-month-day :month (month-day-month value) :day year))
  (make-local-date year
                   (month-day-month value)
                   (min (month-day-day value)
                        (length-of-month year (month-day-month value)))))

(defun month-day-compare (a b)
  "Returns -1, 0, or 1 according to A's month/day ordering relative to B."
  (let ((month-delta (- (month-day-month a) (month-day-month b))))
    (cond ((minusp month-delta) -1)
          ((plusp month-delta) 1)
          (t (let ((day-delta (- (month-day-day a) (month-day-day b))))
               (cond ((minusp day-delta) -1)
                     ((plusp day-delta) 1)
                     (t 0)))))))

(defun month-day= (a b) (zerop (month-day-compare a b)))
(defun month-day< (a b) (minusp (month-day-compare a b)))
(defun month-day<= (a b) (not (plusp (month-day-compare a b))))
(defun month-day> (a b) (plusp (month-day-compare a b)))
(defun month-day>= (a b) (not (minusp (month-day-compare a b))))

(defun month-day-with-month (value month)
  "Returns VALUE with MONTH replaced, clamping to the target month's end."
  (unless (and (integerp month) (<= 1 month 12))
    (error 'invalid-month-day :month month :day (month-day-day value)))
  (make-month-day month
                  (min (month-day-day value) (length-of-month 2000 month))))

(defun month-day-with-day (value day)
  "Returns VALUE with DAY replaced."
  (make-month-day (month-day-month value) day))
