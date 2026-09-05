(in-package #:cl-date-kit)

(defparameter *day-of-week-names* #(:thursday :friday :saturday :sunday :monday :tuesday :wednesday))

(defun day-of-week (date)
  "One of :MONDAY .. :SUNDAY. Epoch day 0 (1970-01-01) is a Thursday."
  (aref *day-of-week-names* (mod (local-date-to-epoch-day date) 7)))

(defparameter *iso-day-of-week-names* #(:monday :tuesday :wednesday :thursday :friday :saturday :sunday)
  "ISO-8601 weekday keywords ordered from Monday through Sunday.")

(defun day-of-week-value (day-of-week)
  "Returns the ISO-8601 value for DAY-OF-WEEK: Monday is 1 and Sunday is 7."
  (let ((position (position day-of-week *iso-day-of-week-names*)))
    (if position (1+ position)
      (error 'invalid-day-of-week :value day-of-week))))

(defun day-of-week-from-value (value)
  "Returns the weekday keyword for ISO-8601 VALUE in the inclusive range 1 through 7."
  (if (and (integerp value) (<= 1 value 7)) (aref *iso-day-of-week-names* (1- value))
    (error 'invalid-day-of-week :value value)))

(defun day-of-week-length (day-of-week)
  "Returns the number of days in DAY-OF-WEEK's ISO week."
  (day-of-week-value day-of-week)
  7)

(defun day-of-week-plus (day-of-week days)
  "Returns DAY-OF-WEEK advanced by integral DAYS, wrapping at the ISO week boundary."
  (unless (integerp days)
    (error 'invalid-day-of-week :value days))
  (aref
    *iso-day-of-week-names*
    (mod (+ (1- (day-of-week-value day-of-week)) days) 7)))

(defun day-of-week-minus (day-of-week days)
  "Returns DAY-OF-WEEK moved backward by integral DAYS, wrapping at the ISO week boundary."
  (unless (integerp days)
    (error 'invalid-day-of-week :value days))
  (day-of-week-plus day-of-week (- days)))

(defun %iso-weekday-number (date)
  "Returns DATE's ISO weekday number, where Monday is 1 and Sunday is 7."
  (day-of-week-value (day-of-week date)))

(defun %iso-week-1-monday (week-based-year)
  "Returns the Monday starting ISO week 1 of WEEK-BASED-YEAR."
  (let ((january-fourth (make-local-date week-based-year 1 4)))
    (local-date-minus-days january-fourth (1- (%iso-weekday-number january-fourth)))))

(defun local-date-week-based-year (date)
  "Returns DATE's ISO 8601 week-based year.

The week-based year can differ from LOCAL-DATE-YEAR around New Year's: ISO
week 1 is the week containing January 4 and starts on Monday."
  (local-date-year (local-date-plus-days date (- 4 (%iso-weekday-number date)))))

(defun local-date-week-of-week-based-year (date)
  "Returns DATE's ISO 8601 week number within its week-based year."
  (let* ((week-based-year (local-date-week-based-year date))
         (week-one-monday (%iso-week-1-monday week-based-year))
         (week-monday (local-date-minus-days date (1- (%iso-weekday-number date)))))
    (1+
      (floor
        (-
          (local-date-to-epoch-day week-monday)
          (local-date-to-epoch-day week-one-monday))
        7))))

(defun local-date-of-week-date (week-based-year week day-of-week)
  "Constructs a date from ISO WEEK-BASED-YEAR, WEEK, and weekday 1 through 7.

Signals INVALID-DATE when the requested week does not exist in the given
week-based year."
  (unless (and
      (integerp week-based-year)
      (integerp week)
      (integerp day-of-week)
      (<= 1 week 53)
      (<= 1 day-of-week 7))
    (error 'invalid-date :year week-based-year :month week :day day-of-week))
  (let ((date
        (local-date-plus-days
          (%iso-week-1-monday week-based-year)
          (+ (* 7 (1- week)) (1- day-of-week)))))
    (unless (and
        (= (local-date-week-based-year date) week-based-year)
        (= (local-date-week-of-week-based-year date) week))
      (error 'invalid-date :year week-based-year :month week :day day-of-week))
    date))

(defun local-date-next-or-same (date day-of-week)
  "Returns DATE or the next DATE whose weekday is DAY-OF-WEEK."
  (local-date-plus-days
    date
    (mod
      (- (day-of-week-value day-of-week) (%iso-weekday-number date))
      7)))

(defun local-date-next (date day-of-week)
  "Returns the first DATE after DATE whose weekday is DAY-OF-WEEK."
  (let ((result (local-date-next-or-same date day-of-week)))
    (if (local-date= result date) (local-date-plus-days date 7)
      result)))

(defun local-date-previous-or-same (date day-of-week)
  "Returns DATE or the preceding DATE whose weekday is DAY-OF-WEEK."
  (local-date-minus-days
    date
    (mod
      (- (%iso-weekday-number date) (day-of-week-value day-of-week))
      7)))

(progn
  (defun local-date-previous (date day-of-week)
    "Returns the first DATE before DATE whose weekday is DAY-OF-WEEK."
    (let ((result (local-date-previous-or-same date day-of-week)))
      (if (local-date= result date) (local-date-minus-days date 7)
        result)))
  (defun local-date-first-day-of-next-month (date)
    "Returns the first calendar day in the month after DATE."
    (local-date-first-day-of-month (local-date-plus-months date 1)))
  (defun local-date-first-day-of-next-year (date)
    "Returns January 1 in the calendar year after DATE."
    (local-date-first-day-of-year (local-date-plus-years date 1)))
  (defun local-date-first-in-month (date day-of-week)
    "Returns the first DAY-OF-WEEK in the calendar month of DATE."
    (local-date-next-or-same (local-date-first-day-of-month date) day-of-week))
  (defun local-date-last-in-month (date day-of-week)
    "Returns the final DAY-OF-WEEK in the calendar month of DATE."
    (local-date-previous-or-same (local-date-last-day-of-month date) day-of-week))
  (defun local-date-day-of-week-in-month (date ordinal day-of-week)
    "Returns the ORDINAL occurrence of DAY-OF-WEEK relative to DATE month.

Positive ordinals count from the first matching weekday and negative ordinals
count from the last; results may fall outside DATE month."
    (day-of-week-value day-of-week)
    (unless (and (integerp ordinal) (not (zerop ordinal)))
      (error
        (quote invalid-date)
        :year
        (local-date-year date)
        :month
        (local-date-month date)
        :day
        ordinal))
    (if (plusp ordinal) (local-date-plus-days
        (local-date-first-in-month date day-of-week)
        (* 7 (1- ordinal)))
      (local-date-minus-days
        (local-date-last-in-month date day-of-week)
        (* 7 (1- (- ordinal)))))))
