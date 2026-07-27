;;;; src/tzif.lisp
;;;;
;;;; A from-scratch reader for the on-disk IANA time zone database format,
;;;; TZif (RFC 8536) -- the same binary compiled-zoneinfo files every other
;;;; language's tz support ultimately reads (glibc, Go's time/tzdata,
;;;; Python's zoneinfo, chrono-tz's data generator). Keeping this a plain
;;;; file reader rather than an ASDF dependency is what lets CL-DATE-KIT
;;;; support real IANA zones while staying dependency-free: see zone.lisp for
;;;; the TZDIR / /usr/share/zoneinfo search path that finds these files.
(in-package #:cl-date-kit)

(defstruct tzif-type
  (utc-offset 0 :type integer :read-only t)
  (dst-p nil :type boolean :read-only t))

(defstruct tzif-data
  (transition-times #() :type simple-vector :read-only t)
  (transition-types #() :type simple-vector :read-only t)
  (initial-type nil :type tzif-type :read-only t)
  (posix-tz-string nil :type (or null string) :read-only t))

(defstruct %tzif-header
  (version 0) (isutcnt 0) (isstdcnt 0) (leapcnt 0) (timecnt 0) (typecnt 0) (charcnt 0))

(defun %read-u8 (bytes offset) (aref bytes offset))

(defun %read-u32-be (bytes offset)
  (loop with value = 0
        for i from 0 below 4
        do (setf value (+ (* value 256) (aref bytes (+ offset i))))
        finally (return value)))

(defun %read-s32-be (bytes offset)
  (let ((u (%read-u32-be bytes offset)))
    (if (>= u #x80000000) (- u #x100000000) u)))

(defun %read-u64-be (bytes offset)
  (loop with value = 0
        for i from 0 below 8
        do (setf value (+ (* value 256) (aref bytes (+ offset i))))
        finally (return value)))

(defun %read-s64-be (bytes offset)
  (let ((u (%read-u64-be bytes offset)))
    (if (>= u #x8000000000000000) (- u #x10000000000000000) u)))

(defun %parse-tzif-header (bytes offset path)
  (unless (and (<= (+ offset 44) (length bytes))
               (= (%read-u8 bytes offset) #x54)        ; T
               (= (%read-u8 bytes (+ offset 1)) #x5a)   ; Z
               (= (%read-u8 bytes (+ offset 2)) #x69)   ; i
               (= (%read-u8 bytes (+ offset 3)) #x66))  ; f
    (error 'malformed-tzif :path path :reason "missing TZif magic number"))
  (make-%tzif-header
   :version (%read-u8 bytes (+ offset 4))
   :isutcnt (%read-u32-be bytes (+ offset 20))
   :isstdcnt (%read-u32-be bytes (+ offset 24))
   :leapcnt (%read-u32-be bytes (+ offset 28))
   :timecnt (%read-u32-be bytes (+ offset 32))
   :typecnt (%read-u32-be bytes (+ offset 36))
   :charcnt (%read-u32-be bytes (+ offset 40))))

(defun %parse-tzif-block (bytes offset header time-width path)
  "Parses one TZif data block (the part after its own 44-byte header) at
OFFSET, using TIME-WIDTH-byte transition times (4 for the legacy v1 block, 8
for the v2+ block). Returns (values transition-times transition-types
initial-type end-offset), where TRANSITION-TYPES\\[i\\] is the regime that
starts at TRANSITION-TIMES\\[i\\] and INITIAL-TYPE is the regime in force
before the first transition."
  (let* ((timecnt (%tzif-header-timecnt header))
         (typecnt (%tzif-header-typecnt header))
         (charcnt (%tzif-header-charcnt header))
         (isutcnt (%tzif-header-isutcnt header))
         (isstdcnt (%tzif-header-isstdcnt header))
         (leapcnt (%tzif-header-leapcnt header))
         (block-size (+ (* timecnt time-width)
                        timecnt
                        (* typecnt 6)
                        charcnt
                        (* leapcnt (+ time-width 4))
                        isstdcnt
                        isutcnt))
         (end (+ offset block-size))
         (read-time (if (= time-width 4) #'%read-s32-be #'%read-s64-be)))
    ;; Validate every count before allocating or indexing into the data block.
    (unless (<= 1 typecnt 256)
      (error 'malformed-tzif :path path :reason "type count must be between 1 and 256"))
    (unless (and (or (zerop isstdcnt) (= isstdcnt typecnt))
                 (or (zerop isutcnt) (= isutcnt typecnt)))
      (error 'malformed-tzif
             :path path
             :reason "standard and UT indicator counts must be zero or match the type count"))
    (unless (<= end (length bytes))
      (error 'malformed-tzif :path path :reason "data block runs past end of file"))
    (let ((transition-times (make-array timecnt))
          (type-indices (make-array timecnt))
          (types (make-array typecnt))
          (pos offset))
      (dotimes (i timecnt)
        (let ((transition-time (funcall read-time bytes pos)))
          (when (and (plusp i)
                     (<= transition-time (aref transition-times (1- i))))
            (error 'malformed-tzif
                   :path path
                   :reason "transition times must be strictly increasing"))
          (setf (aref transition-times i) transition-time))
        (incf pos time-width))
      (dotimes (i timecnt)
        (let ((type-index (%read-u8 bytes pos)))
          (unless (< type-index typecnt)
            (error 'malformed-tzif
                   :path path
                   :reason "transition type index is outside the type table"))
          (setf (aref type-indices i) type-index))
        (incf pos))
      (dotimes (i typecnt)
        ;; ttinfo is 6 bytes: 4-byte UTC offset, 1-byte DST flag, 1-byte index
        ;; into the abbreviation-string table (which CL-DATE-KIT does not use).
        (let ((dst-flag (%read-u8 bytes (+ pos 4))))
          (unless (<= dst-flag 1)
            (error 'malformed-tzif :path path :reason "DST flag must be zero or one"))
          (setf (aref types i)
                (make-tzif-type :utc-offset (%read-s32-be bytes pos)
                                :dst-p (plusp dst-flag))))
        (incf pos 6))
      (incf pos charcnt)                      ; abbreviation strings
      (incf pos (* leapcnt (+ time-width 4))) ; leap-second records
      (incf pos isstdcnt)                     ; standard/wall indicators
      (incf pos isutcnt)                      ; UT/local indicators
      (let ((initial-type
              (or (find-if (lambda (ty) (not (tzif-type-dst-p ty))) types)
                  (aref types 0)))
            (transition-types
              (map 'simple-vector (lambda (i) (aref types i)) type-indices)))
        (values transition-times transition-types initial-type pos)))))

(defun %parse-posix-tz-string (bytes offset path)
  "Parses the newline-framed v2+ POSIX TZ footer at OFFSET.
An empty footer denotes that no future rule is supplied."
  (unless (and (< offset (length bytes)) (= (%read-u8 bytes offset) 10))
    (error
      (quote malformed-tzif)
      :path path
      :reason "POSIX TZ footer is missing its opening newline"))
  (let* ((start (1+ offset))
         (end (position 10 bytes :start start)))
    (unless end
      (error
        (quote malformed-tzif)
        :path path
        :reason "POSIX TZ footer is missing its closing newline"))
    (unless (= (1+ end) (length bytes))
      (error
        (quote malformed-tzif)
        :path path
        :reason "POSIX TZ footer has trailing bytes"))
    (unless (= start end)
      (map (quote string) (function code-char) (subseq bytes start end)))))

(progn
  (defun %read-file-bytes (path)
    (with-open-file (stream path :element-type (quote (unsigned-byte 8)))
      (let ((buffer (make-array (file-length stream)
                                :element-type (quote (unsigned-byte 8)))))
        (read-sequence buffer stream)
        buffer)))
  (defun parse-tzif-file (path)
    "Parses the TZif file at PATH (RFC 8536, versions 1-3) into a TZIF-DATA."
    (let* ((bytes (%read-file-bytes path))
           (v1-header (%parse-tzif-header bytes 0 path)))
      (multiple-value-bind (v1-times v1-types v1-initial v1-end)
          (%parse-tzif-block bytes 44 v1-header 4 path)
        (if (zerop (%tzif-header-version v1-header))
            (make-tzif-data :transition-times v1-times :transition-types v1-types
                             :initial-type v1-initial :posix-tz-string nil)
            (let ((v2-header (%parse-tzif-header bytes v1-end path)))
              (multiple-value-bind (v2-times v2-types v2-initial v2-end)
                  (%parse-tzif-block bytes (+ v1-end 44) v2-header 8 path)
                (make-tzif-data :transition-times v2-times :transition-types v2-types
                                 :initial-type v2-initial
                                 :posix-tz-string
                                 (%parse-posix-tz-string bytes v2-end path)))))))))
