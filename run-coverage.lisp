;;;; SB-COVER bootstrap script.
(require :asdf)

(require :sb-cover)

(progn
  (declaim (optimize sb-cover:store-coverage-data))
  (defun script-directory ()
    (make-pathname
      :name
      nil
      :type
      nil
      :defaults
      (or
        *load-truename*
        *compile-file-truename*
        (error "Unable to determine the script location"))))
  (defun configure-local-source-registry (root)
    (asdf:initialize-source-registry
      `(:source-registry (:tree ,root) :inherit-configuration)))
  (defun coverage-report-directory ()
    (let ((argument (first (uiop:command-line-arguments))))
      (uiop:ensure-directory-pathname
        (if argument (uiop:parse-native-namestring argument)
          (merge-pathnames "cl-date-kit-coverage/" (uiop:temporary-directory))))))
  (defun project-source-p (root)
    (let ((source-directory (namestring (merge-pathnames "src/" root))))
      (lambda (file)
        (and
          (<= (length source-directory) (length file))
          (string= source-directory file :end2 (length source-directory))))))
  (let ((root (script-directory))
        (report-directory (coverage-report-directory)))
    (configure-local-source-registry root)
    (ensure-directories-exist report-directory)
    (asdf:load-system "cl-date-kit" :force t)
    (declaim (optimize (sb-cover:store-coverage-data 0)))
    (asdf:test-system "cl-date-kit/test")
    (sb-cover:report report-directory :if-matches (project-source-p root))
    (format t "Coverage report: ~A~%" report-directory)
    (uiop:quit 0)))
