(in-package #:cl-date-kit/test)
(eval-when (:compile-toplevel :load-toplevel :execute) (require :sb-posix))

(describe
  "AVAILABLE-TIME-ZONE-NAMES"
  (it-needs-zoneinfo
    "returns sorted, non-empty, duplicate-free names"
    (let ((names (cl-date-kit:available-time-zone-names)))
      (expect names :to-be-truthy)
      (expect
        (every
          (lambda (name)
            (and (stringp name) (plusp (length name))))
          names)
        :to-be-truthy)
      (expect names :to-equal (sort (copy-list names) (function string<)))
      (expect
        (length names)
        :to-be
        (length (remove-duplicates names :test (function string=))))))
  (it-needs-zoneinfo "resolves UTC" (expect (time-zone-p (find-time-zone "UTC")) :to-be-truthy))
  (it-needs-zoneinfo "resolves Asia/Tokyo" (expect (time-zone-p (find-time-zone "Asia/Tokyo")) :to-be-truthy))
  (it-needs-zoneinfo "resolves America/New_York" (expect (time-zone-p (find-time-zone "America/New_York")) :to-be-truthy))
  (it-needs-zoneinfo
    "returns a fresh list after a cached lookup"
    (let* ((first-result (cl-date-kit:available-time-zone-names))
           (first-name (car first-result))
           (second-result (cl-date-kit:available-time-zone-names)))
      (setf (car first-result) "Synthetic/Mutated")
      (expect (eq first-result second-result) :to-be-falsy)
      (expect (car second-result) :to-equal first-name)))
  (it-run-if
      (let* ((tzdir (sb-ext:posix-getenv "TZDIR"))
              (root (and tzdir (cl-date-kit::%zoneinfo-root-pathname tzdir))))
         (and root (probe-file (merge-pathnames "UTC" root))))
      "uses the TZDIR environment root when one is configured"
    (expect
      (cl-date-kit:available-time-zone-names :tzdir (sb-ext:posix-getenv "TZDIR"))
      :to-equal
      (cl-date-kit:available-time-zone-names))))

(defun %call-with-temporary-tzdir (function)
  (let ((directory
        (merge-pathnames
          (format
            nil
            "cl-date-kit-tzdir-~36R-~36R/"
            (get-universal-time)
            (random most-positive-fixnum))
          #P"/tmp/")))
    (ensure-directories-exist directory)
    (unwind-protect (funcall function directory)
      (ignore-errors (delete-file (merge-pathnames #P"+VERSION" directory)))
      (ignore-errors (delete-file (merge-pathnames #P"tzdata.zi" directory)))
      (ignore-errors (sb-ext:delete-directory directory)))))

(defun %write-temporary-tzdir-file (directory name content)
  (with-open-file (stream
      (merge-pathnames name directory)
      :direction
      :output
      :if-exists
      :supersede)
    (write-string content stream)))
(defun %write-temporary-tzdir-octets (directory name octets)
  (let ((path (merge-pathnames name directory)))
    (with-open-file
        (stream path
                :direction :output
                :if-exists :supersede
                :element-type (quote (unsigned-byte 8)))
      (write-sequence octets stream))
    path))
(defun %call-with-tzdir-environment (tzdir function)
  (let ((original (sb-ext:posix-getenv "TZDIR")))
    (unwind-protect
         (progn
           (if tzdir
               (sb-posix:setenv "TZDIR" (namestring tzdir) 1)
               (sb-posix:unsetenv "TZDIR"))
           (funcall function))
      (if original
          (sb-posix:setenv "TZDIR" original 1)
          (sb-posix:unsetenv "TZDIR")))))
(describe
  "%READ-BOUNDED-LINE"
  (it
    "treats end-of-stream without a trailing newline as a complete line"
    (multiple-value-bind (line complete-p)
        (with-input-from-string (stream "2025b") (cl-date-kit::%read-bounded-line stream))
      (expect complete-p :to-be-truthy)
      (expect line :to-equal "2025b")))
  (it
    "reports an incomplete line once it exceeds the configured limit"
    (multiple-value-bind (line complete-p)
        (with-input-from-string
            (stream (make-string 200 :initial-element #\a))
          (cl-date-kit::%read-bounded-line stream))
      (expect complete-p :to-be nil)
      (expect line :to-be nil))))

(describe
  "TIME-ZONE-DATABASE-VERSION"
  (it
    "trims whitespace around the +VERSION release"
    (%call-with-temporary-tzdir
      (lambda (tzdir)
        (%write-temporary-tzdir-file
          tzdir
          #P"+VERSION"
          (format nil " ~C2025b~C~%" #\Tab #\Return))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-equal "2025b"))))
  (it
    "falls back to tzdata.zi when +VERSION is absent or invalid"
    (%call-with-temporary-tzdir
      (lambda (tzdir)
        (%write-temporary-tzdir-file
          tzdir
          #P"tzdata.zi"
          (format nil "# version 2025b~%"))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-equal "2025b")
        (%write-temporary-tzdir-file tzdir #P"+VERSION" (format nil "not-a-release~%"))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-equal "2025b"))))
  (it
    "returns NIL when neither version source is valid"
    (%call-with-temporary-tzdir
      (lambda (tzdir)
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-be nil)
        (%write-temporary-tzdir-file tzdir #P"+VERSION" (format nil "not-a-release~%"))
        (%write-temporary-tzdir-file
          tzdir
          #P"tzdata.zi"
          (format nil "# version invalid~%"))
        (expect (cl-date-kit:time-zone-database-version :tzdir tzdir) :to-be nil)))))

(describe
  "FIND-TIME-ZONE error paths"
  (it
    "signals TIME-ZONE-NOT-FOUND for an unsafe or nonexistent zone name"
    (let ((condition
          (handler-case (find-time-zone "Nonexistent/Zone_ABC")
            (time-zone-not-found (signaled) signaled))))
      (expect (typep condition 'time-zone-not-found) :to-be-truthy)
      (expect (time-zone-not-found-name condition) :to-equal "Nonexistent/Zone_ABC"))
    (let ((condition
          (handler-case (find-time-zone "../etc/passwd")
            (time-zone-not-found (signaled) signaled))))
      (expect (typep condition 'time-zone-not-found) :to-be-truthy)
      (expect (time-zone-not-found-name condition) :to-equal "../etc/passwd")))
  (it
  "reports the on-disk pathname for malformed TZif data found by name"
  (%call-with-temporary-tzdir
    (lambda (tzdir)
      (let ((path
              (%write-temporary-tzdir-octets
                tzdir
                "MalformedZone"
                (vector 84 90 105 102))))
        (unwind-protect
             (let ((condition
                     (handler-case
                         (%call-with-tzdir-environment
                           tzdir
                           (lambda () (find-time-zone "MalformedZone")))
                       (malformed-tzif (signaled) signaled))))
               (expect (typep condition (quote malformed-tzif)) :to-be-truthy)
               (expect
                 (namestring (malformed-tzif-path condition))
                 :to-equal
                 (namestring (truename path))))
          (ignore-errors (delete-file path))))))))
(describe
  "FIND-TIME-ZONE TZDIR fallback"
  (it-run-if
    (probe-file #P"/usr/share/zoneinfo/UTC")
    "uses the default zoneinfo root when TZDIR is unset"
    (%call-with-tzdir-environment
      nil
      (lambda ()
        (expect (time-zone-name (find-time-zone "UTC")) :to-equal "UTC"))))
  (it-run-if
    (probe-file #P"/usr/share/zoneinfo/UTC")
    "falls back to the default zoneinfo root when TZDIR does not exist"
    (%call-with-temporary-tzdir
      (lambda (directory)
        (let ((missing (merge-pathnames #P"missing/" directory)))
          (expect (probe-file missing) :to-be nil)
          (%call-with-tzdir-environment
            missing
            (lambda ()
              (expect (time-zone-name (find-time-zone "UTC")) :to-equal "UTC"))))))))

(describe
  "%ZONEINFO-ROOT-NAMESTRING"
  (it-each
      ((nil) (42) (some-symbol))
      "returns NIL for a root that is neither a string nor a pathname (~S)"
      (root)
    (expect (cl-date-kit::%zoneinfo-root-namestring root) :to-be nil)))
(describe
  "%FIND-TIME-ZONE-IN-ROOTS"
  (it
    "signals ZONEINFO-DIRECTORY-NOT-FOUND when no root directory exists"
    (%call-with-temporary-tzdir
      (lambda (directory)
        (let* ((name "Asia/Tokyo")
               (missing-root
                 (namestring (merge-pathnames #P"missing/" directory)))
               (condition
                 (handler-case
                     (cl-date-kit::%find-time-zone-in-roots name (list missing-root))
                   (zoneinfo-directory-not-found (signaled) signaled))))
          (expect (typep condition 'zoneinfo-directory-not-found) :to-be-truthy)
          (expect (typep condition 'time-zone-not-found) :to-be-truthy)
          (expect (time-zone-not-found-name condition) :to-equal name)))))
  (it
    "signals TIME-ZONE-NOT-FOUND when a valid root lacks the zone name"
    (%call-with-temporary-tzdir
      (lambda (directory)
        (let* ((name "Nonexistent/Zone_ABC")
               (condition
                 (handler-case
                     (cl-date-kit::%find-time-zone-in-roots name (list (namestring directory)))
                   (zoneinfo-directory-not-found (signaled) signaled)
                   (time-zone-not-found (signaled) signaled))))
          (expect (typep condition 'time-zone-not-found) :to-be-truthy)
          (expect (typep condition 'zoneinfo-directory-not-found) :to-be-falsy)
          (expect (time-zone-not-found-name condition) :to-equal name))))))
