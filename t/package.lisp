(defpackage #:cl-date-kit/test
  (:use #:cl #:cl-date-kit)
  ;; DESCRIBE clashes with CL:DESCRIBE; nothing else needs shadowing.
  (:shadowing-import-from #:cl-weave #:describe)
  (:import-from #:cl-weave
   #:it #:expect #:signals #:run-all #:it-each #:it-property #:gen-integer
   #:before-each #:it-run-if)
  (:import-from #:cl-date-kit #:with-clock)
  (:export #:run-tests))

(in-package #:cl-date-kit/test)

(defun run-tests ()
  "Run every registered spec, signalling on any failure so ASDF's TEST-OP fails."
  (unless (run-all :reporter :spec :timeout-ms 20000)
    (error "cl-date-kit test suite failed"))
  (format t "~&cl-date-kit/test: successful completion with 0 failures~%")
  t)
(defun %zoneinfo-database-available-p ()
  (some #'probe-file
        (cl-date-kit::%candidate-zoneinfo-paths "UTC")))
(progn
  (defmacro it-needs-zoneinfo (description &body body)
    `(it-run-if
       (%zoneinfo-database-available-p)
       ,description
       ,@body))
  (defmacro it-each-needs-zoneinfo (&rest arguments)
    (let ((expanded (macroexpand-1 `(it-each ,@arguments))))
      (unless (and (consp expanded) (eq (car expanded) 'progn))
        (error "Unexpected IT-EACH expansion"))
      `(progn
         ,@(mapcar
             (lambda (spec)
               (unless (and (consp spec) (eq (car spec) 'cl-weave:it))
                 (error "Unexpected IT-EACH spec: ~S" spec))
               `(it-needs-zoneinfo ,@(cdr spec)))
             (cdr expanded))))))
