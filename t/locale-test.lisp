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
       :weekdays (make-array 7 :initial-element "W") :am "" :pm "PM")))
  (it "copies mutable locale strings"
    (let* ((month-name (copy-seq "MONTH"))
           (am (copy-seq "morning"))
           (locale (make-date-time-locale
                    :name :mutable-strings
                    :short-months (make-array 12 :initial-element "SM")
                    :months (make-array 12 :initial-element month-name)
                    :short-weekdays (make-array 7 :initial-element "SW")
                    :weekdays (make-array 7 :initial-element "WEEKDAY")
                    :am am
                    :pm "afternoon")))
      (setf (char month-name 0) #\X
            (char am 0) #\X)
      (expect
        (format-date-time-with-pattern
         "MMMM a" (local-date-time-of 2024 2 29 7 0 0) :locale locale)
        :to-equal
        "MONTH morning")))
  (it "resolves bundled locales and preserves supplied locales"
    (let ((locale (find-date-time-locale :en)))
      (expect (date-time-locale-name locale) :to-be :en)
      (expect (date-time-locale-name (find-date-time-locale :ja)) :to-be :ja)
      (expect (eq (find-date-time-locale locale) locale) :to-be-truthy))
    (signals date-time-format-error
      (find-date-time-locale :unknown))))
