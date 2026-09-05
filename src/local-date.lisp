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
