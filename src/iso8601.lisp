;;;; src/iso8601.lisp
;;;;
;;;; ISO-8601 / RFC-3339 formatting and parsing for every type in this
;;;; library. Formatters emit canonical extended forms; parsers also accept
;;;; ISO 8601 basic calendar, ordinal-date, and week-date forms where a date
;;;; is syntactically permitted.
(in-package #:cl-date-kit)

;;; --- LocalTime -------------------------------------------------------------
(progn
  (defun %write-local-time (time stream)
    (if (zerop (local-time-nanosecond time)) (format
        stream
        "~2,'0D:~2,'0D:~2,'0D"
        (local-time-hour time)
        (local-time-minute time)
        (local-time-second time))
      (format
        stream
        "~2,'0D:~2,'0D:~2,'0D.~9,'0D"
        (local-time-hour time)
        (local-time-minute time)
        (local-time-second time)
        (local-time-nanosecond time))))
  (defun format-local-time (time)
    "Formats TIME as the canonical ISO 8601 form HH:MM:SS[.nnnnnnnnn]."
    (with-output-to-string (stream)
      (%write-local-time time stream))))

(defun parse-local-time (string)
  "Parses an ISO 8601 extended (HH:MM:SS) or basic (HHMMSS) time, with an
optional fractional-second suffix."
  (with-date-time-parse-error
    (string "HH:MM:SS[.nnnnnnnnn] or HHMMSS[.nnnnnnnnn]")
    (let* ((length (and (stringp string) (length string)))
           (extended-p
          (and
            length
            (>= length 8)
            (char= (char string 2) #\:)
            (char= (char string 5) #\:)
            (or
              (= length 8)
              (and
                (<= 10 length 18)
                (char= (char string 8) #\.)
                (loop for index from 9 below length
                      always (digit-char-p (char string index)))))))
           (basic-p
          (and
            length
            (>= length 6)
            (loop for index from 0 below 6
                  always (digit-char-p (char string index)))
            (or
              (= length 6)
              (and
                (<= 8 length 16)
                (char= (char string 6) #\.)
                (loop for index from 7 below length
                      always (digit-char-p (char string index))))))))
      (unless (or extended-p basic-p)
        (error
          (quote date-time-parse-error)
          :string
          string
          :expected
          "HH:MM:SS[.nnnnnnnnn] or HHMMSS[.nnnnnnnnn]"))
      (if extended-p (make-local-time
          (%parse-fixed-integer string 0 2 "HH:MM:SS")
          (%parse-fixed-integer string 3 5 "HH:MM:SS")
          (%parse-fixed-integer string 6 8 "HH:MM:SS")
          (if (= length 8) 0
            (*
              (%parse-fixed-integer string 9 length "HH:MM:SS.nnnnnnnnn")
              (expt 10 (- 18 length)))))
        (make-local-time
          (%parse-fixed-integer string 0 2 "HHMMSS")
          (%parse-fixed-integer string 2 4 "HHMMSS")
          (%parse-fixed-integer string 4 6 "HHMMSS")
          (if (= length 6) 0
            (*
              (%parse-fixed-integer string 7 length "HHMMSS.nnnnnnnnn")
              (expt 10 (- 16 length)))))))))

;;; --- LocalDateTime ---------------------------------------------------------
(progn
  (defun %write-local-date-time (date-time stream)
    (%write-local-date (local-date-time-date date-time) stream)
    (write-char #\T stream)
    (%write-local-time (local-date-time-time date-time) stream))
  (defun format-local-date-time (dt)
    "Formats DT as the canonical ISO 8601 form YYYY-MM-DDTHH:MM:SS[.nnnnnnnnn]."
    (with-output-to-string (stream)
      (%write-local-date-time dt stream))))

(defun parse-local-date-time (string)
  "Parses an ISO 8601 date-time of the form YYYY-MM-DDTHH:MM:SS[.nnnnnnnnn]."
  (with-date-time-parse-error
    (string "YYYY-MM-DDTHH:MM:SS")
    (let ((sep (or (position #\T string) (position #\t string))))
      (unless sep
        (error 'date-time-parse-error :string string :expected "YYYY-MM-DDTHH:MM:SS"))
      (make-local-date-time
        (parse-local-date (subseq string 0 sep))
        (parse-local-time (subseq string (1+ sep)))))))
