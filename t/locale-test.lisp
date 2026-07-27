;;;; t/locale-test.lisp
(in-package #:cl-date-kit/test)

(describe "DateTimeLocale"
  (it "formats with custom locale data after defensively copying it"
    (let* ((short-months (make-array 12 :initial-element "SM"))
           (months (make-array 12 :initial-element "MONTH"))
           (short-weekdays (make-array 7 :initial-element "SW"))
           (weekdays (make-array 7 :initial-element "WEEKDAY"))
           (locale (make-date-time-locale
                    :name :test
                    :short-months short-months
                    :months months
                    :short-weekdays short-weekdays
                    :weekdays weekdays
                    :am "before noon"
                    :pm "after noon")))
      (setf (aref months 1) "MUTATED")
      (expect
        (format-date-time-with-pattern
         "EEEE MMMM a" (local-date-time-of 2024 2 29 7 0 0) :locale locale)
        :to-equal
        "WEEKDAY MONTH before noon")))
  (it "rejects incomplete or malformed locale data"
    (signals type-error
      (make-date-time-locale
       :name nil :short-months #() :months #() :short-weekdays #()
       :weekdays #() :am "AM" :pm "PM"))
    (signals type-error
      (make-date-time-locale
       :name :bad :short-months #() :months #() :short-weekdays #()
       :weekdays #() :am "AM" :pm "PM"))
    (signals type-error
      (make-date-time-locale
       :name :bad :short-months (make-array 12 :initial-element "M")
       :months (make-array 12 :initial-element "M")
       :short-weekdays (make-array 7 :initial-element "W")
       :weekdays (make-array 7 :initial-element "W") :am "" :pm "PM"))))
