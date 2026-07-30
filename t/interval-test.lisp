(in-package #:cl-date-kit/test)

(describe "interval construction"
  (it "accepts an empty interval and reports its exact duration"
    (let ((interval (cl-date-kit:make-interval (make-instant 12 34)
                                                (make-instant 12 34))))
      (expect (cl-date-kit:interval-empty-p interval) :to-be-truthy)
      (expect (duration= (cl-date-kit:interval-duration interval) (duration-zero)) :to-be-truthy)))
  (it "rejects an end before the start"
    (signals cl-date-kit:invalid-interval
      (cl-date-kit:make-interval (make-instant 2) (make-instant 1))))
  (it "validates instant endpoint types"
    (let ((instant (make-instant 0)))
      (signals type-error
        (cl-date-kit:make-interval 0 instant))
      (signals type-error
        (cl-date-kit:make-interval instant 0)))))

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
    "classifies connected, preceding, and following intervals at their boundaries"
    (let ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
          (abutting (cl-date-kit:make-interval (make-instant 10) (make-instant 20)))
          (separated (cl-date-kit:make-interval (make-instant 11) (make-instant 20))))
      (expect (cl-date-kit:interval-connected-p a abutting) :to-be-truthy)
      (expect (cl-date-kit:interval-connected-p a separated) :to-be-falsy)
      (expect (cl-date-kit:interval-before-p a abutting) :to-be-truthy)
      (expect (cl-date-kit:interval-before-p a separated) :to-be-truthy)
      (expect (cl-date-kit:interval-after-p abutting a) :to-be-truthy)
      (expect (cl-date-kit:interval-after-p separated a) :to-be-truthy)
      (expect (cl-date-kit:interval-before-p abutting a) :to-be-falsy)
      (expect (cl-date-kit:interval-after-p a abutting) :to-be-falsy)))
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
    "spans separated ranges and returns their separating interval in either order"
    (let* ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
           (b (cl-date-kit:make-interval (make-instant 20) (make-instant 30)))
           (span (cl-date-kit:interval-span a b))
           (gap (cl-date-kit:interval-gap a b))
           (reverse-gap (cl-date-kit:interval-gap b a)))
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
        :to-be-truthy)
      (expect reverse-gap :to-be-truthy)
      (expect
        (instant= (cl-date-kit:interval-start reverse-gap) (make-instant 10))
        :to-be-truthy)
      (expect
        (instant= (cl-date-kit:interval-end reverse-gap) (make-instant 20))
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
    "does not bridge a positive gap and retains empty intervals at every boundary"
    (let ((a (cl-date-kit:make-interval (make-instant 0) (make-instant 10)))
          (separated (cl-date-kit:make-interval (make-instant 11) (make-instant 20)))
          (interior-empty (cl-date-kit:make-interval (make-instant 5) (make-instant 5)))
          (start-empty (cl-date-kit:make-interval (make-instant 0) (make-instant 0)))
          (end-empty (cl-date-kit:make-interval (make-instant 10) (make-instant 10))))
      (expect (cl-date-kit:interval-union a separated) :to-be-falsy)
      (dolist (empty (list interior-empty start-empty end-empty))
        (let ((union (cl-date-kit:interval-union a empty)))
          (expect
            (instant= (cl-date-kit:interval-start union) (make-instant 0))
            :to-be-truthy)
          (expect
            (instant= (cl-date-kit:interval-end union) (make-instant 10))
            :to-be-truthy))))))

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

(progn
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
      (dolist (removed (list
                         (cl-date-kit:make-interval (make-instant 0) (make-instant 5))
                         (cl-date-kit:make-interval (make-instant 5) (make-instant 10))))
        (let ((parts (cl-date-kit:interval-difference interval removed)))
          (expect (length parts) :to-equal 1)))
      (let ((left-parts
              (cl-date-kit:interval-difference interval (cl-date-kit:make-interval (make-instant 0) (make-instant 5))))
            (right-parts
              (cl-date-kit:interval-difference interval (cl-date-kit:make-interval (make-instant 5) (make-instant 10)))))
        (expect (instant= (cl-date-kit:interval-start (first left-parts)) (make-instant 5)) :to-be-truthy)
        (expect (instant= (cl-date-kit:interval-end (first left-parts)) (make-instant 10)) :to-be-truthy)
        (expect (instant= (cl-date-kit:interval-start (first right-parts)) (make-instant 0)) :to-be-truthy)
        (expect (instant= (cl-date-kit:interval-end (first right-parts)) (make-instant 5)) :to-be-truthy)))))
