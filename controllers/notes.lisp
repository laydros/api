(in-package :tagit)

(defroute (:get "/api/projects/([0-9a-f-]+)/notes") (req res args)
  (catch-errors (res)
    (alet* ((project-id (car args))
            (user-id (user-id req))
            (notes (get-user-notes user-id project-id)))
      (send-json res notes))))

(defroute (:post "/api/projects/([0-9a-f-]+)/notes") (req res args)
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (project-id (car args))
            (note-data (post-var req "data")))
      (alet ((note (add-note user-id project-id note-data)))
        (send-json res note)))))

(defroute (:put "/api/notes/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((note-id (car args))
            (user-id (user-id req))
            (note-data (post-var req "data")))
      (alet ((note (edit-note user-id note-id note-data)))
        (send-json res note)))))

(defroute (:delete "/api/notes/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((note-id (car args))
            (user-id (user-id req))
            (nil (delete-note user-id note-id)))
      (send-json res t))))

