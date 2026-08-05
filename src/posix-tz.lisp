;;;; POSIX TZ footer parsing and annual transition projection.
(in-package #:cl-date-kit)

(defstruct posix-tz-rule (std-utc-offset 0 :type integer :read-only t)
  (std-name "" :type string :read-only t)
  (dst-utc-offset nil :type (or null integer) :read-only t)
  (dst-name nil :type (or null string) :read-only t)
  (dst-start nil :read-only t)
  (dst-end nil :read-only t)
  (transitions-cache
    (make-hash-table :test (function eql))
    :type
    hash-table
    :read-only
    t))

(defconstant +posix-offset-max-hours+ 24
  "Maximum hour magnitude the POSIX TZ grammar permits in a UTC offset.")
(defconstant +posix-offset-max-minutes+ 59
  "Maximum minute magnitude the POSIX TZ grammar permits in a UTC offset.")
(defconstant +posix-offset-max-seconds+ 59
  "Maximum second magnitude the POSIX TZ grammar permits in a UTC offset.")

(defconstant +posix-transition-time-max-hour+ 167
  "Maximum hour value in a POSIX transition time: 24*7-1, permitting a
transition to fall up to a week away from its nominal day.")
(defconstant +posix-transition-time-max-minute+ 59
  "Maximum minute value in a POSIX transition time.")
(defconstant +posix-transition-time-max-second+ 59
  "Maximum second value in a POSIX transition time.")

(defconstant +posix-month-min+ 1 "Minimum month in an Mm.w.d transition-date rule.")
(defconstant +posix-month-max+ 12 "Maximum month in an Mm.w.d transition-date rule.")
(defconstant +posix-month-week-min+ 1
  "Minimum week-of-month in an Mm.w.d rule; week 5 always means \"the last
occurrence,\" so this is never zero.")
(defconstant +posix-month-week-max+ 5 "Maximum week-of-month in an Mm.w.d rule.")
(defconstant +posix-day-of-week-min+ 0 "Sunday, in an Mm.w.d rule's zero-based weekday.")
(defconstant +posix-day-of-week-max+ 6 "Saturday, in an Mm.w.d rule's zero-based weekday.")

(defconstant +posix-julian-day-min+ 1
  "Minimum day value in a Julian-day (Jn) rule; day 60 always means March 1st,
so a Jn rule cannot name a leap day.")
(defconstant +posix-julian-day-max+ 365 "Maximum day value in a Julian-day (Jn) rule.")

(defconstant +posix-day-of-year-min+ 0
  "Minimum day value in a zero-based day-of-year rule, which (unlike Jn) can
name a leap day.")
(defconstant +posix-day-of-year-max+ 365 "Maximum day value in a zero-based day-of-year rule.")

(defun %split-string (string separator)
  (loop with start = 0
        for pos = (position separator string :start start)
        collect (subseq string start pos)
        while pos
        do (setf start (1+ pos))))

(defun %parse-posix-name-offset (segment pos offset-required-p on-success invalid)
  "Parses one POSIX abbreviation and its optional UTC offset from SEGMENT,
calling ON-SUCCESS with (name offset-or-nil end-pos) on success. INVALID is
called for grammar violations."
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
              (loop for
                    end from pos below length
                    while (alpha-char-p (char segment end))
                    finally (return
                  (if (>= (- end pos) 3) end
                    (funcall
                      invalid
                      "abbreviation must contain at least three letters in ~S"
                      segment)))))
            (t (funcall invalid "invalid time-zone abbreviation in ~S" segment)))))
      (let ((name
            (if (char= (char segment pos) #\<) (subseq segment (1+ pos) (1- name-end))
              (subseq segment pos name-end))))
        (if (= name-end length) (if offset-required-p (funcall invalid "missing UTC offset after abbreviation in ~S" segment)
            (funcall on-success name nil name-end))
          (let* ((sign-char (char segment name-end))
                 (has-sign (member sign-char (list #\+ #\-)))
                 (digits-start
                (if has-sign (1+ name-end)
                  name-end)))
            (when (>= digits-start length)
              (funcall invalid "missing UTC offset digits in ~S" segment))
            (let* ((digits-end
                  (or
                    (position-if-not
                      (lambda (character)
                        (or (digit-char-p character) (char= character #\:)))
                      segment
                      :start
                      digits-start)
                    length))
                   (parts (%split-string (subseq segment digits-start digits-end) #\:)))
              (unless (and
                  (<= 1 (length parts) 3)
                  (every
                    (lambda (part)
                      (and
                        (plusp (length part))
                        (every
                          (lambda (character)
                            (digit-char-p character))
                          part)))
                    parts))
                (funcall invalid "invalid UTC offset in ~S" segment))
              (let ((hours (parse-integer (first parts)))
                    (minutes
                    (if (second parts) (parse-integer (second parts))
                      0))
                    (seconds
                    (if (third parts) (parse-integer (third parts))
                      0)))
                (unless (and (<= 0 hours +posix-offset-max-hours+) (<= 0 minutes +posix-offset-max-minutes+) (<= 0 seconds +posix-offset-max-seconds+))
                  (funcall invalid "UTC offset out of range in ~S" segment))
                (funcall on-success
                  name
                  (-
                    (*
                      (if (char= sign-char #\-) -1
                        1)
                      (+ (* hours 3600) (* minutes 60) seconds)))
                  digits-end)))))))))

(defun %day-of-week-index (date)
  "0=Sunday .. 6=Saturday."
  (mod (+ (local-date-to-epoch-day date) 4) 7))

(defun %posix-state-values-at-instant (epoch rule)
  (if (null (posix-tz-rule-dst-start rule)) (values (posix-tz-rule-std-utc-offset rule) (posix-tz-rule-std-name rule) nil)
    (let* ((approx-year
          (local-date-year
            (local-date-from-epoch-day
              (floor (+ epoch (posix-tz-rule-std-utc-offset rule)) +seconds-per-day+))))
           (latest-transition nil))
      (loop for year from (- approx-year 2) to (1+ approx-year)
            do (dolist (transition (%posix-transitions-for-year year rule))
          (when (and
              (<= (first transition) epoch)
              (or (null latest-transition) (> (first transition) (first latest-transition))))
            (setf latest-transition transition))))
      (if (= (third latest-transition) (posix-tz-rule-dst-utc-offset rule)) (values (posix-tz-rule-dst-utc-offset rule) (posix-tz-rule-dst-name rule) t)
        (values (posix-tz-rule-std-utc-offset rule) (posix-tz-rule-std-name rule) nil)))))

(defun %offset-from-posix-rule (epoch rule)
  (nth-value 0 (%posix-state-values-at-instant epoch rule)))

(defun %posix-transitions-for-year (year rule)
  "Returns the two DST transitions for YEAR as (INSTANT BEFORE AFTER) lists."
  (let ((cache (posix-tz-rule-transitions-cache rule)))
    (multiple-value-bind (cached present-p) (gethash year cache)
      (if present-p cached
        (setf (gethash year cache) (if (and (posix-tz-rule-dst-start rule) (posix-tz-rule-dst-end rule)) (let ((standard-offset (posix-tz-rule-std-utc-offset rule))
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
                (function <)
                :key
                (function first)))
            (quote ())))))))

(defun %classify-posix-local-date-time (naive-seconds rule)
  (let ((year (local-date-year (local-date-from-epoch-day (floor naive-seconds +seconds-per-day+)))))
    (block found
      (loop for transition-year from (1- year) to (1+ year)
            do (dolist (description (%posix-transitions-for-year transition-year rule))
          (destructuring-bind (boundary before after) description
            (let ((local-before (+ boundary before))
                  (local-after (+ boundary after)))
              (cond
                ((and
                    (> local-after local-before)
                    (<= local-before naive-seconds)
                    (< naive-seconds local-after))
                  (return-from
                    found
                    (values :gap (%make-zone-offset before) (%make-zone-offset after))))
                ((and
                    (< local-after local-before)
                    (<= local-after naive-seconds)
                    (< naive-seconds local-before))
                  (return-from
                    found
                    (values :overlap (%make-zone-offset before) (%make-zone-offset after)))))))))
      (values nil nil nil))))

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
              (* (local-date-to-epoch-day (%nth-weekday-of-month year first week day)) +seconds-per-day+)
              second-of-day)))
        (:julian-day
          (destructuring-bind (second-of-day mode) rest
            (declare (ignore mode))
            (let ((ordinal
                  (if (and (leap-year-p year) (>= first 60)) (1+ first)
                    first)))
              (+
                (* (local-date-to-epoch-day (local-date-of-year-day year ordinal)) +seconds-per-day+)
                second-of-day))))
        (:day-of-year
          (destructuring-bind (second-of-day mode) rest
            (declare (ignore mode))
            (+
              (* (local-date-to-epoch-day (local-date-of-year-day year (1+ first))) +seconds-per-day+)
              second-of-day))))))
  (defun %posix-transition-instant (year rule standard-offset offset-before-transition)
    "Converts a POSIX rule transition to UTC according to its time basis."
    (-
      (%posix-rule-local-epoch-seconds year rule)
      (ecase (car (last rule))
        (:wall offset-before-transition)
        (:standard standard-offset)
        (:utc 0)))))

(defun parse-posix-tz-string (string &optional (path "POSIX TZ string"))
  "Parses STRING according to the POSIX TZ grammar used by TZif footers."
  (labels ((invalid (control &rest arguments)
             (error
          (quote malformed-tzif)
          :path
          path
          :reason
          (apply (function format) nil control arguments))))
    (unless (and
        (stringp string)
        (plusp (length string))
        (every
          (lambda (character)
            (< (char-code character) 128))
          string))
      (invalid "POSIX TZ footer must be nonempty ASCII text"))
    (let ((segments (%split-string string #\,)))
      (unless (member (length segments) (list 1 3))
        (invalid
          "POSIX TZ footer must contain either no rules or two DST rules: ~S"
          string))
      (let ((zone-segment (first segments)))
        (%parse-posix-name-offset zone-segment 0 t
          (lambda (std-name std-offset std-pos)
            (if (= (length segments) 1)
                (progn
                  (unless (= std-pos (length zone-segment))
                    (invalid "trailing data after standard offset in ~S" string))
                  (make-posix-tz-rule :std-name std-name :std-utc-offset std-offset))
                (progn
                  (when (>= std-pos (length zone-segment))
                    (invalid "missing daylight abbreviation in ~S" string))
                  (%parse-posix-name-offset zone-segment std-pos nil
                    (lambda (dst-name explicit-dst-offset dst-pos)
                      (unless (= dst-pos (length zone-segment))
                        (invalid "trailing data after daylight offset in ~S" string))
                      (%parse-posix-rule (second segments)
                        (lambda (dst-start)
                          (%parse-posix-rule (third segments)
                            (lambda (dst-end)
                              (make-posix-tz-rule
                                :std-name std-name
                                :std-utc-offset std-offset
                                :dst-name dst-name
                                :dst-utc-offset (or explicit-dst-offset (+ std-offset 3600))
                                :dst-start dst-start
                                :dst-end dst-end))
                            (function invalid)))
                        (function invalid)))
                    (function invalid)))))
          (function invalid))))))

(defun %parse-posix-rule-time (string on-success invalid)
  "Parses a POSIX transition time from STRING, calling ON-SUCCESS with
(seconds mode) on success."
  (let ((length (length string))
        (position 0)
        (sign 1))
    (labels ((fail (control &rest arguments)
               (apply invalid control arguments))
             (read-number (maximum)
               (let ((start position))
            (loop while (and (< position length) (digit-char-p (char string position)))
                  do (incf position))
            (when (= start position)
              (fail "expected a decimal transition time in ~S" string))
            (let ((value (parse-integer string :start start :end position)))
              (when (> value maximum)
                (fail "transition time component exceeds ~D in ~S" maximum string))
              value))))
      (when (zerop length)
        (fail "missing transition time"))
      (when (and (< position length) (member (char string position) (list #\+ #\-)))
        (when (char= (char string position) #\-)
          (setf sign -1))
        (incf position))
      (let ((hour (read-number +posix-transition-time-max-hour+))
            (minute 0)
            (second 0))
        (when (and (< position length) (char= (char string position) #\:))
          (incf position)
          (setf minute (read-number +posix-transition-time-max-minute+))
          (when (and (< position length) (char= (char string position) #\:))
            (incf position)
            (setf second (read-number +posix-transition-time-max-second+))))
        (let ((mode
              (if (= position length) :wall
                (prog1
                  (case (char string position)
                    ((#\w) :wall)
                    ((#\s) :standard)
                    ((#\u #\g #\z) :utc)
                    (otherwise (fail "invalid transition time basis in ~S" string)))
                  (incf position)))))
          (unless (= position length)
            (fail "trailing data in transition time ~S" string))
          (funcall on-success (* sign (+ (* hour 3600) (* minute 60) second)) mode))))))

(defun %parse-posix-rule (string on-success invalid)
  "Parses a POSIX transition date rule and optional transition time, calling
ON-SUCCESS with the parsed rule list."
  (let* ((slash (position #\/ string))
         (date-part
        (if slash (subseq string 0 slash)
          string))
         (time-part (and slash (subseq string (1+ slash)))))
    (when (and slash (zerop (length time-part)))
      (funcall invalid "missing transition time in ~S" string))
    (flet ((continue-with-time (second-of-day mode)
             (labels ((decimal (text)
                        (unless (and
                       (plusp (length text))
                       (every
                         (lambda (character)
                           (digit-char-p character))
                         text))
                     (funcall invalid "invalid POSIX transition date in ~S" string))
                        (parse-integer text)))
               (funcall on-success
                 (cond
                   ((and (plusp (length date-part)) (char= (char date-part 0) #\M))
                     (let ((parts (%split-string (subseq date-part 1) #\.)))
                       (unless (= (length parts) 3)
                         (funcall invalid "invalid month-week-day rule in ~S" string))
                       (let ((month (decimal (first parts)))
                             (week (decimal (second parts)))
                             (day (decimal (third parts))))
                         (unless (and (<= +posix-month-min+ month +posix-month-max+) (<= +posix-month-week-min+ week +posix-month-week-max+) (<= +posix-day-of-week-min+ day +posix-day-of-week-max+))
                           (funcall invalid "month-week-day rule out of range in ~S" string))
                         (list :month-week-day month week day second-of-day mode))))
                   ((and (plusp (length date-part)) (char= (char date-part 0) #\J))
                     (let ((day (decimal (subseq date-part 1))))
                       (unless (<= +posix-julian-day-min+ day +posix-julian-day-max+)
                         (funcall invalid "Julian day rule out of range in ~S" string))
                       (list :julian-day day second-of-day mode)))
                   (t
                     (let ((day (decimal date-part)))
                       (unless (<= +posix-day-of-year-min+ day +posix-day-of-year-max+)
                         (funcall invalid "day-of-year rule out of range in ~S" string))
                       (list :day-of-year day second-of-day mode))))))))
      (if time-part
          (%parse-posix-rule-time time-part (function continue-with-time) invalid)
          (continue-with-time 7200 :wall)))))
