;;;; t/recurrence-test.lisp

(in-package #:cl-date-kit/test)

(defun recurrence-test-local (year month day hour minute)
  (local-date-time-of year month day hour minute 0))

(defun recurrence-test-seed (year month day hour minute zone)
  (zoned-date-time-of-local (recurrence-test-local year month day hour minute)
                            (find-time-zone zone)))

(describe "ZonedRecurrence"
  (it "preserves the seed local schedule across a compatible spring gap"
    (let* ((recurrence (make-zoned-recurrence
                        (recurrence-test-seed 2024 3 9 2 30 "America/New_York")
                        :frequency :daily))
           (occurrences (zoned-recurrence-occurrences recurrence :limit 3)))
      (expect (local-date-time= (zoned-date-time-local (second occurrences)) (recurrence-test-local 2024 3 10 3 30)) :to-be-truthy)
      (expect (local-date-time= (zoned-date-time-local (third occurrences)) (recurrence-test-local 2024 3 11 2 30)) :to-be-truthy)))

  (it "preserves an overlap seed and uses the selected overlap resolution"
    (let* ((seed (recurrence-test-seed 2024 11 2 1 30 "America/New_York"))
           (earlier (zoned-recurrence-occurrences
                     (make-zoned-recurrence seed :frequency :daily
                                             :disambiguation :earlier)
                     :limit 2))
           (later (zoned-recurrence-occurrences
                   (make-zoned-recurrence seed :frequency :daily
                                           :disambiguation :later)
                   :limit 2))
           (later-seed (zoned-date-time-of-local
                        (recurrence-test-local 2024 11 3 1 30)
                        (find-time-zone "America/New_York")
                        :disambiguation :later))
           (first-occurrence
             (first (zoned-recurrence-occurrences
                     (make-zoned-recurrence later-seed :frequency :daily
                                             :disambiguation :earlier)
                     :limit 1))))
      (expect (zone-offset-total-seconds (zoned-date-time-offset (second earlier)))
              :to-be -14400)
      (expect (zone-offset-total-seconds (zoned-date-time-offset (second later)))
              :to-be -18000)
      (expect (eq first-occurrence later-seed) :to-be-truthy)
      (expect (zoned-date-time= first-occurrence later-seed) :to-be-truthy)
      (expect (zone-offset-total-seconds
               (zoned-date-time-offset first-occurrence))
              :to-be
              (zone-offset-total-seconds (zoned-date-time-offset later-seed)))))

  (it "clamps month ends while retaining the original seed day"
    (let* ((recurrence (make-zoned-recurrence
                        (recurrence-test-seed 2024 1 31 9 0 "UTC")
                        :frequency :monthly))
           (occurrences (zoned-recurrence-occurrences recurrence :limit 3)))
      (expect (local-date-time= (zoned-date-time-local (second occurrences)) (recurrence-test-local 2024 2 29 9 0)) :to-be-truthy)
      (expect (local-date-time= (zoned-date-time-local (third occurrences)) (recurrence-test-local 2024 3 31 9 0)) :to-be-truthy)))

  (it "applies weekly intervals from the seed"
    (let* ((recurrence (make-zoned-recurrence
                        (recurrence-test-seed 2024 1 1 9 0 "UTC")
                        :frequency :weekly :interval 2))
           (occurrences (zoned-recurrence-occurrences recurrence :limit 3)))
      (expect (local-date-time= (zoned-date-time-local (third occurrences)) (recurrence-test-local 2024 1 29 9 0)) :to-be-truthy)))

  (it "applies count and an inclusive local until boundary"
    (let ((seed (recurrence-test-seed 2024 1 1 9 0 "UTC")))
      (expect (length (zoned-recurrence-occurrences
                       (make-zoned-recurrence seed :frequency :daily :count 2)
                       :limit 5))
              :to-be 2)
      (expect (length (zoned-recurrence-occurrences
                       (make-zoned-recurrence
                        seed :frequency :daily
                        :until (recurrence-test-local 2024 1 3 9 0))
                       :limit 5))
              :to-be 3)))

  (it "validates constructor values and generation limits"
    (let ((seed (recurrence-test-seed 2024 1 1 9 0 "UTC")))
      (signals type-error (make-zoned-recurrence seed :frequency :hourly))
      (signals type-error (make-zoned-recurrence seed :frequency :daily :interval 0))
      (signals type-error (make-zoned-recurrence seed :frequency :daily :count 0))
      (signals type-error (zoned-recurrence-occurrences
                           (make-zoned-recurrence seed :frequency :daily)
                           :limit 0))))

  (it "stops mapping when the callback returns NIL"
    (let ((calls 0)
          (recurrence (make-zoned-recurrence
                       (recurrence-test-seed 2024 1 1 9 0 "UTC")
                       :frequency :daily)))
      (map-zoned-recurrence-occurrences
       (lambda (occurrence)
         (declare (ignore occurrence))
         (incf calls)
         (< calls 2))
       recurrence
       :limit 5)
      (expect calls :to-be 2)))

  (it "supports the recurrence iteration macro"
    (let ((days '())
          (recurrence (make-zoned-recurrence
                       (recurrence-test-seed 2024 1 1 9 0 "UTC")
                       :frequency :daily)))
      (do-zoned-recurrence-occurrences (occurrence recurrence :limit 3)
        (push (local-date-day (local-date-time-date
                               (zoned-date-time-local occurrence)))
              days)
        t)
      (expect (nreverse days) :to-equal '(1 2 3)))))
