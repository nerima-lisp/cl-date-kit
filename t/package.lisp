;;;; t/package.lisp
;;;; t/package.lisp
(defpackage #:cl-date-kit/test
  (:use #:cl)
  ;; DESCRIBE clashes with CL:DESCRIBE; nothing else needs shadowing.
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:it #:expect #:signals #:run-all)
  (:import-from #:cl-date-kit
   ;; Duration
   #:duration-seconds #:duration-nanos #:duration-of-nanos #:duration-of-seconds #:duration-of-millis #:duration-of-micros #:duration-of-minutes #:duration-of-hours #:duration-of-days
   #:duration-zero #:duration-with-seconds #:duration-with-nanos #:duration-plus #:duration-minus #:duration-negate #:duration-abs #:duration-multiplied-by #:duration-divided-by
   #:duration-plus-nanos #:duration-plus-micros #:duration-plus-millis #:duration-plus-seconds #:duration-plus-minutes #:duration-plus-hours #:duration-plus-days
   #:duration-minus-nanos #:duration-minus-micros #:duration-minus-millis #:duration-minus-seconds #:duration-minus-minutes #:duration-minus-hours #:duration-minus-days
   #:duration-zero-p #:duration-negative-p #:duration-positive-p
   #:duration-compare #:duration= #:duration< #:duration<= #:duration> #:duration>=
   #:duration-to-nanos #:duration-to-millis #:duration-to-micros #:duration-to-minutes #:duration-to-hours #:duration-to-days #:duration-to-seconds
   #:duration-to-days-part #:duration-to-hours-part #:duration-to-minutes-part #:duration-to-seconds-part
   #:duration-to-millis-part #:duration-to-micros-part #:duration-to-nanos-part
   #:duration-truncated-to
   #:duration-between
   ;; Period
   #:make-period #:period-years #:period-months #:period-days
   #:period-of-years #:period-of-months #:period-of-days #:period-of #:period-between
   #:period-with-years #:period-with-months #:period-with-days
   #:period-plus #:period-plus-years #:period-plus-months #:period-plus-days #:period-minus #:period-minus-years #:period-minus-months #:period-minus-days #:period-multiplied-by #:period-abs #:period-to-total-months #:period-zero-p #:period-negative-p #:period-negate #:period= #:period-normalized
   ;; LocalDate
   #:make-local-date #:local-date-year #:local-date-month #:local-date-day #:local-date-of-year-day
   #:local-date-of-week-date #:local-date-week-based-year #:local-date-week-of-week-based-year
   #:local-date-at-time #:local-date-at-start-of-day #:local-date-at-start-of-day-in-zone #:local-date-of-instant
   #:leap-year-p #:length-of-month #:local-date-leap-year-p #:local-date-length-of-month #:local-date-length-of-year #:day-of-week #:day-of-year
   #:local-date-plus-days #:local-date-plus-weeks #:local-date-plus-months #:local-date-plus-years
   #:local-date-minus-days #:local-date-minus-weeks #:local-date-minus-months #:local-date-minus-years
   #:local-date-plus-period #:local-date-minus-period #:local-date-until
   #:local-date-compare #:local-date= #:local-date< #:local-date<= #:local-date> #:local-date>=
   #:local-date-to-epoch-day #:local-date-from-epoch-day
   ;; YearMonth
   #:make-year-month #:year-month-of #:year-month-year #:year-month-month
   #:year-month-from-local-date #:year-month-now #:year-month-to-proleptic-month #:year-month-from-proleptic-month
   #:year-month-length-of-month #:year-month-leap-year-p #:year-month-length-of-year #:year-month-valid-day-p #:year-month-at-day #:year-month-at-end-of-month
   #:year-month-plus-months #:year-month-minus-months #:year-month-plus-years #:year-month-minus-years
   #:year-month-until #:year-month-compare #:year-month= #:year-month< #:year-month<= #:year-month> #:year-month>=
   #:year-month-with-year #:year-month-with-month
   ;; MonthDay
   #:make-month-day #:month-day-of #:month-day-month #:month-day-day
   #:month-day-from-local-date #:month-day-now #:month-day-valid-year-p #:month-day-at-year
   #:month-day-compare #:month-day= #:month-day< #:month-day<= #:month-day> #:month-day>=
   #:month-day-with-month #:month-day-with-day
   ;; Year
   #:make-year #:year-of #:year-value #:year-from-local-date #:year-now #:year-from-year-month
   #:year-leap-p #:year-length #:year-valid-month-day-p #:year-at-month #:year-at-month-day #:year-at-day
   #:year-plus-years #:year-minus-years #:year-until
   #:year-compare #:year= #:year< #:year<= #:year> #:year>=
   ;; LocalTime
   #:make-local-time #:local-time-hour #:local-time-minute #:local-time-second #:local-time-nanosecond
   #:local-time-of-second-of-day #:local-time-of-nano-of-day #:local-time-midnight #:local-time-noon #:local-time-at-date #:local-time-of-instant #:local-time-now
   #:local-time-plus-hours #:local-time-plus-minutes #:local-time-plus-seconds #:local-time-plus-millis #:local-time-plus-micros #:local-time-plus-nanos
   #:local-time-minus-hours #:local-time-minus-minutes #:local-time-minus-seconds #:local-time-minus-millis #:local-time-minus-micros #:local-time-minus-nanos #:local-time-until
   #:local-time-to-second-of-day #:local-time-to-nano-of-day
   #:local-time-compare #:local-time= #:local-time< #:local-time<= #:local-time> #:local-time>=
   ;; LocalDateTime
   #:make-local-date-time #:local-date-time-of #:local-date-time-date #:local-date-time-time
   #:local-date-time-to-epoch-second #:local-date-time-of-epoch-second #:local-date-time-to-instant #:local-date-time-of-instant
   #:local-date-time-year #:local-date-time-month #:local-date-time-day
   #:local-date-time-hour #:local-date-time-minute #:local-date-time-second #:local-date-time-nanosecond
   #:local-date-time-plus-days #:local-date-time-plus-weeks #:local-date-time-plus-months #:local-date-time-plus-years
   #:local-date-time-plus-hours #:local-date-time-plus-minutes #:local-date-time-plus-seconds
   #:local-date-time-plus-millis #:local-date-time-plus-micros #:local-date-time-plus-nanos
   #:local-date-time-minus-days #:local-date-time-minus-months #:local-date-time-minus-years
   #:local-date-time-minus-hours #:local-date-time-minus-minutes #:local-date-time-minus-seconds
   #:local-date-time-minus-millis #:local-date-time-minus-micros
   #:local-date-time-plus-duration #:local-date-time-minus-duration
   #:local-date-time-plus-period #:local-date-time-minus-period #:local-date-time-until
   #:local-date-time-compare #:local-date-time= #:local-date-time< #:local-date-time<= #:local-date-time> #:local-date-time>=
   ;; Instant
   #:make-instant #:instant-epoch-second #:instant-nanosecond #:instant-epoch
   #:instant-of-epoch-nanos #:instant-of-epoch-millis #:instant-of-epoch-micros
   #:instant-to-epoch-nanos #:instant-to-epoch-millis #:instant-to-epoch-micros
   #:instant-plus-nanos #:instant-plus-micros #:instant-plus-millis
   #:instant-plus-seconds #:instant-plus-minutes #:instant-plus-hours
   #:instant-plus-days #:instant-plus-duration
   #:instant-minus-nanos #:instant-minus-micros #:instant-minus-millis
   #:instant-minus-seconds #:instant-minus-minutes #:instant-minus-hours
   #:instant-minus-days #:instant-minus-duration #:instant-until
   #:instant-compare #:instant= #:instant< #:instant<= #:instant> #:instant>=
   ;; Clock
   #:clock-now #:make-system-clock #:make-fixed-clock #:fixed-clock-instant #:instant-now
   #:make-offset-clock #:offset-clock-base-clock #:offset-clock-offset
   #:make-tick-clock #:tick-clock-base-clock #:tick-clock-duration
   ;; Zone
   #:zone-offset-total-seconds #:zone-offset-of-hours #:zone-offset-of-hms #:zone-offset-of-total-seconds
   #:zone-offset-compare #:zone-offset= #:zone-offset< #:zone-offset<= #:zone-offset> #:zone-offset>= #:zone-offset-utc
   #:time-zone-p #:time-zone-name #:find-time-zone
   #:offset-for-instant
   #:zone-transition-p #:zone-transition-instant
   #:zone-transition-offset-before #:zone-transition-offset-after
   #:zone-transition-gap-p #:zone-transition-overlap-p
   #:next-zone-transition #:previous-zone-transition
   #:possible-offsets-for-local-date-time #:possible-offsets-for-local-date-time #:resolve-local-date-time
   ;; ZonedDateTime
   #:zoned-date-time-local #:zoned-date-time-zone #:zoned-date-time-offset
   #:zoned-date-time-of-local #:zoned-date-time-of-instant #:zoned-date-time-to-instant
   #:zoned-date-time-date #:zoned-date-time-time
   #:zoned-date-time-year #:zoned-date-time-month #:zoned-date-time-day
   #:zoned-date-time-hour #:zoned-date-time-minute #:zoned-date-time-second #:zoned-date-time-nanosecond #:zoned-date-time-of-instant #:zoned-date-time-to-instant
   #:zoned-date-time-with-zone-same-instant #:zoned-date-time-with-zone-same-local
   #:zoned-date-time-plus-days #:zoned-date-time-minus-days #:zoned-date-time-plus-weeks #:zoned-date-time-minus-weeks #:zoned-date-time-plus-months #:zoned-date-time-minus-months #:zoned-date-time-plus-years #:zoned-date-time-minus-years #:zoned-date-time-plus-hours #:zoned-date-time-plus-minutes #:zoned-date-time-plus-seconds #:zoned-date-time-plus-millis #:zoned-date-time-plus-micros #:zoned-date-time-plus-nanos #:zoned-date-time-minus-hours #:zoned-date-time-minus-minutes #:zoned-date-time-minus-seconds #:zoned-date-time-minus-millis #:zoned-date-time-minus-micros #:zoned-date-time-minus-nanos #:zoned-date-time-plus-duration #:zoned-date-time-minus-duration
   #:zoned-date-time-plus-period #:zoned-date-time-minus-period #:zoned-date-time-until
   #:zoned-date-time-compare #:zoned-date-time= #:zoned-date-time< #:zoned-date-time<= #:zoned-date-time> #:zoned-date-time>=
   #:local-date-now #:local-date-time-now #:zoned-date-time-now
   ;; OffsetTime
   #:make-offset-time #:offset-time-of #:offset-time-of-instant
   #:offset-time-local-time #:offset-time-offset #:offset-date-time-offset #:offset-time-time
   #:offset-time-hour #:offset-time-minute #:offset-time-second #:offset-time-nanosecond
   #:offset-time-with-offset-same-instant #:offset-time-with-offset-same-local
   #:offset-time-plus-hours #:offset-time-plus-minutes #:offset-time-plus-seconds #:offset-time-plus-millis #:offset-time-plus-micros #:offset-time-plus-nanos #:offset-time-minus-hours #:offset-time-minus-minutes #:offset-time-minus-seconds #:offset-time-minus-millis #:offset-time-minus-micros #:offset-time-minus-nanos #:offset-time-plus-duration #:offset-time-minus-duration #:offset-time-until
   #:offset-time-compare #:offset-time= #:offset-time< #:offset-time<= #:offset-time> #:offset-time>= #:offset-time-now
   ;; ISO-8601
   #:format-local-date #:parse-local-date #:format-local-date-ordinal #:parse-local-date-ordinal
   #:format-year-month #:parse-year-month
   #:format-month-day #:parse-month-day
   #:format-year #:parse-year
   #:format-local-date-week-date #:parse-local-date-week-date #:format-local-time #:parse-local-time
   #:format-local-date-time #:parse-local-date-time #:format-instant #:parse-instant
   #:format-offset-time #:parse-offset-time
   #:format-zoned-date-time #:parse-zoned-date-time
   #:format-duration #:parse-duration #:format-period #:parse-period
   ;; Pattern formatting
   #:make-date-time-formatter #:format-date-time #:format-date-time-with-pattern #:parse-date-time #:parse-date-time-with-pattern
   ;; Conditions
   #:invalid-date #:invalid-year-month #:invalid-year #:invalid-month-day #:invalid-time #:invalid-zone-offset #:date-time-parse-error #:date-time-format-error
   #:time-zone-not-found #:malformed-tzif #:nonexistent-local-time #:ambiguous-local-time)
  (:export #:run-tests))

;;;; t/package.lisp
(in-package #:cl-date-kit/test)

(defun run-tests ()
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP fails."
  (unless (run-all :reporter :spec :timeout-ms 20000)
    (error "cl-date-kit test suite failed"))
  (format t "~&cl-date-kit/test: successful completion with 0 failures~%")
  t)

;;;; t/package.lisp
