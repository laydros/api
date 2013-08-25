(in-package :turtl)

(defroute (:get "/api/personas/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((persona-id (car args))
            (persona (get-persona-by-id persona-id)))
      (if persona
          (send-json res persona)
          (send-json res "Persona not found." :status 404)))))

(defroute (:post "/api/personas") (req res)
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (persona-data (post-var req "data"))
            (persona (add-persona user-id persona-data)))
      (send-json res persona))))

(defroute (:put "/api/personas/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (persona-id (car args))
            (persona-data (post-var req "data"))
            (persona (edit-persona user-id persona-id persona-data)))
      (send-json res persona))))

(defroute (:delete "/api/personas/([0-9a-f-]+)") (req res args)
  (catch-errors (res)
    (alet* ((user-id (user-id req))
            (persona-id (car args))
            (nil (delete-persona user-id persona-id)))
      (send-json res t))))

(defroute (:get "/api/personas/email/([a-zA-Z0-9@\/\.\-]+)") (req res args)
  (catch-errors (res)
    (alet* ((email (car args))
            (ignore-persona-id (get-var req "ignore_persona_id"))
            (persona (get-persona-by-email email ignore-persona-id)))
      (if persona
          (send-json res persona)
          (send-json res "Persona not found ='[" :status 404)))))

;(defroute (:post "/api/personas/([0-9a-f-]+)/challenge") (req res args)
;  (catch-errors (res)
;    (alet* ((persona-id (car args))
;            (expire (min (varint (post-var req "expire") 10) 3600))
;            (persist (if (zerop (varint (post-var req "persist") 0))
;                         nil
;                         t))
;            (challenge (generate-challenge :persona persona-id :expire expire :persist persist)))
;      (send-json res challenge))))

;(defroute (:post "/api/personas/challenges") (req res)
;  (catch-errors (res)
;    (alet* ((persona-ids (yason:parse (post-var req "personas")))
;            (challenges (generate-multiple-challenges :persona persona-ids :expire 1800)))
;      (send-json res challenges))))

