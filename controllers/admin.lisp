(in-package :turtl)

(defparameter *admin-page*
  (file-contents (concatenate 'string (namestring *root*) "views/admin.html"))
  "Holds the admin page.")

(defroute (:get "/admin") (req res)
  "Get the admin page, populated with our data."
  (catch-errors (res)
    ;(setf *admin-page* (file-contents (concatenate 'string (namestring *root*) "views/admin.html")))
    (alet* ((admin-stats (get-admin-stats))
            (admin-log (get-logs 200))
            (html (populate-stats *admin-page* admin-stats))
            (html (populate-log html admin-log)))
      (send-response res :body html))))

