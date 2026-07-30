;;;; src/period.lisp
;;;;
;;;; PERIOD is a calendar-based delta of years, months, and days: java.time's
;;;; Period. Unlike DURATION it is not an exact elapsed time -- "1 month" is
;;;; 28, 29, 30, or 31 days depending where you start counting. Rust's chrono
;;;; deliberately has no single unified type here (it splits Months and
;;;; Days); CL-DATE-KIT follows java.time instead, since one type is easier
;;;; for callers to reach for than two.




(in-package #:cl-date-kit)
  (defstruct (period (:constructor %make-period (years months days)))
    (years 0 :type integer :read-only t)
    (months 0 :type integer :read-only t)
    (days 0 :type integer :read-only t))
  (defun make-period (&key (years 0) (months 0) (days 0))
    "Construct a calendar PERIOD from integral YEARS, MONTHS, and DAYS."
    (check-type years integer)
    (check-type months integer)
    (check-type days integer)
    (%make-period years months days))
  (defun period-of-years (years)
    (check-type years integer)
    (make-period :years years))
  (defun period-of-months (months)
    (check-type months integer)
    (make-period :months months))
  (defun period-of-days (days)
    (check-type days integer)
    (make-period :days days))

(defun period-of-weeks (weeks)
  "Construct a calendar PERIOD representing WEEKS as seven-day units."
  (check-type weeks integer)
  (period-of-days (* weeks 7)))
  (defun period-of (years months days)
    "Construct a calendar PERIOD from integral YEARS, MONTHS, and DAYS."
    (make-period :years years :months months :days days))
  (defun period-with-years (period years)
    "Return PERIOD with its year component replaced by integral YEARS."
    (make-period
      :years years
      :months (period-months period)
      :days (period-days period)))
  (defun period-with-months (period months)
    "Return PERIOD with its month component replaced by integral MONTHS."
    (make-period
      :years (period-years period)
      :months months
      :days (period-days period)))
  (defun period-with-days (period days)
    "Return PERIOD with its day component replaced by integral DAYS."
    (make-period
      :years (period-years period)
      :months (period-months period)
      :days days))
  (defun period-plus (a b)
    (make-period
      :years (+ (period-years a) (period-years b))
      :months (+ (period-months a) (period-months b))
      :days (+ (period-days a) (period-days b))))



(defun period-minus (a b)
  (make-period
    :years
    (- (period-years a) (period-years b))
    :months
    (- (period-months a) (period-months b))
    :days
    (- (period-days a) (period-days b))))

(defun period-plus-years (period years)
  "Return PERIOD with integral YEARS added to its year component."
  (period-plus period (period-of-years years)))

(defun period-plus-months (period months)
  "Return PERIOD with integral MONTHS added to its month component."
  (period-plus period (period-of-months months)))

(defun period-plus-days (period days)
  "Return PERIOD with integral DAYS added to its day component."
  (period-plus period (period-of-days days)))

(defun period-minus-years (period years)
  "Return PERIOD with integral YEARS subtracted from its year component."
  (period-minus period (period-of-years years)))

(defun period-minus-months (period months)
  "Return PERIOD with integral MONTHS subtracted from its month component."
  (period-minus period (period-of-months months)))

(defun period-minus-days (period days)
  "Return PERIOD with integral DAYS subtracted from its day component."
  (period-minus period (period-of-days days)))

(defun period-multiplied-by (period factor)
  "Return PERIOD with every component multiplied by integer FACTOR."
  (check-type factor integer)
  (make-period
    :years
    (* (period-years period) factor)
    :months
    (* (period-months period) factor)
    :days
    (* (period-days period) factor)))

(defun period-abs (period)
  "Return PERIOD with the absolute value of each component."
  (make-period
    :years
    (abs (period-years period))
    :months
    (abs (period-months period))
    :days
    (abs (period-days period))))

(defun period-negative-p (period)
  "Whether any component of PERIOD is negative."
  (or
    (minusp (period-years period))
    (minusp (period-months period))
    (minusp (period-days period))))

(defun period-to-total-months (period)
  "Return the signed total of PERIOD years and months in calendar months."
  (+ (* (period-years period) 12) (period-months period)))

(defun period-negate (p)
  (make-period
    :years
    (- (period-years p))
    :months
    (- (period-months p))
    :days
    (- (period-days p))))

(defun period-zero-p (p)
  (and (zerop (period-years p)) (zerop (period-months p)) (zerop (period-days p))))

(defun period= (a b)
  (and
    (= (period-years a) (period-years b))
    (= (period-months a) (period-months b))
    (= (period-days a) (period-days b))))

(defun period-normalized (p)
  "Fold YEARS and MONTHS into a single YEARS/MONTHS pair with |MONTHS| < 12,
matching java.time's Period.normalized(). DAYS is left untouched, since days
cannot be folded into months without knowing which months they fall in."
  (multiple-value-bind (years months) (truncate (+ (* (period-years p) 12) (period-months p)) 12)
    (make-period :years years :months months :days (period-days p))))
