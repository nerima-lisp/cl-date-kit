;;;; src/period.lisp
;;;;
;;;; PERIOD is a calendar-based delta of years, months, and days: java.time's
;;;; Period. Unlike DURATION it is not an exact elapsed time -- "1 month" is
;;;; 28, 29, 30, or 31 days depending where you start counting. Rust's chrono
;;;; deliberately has no single unified type here (it splits Months and
;;;; Days); CL-DATE-KIT follows java.time instead, since one type is easier
;;;; for callers to reach for than two.
(in-package #:cl-date-kit)

(defstruct period
  (years 0 :type integer :read-only t)
  (months 0 :type integer :read-only t)
  (days 0 :type integer :read-only t))

(defun period-of-years (years) (make-period :years years))
(defun period-of-months (months) (make-period :months months))
(defun period-of-days (days) (make-period :days days))

(defun period-plus (a b)
  (make-period :years (+ (period-years a) (period-years b))
               :months (+ (period-months a) (period-months b))
               :days (+ (period-days a) (period-days b))))

(defun period-negate (p)
  (make-period :years (- (period-years p))
               :months (- (period-months p))
               :days (- (period-days p))))

(defun period-zero-p (p)
  (and (zerop (period-years p)) (zerop (period-months p)) (zerop (period-days p))))

(defun period= (a b)
  (and (= (period-years a) (period-years b))
       (= (period-months a) (period-months b))
       (= (period-days a) (period-days b))))

(defun period-normalized (p)
  "Fold YEARS and MONTHS into a single YEARS/MONTHS pair with |MONTHS| < 12,
matching java.time's Period.normalized(). DAYS is left untouched, since days
cannot be folded into months without knowing which months they fall in."
  (multiple-value-bind (years months) (truncate (+ (* (period-years p) 12) (period-months p)) 12)
    (make-period :years years :months months :days (period-days p))))
