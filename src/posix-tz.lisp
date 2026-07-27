;;;; POSIX TZ footer parsing and annual transition projection.

(in-package #:cl-date-kit)

(defstruct posix-tz-rule (std-utc-offset 0 :type integer :read-only t)
  (dst-utc-offset nil :type (or null integer) :read-only t)
  (dst-start nil :read-only t)
  (dst-end nil :read-only t))

(defun %split-string (string separator)
  (loop with start = 0
        for pos = (position separator string :start start)
        collect (subseq string start pos)
        while pos
        do (setf start (1+ pos))))

(defun %parse-posix-name-offset (segment pos offset-required-p invalid)
  "Parses one POSIX abbreviation and its optional UTC offset from SEGMENT.
INVALID is called for grammar violations."
  (let ((length (length segment)))
    (when (>= pos length)
      (funcall invalid "missing time-zone abbreviation"))
    (let ((name-end
          (cond
            ((char= (char segment pos) #\<)
              (let ((close (position #\> segment :start (1+ pos))))
                (unless (and close (> close (1+ pos)))
                  (funcall invalid "unterminated or empty bracketed abbreviation in ~S" segment))
                (1+ close)))
            ((alpha-char-p (char segment pos))
              (loop for end from pos below length
                    while (alpha-char-p (char segment end))
                    finally (return
                              (if (>= (- end pos) 3) end
                                (funcall invalid "abbreviation must contain at least three letters in ~S" segment)))))
            (t
              (funcall invalid "invalid time-zone abbreviation in ~S" segment)))))
      (if (= name-end length)
          (if offset-required-p
              (funcall invalid "missing UTC offset after abbreviation in ~S" segment)
            (values nil name-end))
        (let* ((sign-char (char segment name-end))
               (has-sign (member sign-char (list #\+ #\-)))
               (digits-start (if has-sign (1+ name-end) name-end)))
          (when (>= digits-start length)
            (funcall invalid "missing UTC offset digits in ~S" segment))
          (let* ((digits-end
                 (or (position-if-not
                       (lambda (character)
                         (or (digit-char-p character) (char= character #\:)))
                       segment
                       :start digits-start)
                   length))
                 (parts (%split-string (subseq segment digits-start digits-end) #\:)))
            (unless (and (<= 1 (length parts) 3)
                         (every
                          (lambda (part)
                            (and (plusp (length part))
                                 (every (lambda (character) (digit-char-p character)) part)))
                          parts))
              (funcall invalid "invalid UTC offset in ~S" segment))
            (let ((hours (parse-integer (first parts)))
                  (minutes (if (second parts) (parse-integer (second parts)) 0))
                  (seconds (if (third parts) (parse-integer (third parts)) 0)))
              (unless (and (<= 0 hours 24) (<= 0 minutes 59) (<= 0 seconds 59))
                (funcall invalid "UTC offset out of range in ~S" segment))
              (values
               (- (* (if (char= sign-char #\-) -1 1)
                     (+ (* hours 3600) (* minutes 60) seconds)))
               digits-end))))))))

(progn
  (defun %parse-posix-rule-time (time-string invalid)
    "Parses POSIX transition TIME-STRING and signals INVALID on malformed input."
    (let* ((length (length time-string))
           (suffix (and (plusp length) (char-downcase (char time-string (1- length)))))
           (mode (case suffix
                   ((#\w) :wall)
                   ((#\s) :standard)
                   ((#\u #\g #\z) :utc)
                   (otherwise :wall)))
           (numeric-time (if (member suffix (list #\w #\s #\u #\g #\z))
                             (subseq time-string 0 (1- length))
                           time-string))
           (signed-p (and (plusp (length numeric-time))
                          (member (char numeric-time 0) (list #\+ #\-))))
           (sign (if (and signed-p (char= (char numeric-time 0) #\-)) -1 1))
           (parts (%split-string (subseq numeric-time (if signed-p 1 0)) #\:)))
      (unless (and (<= 1 (length parts) 3)
                   (every
                    (lambda (part)
                      (and (plusp (length part))
                           (every (lambda (character) (digit-char-p character)) part)))
                    parts))
        (funcall invalid "invalid POSIX transition time ~S" time-string))
      (let ((hours (parse-integer (first parts)))
            (minutes (if (second parts) (parse-integer (second parts)) 0))
            (seconds (if (third parts) (parse-integer (third parts)) 0)))
        (unless (and (<= 0 hours 167) (<= 0 minutes 59) (<= 0 seconds 59))
          (funcall invalid "POSIX transition time out of range ~S" time-string))
        (values (* sign (+ (* hours 3600) (* minutes 60) seconds)) mode))))
  (defun %parse-posix-rule (rule-string invalid)
    "Parses a POSIX DST date[/time] rule and signals INVALID on malformed input."
    (let* ((slash (position #\/ rule-string))
           (date-part (subseq rule-string 0 slash))
           (time-part (if slash (subseq rule-string (1+ slash)) "2")))
      (when (zerop (length date-part))
        (funcall invalid "missing POSIX transition date in ~S" rule-string))
      (multiple-value-bind (second-of-day mode) (%parse-posix-rule-time time-part invalid)
        (cond
          ((char-equal (char date-part 0) #\M)
            (let ((numbers (%split-string (subseq date-part 1) #\.)))
              (unless (and (= (length numbers) 3)
                           (every
                            (lambda (number)
                              (and (plusp (length number))
                                   (every (lambda (character) (digit-char-p character)) number)))
                            numbers))
                (funcall invalid "invalid POSIX month-week-day rule ~S" date-part))
              (let ((month (parse-integer (first numbers)))
                    (week (parse-integer (second numbers)))
                    (day (parse-integer (third numbers))))
                (unless (and (<= 1 month 12) (<= 1 week 5) (<= 0 day 6))
                  (funcall invalid "POSIX month-week-day rule out of range ~S" date-part))
                (list :month-week-day month week day second-of-day mode))))
          ((char-equal (char date-part 0) #\J)
            (let ((day-string (subseq date-part 1)))
              (unless (and (plusp (length day-string))
                           (every (lambda (character) (digit-char-p character)) day-string))
                (funcall invalid "invalid POSIX Julian-day rule ~S" date-part))
              (let ((day (parse-integer day-string)))
                (unless (<= 1 day 365)
                  (funcall invalid "POSIX Julian-day rule out of range ~S" date-part))
                (list :julian-day day second-of-day mode))))
          (t
            (unless (every (lambda (character) (digit-char-p character)) date-part)
              (funcall invalid "invalid POSIX day-of-year rule ~S" date-part))
            (let ((day (parse-integer date-part)))
              (unless (<= 0 day 365)
                (funcall invalid "POSIX day-of-year rule out of range ~S" date-part))
              (list :day-of-year day second-of-day mode)))))))
  (defun parse-posix-tz-string (string &optional (path "POSIX TZ string"))
    "Parses STRING according to the POSIX TZ grammar used by TZif footers."
    (labels ((invalid (control &rest arguments)
               (error (quote malformed-tzif)
                      :path path
                      :reason (apply (function format) nil control arguments))))
      (unless (and (stringp string)
                   (plusp (length string))
                   (every (lambda (character) (< (char-code character) 128)) string))
        (invalid "POSIX TZ footer must be nonempty ASCII text"))
      (let ((segments (%split-string string #\,)))
        (unless (member (length segments) (list 1 3))
          (invalid "POSIX TZ footer must contain either no rules or two DST rules: ~S" string))
        (let ((zone-segment (first segments)))
          (multiple-value-bind (std-offset std-pos)
              (%parse-posix-name-offset zone-segment 0 t (function invalid))
            (if (= (length segments) 1)
                (progn
                  (unless (= std-pos (length zone-segment))
                    (invalid "trailing data after standard offset in ~S" string))
                  (make-posix-tz-rule :std-utc-offset std-offset))
              (progn
                (when (>= std-pos (length zone-segment))
                  (invalid "missing daylight abbreviation in ~S" string))
                (multiple-value-bind (explicit-dst-offset dst-pos)
                    (%parse-posix-name-offset zone-segment std-pos nil (function invalid))
                  (unless (= dst-pos (length zone-segment))
                    (invalid "trailing data after daylight offset in ~S" string))
                  (make-posix-tz-rule
                   :std-utc-offset std-offset
                   :dst-utc-offset (or explicit-dst-offset (+ std-offset 3600))
                   :dst-start (%parse-posix-rule (second segments) (function invalid))
                   :dst-end (%parse-posix-rule (third segments) (function invalid))))))))))))

(defun %day-of-week-index (date)
  "0=Sunday .. 6=Saturday."
  (mod (+ (local-date-to-epoch-day date) 4) 7))

(defun %nth-weekday-of-month (year month week target-dow)
  (let* ((first-of-month (make-local-date year month 1))
         (offset (mod (- target-dow (%day-of-week-index first-of-month)) 7))
         (first-occurrence (local-date-plus-days first-of-month offset)))
    (if (= week 5) (loop with candidate = first-occurrence
            for next = (local-date-plus-days candidate 7)
            while (= (local-date-month next) month)
            do (setf candidate next)
            finally (return candidate))
      (local-date-plus-days first-occurrence (* (1- week) 7)))))

(progn
  (defun %posix-rule-local-epoch-seconds (year rule)
    "Projects a parsed POSIX RULE to naive local epoch seconds in YEAR."
    (destructuring-bind (kind first &rest rest) rule
      (ecase kind
        (:month-week-day
          (destructuring-bind (week day second-of-day mode) rest
            (declare (ignore mode))
            (+
              (* (local-date-to-epoch-day (%nth-weekday-of-month year first week day)) 86400)
              second-of-day)))
        (:julian-day
          (destructuring-bind (second-of-day mode) rest
            (declare (ignore mode))
            (let ((ordinal
                  (if (and (leap-year-p year) (>= first 60)) (1+ first)
                    first)))
              (+
                (* (local-date-to-epoch-day (local-date-of-year-day year ordinal)) 86400)
                second-of-day))))
        (:day-of-year
          (destructuring-bind (second-of-day mode) rest
            (declare (ignore mode))
            (+
              (* (local-date-to-epoch-day (local-date-of-year-day year (1+ first))) 86400)
              second-of-day))))))
  (defun %posix-transition-instant (year rule standard-offset offset-before-transition)
    "Converts a POSIX rule transition to UTC according to its time basis."
    (-
      (%posix-rule-local-epoch-seconds year rule)
      (ecase (car (last rule))
        (:wall offset-before-transition)
        (:standard standard-offset)
        (:utc 0)))))

(defun %offset-from-posix-rule (epoch rule)
  (if (null (posix-tz-rule-dst-start rule)) (posix-tz-rule-std-utc-offset rule)
    (let* ((approx-year
          (local-date-year
            (local-date-from-epoch-day
              (floor (+ epoch (posix-tz-rule-std-utc-offset rule)) 86400))))
           (dst-start
          (%posix-transition-instant
            approx-year
            (posix-tz-rule-dst-start rule)
            (posix-tz-rule-std-utc-offset rule)
            (posix-tz-rule-std-utc-offset rule)))
           (dst-end
          (%posix-transition-instant
            approx-year
            (posix-tz-rule-dst-end rule)
            (posix-tz-rule-std-utc-offset rule)
            (posix-tz-rule-dst-utc-offset rule))))
      (if (< dst-start dst-end) (if (and (<= dst-start epoch) (< epoch dst-end)) (posix-tz-rule-dst-utc-offset rule)
          (posix-tz-rule-std-utc-offset rule))
        (if (or (>= epoch dst-start) (< epoch dst-end)) (posix-tz-rule-dst-utc-offset rule)
          (posix-tz-rule-std-utc-offset rule))))))

(defun %posix-transitions-for-year (year rule)
  "Returns the two DST transitions for YEAR as (INSTANT BEFORE AFTER) lists."
  (if (and (posix-tz-rule-dst-start rule) (posix-tz-rule-dst-end rule)) (let ((standard-offset (posix-tz-rule-std-utc-offset rule))
          (daylight-offset (posix-tz-rule-dst-utc-offset rule)))
      (sort
        (list
          (list
            (%posix-transition-instant
              year
              (posix-tz-rule-dst-start rule)
              standard-offset
              standard-offset)
            standard-offset
            daylight-offset)
          (list
            (%posix-transition-instant
              year
              (posix-tz-rule-dst-end rule)
              standard-offset
              daylight-offset)
            daylight-offset
            standard-offset))
        #'<
        :key
        #'first))
    '()))

(defun %classify-posix-local-date-time (naive-seconds rule)
  "Classifies NAIVE-SECONDS against the footer rule's nearby transitions.
The transition year is taken from the wall-clock date, with adjacent years
included for rules whose transition time crosses midnight or New Year's Day."
  (let ((year (local-date-year (local-date-from-epoch-day (floor naive-seconds 86400)))))
    (loop for transition-year from (1- year) to (1+ year)
          do (loop for (boundary before after) in (%posix-transitions-for-year transition-year rule)
            for local-before = (+ boundary before)
            for local-after = (+ boundary after)
            do (cond
          ((and
              (> local-after local-before)
              (<= local-before naive-seconds)
              (< naive-seconds local-after))
            (return-from
              %classify-posix-local-date-time
              (values :gap (list (%make-zone-offset before) (%make-zone-offset after)))))
          ((and
              (< local-after local-before)
              (<= local-after naive-seconds)
              (< naive-seconds local-before))
            (return-from
              %classify-posix-local-date-time
              (values :overlap (list (%make-zone-offset before) (%make-zone-offset after))))))))
    (values nil nil)))
