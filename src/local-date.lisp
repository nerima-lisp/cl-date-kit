;;;; src/local-date.lisp
;;;;
;;;; LOCAL-DATE is a proleptic-Gregorian calendar date with no time-of-day or
;;;; zone: java.time's LocalDate, Temporal's PlainDate, chrono's NaiveDate.
;;;;
;;;; Date <-> day-count conversion uses Howard Hinnant's days_from_civil /
;;;; civil_from_days ("chrono-Compatible Low-Level Date Algorithms"), the same
;;;; algorithm behind libc++'s <chrono>, Rust's `time` crate, and Abseil's
;;;; civil_time -- correct for the entire proleptic Gregorian calendar, not
;;;; just the range the host Lisp's universal-time happens to support. Day 0
;;;; is 1970-01-01, matching INSTANT's Unix epoch.
(in-package #:cl-date-kit)

(defstruct (local-date (:constructor %make-local-date (year month day))) (year 0 :type integer :read-only t)
  (month 1 :type (integer 1 12) :read-only t)
  (day 1 :type (integer 1 31) :read-only t))

(defun leap-year-p (year)
  (and
    (zerop (mod year 4))
    (or (not (zerop (mod year 100))) (zerop (mod year 400)))))

(defun length-of-month (year month)
  (check-type year integer)
  (check-type month (integer 1 12))
  (case month
    ((1 3 5 7 8 10 12) 31)
    ((4 6 9 11) 30)
    (2
      (if (leap-year-p year) 29
        28))))

(defun local-date-leap-year-p (date)
  "Returns true when DATE occurs in a proleptic Gregorian leap year."
  (leap-year-p (local-date-year date)))

(defun local-date-length-of-month (date)
  "Returns the number of days in DATE's calendar month."
  (length-of-month (local-date-year date) (local-date-month date)))

(defun local-date-length-of-year (date)
  "Returns the number of days in DATE's calendar year."
  (if (local-date-leap-year-p date) 366
    365))

(defun make-local-date (year month day)
  (unless (and
      (integerp year)
      (integerp month)
      (integerp day)
      (<= 1 month 12)
      (<= 1 day (length-of-month year month)))
    (error (quote invalid-date) :year year :month month :day day))
  (%make-local-date year month day))

(defun local-date-to-epoch-day (date)
  (%days-from-civil
    (local-date-year date)
    (local-date-month date)
    (local-date-day date)))

(defun local-date-of (year month day)
  "Construct a LOCAL-DATE from proleptic Gregorian fields."
  (make-local-date year month day))

(defun local-date-from-epoch-day (epoch-day)
  (multiple-value-bind (year month day) (%civil-from-days epoch-day)
    (%make-local-date year month day)))

(defun local-date-at-time (date time)
  "Combines DATE and TIME into a LOCAL-DATE-TIME."
  (make-local-date-time date time))

(defun local-date-at-start-of-day (date)
  "Returns DATE at 00:00:00."
  (local-date-at-time date (local-time-midnight)))

(defun local-date-at-start-of-day-in-zone (date zone &key (disambiguation :compatible))
  "Resolves the start of DATE in ZONE using DISAMBIGUATION.
A compatible resolution shifts a nonexistent midnight forward across a gap."
  (local-date-time-at-zone
    (local-date-at-start-of-day date)
    zone
    :disambiguation
    disambiguation))

(defun %days-from-civil (year month day)
  (let* ((y
        (if (<= month 2) (1- year)
          year))
         (era
        (truncate
          (if (>= y 0) y
            (- y 399))
          400))
         (yoe (- y (* era 400)))
         (doy
        (+
          (truncate
            (+
              (*
                153
                (+
                  month
                  (if (> month 2) -3
                    9)))
              2)
            5)
          (1- day)))
         (doe (+ (* yoe 365) (truncate yoe 4) (- (truncate yoe 100)) doy)))
    (+ (* era 146097) doe -719468)))

(defun %civil-from-days (z)
  (let* ((z (+ z 719468))
         (era
        (truncate
          (if (>= z 0) z
            (- z 146096))
          146097))
         (doe (- z (* era 146097)))
         (yoe
        (truncate
          (+ doe (- (truncate doe 1460)) (truncate doe 36524) (- (truncate doe 146096)))
          365))
         (y (+ yoe (* era 400)))
         (doy (- doe (+ (* 365 yoe) (truncate yoe 4) (- (truncate yoe 100)))))
         (mp (truncate (+ (* 5 doy) 2) 153))
         (d (+ (- doy (truncate (+ (* 153 mp) 2) 5)) 1))
         (m
        (+
          mp
          (if (< mp 10) 3
            -9))))
    (values
      (if (<= m 2) (1+ y)
        y)
      m
      d)))

(defun day-of-year (date)
  (1+
    (-
      (local-date-to-epoch-day date)
      (local-date-to-epoch-day (%make-local-date (local-date-year date) 1 1)))))

(defun local-date-of-year-day (year day-of-year)
  (let ((max
        (if (leap-year-p year) 366
          365)))
    (unless (<= 1 day-of-year max)
      (error 'invalid-date :year year :month 0 :day day-of-year))
    (local-date-from-epoch-day
      (+ (local-date-to-epoch-day (%make-local-date year 1 1)) (1- day-of-year)))))

(defparameter *day-of-week-names* #(:thursday :friday :saturday :sunday :monday :tuesday :wednesday))

(defun day-of-week (date)
  "One of :MONDAY .. :SUNDAY. Epoch day 0 (1970-01-01) is a Thursday."
  (aref *day-of-week-names* (mod (local-date-to-epoch-day date) 7)))

(defparameter *iso-day-of-week-names* #(:monday :tuesday :wednesday :thursday :friday :saturday :sunday)
  "ISO-8601 weekday keywords ordered from Monday through Sunday.")

(defun day-of-week-value (day-of-week)
  "Returns the ISO-8601 value for DAY-OF-WEEK: Monday is 1 and Sunday is 7."
  (case day-of-week
    (:monday 1)
    (:tuesday 2)
    (:wednesday 3)
    (:thursday 4)
    (:friday 5)
    (:saturday 6)
    (:sunday 7)
    (otherwise (error 'invalid-day-of-week :value day-of-week))))

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
  (ecase (day-of-week date)
    (:monday 1)
    (:tuesday 2)
    (:wednesday 3)
    (:thursday 4)
    (:friday 5)
    (:saturday 6)
    (:sunday 7)))

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

(defun local-date-plus-days (date n)
  (local-date-from-epoch-day (+ (local-date-to-epoch-day date) n)))

(defun local-date-minus-days (date n)
  (local-date-plus-days date (- n)))

(defun local-date-plus-weeks (date n)
  (local-date-plus-days date (* n 7)))

(defun local-date-minus-weeks (date n)
  (local-date-plus-days date (* n -7)))

(defun %clamp-day (year month day)
  (min day (length-of-month year month)))

(defun local-date-plus-months (date n)
  "Adds N months. When the target month is shorter than DATE's day-of-month,
the result clamps to the last day of the target month -- java.time's
plusMonths behavior (2023-01-31 plus 1 month is 2023-02-28, not an error)."
  (multiple-value-bind (extra-years month0) (floor (+ (1- (local-date-month date)) n) 12)
    (let ((year (+ (local-date-year date) extra-years))
          (month (1+ month0)))
      (%make-local-date year month (%clamp-day year month (local-date-day date))))))

(defun local-date-minus-months (date n)
  (local-date-plus-months date (- n)))

(defun local-date-plus-years (date n)
  (local-date-plus-months date (* n 12)))

(defun local-date-minus-years (date n)
  (local-date-plus-months date (* n -12)))

(defun local-date-plus-period (date p)
  (local-date-plus-days
    (local-date-plus-months date (+ (* (period-years p) 12) (period-months p)))
    (period-days p)))

(defun local-date-minus-period (date p)
  (local-date-plus-period date (period-negate p)))

(defun local-date-compare (a b)
  (let ((delta (- (local-date-to-epoch-day a) (local-date-to-epoch-day b))))
    (cond
      ((minusp delta) -1)
      ((plusp delta) 1)
      (t 0))))

(defun local-date= (a b)
  (zerop (local-date-compare a b)))

(defun local-date< (a b)
  (minusp (local-date-compare a b)))

(defun local-date<= (a b)
  (not (plusp (local-date-compare a b))))

(defun local-date> (a b)
  (plusp (local-date-compare a b)))

(defun local-date>= (a b)
  (not (minusp (local-date-compare a b))))

(defun local-date-until (start end)
  "The PERIOD from START to END, as whole years, then whole months, then
remaining days -- a direct port of java.time's Period.between algorithm."
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

(defun %iso-weekday-number-from-symbol (day-of-week)
  "Returns DAY-OF-WEEK's ISO number, accepting :MONDAY through :SUNDAY."
  (ecase day-of-week
    (:monday 1)
    (:tuesday 2)
    (:wednesday 3)
    (:thursday 4)
    (:friday 5)
    (:saturday 6)
    (:sunday 7)))

(defun local-date-next-or-same (date day-of-week)
  "Returns DATE or the next DATE whose weekday is DAY-OF-WEEK."
  (local-date-plus-days
    date
    (mod
      (- (%iso-weekday-number-from-symbol day-of-week) (%iso-weekday-number date))
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
      (- (%iso-weekday-number date) (%iso-weekday-number-from-symbol day-of-week))
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
    (%iso-weekday-number-from-symbol day-of-week)
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
