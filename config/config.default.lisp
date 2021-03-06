(in-package :turtl)

(defparameter *root* (asdf:system-relative-pathname :turtl #P"")
  "Defines the root directory turtl is loading from (basically the ASDF path).")

(defparameter *pid-file* nil
  "File to write the current proc's PID to.")

(defvar *db-name* "turtl"
  "The name of the database we'll be using LOL")

(defvar *db-host* "127.0.0.1"
  "The database hostname/ip.")

(defvar *db-port* 28015
  "The database port number.")

(defvar *production-error-handling* nil
  "If t, will attempt to catch all errors that make it to top-level and not let
   the parent process enter the debugger.")

(defvar *enable-hsts-header* nil
  "If NIL, Turtl won't pass back an HSTS security header. If this is set, it
   should be set to a integer value, which will be passed to the max-age value
   of the header.")

(defvar *enabled-cors-resources* "resource://turtl-at-lyonbros-dot-com"
  "When set, will enable CORS for resource:// origins if they match the given
   string. Entries should be comma separated (this string is passed verbatim in
   the Access-Control-Allow-Origin header).")

(defvar *site-url* "http://turtl.dev:8181"
  "The main URL the site will load from.")

(defvar *invite-site-url* "http://invites.turtl.dev:8182"
  "The main URL used to generate invite links.")

(defvar *api-url* "/api"
  "The location (absolute or relative to *site-url*) that API calls will go to.")

(defvar *api-key* "12345"
  "The API key used for the app. Completely unused.")

(defvar *admin-email* "andrew@lyonbros.com"
  "The email used for admin communications. This is reported to users on a
   server error, and possibly other instances.")

(defvar *email-from* "noreply@turtl.it"
  "The email address all turtl emails come from.")

(defvar *email-user* ""
  "The username used for sending email. Needs to be set on load.")
(defvar *email-pass* ""
  "The password used for sending email. Needs to be set on load.")

(defvar *display-errors* t
  "Whether or not to show errors in HTTP responses. Useful for debugging, bad
   for production.")

(defparameter *public-actions*
  `((:post . "/api/users")
    (:post . "/api/log/error")
    (:get . ,(cl-ppcre:create-scanner "/api/invites/codes/([0-9a-f-]+)")))
  "A list of public resources/actions that do not require authentication.")

(defparameter *default-storage-limit* 100
  "The max amount of data a profile can hold (in megabytes). Set to nil to allow
   infinite size profiles.")

(defparameter *storage-invite-credit* 25
  "The amount of storage (in mb) to credit a user when they refer someone.")

;; setup the logger
(vom:config (log4cl:make-logger :turtl) :debug)

(defvar *analytics* '(:enabled t)
  "Holds analytics config")

(defvar *local-upload* nil
  "NIL disables local files storage (files are uploaded to S3). Set to a local
   path to save files locally instead of remotely. No trailing slash!")
(defvar *local-upload-url* nil
  "Define the URL that local files will be loaded from. Generally, this will be
   the same URL the API is accessed from and only needs to be defined if the
   *local-upload* variable has a value. This should *not* include the /files
   path, and there should be no trailing slash. Example:

     http://turtl.dev:8181")

(defvar *amazon-s3* '(:token ""
                      :secret ""
                      :bucket ""
                      :endpoint "https://s3.amazonaws.com")
  "Holds Amazon S3 config.")

