(in-package #:cl-date-kit)

(defun %parse-fraction-nanoseconds (string start end profile expected)
  (let ((digits (- end start)))
    (when (or (zerop digits) (and (null profile) (> digits 9)))
      (error 'date-time-parse-error :string string :expected expected))
    (let ((value 0))
      (loop for index from start below end
            do (let ((digit (digit-char-p (char string index))))
                 (unless digit
                   (error 'date-time-parse-error :string string :expected expected))
                 (when (< index (+ start 9))
                   (setf value (+ (* value 10) digit)))))
      (* value (expt 10 (max 0 (- 9 (min digits 9))))))))

(defun %parse-toml-local-time (string start end)
  (let ((length (- end start))
        (fraction-pos nil))
    (when (> length 0)
      (setf fraction-pos (position #\. string :start start :end end)))
    (let* ((main-end (or fraction-pos end))
           (main-length (- main-end start))
           (has-seconds (= main-length 8)))
      (unless (or (= main-length 5) has-seconds)
        (error 'date-time-parse-error :string string :expected "HH:MM[:SS][.fraction]"))
      (unless (and (char= (char string (+ start 2)) #\:)
                   (or (not has-seconds) (char= (char string (+ start 5)) #\:)))
        (error 'date-time-parse-error :string string :expected "HH:MM[:SS][.fraction]"))
      (make-local-time
        (%parse-fixed-integer string start (+ start 2) "HH:MM[:SS]")
        (%parse-fixed-integer string (+ start 3) (+ start 5) "HH:MM[:SS]")
        (if has-seconds
            (%parse-fixed-integer string (+ start 6) (+ start 8) "HH:MM:SS")
            0)
        (if fraction-pos
            (%parse-fraction-nanoseconds string (1+ fraction-pos) end t "fraction")
            0)))))

(progn
  (defun %write-local-time (time stream &key minimal-fraction)
    (if (zerop (local-time-nanosecond time)) (format
        stream
        "~2,'0D:~2,'0D:~2,'0D"
        (local-time-hour time)
        (local-time-minute time)
        (local-time-second time))
      (let* ((nanosecond (local-time-nanosecond time))
             (fraction (if minimal-fraction
                          (string-right-trim "0" (format nil "~9,'0D" nanosecond))
                          (format nil "~9,'0D" nanosecond))))
        (format stream "~2,'0D:~2,'0D:~2,'0D.~A"
          (local-time-hour time) (local-time-minute time)
          (local-time-second time) fraction))))
  (defun format-local-time (time &key profile)
    "Formats TIME as ISO 8601, or as TOML/RFC3339 with PROFILE :RFC3339."
    (with-output-to-string (stream)
      (%write-local-time time stream :minimal-fraction (eq profile :rfc3339)))))

(defun %parse-local-time-profile (string profile)
  (when profile
    (return-from %parse-local-time-profile
      (%parse-toml-local-time string 0 (length string))))
  (with-date-time-parse-error
    (string "HH:MM:SS[.nnnnnnnnn] or HHMMSS[.nnnnnnnnn]")
    (let* ((length (and (stringp string) (length string)))
           (extended-p (and length (>= length 8)
                            (char= (char string 2) #\:)
                            (char= (char string 5) #\:)
                            (or (= length 8)
                                (and (<= 10 length 18)
                                     (char= (char string 8) #\.)
                                     (%digits-p string 9 length)))))
           (basic-p (and length (>= length 6)
                         (%digits-p string 0 6)
                         (or (= length 6)
                             (and (<= 8 length 16)
                                  (char= (char string 6) #\.)
                                  (%digits-p string 7 length))))))
      (unless (or extended-p basic-p)
        (error 'date-time-parse-error :string string
          :expected "HH:MM:SS[.nnnnnnnnn] or HHMMSS[.nnnnnnnnn]"))
      (if extended-p
          (make-local-time
            (%parse-fixed-integer string 0 2 "HH:MM:SS")
            (%parse-fixed-integer string 3 5 "HH:MM:SS")
            (%parse-fixed-integer string 6 8 "HH:MM:SS")
            (if (= length 8) 0
                (%parse-fraction-nanoseconds string 9 length nil "fraction")))
          (make-local-time
            (%parse-fixed-integer string 0 2 "HHMMSS")
            (%parse-fixed-integer string 2 4 "HHMMSS")
            (%parse-fixed-integer string 4 6 "HHMMSS")
            (if (= length 6) 0
                (%parse-fraction-nanoseconds string 7 length nil "fraction")))))))

(defun parse-local-time (string &key profile)
  (with-date-time-parse-error
    (string "HH:MM[:SS][.fraction] or HHMM[SS][.fraction]")
    (%parse-local-time-profile string profile)))

(progn
  (defun %write-local-date-time (date-time stream &key profile)
    (%write-local-date (local-date-time-date date-time) stream)
    (write-char (if (eq profile :rfc3339) #\T #\T) stream)
    (%write-local-time (local-date-time-time date-time)
      stream :minimal-fraction (eq profile :rfc3339)))
  (defun format-local-date-time (dt &key profile)
    "Formats DT as the canonical ISO 8601 form YYYY-MM-DDTHH:MM:SS[.nnnnnnnnn]."
    (with-output-to-string (stream)
      (%write-local-date-time dt stream :profile profile))))

(defun %parse-local-date-time-profile (string profile)
  "Parses an ISO 8601 date-time of the form YYYY-MM-DDTHH:MM:SS[.nnnnnnnnn]."
  (with-date-time-parse-error
    (string "YYYY-MM-DDTHH:MM:SS")
    (let ((sep (or (position #\T string)
                   (position #\t string)
                   (and profile (position #\Space string)))))
      (unless sep
        (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SS"))
      (if profile
          (make-local-date-time
            (make-local-date
              (%parse-fixed-integer string 0 4 "YYYY-MM-DD")
              (%parse-fixed-integer string 5 7 "YYYY-MM-DD")
              (%parse-fixed-integer string 8 10 "YYYY-MM-DD"))
            (%parse-toml-local-time string 11 (length string)))
        (make-local-date-time
          (parse-local-date (subseq string 0 sep))
          (parse-local-time (subseq string (1+ sep))))))))

(defun parse-local-date-time (string &key profile)
  (with-date-time-parse-error
    (string "YYYY-MM-DDTHH:MM[:SS][.fraction]")
    (%parse-local-date-time-profile string profile)))
