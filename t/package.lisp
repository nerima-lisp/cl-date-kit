;;;; t/package.lisp
;;;; t/package.lisp
(defpackage #:cl-date-kit/test
  (:use #:cl #:cl-date-kit)
  ;; DESCRIBE clashes with CL:DESCRIBE; nothing else needs shadowing.
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:it #:expect #:signals #:run-all #:it-each #:it-property #:gen-integer
   #:before-each #:it-run-if)
  (:import-from #:cl-date-kit #:with-clock)
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
