(in-package :turtl)

(defroute (:post "/api/boards/([0-9a-f-]+)/notes") (req res args)
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (persona-id (post-var req "persona"))
            (board-id (car args))
            (note-data (post-var req "data"))
            (note (if persona-id
                      (with-valid-persona (persona-id user-id)
                        (add-note user-id board-id note-data :persona-id persona-id))
                      (add-note user-id board-id note-data))))
      (send-json res note))))

(defroute (:put "/api/notes/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((note-id (car args))
            (user-id (user-id req))
            (persona-id (post-var req "persona"))
            (note-data (post-var req "data"))
            (note (if persona-id
                      (with-valid-persona (persona-id user-id)
                        (edit-note persona-id note-id note-data))
                      (edit-note user-id note-id note-data))))
      (send-json res note))))

(defroute (:delete "/api/notes/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((note-id (car args))
            (user-id (user-id req))
            (persona-id (post-var req "persona"))
            (nil (if persona-id
                    (with-valid-persona (persona-id user-id)
                      (delete-note persona-id note-id))
                    (delete-note user-id note-id))))
      (send-json res t))))

(defroute (:put "/api/notes/batch") (req res)
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (persona-id (post-var req "persona"))
            (batch-edit-data (post-var req "data"))
            (nil (if persona-id
                     (with-valid-persona (persona-id user-id)
                       (batch-note-edit persona-id batch-edit-data))
                     (batch-note-edit user-id batch-edit-data))))
      (send-json res t))))

