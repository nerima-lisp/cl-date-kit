;;; This form comes FIRST, before any defsystem. ASDF binds *package* to
;;; ASDF-USER only for a file it loads itself; read any other way -- a REPL
;;; `load`, an editor evaluating the buffer, flake.nix parsing :version -- the
;;; file is read in whatever package happens to be current. Saying it makes
;;; the file self-contained.
(in-package #:asdf-user)

(asdf:defsystem "cl-date-kit"
  :description "Dependency-free, SBCL-only date/time library with IANA time zone support"
  :long-description "cl-date-kit builds calendar and clock values with IANA time zone support and ISO 8601 parsing."
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "1.0.0"
  :homepage "https://github.com/nerima-lisp/cl-date-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-date-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-date-kit.git")
  :depends-on ()
  :pathname "src"
  :serial t
  :components ((:file "package")
    (:file "macros")
    (:file "conditions")
    (:file "duration")
    (:file "period")
    (:file "local-date")
    (:file "local-date-arithmetic")
    (:file "local-date-week")
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
     (:file "zone-version")
     (:file "zone-local")
     (:file "offset-time")
   (:file "zoned-date-time")
   (:file "zoned-date-time-arithmetic")
   (:file "rrule")
   (:file "rrule-codec")
   (:file "rrule-date-selection")
   (:file "rrule-candidates")
   (:file "rrule-occurrences")
   (:file "rrule-set")
   (:file "offset-date-time")
    (:file "iso8601-date")
    (:file "iso8601-year-month-day")
    (:file "iso8601")
    (:file "iso8601-offset")
    (:file "iso8601-amounts")
    (:file "locale")
    (:file "pattern")
    (:file "pattern-builder")
    (:file "pattern-parser"))
  :in-order-to ((asdf:test-op (asdf:test-op "cl-date-kit/test"))))

;;; The test system is `cl-date-kit/test` (singular, slash-separated) with
;;; :pathname "t". It is NOT `cl-date-kit-test`.
(asdf:defsystem "cl-date-kit/test"
  :description "Test system for cl-date-kit"
  :author "takeokunn <bararararatty@gmail.com>"
  :maintainer "takeokunn <bararararatty@gmail.com>"
  :license "MIT"
  :version "1.0.0"
  :homepage "https://github.com/nerima-lisp/cl-date-kit"
  :bug-tracker "https://github.com/nerima-lisp/cl-date-kit/issues"
  :source-control (:git "https://github.com/nerima-lisp/cl-date-kit.git")
  :depends-on ("cl-date-kit" (:version "cl-weave" "1.3.0"))
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
   (:file "zone-database-test")
   (:file "zone-transition-test")
   (:file "zone-state-test")
   (:file "posix-tz-test")
   (:file "zoned-date-time-test")
   (:file "zoned-date-time-arithmetic-test")
   (:file "rrule-test")
   (:file "rrule-occurrences-test")
   (:file "rrule-schedule-test")
   (:file "rrule-set-test")
   (:file "offset-date-time-test")
    (:file "offset-time-test")
    (:file "iso8601-test")
    (:file "iso8601-offset-test")
    (:file "locale-test")
    (:file "pattern-test"))
  :perform (asdf:test-op
    (operation component)
    (declare (ignore operation component))
    (unless (funcall (symbol-function (find-symbol "RUN-TESTS" "CL-DATE-KIT/TEST")))
      (error "cl-date-kit test suite failed"))))
