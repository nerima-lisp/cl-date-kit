(in-package #:cl-date-kit)

(defstruct tzif-type (utc-offset 0 :type integer :read-only t)
  (dst-p nil :type boolean :read-only t)
  (abbreviation-index 0 :type integer :read-only t)
  (offset-cache nil))

(defstruct tzif-data (transition-times #() :type simple-vector :read-only t)
  (transition-types #() :type simple-vector :read-only t)
  (initial-type nil :type tzif-type :read-only t)
  (abbreviation-table "" :type string :read-only t)
  (posix-tz-string nil :type (or null string) :read-only t))

(progn
  (defstruct %tzif-header (version 0)
    (isutcnt 0)
    (isstdcnt 0)
    (leapcnt 0)
    (timecnt 0)
    (typecnt 0)
    (charcnt 0))
  (defconstant +maximum-tzif-file-size+ (* 16 1024 1024)
    "Maximum TZif input size in octets.")
  (defconstant +maximum-tzif-time-count+ 1000000
    "Maximum number of TZif transition timestamps in one block.")
  (defconstant +maximum-tzif-leap-count+ 10000
    "Maximum number of TZif leap-second records in one block.")
  (defconstant +maximum-tzif-character-count+ (* 1024 1024)
    "Maximum number of TZif abbreviation bytes in one block."))

(defun %read-u8 (bytes offset)
  (aref bytes offset))

(defun %read-u32-be (bytes offset)
  (loop with value = 0
        for i from 0 below 4
        do (setf value (+ (* value 256) (aref bytes (+ offset i))))
        finally (return value)))

(defun %read-s32-be (bytes offset)
  (let ((u (%read-u32-be bytes offset)))
    (if (>= u #x80000000) (- u #x100000000)
      u)))

(defun %read-u64-be (bytes offset)
  (loop with value = 0
        for i from 0 below 8
        do (setf value (+ (* value 256) (aref bytes (+ offset i))))
        finally (return value)))

(defun %read-s64-be (bytes offset)
  (let ((u (%read-u64-be bytes offset)))
    (if (>= u #x8000000000000000) (- u #x10000000000000000)
      u)))

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
  "Parses one TZif data block and returns its transitions, types, initial type,
abbreviation table, and end offset."
  (let* ((timecnt (%tzif-header-timecnt header))
         (typecnt (%tzif-header-typecnt header))
         (charcnt (%tzif-header-charcnt header))
         (isutcnt (%tzif-header-isutcnt header))
         (isstdcnt (%tzif-header-isstdcnt header))
         (leapcnt (%tzif-header-leapcnt header))
         (read-time
        (if (= time-width 4) (function %read-s32-be)
          (function %read-s64-be))))
    (unless (<= 1 typecnt 256)
      (error
        (quote malformed-tzif)
        :path
        path
        :reason
        "type count must be between 1 and 256"))
    (unless (<= timecnt +maximum-tzif-time-count+)
      (error
        (quote malformed-tzif)
        :path
        path
        :reason
        "transition count exceeds the maximum supported value"))
    (unless (<= leapcnt +maximum-tzif-leap-count+)
      (error
        (quote malformed-tzif)
        :path
        path
        :reason
        "leap-second count exceeds the maximum supported value"))
    (unless (<= charcnt +maximum-tzif-character-count+)
      (error
        (quote malformed-tzif)
        :path
        path
        :reason
        "abbreviation byte count exceeds the maximum supported value"))
    (unless (and
        (or (zerop isstdcnt) (= isstdcnt typecnt))
        (or (zerop isutcnt) (= isutcnt typecnt)))
      (error
        (quote malformed-tzif)
        :path
        path
        :reason
        "standard and UT indicator counts must be zero or match the type count"))
    (let* ((block-size
          (+
            (* timecnt time-width)
            timecnt
            (* typecnt 6)
            charcnt
            (* leapcnt (+ time-width 4))
            isstdcnt
            isutcnt))
           (end (+ offset block-size)))
      (unless (<= end (length bytes))
        (error
          (quote malformed-tzif)
          :path
          path
          :reason
          "data block runs past end of file"))
      (let ((transition-times (make-array timecnt))
            (type-indices (make-array timecnt))
            (types (make-array typecnt))
            (pos offset))
        (dotimes (i timecnt)
          (let ((transition-time (funcall read-time bytes pos)))
            (when (and (plusp i) (<= transition-time (aref transition-times (1- i))))
              (error
                (quote malformed-tzif)
                :path
                path
                :reason
                "transition times must be strictly increasing"))
            (setf (aref transition-times i) transition-time))
          (incf pos time-width))
        (dotimes (i timecnt)
          (let ((index (%read-u8 bytes pos)))
            (unless (< index typecnt)
              (error
                (quote malformed-tzif)
                :path
                path
                :reason
                "transition type index is out of range"))
            (setf (aref type-indices i) index))
          (incf pos))
        (dotimes (i typecnt)
          (let ((dst-flag (%read-u8 bytes (+ pos 4))))
            (unless (<= dst-flag 1)
              (error (quote malformed-tzif) :path path :reason "DST flag must be zero or one"))
            (setf (aref types i) (make-tzif-type
                :utc-offset
                (%read-s32-be bytes pos)
                :dst-p
                (plusp dst-flag)
                :abbreviation-index
                (%read-u8 bytes (+ pos 5)))))
          (incf pos 6))
        (let ((abbreviation-table (make-string charcnt)))
          (dotimes (i charcnt)
            (setf (char abbreviation-table i) (code-char (%read-u8 bytes (+ pos i)))))
          (loop for type across types
                for index = (tzif-type-abbreviation-index type)
                unless (and (< index charcnt) (position #\Null abbreviation-table :start index))
                  do (error
              (quote malformed-tzif)
              :path
              path
              :reason
              "abbreviation index must select a NUL-terminated designation"))
          (let ((transition-types (make-array timecnt)))
            (dotimes (index timecnt)
              (setf (aref transition-types index) (aref types (aref type-indices index))))
            (values
              transition-times
              transition-types
              (or (find-if-not (function tzif-type-dst-p) types) (aref types 0))
              abbreviation-table
              end)))))))

(defun %parse-posix-tz-string (bytes offset path)
  "Parses the newline-framed v2+ POSIX TZ footer at OFFSET.
An empty footer denotes that no future rule is supplied."
  (unless (and (< offset (length bytes)) (= (%read-u8 bytes offset) 10))
    (error
      (quote malformed-tzif)
      :path
      path
      :reason
      "POSIX TZ footer is missing its opening newline"))
  (let* ((start (1+ offset))
         (end (position 10 bytes :start start)))
    (unless end
      (error
        (quote malformed-tzif)
        :path
        path
        :reason
        "POSIX TZ footer is missing its closing newline"))
    (unless (= (1+ end) (length bytes))
      (error
        (quote malformed-tzif)
        :path
        path
        :reason
        "POSIX TZ footer has trailing bytes"))
    (unless (= start end)
      (map (quote string) (function code-char) (subseq bytes start end)))))

(progn
  (defun %read-file-bytes (path)
    (with-open-file (stream path :element-type '(unsigned-byte 8))
      (let ((file-size (file-length stream)))
        (when (> file-size +maximum-tzif-file-size+)
          (error
            'malformed-tzif
            :path
            path
            :reason
            "TZif file exceeds the maximum supported size"))
        (let ((buffer (make-array file-size :element-type '(unsigned-byte 8))))
          (read-sequence buffer stream)
          buffer))))
  (defun parse-tzif-file (path)
    "Parses the TZif file at PATH (RFC 8536, versions 1-3) into a TZIF-DATA."
    (let* ((bytes (%read-file-bytes path))
           (v1-header (%parse-tzif-header bytes 0 path)))
      (multiple-value-bind (v1-times v1-types v1-initial v1-abbreviations v1-end) (%parse-tzif-block bytes 44 v1-header 4 path)
        (if (zerop (%tzif-header-version v1-header)) (make-tzif-data
            :transition-times
            v1-times
            :transition-types
            v1-types
            :initial-type
            v1-initial
            :abbreviation-table
            v1-abbreviations
            :posix-tz-string
            nil)
          (let ((v2-header (%parse-tzif-header bytes v1-end path)))
            (multiple-value-bind (v2-times v2-types v2-initial v2-abbreviations v2-end) (%parse-tzif-block bytes (+ v1-end 44) v2-header 8 path)
              (make-tzif-data
                :transition-times
                v2-times
                :transition-types
                v2-types
                :initial-type
                v2-initial
                :abbreviation-table
                v2-abbreviations
                :posix-tz-string
                (%parse-posix-tz-string bytes v2-end path)))))))))