(describe
  "local-date intervals"
  (it
    "uses half-open calendar bounds and counts leap days"
    (flet ((date (month day) (cl-date-kit:make-local-date 2024 month day)))
      (let ((interval (cl-date-kit:make-local-date-interval (date 2 28) (date 3 1))))
        (expect (cl-date-kit:local-date-interval-contains-p interval (date 2 28)) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-contains-p interval (date 2 29)) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-contains-p interval (date 3 1)) :to-be-falsy)
        (expect (cl-date-kit:local-date-interval-length-in-days interval) :to-equal 2))))
  (it
  "accepts empty intervals, rejects reversed bounds, and validates types"
  (flet ((date (day) (cl-date-kit:make-local-date 2024 1 day)))
    (let ((interval (cl-date-kit:make-local-date-interval (date 1) (date 2))))
      (expect (cl-date-kit:local-date-interval-empty-p
               (cl-date-kit:make-local-date-interval (date 2) (date 2)))
              :to-be-truthy)
      (signals cl-date-kit:invalid-interval
        (cl-date-kit:make-local-date-interval (date 3) (date 2)))
      (signals type-error
        (cl-date-kit:make-local-date-interval 0 (date 2)))
      (signals type-error
        (cl-date-kit:make-local-date-interval (date 1) 0))
      (signals type-error
        (cl-date-kit:local-date-interval-contains-p interval 0)))))
  (it
  "computes overlap, union, gap, and difference as date sets"
  (flet ((date (day) (cl-date-kit:make-local-date 2024 1 day)))
    (let* ((a (cl-date-kit:make-local-date-interval (date 1) (date 5)))
           (overlap (cl-date-kit:make-local-date-interval (date 3) (date 7)))
           (abutting (cl-date-kit:make-local-date-interval (date 5) (date 7)))
           (separated (cl-date-kit:make-local-date-interval (date 7) (date 9)))
           (start-empty (cl-date-kit:make-local-date-interval (date 1) (date 1)))
           (end-empty (cl-date-kit:make-local-date-interval (date 5) (date 5)))
           (intersection (cl-date-kit:local-date-interval-intersection a overlap))
           (difference (cl-date-kit:local-date-interval-difference a overlap)))
      (expect (cl-date-kit:local-date-interval-overlaps-p a overlap) :to-be-truthy)
      (expect (cl-date-kit:local-date-interval-overlaps-p a abutting) :to-be-falsy)
      (expect (cl-date-kit:local-date-interval-union a abutting) :to-be-truthy)
      (expect (cl-date-kit:local-date-interval-union a separated) :to-be-falsy)
      (dolist (empty (list start-empty end-empty))
        (let ((union (cl-date-kit:local-date-interval-union a empty)))
          (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-start union)) :to-equal 1)
          (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-end union)) :to-equal 5)))
      (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-start intersection)) :to-equal 3)
      (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-end intersection)) :to-equal 5)
      (dolist (gap (list (cl-date-kit:local-date-interval-gap a separated)
                         (cl-date-kit:local-date-interval-gap separated a)))
        (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-start gap)) :to-equal 5)
        (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-end gap)) :to-equal 7))
      (expect (mapcar (lambda (part)
                        (cl-date-kit:local-date-day
                         (cl-date-kit:local-date-interval-start part)))
                      difference)
              :to-equal (list 1))
      (expect (mapcar (lambda (part)
                        (cl-date-kit:local-date-day
                         (cl-date-kit:local-date-interval-end part)))
                      difference)
              :to-equal (list 3))))))
  (it
    "classifies enclosure and relations at boundaries, including empty intervals"
    (flet ((date (day) (cl-date-kit:make-local-date 2024 1 day)))
      (let ((outer (cl-date-kit:make-local-date-interval (date 1) (date 5)))
            (inner (cl-date-kit:make-local-date-interval (date 2) (date 5)))
            (abutting (cl-date-kit:make-local-date-interval (date 5) (date 7)))
            (separated (cl-date-kit:make-local-date-interval (date 6) (date 7)))
            (empty (cl-date-kit:make-local-date-interval (date 5) (date 5))))
        (expect (cl-date-kit:local-date-interval-encloses-p outer inner) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-encloses-p outer empty) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-abuts-p outer abutting) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-abuts-p outer empty) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-connected-p outer abutting) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-connected-p outer separated) :to-be-falsy)
        (expect (cl-date-kit:local-date-interval-before-p outer abutting) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-after-p abutting outer) :to-be-truthy)
        (expect (cl-date-kit:local-date-interval-before-p abutting outer) :to-be-falsy)
        (expect (cl-date-kit:local-date-interval-after-p outer abutting) :to-be-falsy))))
  (it
    "replaces bounds without mutating and retains interval validation"
    (flet ((date (day) (cl-date-kit:make-local-date 2024 1 day)))
      (let* ((interval (cl-date-kit:make-local-date-interval (date 1) (date 5)))
             (with-start (cl-date-kit:local-date-interval-with-start interval (date 2)))
             (with-end (cl-date-kit:local-date-interval-with-end interval (date 4)))
             (empty (cl-date-kit:local-date-interval-with-start interval (date 5))))
        (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-start interval)) :to-equal 1)
        (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-end interval)) :to-equal 5)
        (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-start with-start)) :to-equal 2)
        (expect (cl-date-kit:local-date-day (cl-date-kit:local-date-interval-end with-end)) :to-equal 4)
        (expect (cl-date-kit:local-date-interval-empty-p empty) :to-be-truthy)
        (signals cl-date-kit:invalid-interval
          (cl-date-kit:local-date-interval-with-start interval (date 6)))
        (signals cl-date-kit:invalid-interval
          (cl-date-kit:local-date-interval-with-end
           (cl-date-kit:make-local-date-interval (date 2) (date 5))
           (date 1))))))
)

