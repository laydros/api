(in-package :turtl)

(defroute (:get "/api/profiles/users/([0-9a-f-]+)") (req res args)
  "Returns the curren user's full data profile.
   
   Called when a user joins for the first time (in which case this is blank),
   when a new client connects to an existing account, or an existing client gets
   too far behind."
  (catch-errors (res)
    (let ((user-id (car args)))
      (unless (string= (user-id req) user-id)
        (error 'insufficient-privileges :msg "You are trying to access another user's boards. For shame."))
      ;; note we load everything in parallel here to speed up loading
      (alet ((boards (get-user-boards user-id :get-persona-boards t :get-personas t))
             (personas (get-user-personas user-id))
             (user-data (get-user-data user-id))
             (keychain (get-user-keychain user-id))
             (response (make-hash-table :test #'equal))
             (sync-id (get-latest-sync-id)))
        ;; notes require all our board ids, so load them here
        (alet ((notes (get-notes-from-board-ids (map 'list (lambda (b) (gethash "id" b)) boards))))
          ;; package it all up
          (setf (gethash "boards" response) boards
                (gethash "notes" response) notes
                (gethash "personas" response) personas
                (gethash "user" response) user-data
                (gethash "keychain" response) keychain
                ;; add in a sync-id for syncing reference. if there is no sync
                ;; ID (meaning the sync table is empty), return a new id in its
                ;; place.
                (gethash "sync_id" response) (or sync-id (string-downcase (mongoid:oid-str (mongoid:oid)))))
          (send-json res response))))))

