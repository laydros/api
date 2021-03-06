(in-package :turtl)

(defroute (:post "/api/invites/boards/([0-9a-f-]+)") (req res args)
  "Invite email to board."
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (board-id (car args))
            (persona-id (post-var req "persona"))
            (to (post-var req "to"))
            (key (post-var req "key"))
            (board-key (post-var req "board_key"))
            (question (post-var req "question"))
            (used-secret-p (< 0 (varint (post-var req "used_secret") 0)))
            (invite (create-board-invite user-id
                                         board-id
                                         persona-id
                                         to
                                         key
                                         board-key
                                         question
                                         used-secret-p)))
      (track "invite" `(:persona nil :used-secret ,used-secret-p) req)
      (send-json res invite))))

(defroute (:get "/api/invites/codes/([0-9a-f-]+)") (req res args)
  "Retrieve information about an invite."
  (catch-errors (res)
    (alet* ((invite-code (car args))
            (invite-id (or (get-var req "invite_id") ""))
            (invite (get-invite-by-id-code invite-id invite-code :get-from-persona t)))
      (if invite
          (send-json res invite)
          (send-response res :status 404 :body "\"Invite not found.\"")))))

(defroute (:post "/api/invites/accepted/([0-9a-f-]+)") (req res args)
  "Accept an invite."
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (invite-id (car args))
            (invite-code (post-var req "code"))
            (persona-id (post-var req "persona"))
            (success (accept-invite user-id invite-id invite-code persona-id)))
      (track "invite-accept" `(:persona nil) req)
      (send-json res success))))

(defroute (:post "/api/invites/denied/([0-9a-f-]+)") (req res args)
  "Deny an invite."
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (invite-id (car args))
            (invite-code (post-var req "code"))
            (persona-id (post-var req "persona"))
            (sync-ids (deny-invite user-id invite-id invite-code persona-id)))
      (track "invite-deny" `(:persona nil) req)
      (let ((hash (make-hash-table :test #'equal)))
        (setf (gethash "sync_ids" hash) sync-ids)
        (send-json res hash)))))

(defroute (:delete "/api/invites/([0-9a-f-]+)") (req res args)
  "Delete an invite (aka deny)."
  (catch-errors (res)
    (alet* ((invite-id (car args))
            (user-id (user-id req))
            (sync-ids (delete-invite user-id invite-id)))
      (track "invite-delete" `(:persona nil) req)
      (let ((hash (make-hash-table :test #'equal)))
        (setf (gethash "sync_ids" hash) sync-ids)
        (send-json res hash)))))