(describe "local-date interval iteration"
  (flet ((date (month day)
           (cl-date-kit:make-local-date 2024 month day)))
    (it "does not invoke callbacks for empty intervals"
      (let ((seen (list)))
        (expect
         (cl-date-kit:map-local-date-interval
          (lambda (current)
            (push (cl-date-kit:local-date-day current) seen)
            t)
          (cl-date-kit:make-local-date-interval (date 1 1) (date 1 1)))
         :to-be-falsy)
        (expect seen :to-equal (list))))
    (it "visits a one-day interval"
      (let ((seen (list)))
        (expect
         (cl-date-kit:map-local-date-interval
          (lambda (current)
            (push (cl-date-kit:local-date-day current) seen)
            t)
          (cl-date-kit:make-local-date-interval (date 1 1) (date 1 2)))
         :to-be-falsy)
        (expect seen :to-equal (list 1))))
    (it "visits half-open intervals once in ascending order"
      (let* ((seen (list))
             (result
               (cl-date-kit:map-local-date-interval
                (lambda (current)
                  (push (cl-date-kit:local-date-day current) seen)
                  t)
                (cl-date-kit:make-local-date-interval (date 2 28) (date 3 2)))))
        (expect (nreverse seen) :to-equal (list 28 29 1))
        (expect result :to-be-falsy)))
    (it "stops when the callback returns NIL"
      (let ((seen (list)))
        (expect
         (cl-date-kit:map-local-date-interval
          (lambda (current)
            (push (cl-date-kit:local-date-day current) seen)
            nil)
          (cl-date-kit:make-local-date-interval (date 1 1) (date 1 2)))
         :to-be-falsy)
        (expect seen :to-equal (list 1))))
    (it "supports a normal-completion result in its DO macro"
      (let* ((seen (list))
             (result
               (cl-date-kit:do-local-date-interval
                   (current
                    (cl-date-kit:make-local-date-interval (date 1 1) (date 1 3))
                    :result :completed)
                 (push (cl-date-kit:local-date-day current) seen))))
        (expect (nreverse seen) :to-equal (list 1 2))
        (expect result :to-equal :completed)))
    (it "propagates RETURN from its DO macro"
      (let ((seen (list)))
        (expect
          (cl-date-kit:do-local-date-interval
              (current
                (cl-date-kit:make-local-date-interval (date 1 1) (date 1 4))
                :result :completed)
            (let ((day (cl-date-kit:local-date-day current)))
              (push day seen)
              (when (= day 2)
                (return :stopped))))
          :to-equal :stopped)
        (expect (nreverse seen) :to-equal (list 1 2))))))
