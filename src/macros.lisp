;;;; Loaded before CONDITIONS in the serial system, so these macros cannot
;;;; depend on values or structure types defined by later files.
(in-package #:cl-date-kit)

(defmacro define-ordering-operators (type-name compare-function)
  "Define TYPE-NAME=, TYPE-NAME<, TYPE-NAME<=, TYPE-NAME>, and TYPE-NAME>= in
terms of the three-way COMPARE-FUNCTION, which must return a negative, zero,
or positive integer as its first argument is less than, equal to, or greater
than its second."
  (flet ((operator-name (suffix) (intern (format nil "~A~A" type-name suffix))))
    `(progn
       (defun ,(operator-name "=") (a b) (zerop (,compare-function a b)))
       (defun ,(operator-name "<") (a b) (minusp (,compare-function a b)))
       (defun ,(operator-name "<=") (a b) (not (plusp (,compare-function a b))))
       (defun ,(operator-name ">") (a b) (plusp (,compare-function a b)))
       (defun ,(operator-name ">=") (a b) (not (minusp (,compare-function a b)))))))

(defmacro define-fixed-unit-arithmetic
    (plus-name
      minus-name
      amount-var
      seconds-factor
      nanos-factor
      delegate-function
      &key
      plus-documentation
      minus-documentation)
  "Define PLUS-NAME/MINUS-NAME as a signed step of AMOUNT-VAR fixed units,
each unit worth SECONDS-FACTOR seconds and NANOS-FACTOR nanoseconds, applied
by calling DELEGATE-FUNCTION with (VALUE seconds nanos). DELEGATE-FUNCTION
must normalize/carry seconds and nanos itself; this macro only negates and
scales AMOUNT-VAR for the minus case."
  `(progn
     (defun ,plus-name (value ,amount-var)
       ,@(when plus-documentation (list plus-documentation))
       (check-type ,amount-var integer)
       (,delegate-function value (* ,amount-var ,seconds-factor) (* ,amount-var ,nanos-factor)))
     (defun ,minus-name (value ,amount-var)
       ,@(when minus-documentation (list minus-documentation))
       (check-type ,amount-var integer)
       (,delegate-function
         value
         (* (- ,amount-var) ,seconds-factor)
         (* (- ,amount-var) ,nanos-factor)))))

(defmacro define-period-fixed-component-arithmetic
    (plus-name minus-name amount component-constructor plus-documentation minus-documentation)
  "Define PLUS-NAME/MINUS-NAME as PERIOD-PLUS/PERIOD-MINUS of a period built
from integral AMOUNT by COMPONENT-CONSTRUCTOR (e.g. PERIOD-OF-YEARS)."
  `(progn
     (defun ,plus-name (period ,amount)
       ,plus-documentation
       (period-plus period (,component-constructor ,amount)))
     (defun ,minus-name (period ,amount)
       ,minus-documentation
       (period-minus period (,component-constructor ,amount)))))

(defmacro define-date-kit-condition (name slots report-control &optional documentation)
  "Define NAME as a CL-DATE-KIT-ERROR subcondition with one slot per entry in
SLOTS (each an unevaluated symbol, given a :READER of NAME-SLOT and a
same-named :INITARG keyword) and a :REPORT that applies REPORT-CONTROL via
FORMAT to each slot's reader value, in SLOTS order."
  (let ((readers (mapcar (lambda (slot) (intern (format nil "~A-~A" name slot))) slots)))
    `(define-condition ,name (cl-date-kit-error)
       ,(mapcar
          (lambda (slot reader)
            `(,slot :initarg ,(intern (symbol-name slot) :keyword) :reader ,reader))
          slots
          readers)
       (:report
         (lambda (condition stream)
           (format stream ,report-control ,@(mapcar (lambda (reader) `(,reader condition)) readers))))
       ,@(when documentation (list `(:documentation ,documentation))))))
