(in-package :tagit)

(defroute (:get "/api/projects/users/([0-9a-f-]+)") (req res args)
  ;; TODO: AUTH: make sure user-id == (user-id req)
  (catch-errors (res)
    (alet* ((user-id (car args))
            (projects (get-user-projects user-id)))
      (send-json res projects))))

(defroute (:post "/api/projects/users/([0-9a-f-]+)") (req res args)
  ;; TODO: AUTH: make sure user-id == (user-id req)
  (catch-errors (res)
    (alet* ((user-id (car args))
            (project-data (post-var req "data")))
      (alet ((project (add-project user-id project-data)))
        (send-json res project)))))

(defroute (:delete "/api/projects/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((project-id (car args))
            (user-id (user-id req))
            (nil (delete-project user-id project-id)))
      (send-json res t))))

