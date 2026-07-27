;;;; cl-date-kit.asd
(asdf:defsystem "cl-date-kit"
  :description "Dependency-free, SBCL-only date/time library with IANA time zone support, inspired by java.time, chrono, and Temporal"
  :long-description "cl-date-kit builds modern calendar and clock values with IANA time zone support and ISO 8601 parsing."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-date-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-date-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-date-kit.git")
  :depends-on ()
  :pathname "src"
  :serial t
  :components ((:file "package")
    (:file "conditions")
    (:file "duration")
    (:file "period")
    (:file "local-date")
    (:file "month")
    (:file "year-month")
    (:file "month-day")
    (:file "year")
    (:file "local-time")
    (:file "local-date-time")
    (:file "instant")
    (:file "interval")
    (:file "clock")
    (:file "tzif")
    (:file "zone-offset")
    (:file "posix-tz")
    (:file "zone")
    (:file "offset-time")
    (:file "zoned-date-time")
    (:file "offset-date-time")
    (:file "iso8601-date")
    (:file "iso8601")
    (:file "pattern"))
  :in-order-to ((test-op (test-op "cl-date-kit/test"))))

;;; The test system is `cl-date-kit/test` (singular, slash-separated) with
;;; :pathname "t". It is NOT `cl-date-kit-test`.
(asdf:defsystem "cl-date-kit/test"
  :description "Test system for cl-date-kit"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/nerima-lisp/cl-date-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-date-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-date-kit.git")
  :depends-on ("cl-date-kit" "cl-weave")
  :pathname "t"
  :serial t
  :components ((:file "package")
    (:file "duration-test")
    (:file "period-test")
    (:file "local-date-test")
    (:file "month-test")
    (:file "year-month-test")
    (:file "month-day-test")
    (:file "year-test")
    (:file "local-time-test")
    (:file "local-date-time-test")
    (:file "instant-test")
    (:file "interval-test")
    (:file "clock-test")
    (:file "zone-test")
    (:file "zoned-date-time-test")
    (:file "offset-date-time-test")
    (:file "offset-time-test")
    (:file "iso8601-test")
    (:file "pattern-test"))
  :perform (test-op
    (operation component)
    (declare (ignore operation component))
    (unless (funcall (symbol-function (find-symbol "RUN-TESTS" "CL-DATE-KIT/TEST")))
      (error "cl-date-kit test suite failed"))))
