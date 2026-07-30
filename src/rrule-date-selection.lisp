(in-package #:cl-date-kit)

(defun %rrule-weekday-value (weekday)
  (ecase weekday
    (:mo 1)
    (:tu 2)
    (:we 3)
    (:th 4)
    (:fr 5)
    (:sa 6)
    (:su 7)))

(defun %rrule-week-start (date week-start)
  (local-date-minus-days
    date
    (mod
      (- (day-of-week-value (day-of-week date)) (%rrule-weekday-value week-start))
      7)))

(defun %rrule-week-one-start (year week-start)
  (let ((january-fourth (make-local-date year 1 4)))
    (%rrule-week-start january-fourth week-start)))

(defun %rrule-week-info (date week-start)
  (let* ((week-start-date (%rrule-week-start date week-start))
         (year (local-date-year (local-date-plus-days week-start-date 3)))
         (first (%rrule-week-one-start year week-start)))
    (values
      year
      (1+
        (floor
          (- (local-date-to-epoch-day week-start-date) (local-date-to-epoch-day first))
          7)))))

(defun %rrule-weeks-in-year (year week-start)
  (multiple-value-bind (week-year week) (%rrule-week-info (make-local-date year 12 28) week-start)
    (if (= week-year year) week
      52)))

(progn
  (defstruct (%rrule-day-selector
      (:constructor
        %make-rrule-day-selector
        (month-bits
          month-day-positive-bits
          month-day-negative-bits
          year-day-positive-bits
          year-day-negative-bits
          week-no-positive-bits
          week-no-negative-bits
          weekday-mask
          ordinal-weekdays
          week-start
          month-scope))) month-bits
    month-day-positive-bits
    month-day-negative-bits
    year-day-positive-bits
    year-day-negative-bits
    week-no-positive-bits
    week-no-negative-bits
    weekday-mask
    ordinal-weekdays
    week-start
    month-scope)
  (defvar *rrule-day-selector* nil)
  (defun %rrule-selector-bits (values limit)
    (when values
      (let ((bits (make-array (1+ limit) :element-type 'bit :initial-element 0)))
        (dolist (value values bits)
          (setf (sbit bits value) 1)))))
  (defun %rrule-selector-signed-bits (values limit)
    (let (positive
          negative)
      (dolist (value values)
        (if (plusp value) (setf (sbit
              (or
                positive
                (setf positive (make-array (1+ limit) :element-type 'bit :initial-element 0)))
              value) 1)
          (setf (sbit
              (or
                negative
                (setf negative (make-array (1+ limit) :element-type 'bit :initial-element 0)))
              (- value)) 1)))
      (values positive negative)))
  (defun %rrule-selector-weekdays (values)
    (let ((mask 0)
          ordinals)
      (dolist (item values)
        (let ((weekday (%rrule-weekday-value (rrule-by-day-weekday item)))
              (ordinal (rrule-by-day-ordinal item)))
          (if ordinal (push (cons weekday ordinal) ordinals)
            (setf mask (logior mask (ash 1 weekday))))))
      (values mask (nreverse ordinals))))
  (defun %compile-rrule-day-selector (rule)
    (multiple-value-bind (month-day-positive-bits month-day-negative-bits) (%rrule-selector-signed-bits (rrule-by-month-day rule) 31)
      (multiple-value-bind (year-day-positive-bits year-day-negative-bits) (%rrule-selector-signed-bits (rrule-by-year-day rule) 366)
        (multiple-value-bind (week-no-positive-bits week-no-negative-bits) (%rrule-selector-signed-bits (rrule-by-week-no rule) 53)
          (multiple-value-bind (weekday-mask ordinal-weekdays) (%rrule-selector-weekdays (rrule-by-day rule))
            (%make-rrule-day-selector
              (%rrule-selector-bits (rrule-by-month rule) 12)
              month-day-positive-bits
              month-day-negative-bits
              year-day-positive-bits
              year-day-negative-bits
              week-no-positive-bits
              week-no-negative-bits
              weekday-mask
              ordinal-weekdays
              (rrule-week-start rule)
              (or
                (eq (rrule-frequency rule) :monthly)
                (and (eq (rrule-frequency rule) :yearly) (rrule-by-month rule)))))))))
  (defmacro %rrule-selector-index-matches-p (positive-bits negative-bits index length)
    `(or
      (and ,positive-bits (= (sbit ,positive-bits ,index) 1))
      (and ,negative-bits (= (sbit ,negative-bits (1+ (- ,length ,index))) 1)))))

(defun %rrule-weekday-ordinal-p (date weekday ordinal month-scope)
  "Return whether DATE is the requested positive or negative weekday ordinal."
  (let* ((year (local-date-year date))
         (scope-length
        (if month-scope (length-of-month year (local-date-month date))
          (local-date-length-of-year date)))
         (scope-index
        (if month-scope (local-date-day date)
          (day-of-year date)))
         (first-index
        (1+
          (mod
            (-
              weekday
              (day-of-week-value
                (day-of-week
                  (if month-scope (make-local-date year (local-date-month date) 1)
                    (make-local-date year 1 1)))))
            7)))
         (ordinal-from-start (1+ (floor (- scope-index first-index) 7)))
         (occurrences (1+ (floor (- scope-length first-index) 7))))
    (=
      ordinal-from-start
      (if (plusp ordinal) ordinal
        (+ occurrences ordinal 1)))))

(defun %rrule-day-matches-p (date selector period-year)
  (let* ((year (local-date-year date))
         (month (local-date-month date))
         (month-length (length-of-month year month))
         (year-length (local-date-length-of-year date))
         (date-weekday (day-of-week-value (day-of-week date)))
         (month-bits (%rrule-day-selector-month-bits selector))
         (month-day-positive-bits (%rrule-day-selector-month-day-positive-bits selector))
         (month-day-negative-bits (%rrule-day-selector-month-day-negative-bits selector))
         (year-day-positive-bits (%rrule-day-selector-year-day-positive-bits selector))
         (year-day-negative-bits (%rrule-day-selector-year-day-negative-bits selector))
         (week-no-positive-bits (%rrule-day-selector-week-no-positive-bits selector))
         (week-no-negative-bits (%rrule-day-selector-week-no-negative-bits selector))
         (ordinal-weekdays (%rrule-day-selector-ordinal-weekdays selector)))
    (and
      (or (null month-bits) (= (sbit month-bits month) 1))
      (or
        (and (null month-day-positive-bits) (null month-day-negative-bits))
        (%rrule-selector-index-matches-p
          month-day-positive-bits
          month-day-negative-bits
          (local-date-day date)
          month-length))
      (or
        (and (null year-day-positive-bits) (null year-day-negative-bits))
        (%rrule-selector-index-matches-p
          year-day-positive-bits
          year-day-negative-bits
          (day-of-year date)
          year-length))
      (or
        (and (null week-no-positive-bits) (null week-no-negative-bits))
        (multiple-value-bind (week-year week) (%rrule-week-info date (%rrule-day-selector-week-start selector))
          (and
            (= week-year period-year)
            (%rrule-selector-index-matches-p
              week-no-positive-bits
              week-no-negative-bits
              week
              (%rrule-weeks-in-year period-year (%rrule-day-selector-week-start selector))))))
      (or
        (and
          (zerop (%rrule-day-selector-weekday-mask selector))
          (null ordinal-weekdays))
        (logbitp date-weekday (%rrule-day-selector-weekday-mask selector))
        (loop for (weekday . ordinal) in ordinal-weekdays
              thereis (and
            (= date-weekday weekday)
            (%rrule-weekday-ordinal-p
              date
              weekday
              ordinal
              (%rrule-day-selector-month-scope selector))))))))

(defun %rrule-map-yearly-direct-date-components (rule dtstart period-year visitor)
  "Call VISITOR for direct YEARLY candidates in date order."
  (let* ((by-month (rrule-by-month rule))
         (by-month-day (rrule-by-month-day rule))
         (months
        (cond
          (by-month by-month)
          (by-month-day (quote (1 2 3 4 5 6 7 8 9 10 11 12)))
          (t (list (local-date-time-month dtstart)))))
         (month-days (or by-month-day (list (local-date-time-day dtstart)))))
    (if (and
        by-month-day
        (not
          (or
            (every (function plusp) by-month-day)
            (every (function minusp) by-month-day)))) (let ((days (make-array 32 :element-type (quote bit) :initial-element 0)))
        (loop for month in months
              do (let ((month-length (length-of-month period-year month)))
            (fill days 0)
            (dolist (month-day month-days)
              (let ((day
                    (if (minusp month-day) (+ month-length month-day 1)
                      month-day)))
                (when (<= 1 day month-length)
                  (setf (sbit days day) 1))))
            (loop for day from 1 to month-length
                  when (= (sbit days day) 1)
                    do (funcall visitor period-year month day)))))
      (loop for month in months
            for month-length = (length-of-month period-year month)
            do (loop for month-day in month-days
              for day = (if (minusp month-day) (+ month-length month-day 1)
            month-day)
              when (<= 1 day month-length)
                do (funcall visitor period-year month day))))))

(defun %rrule-period-dates (anchor rule dtstart &optional visitor component-visitor)
  (let* ((frequency (rrule-frequency rule))
         (period-year (local-date-time-year anchor))
         (selector (or *rrule-day-selector* (%compile-rrule-day-selector rule))))
    (if (%rrule-yearly-direct-p rule) (cond
        (component-visitor
          (%rrule-map-yearly-direct-date-components
            rule
            dtstart
            period-year
            component-visitor))
        (visitor
          (%rrule-map-yearly-direct-date-components
            rule
            dtstart
            period-year
            (lambda (year month day)
              (funcall visitor (make-local-date year month day)))))
        (t (%rrule-yearly-direct-dates rule dtstart period-year)))
      (let* ((date (local-date-time-date anchor))
             (week-number-year-p (and (eq frequency :yearly) (rrule-by-week-no rule)))
             (default-yearly-month-p
            (and
              (eq frequency :yearly)
              (null (rrule-by-month rule))
              (null (rrule-by-day rule))
              (null (rrule-by-year-day rule))
              (null (rrule-by-week-no rule))))
             (default-month-day-p
            (and
              (member frequency (quote (:monthly :yearly)))
              (null (rrule-by-month-day rule))
              (null (rrule-by-day rule))
              (null (rrule-by-year-day rule))
              (null (rrule-by-week-no rule))))
             (default-weekly-day-p (and (eq frequency :weekly) (null (rrule-by-day rule))))
             (start
            (if week-number-year-p (%rrule-week-one-start period-year (rrule-week-start rule))
              (ecase frequency
                ((:secondly :minutely :hourly :daily) date)
                (:weekly (%rrule-week-start date (rrule-week-start rule)))
                (:monthly (make-local-date (local-date-year date) (local-date-month date) 1))
                (:yearly (make-local-date period-year 1 1)))))
             (end
            (if week-number-year-p (local-date-minus-days
                (%rrule-week-one-start (1+ period-year) (rrule-week-start rule))
                1)
              (ecase frequency
                ((:secondly :minutely :hourly :daily) date)
                (:weekly (local-date-plus-days start 6))
                (:monthly
                  (make-local-date
                    (local-date-year date)
                    (local-date-month date)
                    (length-of-month (local-date-year date) (local-date-month date))))
                (:yearly (make-local-date period-year 12 31))))))
        (let ((candidates nil))
          (loop for current = start then (local-date-plus-days current 1)
                while (local-date<= current end)
                when (and
              (%rrule-day-matches-p current selector period-year)
              (or
                (not default-yearly-month-p)
                (= (local-date-month current) (local-date-time-month dtstart)))
              (or
                (not default-month-day-p)
                (= (local-date-day current) (local-date-time-day dtstart)))
              (or
                (not default-weekly-day-p)
                (=
                  (day-of-week-value (day-of-week current))
                  (day-of-week-value (day-of-week (local-date-time-date dtstart))))))
                  do (cond
              (component-visitor
                (funcall
                  component-visitor
                  (local-date-year current)
                  (local-date-month current)
                  (local-date-day current)))
              (visitor (funcall visitor current))
              (t (push current candidates))))
          (unless (or visitor component-visitor)
            (nreverse candidates)))))))

(progn
  (defun %rrule-yearly-direct-p (rule)
    (and
      (eq (rrule-frequency rule) :yearly)
      (null (rrule-by-week-no rule))
      (null (rrule-by-year-day rule))
      (null (rrule-by-day rule))))
  (defun %rrule-yearly-direct-dates (rule dtstart period-year)
    "Generate yearly candidates when no week, year-day, or weekday selector applies."
    (let ((candidates nil))
      (%rrule-map-yearly-direct-date-components
        rule
        dtstart
        period-year
        (lambda (year month day)
          (push (make-local-date year month day) candidates)))
      (nreverse candidates))))
