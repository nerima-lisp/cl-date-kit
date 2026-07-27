(in-package #:cl-date-kit/test)

(describe "interval construction" (it "accepts an empty interval and reports its exact duration" (let ((interval (cl-date-kit:make-interval (make-instant 12 34) (make-instant 12 34)))) (expect (cl-date-kit:interval-empty-p interval) :to-be-truthy) (expect (duration= (cl-date-kit:interval-duration interval) (duration-zero)) :to-be-truthy))) (it "rejects an end before the start" (signals cl-date-kit:invalid-interval (cl-date-kit:make-interval (make-instant 2) (make-instant 1)))))

(describe
  "interval membership"
  (it
    "uses half-open bounds"
    (let ((interval (cl-date-kit:make-interval (make-instant 10) (make-instant 20))))
      (expect
        (cl-date-kit:interval-contains-p interval (make-instant 10))
        :to-be-truthy)
      (expect
        (cl-date-kit:interval-contains-p interval (make-instant 19 999999999))
        :to-be-truthy)
      (expect
        (cl-date-kit:interval-contains-p interval (make-instant 20))
        :to-be-falsy)))
  (it
    "encloses an interval whose end matches its end"
    (let ((outer (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
          (inner (cl-date-kit:make-interval (make-instant 2) (make-instant 10))))
      (expect (cl-date-kit:interval-encloses-p outer inner) :to-be-truthy))))

(describe
  "interval relations"
  (it
    "distinguishes overlap from abutment"
    (let ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
          (overlap (cl-date-kit:make-interval (make-instant 5) (make-instant 15)))
          (abutting (cl-date-kit:make-interval (make-instant 10) (make-instant 20))))
      (expect (cl-date-kit:interval-overlaps-p a overlap) :to-be-truthy)
      (expect (cl-date-kit:interval-abuts-p a overlap) :to-be-falsy)
      (expect (cl-date-kit:interval-overlaps-p a abutting) :to-be-falsy)
      (expect (cl-date-kit:interval-abuts-p a abutting) :to-be-truthy)))
  (it
    "returns an intersection only when ranges overlap"
    (let* ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
           (b (cl-date-kit:make-interval (make-instant 5) (make-instant 15)))
           (intersection (cl-date-kit:interval-intersection a b)))
      (expect intersection :to-be-truthy)
      (expect
        (instant= (cl-date-kit:interval-start intersection) (make-instant 5))
        :to-be-truthy)
      (expect
        (instant= (cl-date-kit:interval-end intersection) (make-instant 10))
        :to-be-truthy)
      (expect
        (cl-date-kit:interval-intersection
          a
          (cl-date-kit:make-interval (make-instant 10) (make-instant 20)))
        :to-be-falsy))))

(describe
  "interval spans, gaps, and unions"
  (it
    "spans separated ranges and returns their separating interval"
    (let* ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
           (b (cl-date-kit:make-interval (make-instant 20) (make-instant 30)))
           (span (cl-date-kit:interval-span a b))
           (gap (cl-date-kit:interval-gap a b)))
      (expect
        (instant= (cl-date-kit:interval-start span) (make-instant 0))
        :to-be-truthy)
      (expect
        (instant= (cl-date-kit:interval-end span) (make-instant 30))
        :to-be-truthy)
      (expect gap :to-be-truthy)
      (expect
        (instant= (cl-date-kit:interval-start gap) (make-instant 10))
        :to-be-truthy)
      (expect
        (instant= (cl-date-kit:interval-end gap) (make-instant 20))
        :to-be-truthy)))
  (it
    "has no gap for touching or overlapping ranges"
    (let ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
          (b (cl-date-kit:make-interval (make-instant 10) (make-instant 20)))
          (c (cl-date-kit:make-interval (make-instant 5) (make-instant 15))))
      (expect (cl-date-kit:interval-gap a b) :to-be-falsy)
      (expect (cl-date-kit:interval-gap a c) :to-be-falsy)))
  (it
    "unions overlapping and abutting ranges"
    (dolist
      (pair
        (list
          (list
            (cl-date-kit:make-interval (make-instant 0) (make-instant 15))
            (cl-date-kit:make-interval (make-instant 5) (make-instant 20)))
          (list
            (cl-date-kit:make-interval (make-instant 10) (make-instant 20))
            (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))))
      (let ((union (cl-date-kit:interval-union (first pair) (second pair))))
        (expect union :to-be-truthy)
        (expect
          (instant= (cl-date-kit:interval-start union) (make-instant 0))
          :to-be-truthy)
        (expect
          (instant= (cl-date-kit:interval-end union) (make-instant 20))
          :to-be-truthy))))
  (it
    "does not bridge a positive gap and retains contained empty intervals"
    (let ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
          (separated (cl-date-kit:make-interval (make-instant 11) (make-instant 20)))
          (empty (cl-date-kit:make-interval (make-instant 5) (make-instant 5))))
      (expect (cl-date-kit:interval-union a separated) :to-be-falsy)
      (let ((union (cl-date-kit:interval-union a empty)))
        (expect
          (instant= (cl-date-kit:interval-start union) (make-instant 0))
          :to-be-truthy)
        (expect
          (instant= (cl-date-kit:interval-end union) (make-instant 10))
          :to-be-truthy)))))

