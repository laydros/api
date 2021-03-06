(in-package :turtl)

;;; Many of the routes in this controller look for a persona ID passed with the
;;; request, and if found use that insteda of the currently logged-in user when
;;; updating note data. The purpose of this is to use a persona's permissions to
;;; validate changing note data intstead of the user's (in the case that the
;;; note is in a board the persona has share access to).
;;;
;;; If a persona ID is apssed, it is *always* used. The client must make the
;;; decision about whether or not to pass it, the server is not going to take
;;; both and use the one with the highest permissions.

;; TODO: just POST /notes instead of including the board id...
(defroute (:post "/api/boards/([0-9a-f-]+)/notes") (req res args)
  "Add a note. Allows passing in a persona ID, which will be used in place of
   the current user ID when validating permissions."
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (persona-id (post-var req "persona"))
            (board-id (car args))
            (note-data (post-var req "data"))
            (note (if persona-id
                      (with-valid-persona (persona-id user-id)
                        (add-note user-id board-id note-data :persona-id persona-id))
                      (add-note user-id board-id note-data))))
      (track "note-add" `(:shared ,(when persona-id t)) req)
      (send-json res note))))

(defroute (:put "/api/notes/([0-9a-f-]+)") (req res args)
  "Edit a note. Allows passing in a persona ID, which will be used in place of
   the current user ID when validating permissions."
  (catch-errors (res)
    (alet* ((note-id (car args))
            (user-id (user-id req))
            (persona-id (post-var req "persona"))
            (note-data (post-var req "data"))
            (note (if persona-id
                      (with-valid-persona (persona-id user-id)
                        (edit-note persona-id note-id note-data))
                      (edit-note user-id note-id note-data))))
      (track "note-edit" `(:shared ,(when persona-id t)) req)
      (send-json res note))))

(defroute (:delete "/api/notes/([0-9a-f-]+)") (req res args)
  "Delete a note. Allows passing in a persona ID, which will be used in place of
   the current user ID when validating permissions."
  (catch-errors (res)
    (alet* ((note-id (car args))
            (user-id (user-id req))
            (persona-id (post-var req "persona"))
            (sync-ids (if persona-id
                          (with-valid-persona (persona-id user-id)
                            (delete-note persona-id note-id))
                          (delete-note user-id note-id))))
      (track "note-delete" `(:shared ,(when persona-id t)) req)
      (let ((hash (make-hash-table :test #'equal)))
        (setf (gethash "sync_ids" hash) sync-ids)
        (send-json res hash)))))

(defroute (:get "/api/notes/([0-9a-f-]+)/file") (req res args)
  "Get a note's file. This works by generating a URL we can redirect the client
   to on the storage system then running the redirect."
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (note-id (car args))
            (persona-id (get-var req "persona"))
            (disable-redirect (get-var req "disable_redirect"))
            (hash (get-var req "hash"))
            (file-url (if persona-id
                          (with-valid-persona (persona-id user-id)
                            (get-note-file-url persona-id note-id hash))
                          (get-note-file-url user-id note-id hash)))
            (headers (unless (string= disable-redirect "1")
                       `(:location ,file-url))))
      (if file-url
          (send-response res :status (if disable-redirect 200 302) :headers headers :body (to-json file-url))
          (send-response res :status 404 :body "That note has no attachments.")))))

