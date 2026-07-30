;;;; src/rrule-candidates.lisp
;;;;
;;;; RFC 5545 recurrence candidate generation: turning one frequency period's
;;;; anchor into its ordered raw DATE or local DATE-TIME candidates, including
;;;; BYSETPOS positional selection. RRULE-OCCURRENCES.LISP turns these
;;;; candidates into a bounded occurrence stream; RRULE-DATE-SELECTION.LISP
;;;; owns the BYxxx day-selector matching this file calls into.
(in-package #:cl-date-kit)

(progn
  (defun %rrule-date-candidates (anchor rule dtstart &optional visitor)
    "Return ordered DATE candidates, or call VISITOR for each DATE."
    (if visitor (%rrule-period-dates anchor rule dtstart visitor)
      (let ((candidates nil))
        (%rrule-period-dates
          anchor
          rule
          dtstart
          (lambda (date)
            (push date candidates)))
        (nreverse candidates))))
  (defun %rrule-merge-date-candidates (left right)
    "Merge sorted DATE candidate lists, retaining one of each date."
    (let ((result nil))
      (loop (cond
          ((null left) (return (nreconc result right)))
          ((null right) (return (nreconc result left)))
          ((local-date< (car left) (car right)) (push (pop left) result))
          ((local-date< (car right) (car left)) (push (pop right) result))
          (t
            (push (pop left) result)
            (pop right))))))
  (defun %rrule-selected-date-candidates (anchor rule dtstart)
    (let ((positions (rrule-by-set-pos rule)))
      (if (null positions) (%rrule-date-candidates anchor rule dtstart)
        (let ((maximum-positive nil)
              (minimum-negative nil))
          (dolist (position positions)
            (cond
              ((plusp position)
                (setf maximum-positive (if maximum-positive (max maximum-positive position)
                    position)))
              ((minusp position)
                (setf minimum-negative (if minimum-negative (min minimum-negative position)
                    position)))))
          (let* ((positive-positions
                (make-array
                  (1+ (or maximum-positive 0))
                  :element-type
                  (quote bit)
                  :initial-element
                  0))
                 (ring-length (abs (or minimum-negative 0)))
                 (negative-positions
                (make-array (1+ ring-length) :element-type (quote bit) :initial-element 0))
                 (ring-dates (make-array ring-length))
                 (positive-candidates nil)
                 (candidate-count 0))
            (dolist (position positions)
              (cond
                ((plusp position)
                  (setf (aref positive-positions position) 1))
                ((minusp position)
                  (setf (aref negative-positions (- position)) 1))))
            (%rrule-date-candidates
              anchor
              rule
              dtstart
              (lambda (date)
                (incf candidate-count)
                (when (and
                    maximum-positive
                    (<= candidate-count maximum-positive)
                    (= (aref positive-positions candidate-count) 1))
                  (push date positive-candidates))
                (when minimum-negative
                  (setf (aref ring-dates (mod (1- candidate-count) ring-length)) date))))
            (let ((negative-candidates nil))
              (dolist (position positions)
                (when (and
                    (minusp position)
                    (= (aref negative-positions (- position)) 1)
                    (>= candidate-count (- position)))
                  (setf (aref negative-positions (- position)) 0)
                  (push
                    (aref ring-dates (mod (+ candidate-count position) ring-length))
                    negative-candidates)))
              (%rrule-merge-date-candidates
                (nreverse positive-candidates)
                (nreverse negative-candidates)))))))))

(defun %rrule-local-candidates (anchor rule dtstart &optional visitor)
  "Return ordered local DATE-TIME candidates, or visit raw components."
  (let* ((frequency (rrule-frequency rule))
         (rank (position frequency +rrule-frequencies+))
         (by-hour (rrule-by-hour rule))
         (by-minute (rrule-by-minute rule))
         (by-second (rrule-by-second rule))
         ;; A BY part at or below the frequency filters the anchor once.
         (hour-filter (and (< rank 3) by-hour))
         (minute-filter (and (< rank 2) by-minute))
         (second-filter (and (< rank 1) by-second))
         (anchor-hour (local-date-time-hour anchor))
         (anchor-minute (local-date-time-minute anchor))
         (anchor-second (local-date-time-second anchor))
         (hours (if (>= rank 3) (or by-hour (list anchor-hour)) (list anchor-hour)))
         (minutes (if (>= rank 2) (or by-minute (list anchor-minute)) (list anchor-minute)))
         (seconds (if (>= rank 1) (or by-second (list anchor-second)) (list anchor-second)))
         (anchor-time-allowed-p
           (and (or (null hour-filter) (member anchor-hour hour-filter))
                (or (null minute-filter) (member anchor-minute minute-filter))
                (or (null second-filter) (member anchor-second second-filter)))))
    (when anchor-time-allowed-p
      (let ((candidates nil)
            (nanosecond (local-date-time-nanosecond anchor)))
        (labels ((emit-date (year month day)
                   (loop for hour in hours
                         do (loop for minute in minutes
                                  do (loop for second in seconds
                                           do (if visitor
                                                  (funcall visitor year month day hour minute second)
                                                  (push (local-date-time-of
                                                         year month day hour minute second nanosecond)
                                                        candidates)))))))
          (if (%rrule-yearly-direct-p rule)
              (%rrule-map-yearly-direct-date-components
               rule dtstart (local-date-time-year anchor) (function emit-date))
              (%rrule-period-dates anchor rule dtstart nil (function emit-date)))
          (unless visitor (nreverse candidates)))))))

(progn
  (defun %rrule-merge-local-candidates (left right)
    "Merge sorted candidate lists, retaining one value for each local date-time."
    (let ((result nil))
      (loop (cond
          ((null left) (return (nreconc result right)))
          ((null right) (return (nreconc result left)))
          ((local-date-time< (car left) (car right)) (push (pop left) result))
          ((local-date-time< (car right) (car left)) (push (pop right) result))
          (t
            (push (pop left) result)
            (pop right))))))
  (defun %rrule-selected-local-candidates (anchor rule dtstart)
    (let ((positions (rrule-by-set-pos rule)))
      (if (null positions) (%rrule-local-candidates anchor rule dtstart)
        (let ((maximum-positive nil)
              (minimum-negative nil))
          (dolist (position positions)
            (cond
              ((plusp position)
                (setf maximum-positive (if maximum-positive (max maximum-positive position)
                    position)))
              ((minusp position)
                (setf minimum-negative (if minimum-negative (min minimum-negative position)
                    position)))))
          (let* ((positive-positions
                (make-array
                  (1+ (or maximum-positive 0))
                  :element-type
                  (quote bit)
                  :initial-element
                  0))
                 (ring-length (abs (or minimum-negative 0)))
                 (negative-positions
                (make-array (1+ ring-length) :element-type (quote bit) :initial-element 0))
                 (ring-years (make-array ring-length))
                 (ring-months (make-array ring-length))
                 (ring-days (make-array ring-length))
                 (ring-times (make-array ring-length))
                 (positive-candidates nil)
                 (candidate-count 0)
                 (nanosecond (local-date-time-nanosecond anchor)))
            (dolist (position positions)
              (cond
                ((plusp position)
                  (setf (aref positive-positions position) 1))
                ((minusp position)
                  (setf (aref negative-positions (- position)) 1))))
            (%rrule-local-candidates
              anchor
              rule
              dtstart
              (lambda (year month day hour minute second)
                (incf candidate-count)
                (when (and
                    maximum-positive
                    (<= candidate-count maximum-positive)
                    (= (aref positive-positions candidate-count) 1))
                  (push
                    (local-date-time-of year month day hour minute second nanosecond)
                    positive-candidates))
                (when minimum-negative
                  (let ((index (mod (1- candidate-count) ring-length)))
                    (setf (aref ring-years index) year
                          (aref ring-months index) month
                          (aref ring-days index) day
                          (aref ring-times index) (+ (* hour 3600) (* minute 60) second))))))
            (let ((negative-candidates nil))
              (dolist (position positions)
                (when (and
                    (minusp position)
                    (= (aref negative-positions (- position)) 1)
                    (>= candidate-count (- position)))
                  (setf (aref negative-positions (- position)) 0)
                  (let* ((index (mod (+ candidate-count position) ring-length))
                         (year (aref ring-years index))
                         (month (aref ring-months index))
                         (day (aref ring-days index))
                         (seconds-of-day (aref ring-times index)))
                    (multiple-value-bind (hour remainder) (floor seconds-of-day 3600)
                      (multiple-value-bind (minute second) (floor remainder 60)
                        (push
                          (local-date-time-of year month day hour minute second nanosecond)
                          negative-candidates))))))
              (%rrule-merge-local-candidates
                (nreverse positive-candidates)
                (nreverse negative-candidates)))))))))
