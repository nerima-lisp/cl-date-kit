;;;; src/locale.lisp
;;;;
;;;; Pattern locale data is intentionally small and dependency-free. English is
;;;; the only bundled locale; callers can retain the locale object in a formatter.
(in-package #:cl-date-kit)

(defstruct (date-time-locale
    (:constructor
      %make-date-time-locale
      (name short-months months short-weekdays weekdays am pm))) (name :en :type keyword :read-only t)
  (short-months #() :type vector :read-only t)
  (months #() :type vector :read-only t)
  (short-weekdays #() :type vector :read-only t)
  (weekdays #() :type vector :read-only t)
  (am "AM" :type string :read-only t)
  (pm "PM" :type string :read-only t))

(defparameter +english-date-time-locale+ (%make-date-time-locale
    :en
    #("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec")
    #("January"
      "February"
      "March"
      "April"
      "May"
      "June"
      "July"
      "August"
      "September"
      "October"
      "November"
      "December")
    #("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
    #("Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday" "Sunday")
    "AM"
    "PM"))

(progn
  (defun %copy-date-time-locale-names (names expected-length)
    (check-type names vector)
    (unless (and (= (length names) expected-length)
                 (every #'stringp names))
      (error
       'type-error
       :datum names
       :expected-type `(vector string ,expected-length)))
    (map 'vector #'copy-seq names))

  (defun %non-empty-string-p (value)
    (and (stringp value) (plusp (length value))))

  (defun %copy-date-time-locale-meridiem (value)
    (unless (%non-empty-string-p value)
      (error
       'type-error
       :datum value
       :expected-type '(satisfies %non-empty-string-p)))
    (copy-seq value))

  (defun make-date-time-locale
      (&key name short-months months short-weekdays weekdays am pm)
    "Create immutable locale data for pattern formatters.

NAME is a keyword. The month vectors each contain 12 strings and the weekday
vectors each contain 7 strings. AM and PM are nonempty strings. All input text
is defensively copied."
    (check-type name keyword)
    (%make-date-time-locale
     name
     (%copy-date-time-locale-names short-months 12)
     (%copy-date-time-locale-names months 12)
     (%copy-date-time-locale-names short-weekdays 7)
     (%copy-date-time-locale-names weekdays 7)
     (%copy-date-time-locale-meridiem am)
     (%copy-date-time-locale-meridiem pm)))

  (defun find-date-time-locale (locale &optional pattern)
    "Return LOCALE as a DATE-TIME-LOCALE, or signal a format error.

LOCALE can be a custom DATE-TIME-LOCALE or the bundled :EN identifier.
PATTERN is an internal diagnostic context."
    (cond
      ((date-time-locale-p locale) locale)
      ((eq locale :en) +english-date-time-locale+)
      (t
       (error
        'date-time-format-error
        :pattern pattern
        :reason
        (format nil "unsupported locale ~S; only :EN is available" locale))))))

(defun %date-time-locale-month-name (locale month width)
  (aref
    (if (= width 3) (date-time-locale-short-months locale)
      (date-time-locale-months locale))
    (1- month)))

(defun %date-time-locale-weekday-name (locale weekday width)
  (aref
    (if (= width 3) (date-time-locale-short-weekdays locale)
      (date-time-locale-weekdays locale))
    (1- (day-of-week-value weekday))))

(defun %date-time-locale-find-name (names value)
  (loop for name across names
        for index from 1
        when (string-equal name value)
          return index))

(defun %date-time-locale-find-month (locale value width)
  (%date-time-locale-find-name
    (if (= width 3) (date-time-locale-short-months locale)
      (date-time-locale-months locale))
    value))

(defun %date-time-locale-find-weekday (locale value width)
  (let ((index
        (%date-time-locale-find-name
          (if (= width 3) (date-time-locale-short-weekdays locale)
            (date-time-locale-weekdays locale))
          value)))
    (and
      index
      (nth
        (1- index)
        '(:monday :tuesday :wednesday :thursday :friday :saturday :sunday)))))

(defun %date-time-locale-meridiem (locale hour)
  (if (< hour 12) (date-time-locale-am locale)
    (date-time-locale-pm locale)))

(defun %date-time-locale-find-meridiem (locale value)
  (cond
    ((string-equal value (date-time-locale-am locale)) :am)
    ((string-equal value (date-time-locale-pm locale)) :pm)))