(defun upload-local (user-id req res args)
  "Upload a file to the local filesystem."
  (catch-errors (res)
    (let* ((note-id (car args))
           (persona-id (get-var req "persona"))
           (file-id note-id)
           (hash (get-var req "hash"))
           (file (make-note-file :hash hash))
           (path (get-file-path file-id))
           (total-file-size 0)
           (fd nil)
           (finish-fn (lambda ()
                        (catch-errors (res)
                          (close fd)
                          (vom:debug1 "file: close fd, sending final response to client")
                          (setf (gethash "size" file) total-file-size)
                          (remhash "upload_id" file)
                          (alet* ((file (edit-note-file user-id file-id file :remove-upload-id t))
                                  (size (get-file-size-summary total-file-size)))
                                 (track "file-upload" `(:shared ,(when persona-id t) :size ,size) req)
                            (send-json res file))))))
      (vom:debug1 "local: calling with-chunking")
      (when (string= (get-header (request-headers req) :expect) "100-continue")
        (send-100-continue res))
      (with-chunking req (data lastp)
        (vom:debug2 "local: got chunk: ~a ~a" (length data) lastp)
        (unless fd
          (vom:debug1 "file: opening local fd: ~a" path)
          (setf fd (open path :direction :output :if-exists :supersede :element-type '(unsigned-byte 8))))
        (incf total-file-size (length data))
        (write-sequence data fd)
        (when lastp
          (funcall finish-fn))))))

(defun upload-remote (user-id req res args)
  "Upload the given file data to a remote server."
  (catch-errors (res)
    (alet* ((note-id (car args))
            (persona-id (get-var req "persona"))
            (file-id note-id)
            (hash (get-var req "hash"))
            (file (make-note-file :hash hash))
            (s3-uploader :starting)
            (buffered-chunks nil)
            (path (get-file-path file-id))
            (chunking-started nil)
            (last-chunk-sent nil)
            (total-file-size 0)
            (finish-fn (lambda ()
                         (catch-errors (res)
                           (vom:debug1 "file: sending final response to client")
                           (setf (gethash "size" file) total-file-size)
                           (remhash "upload_id" file)
                           (alet* ((file (edit-note-file user-id file-id file :remove-upload-id t))
                                   (size (get-file-size-summary total-file-size)))
                             (track "file-upload" `(:shared ,(when persona-id t) :size ,size) req)
                             (send-json res file))))))
      ;; create an uploader lambda, used to stream our file chunk by chunk to S3
      (vom:debug1 "file: starting uploader with path: ~a" path)
      (multiple-promise-bind (uploader upload-id)
          (s3-upload path)
        ;; save our file record
        (setf (gethash "upload_id" file) upload-id)
        (wait (edit-note-file user-id note-id file :skip-sync t)
          (vom:debug1 "file: saved file ~a" file))
        ;; save our uploader so the chunking brahs can use it
        (vom:debug1 "- file: uploader created: ~a" upload-id)
        (setf s3-uploader uploader)
        ;; if we haven't started getting the body yet, let the client know it's
        ;; ok to send
        (unless chunking-started
          (when (string= (get-header (request-headers req) :expect) "100-continue")
            (send-100-continue res)))
        (when last-chunk-sent
          (alet* ((body (flexi-streams:get-output-stream-sequence buffered-chunks))
                  (finishedp (funcall s3-uploader body)))
            (incf total-file-size (length body))   ; track the file size
            ;; note that finishedp should ALWAYS be true here, but "should" and
            ;; "will" are very different things (especially in async, i'm
            ;; finding)
            (when finishedp
              (funcall finish-fn)))))
      ;; listen for chunked data. if we have an uploader object, send in our
      ;; data directly, otherwise buffer it until the uploader becomes
      ;; available
      (with-chunking req (chunk-data last-chunk-p)
        ;; notify the upload creator that chunking has started. this prevents it
        ;; from sending a 100 Continue header if the flow has already started.
        (setf chunking-started t
              last-chunk-sent (or last-chunk-sent last-chunk-p))
        (cond ((eq s3-uploader :starting)
               (unless buffered-chunks
                 (vom:debug1 "- file: uploader not ready, buffering chunks")
                 (setf buffered-chunks (flexi-streams:make-in-memory-output-stream :element-type '(unsigned-byte 8))))
               (write-sequence chunk-data buffered-chunks))
              (t
               (when buffered-chunks
                 (write-sequence chunk-data buffered-chunks)
                 (setf chunk-data (flexi-streams:get-output-stream-sequence buffered-chunks)))
               (incf total-file-size (length chunk-data))   ; track the file size
               (alet ((finishedp (funcall s3-uploader chunk-data (not last-chunk-p))))
                 (when finishedp
                   (funcall finish-fn)))
               (setf buffered-chunks nil)))))))

(defroute (:put "/api/notes/([0-9a-f-]+)/file" :chunk t :suppress-100 t) (req res args)
  "Attach file contents to a note. The HTTP content body must be the raw,
   unencoded (encrypted) file data."
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (note-id (car args))
            (persona-id (get-var req "persona"))
            (persona-or-user user-id)
            (perms (if persona-id
                       (with-valid-persona (persona-id user-id)
                         (setf persona-or-user persona-id)
                         (get-user-note-permissions persona-id note-id))
                       (get-user-note-permissions user-id note-id))))
      (if (<= 2 perms)
          (if *local-upload*
              (upload-local persona-or-user req res args)
              (upload-remote persona-or-user req res args))
          (error (make-instance 'insufficient-privileges
                                :msg "Sorry, you are accessing a note you don't have access to."))))))

(defroute (:delete "/api/notes/([0-9a-f-]+)/file") (req res args)
  "Remove a note's file attachment."
  (catch-errors (res)
    (alet* ((note-id (car args))
            (user-id (user-id req))
            (persona-id (post-var req "persona"))
            (nil (if persona-id
                     (with-valid-persona (persona-id user-id)
                       (delete-note-file persona-id note-id))
                     (delete-note-file user-id note-id))))
      (track "file-delete" `(:shared ,(when persona-id t)) req)
      (send-json res t))))

(defroute (:put "/api/notes/batch") (req res)
  "Batch edit. Allows passing in a persona ID, which will be used in place of
   the current user ID when validating permissions."
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (persona-id (post-var req "persona"))
            (batch-edit-data (post-var req "data"))
            (nil (if persona-id
                     (with-valid-persona (persona-id user-id)
                       (batch-note-edit persona-id batch-edit-data))
                     (batch-note-edit user-id batch-edit-data))))
      (send-json res t))))

