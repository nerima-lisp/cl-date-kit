(in-package #:cl-date-kit)

(defun %tzif-maximum-absolute-offset-seconds (data)
  (let ((maximum (abs (tzif-type-utc-offset (tzif-data-initial-type data)))))
    (loop for type across (tzif-data-transition-types data)
          do (setf maximum (max maximum (abs (tzif-type-utc-offset type)))))
    maximum))

(defun %time-zone-local-search-radius (zone)
  (or
    (time-zone-local-search-radius zone)
    (setf (time-zone-local-search-radius zone) (%tzif-maximum-absolute-offset-seconds (time-zone-tzif-data zone)))))

(defun %time-zone-local-transition-index-range (zone naive-seconds)
  (let* ((times (tzif-data-transition-times (time-zone-tzif-data zone)))
         (radius (%time-zone-local-search-radius zone))
         (start (1+ (%binary-search-le times (1- (- naive-seconds radius))))))
    (values start (%binary-search-le times (+ naive-seconds radius)))))

(defun %posix-rule-applies-to-local-p (zone naive-seconds)
  "True when NAIVE-SECONDS is safely beyond ZONE's explicit TZif table."
  (let* ((data (time-zone-tzif-data zone))
         (times (tzif-data-transition-times data))
         (count (length times)))
    (or
      (zerop count)
      (let* ((index (1- count))
             (boundary (aref times index))
             (before
            (if (zerop index) (tzif-data-initial-type data)
              (aref (tzif-data-transition-types data) (1- index))))
             (after (aref (tzif-data-transition-types data) index)))
        (>
          naive-seconds
          (max
            (+ boundary (tzif-type-utc-offset before))
            (+ boundary (tzif-type-utc-offset after))))))))

(defun %local-date-time->naive-seconds (local-date-time)
  "LOCAL-DATE-TIME's fields read as if they directly WERE epoch seconds --
i.e. as if the wall-clock reading were UTC. Comparing this against a
transition's local reading under each of its bracketing offsets is the
standard trick for detecting gaps and overlaps."
  (+
    (* (local-date-to-epoch-day (local-date-time-date local-date-time)) 86400)
    (local-time-to-second-of-day (local-date-time-time local-date-time))))

(defun %require-zone-offset (offset)
  (check-type offset zone-offset)
  offset)

(defun local-date-time-to-epoch-second (local-date-time offset)
  "Converts LOCAL-DATE-TIME in a fixed OFFSET to Unix epoch seconds."
  (check-type local-date-time local-date-time)
  (-
    (%local-date-time->naive-seconds local-date-time)
    (zone-offset-total-seconds (%require-zone-offset offset))))

(defun local-date-time-of-epoch-second (epoch-second nanosecond offset)
  "Constructs a LOCAL-DATE-TIME from epoch seconds in a fixed OFFSET."
  (check-type epoch-second integer)
  (multiple-value-bind (epoch-day second-of-day) (floor
      (+ epoch-second (zone-offset-total-seconds (%require-zone-offset offset)))
      +seconds-per-day+)
    (make-local-date-time
      (local-date-from-epoch-day epoch-day)
      (local-time-of-second-of-day second-of-day nanosecond))))

(defun local-date-time-to-instant (local-date-time offset)
  "Interprets LOCAL-DATE-TIME in fixed OFFSET as an INSTANT."
  (make-instant
    (local-date-time-to-epoch-second local-date-time offset)
    (local-date-time-nanosecond local-date-time)))

(defun local-date-time-of-instant (instant zone)
  "Applies the offset in force for ZONE at INSTANT to return local fields."
  (local-date-time-of-epoch-second
    (instant-epoch-second instant)
    (instant-nanosecond instant)
    (offset-for-instant zone instant)))

(defun %local-date-time-transition-kind (naive-seconds local-before local-after)
  "Classifies NAIVE-SECONDS within a transition's affected local-time range."
  (cond
    ((and
        (> local-after local-before)
        (<= local-before naive-seconds)
        (< naive-seconds local-after))
      :gap)
    ((and
        (< local-after local-before)
        (<= local-after naive-seconds)
        (< naive-seconds local-before))
      :overlap)))

(defun %classify-local-date-time (local-date-time zone)
  (etypecase zone
    (zone-offset (values :normal zone nil))
    (time-zone
      (let* ((data (time-zone-tzif-data zone))
             (times (tzif-data-transition-times data))
             (types (tzif-data-transition-types data))
             (naive (%local-date-time->naive-seconds local-date-time)))
        (multiple-value-bind (start end) (%time-zone-local-transition-index-range zone naive)
          (flet ((type-before (index)
                   (if (zerop index) (tzif-data-initial-type data)
                  (aref types (1- index)))))
            (let ((type-at-naive (type-before start)))
              (loop for index from start to
                    end
                    for boundary = (aref times index)
                    for before-type = (type-before index)
                    for after-type = (aref types index)
                    for before-seconds = (tzif-type-utc-offset before-type)
                    for after-seconds = (tzif-type-utc-offset after-type)
                    for kind = (%local-date-time-transition-kind
                  naive
                  (+ boundary before-seconds)
                  (+ boundary after-seconds))
                    when (<= (+ boundary after-seconds) naive)
                      do (setf type-at-naive after-type)
                    when kind
                      do (return-from
                  %classify-local-date-time
                  (values
                    kind
                    (%make-zone-offset before-seconds)
                    (%make-zone-offset after-seconds))))
              (let ((rule (time-zone-posix-rule zone)))
                (when (and rule (%posix-rule-applies-to-local-p zone naive))
                  (multiple-value-bind (kind first-offset second-offset) (%classify-posix-local-date-time naive rule)
                    (when kind
                      (return-from %classify-local-date-time (values kind first-offset second-offset))))))
              (if (and (plusp (length times)) (< end (1- (length times)))) (values :normal (%tzif-type->offset type-at-naive) nil)
                (let ((type (%time-zone-type-for-instant zone naive)))
                  (values
                    :normal
                    (if type (%tzif-type->offset type)
                      (%make-zone-offset
                        (nth-value 0 (%posix-state-values-at-instant naive (time-zone-posix-rule zone)))))
                    nil))))))))))

(defun local-date-time-zone-transition (local-date-time zone)
  "Returns the zone transition responsible for LOCAL-DATE-TIME in ZONE, or NIL."
  (labels ((applies-p (transition naive-seconds)
             (let* ((boundary (instant-epoch-second (zone-transition-instant transition)))
               (before (zone-offset-total-seconds (zone-transition-offset-before transition)))
               (after (zone-offset-total-seconds (zone-transition-offset-after transition))))
          (%local-date-time-transition-kind
            naive-seconds
            (+ boundary before)
            (+ boundary after)))))
    (etypecase zone
      (zone-offset nil)
      (time-zone
        (let* ((naive-seconds (%local-date-time->naive-seconds local-date-time)))
          (multiple-value-bind (start end) (%time-zone-local-transition-index-range zone naive-seconds)
            (or
              (loop for index from start to
                    end
                    for transition = (%time-zone-transition-at-index zone index)
                    when (and transition (applies-p transition naive-seconds))
                      return transition)
              (let ((rule (time-zone-posix-rule zone)))
                (when (and rule (%posix-rule-applies-to-local-p zone naive-seconds))
                  (let ((year (local-date-year (local-date-from-epoch-day (floor naive-seconds 86400)))))
                    (loop for transition-year from (1- year) to (1+ year)
                          do (dolist (description (%posix-transitions-for-year transition-year rule))
                        (destructuring-bind (boundary before after) description
                          (let ((transition (%zone-transition-from-values boundary before after)))
                            (when (and
                                transition
                                (%posix-transition-applies-p zone boundary)
                                (applies-p transition naive-seconds))
                              (return-from local-date-time-zone-transition transition))))))))))))))))

(progn
  (defun possible-offsets-for-local-date-time (local-date-time zone)
    "The ZONE-OFFSETs LOCAL-DATE-TIME could mean in ZONE: empty if it falls in
 a spring-forward gap, one in the normal case, or two (earlier first) if it
 falls in a fall-back overlap.

For a TIME-ZONE, explicit TZif transitions and its POSIX footer rule are both
considered, so far-future gaps and overlaps are classified as well."
    (multiple-value-bind (kind first-offset second-offset) (%classify-local-date-time local-date-time zone)
      (ecase kind
        (:normal (list first-offset))
        (:gap (quote ()))
        (:overlap (list first-offset second-offset)))))
  (defun %local-date-time-has-offset-p (local-date-time zone offset)
    "Whether OFFSET is valid for LOCAL-DATE-TIME in ZONE."
    (multiple-value-bind (kind first-offset second-offset) (%classify-local-date-time local-date-time zone)
      (ecase kind
        (:normal (zone-offset= offset first-offset))
        (:gap nil)
        (:overlap
          (or (zone-offset= offset first-offset) (zone-offset= offset second-offset)))))))

(defun resolve-local-date-time (local-date-time zone &key (disambiguation :compatible))
  "Resolves LOCAL-DATE-TIME to a single ZONE-OFFSET in ZONE. DISAMBIGUATION:
  :COMPATIBLE (default) -- the offset after a gap; the earlier offset in an overlap.
  :EARLIER -- the offset before a gap; the earlier offset in an overlap.
  :LATER -- the offset after a gap; the later offset in an overlap.
  :STRICT -- signals NONEXISTENT-LOCAL-TIME or AMBIGUOUS-LOCAL-TIME instead of picking one."
  (check-type disambiguation (member :compatible :earlier :later :strict))
  (multiple-value-bind (kind first-offset second-offset) (%classify-local-date-time local-date-time zone)
    (ecase kind
      (:normal first-offset)
      (:overlap
        (ecase disambiguation
          ((:compatible :earlier) first-offset)
          (:later second-offset)
          (:strict
            (error
              (quote ambiguous-local-time)
              :local-date-time
              local-date-time
              :zone
              zone
              :earlier-offset
              first-offset
              :later-offset
              second-offset))))
      (:gap
        (ecase disambiguation
          ((:compatible :later) second-offset)
          (:earlier first-offset)
          (:strict
            (error
              (quote nonexistent-local-time)
              :local-date-time
              local-date-time
              :zone
              zone)))))))

(defun local-date-of-instant (instant zone)
  "Applies the offset in force for ZONE at INSTANT and returns the local date."
  (multiple-value-bind (epoch-day second-of-day) (floor
      (+
        (instant-epoch-second instant)
        (zone-offset-total-seconds
          (%require-zone-offset (offset-for-instant zone instant))))
      +seconds-per-day+)
    (declare (ignore second-of-day))
    (local-date-from-epoch-day epoch-day)))

(defun local-time-of-instant (instant zone)
  "Applies the offset in force for ZONE at INSTANT and returns the local time."
  (multiple-value-bind (epoch-day second-of-day) (floor
      (+
        (instant-epoch-second instant)
        (zone-offset-total-seconds
          (%require-zone-offset (offset-for-instant zone instant))))
      +seconds-per-day+)
    (declare (ignore epoch-day))
    (local-time-of-second-of-day second-of-day (instant-nanosecond instant))))

(defun zone-transition-date-time-before (transition)
  "Returns TRANSITION's instant as local fields under its offset before."
  (local-date-time-of-instant
    (zone-transition-instant transition)
    (zone-transition-offset-before transition)))

(defun zone-transition-date-time-after (transition)
  "Returns TRANSITION's instant as local fields under its offset after."
  (local-date-time-of-instant
    (zone-transition-instant transition)
    (zone-transition-offset-after transition)))