(describe
  "interval boundary replacement"
  (it
    "returns new intervals without modifying the source interval"
    (let* ((interval (cl-date-kit:make-interval (make-instant 10) (make-instant 20)))
           (with-start (cl-date-kit:interval-with-start interval (make-instant 12)))
           (with-end (cl-date-kit:interval-with-end interval (make-instant 18))))
      (expect (instant= (cl-date-kit:interval-start interval) (make-instant 10)) :to-be-truthy)
      (expect (instant= (cl-date-kit:interval-end interval) (make-instant 20)) :to-be-truthy)
      (expect (instant= (cl-date-kit:interval-start with-start) (make-instant 12)) :to-be-truthy)
      (expect (instant= (cl-date-kit:interval-end with-start) (make-instant 20)) :to-be-truthy)
      (expect (instant= (cl-date-kit:interval-start with-end) (make-instant 10)) :to-be-truthy)
      (expect (instant= (cl-date-kit:interval-end with-end) (make-instant 18)) :to-be-truthy)))
  (it
    "retains interval validation"
    (let ((interval (cl-date-kit:make-interval (make-instant 10) (make-instant 20))))
      (signals cl-date-kit:invalid-interval
        (cl-date-kit:interval-with-start interval (make-instant 21)))
      (signals cl-date-kit:invalid-interval
        (cl-date-kit:interval-with-end interval (make-instant 9))))))

(describe
  "interval difference"
  (it
    "splits an interval when removal is strictly inside"
    (let* ((interval (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
           (removed (cl-date-kit:make-interval (make-instant 3) (make-instant 7)))
           (parts (cl-date-kit:interval-difference interval removed)))
      (expect
        (mapcar (lambda (part) (cl-date-kit:instant-epoch-second (cl-date-kit:interval-start part))) parts)
        :to-equal (list 0 7))
      (expect
        (mapcar (lambda (part) (cl-date-kit:instant-epoch-second (cl-date-kit:interval-end part))) parts)
        :to-equal (list 3 10))))
  (it
    "keeps a non-empty source interval for disjoint, empty, or abutting removal"
    (let ((interval (cl-date-kit:make-interval (make-instant 0) (make-instant 10))))
      (dolist (removed (list
                         (cl-date-kit:make-interval (make-instant 10) (make-instant 20))
                         (cl-date-kit:make-interval (make-instant 3) (make-instant 3))
                         (cl-date-kit:make-interval (make-instant 20) (make-instant 30))))
        (let ((parts (cl-date-kit:interval-difference interval removed)))
          (expect (length parts) :to-equal 1)
          (expect (instant= (cl-date-kit:interval-start (first parts)) (make-instant 0)) :to-be-truthy)
          (expect (instant= (cl-date-kit:interval-end (first parts)) (make-instant 10)) :to-be-truthy)))))
  (it
    "returns no empty intervals after complete or boundary-aligned removal"
    (let ((interval (cl-date-kit:make-interval (make-instant 0) (make-instant 10))))
      (expect
        (cl-date-kit:interval-difference interval (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
        :to-equal (list))
      (expect
        (cl-date-kit:interval-difference
          (cl-date-kit:make-interval (make-instant 3) (make-instant 3))
          interval)
        :to-equal (list))
      (let ((parts
              (cl-date-kit:interval-difference interval (cl-date-kit:make-interval (make-instant 0) (make-instant 5)))))
        (expect (length parts) :to-equal 1)
        (expect (instant= (cl-date-kit:interval-start (first parts)) (make-instant 5)) :to-be-truthy)
        (expect (instant= (cl-date-kit:interval-end (first parts)) (make-instant 10)) :to-be-truthy)))))
