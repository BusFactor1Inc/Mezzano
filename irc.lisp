(defpackage :irc-client
  (:use :cl :sys.net)
  (:export #:spawn))

(in-package :irc-client)

(defparameter *numeric-replies*
  '((401 :err-no-such-nick)
    (402 :err-no-such-server)
    (403 :err-no-such-channel)
    (404 :err-cannot-send-to-channel)
    (405 :err-too-many-channels)
    (406 :err-was-no-such-nick)
    (407 :err-too-many-targets)
    (409 :err-no-origin)
    (411 :err-no-recipient)
    (412 :err-no-text-to-send)
    (413 :err-no-toplevel)
    (414 :err-wild-toplevel)
    (421 :err-unknown-command)
    (422 :err-no-motd)
    (423 :err-no-admin-info)
    (424 :err-file-error)
    (431 :err-no-nickname-given)
    (432 :err-erroneus-nickname)
    (433 :err-nickname-in-use)
    (436 :err-nick-collision)
    (441 :err-user-not-in-channel)
    (442 :err-not-on-channel)
    (443 :err-user-on-channel)
    (444 :err-no-login)
    (445 :err-summon-disabled)
    (446 :err-users-disabled)
    (451 :err-not-registered)
    (461 :err-need-more-params)
    (462 :err-already-registred)
    (463 :err-no-perm-for-host)
    (464 :err-password-mismatch)
    (465 :err-youre-banned-creep)
    (467 :err-key-set)
    (471 :err-channel-is-full)
    (472 :err-unknown-mode)
    (473 :err-invite-only-chan)
    (474 :err-banned-from-chan)
    (475 :err-bad-channel-key)
    (481 :err-no-privileges)
    (482 :err-chanop-privs-needed)
    (483 :err-cant-kill-server)
    (491 :err-no-oper-host)
    (501 :err-umode-unknown-flag)
    (502 :err-users-dont-match)
    (300 :rpl-none)
    (302 :rpl-userhost)
    (303 :rpl-ison)
    (301 :rpl-away)
    (305 :rpl-unaway)
    (306 :rpl-nowaway)
    (311 :rpl-whoisuser)
    (312 :rpl-whoisserver)
    (313 :rpl-whoisoperator)
    (317 :rpl-whoisidle)
    (318 :rpl-endofwhois)
    (319 :rpl-whoischannels)
    (314 :rpl-whowasuser)
    (369 :rpl-endofwhowas)
    (321 :rpl-liststart)
    (322 :rpl-list)
    (323 :rpl-listend)
    (324 :rpl-channelmodeis)
    (331 :rpl-notopic)
    (332 :rpl-topic)
    (333 :rpl-topic-time)
    (341 :rpl-inviting)
    (342 :rpl-summoning)
    (351 :rpl-version)
    (352 :rpl-whoreply)
    (315 :rpl-endofwho)
    (353 :rpl-namreply)
    (366 :rpl-endofnames)
    (364 :rpl-links)
    (365 :rpl-endoflinks)
    (367 :rpl-banlist)
    (368 :rpl-endofbanlist)
    (371 :rpl-info)
    (374 :rpl-endofinfo)
    (375 :rpl-motdstart)
    (372 :rpl-motd)
    (376 :rpl-endofmotd)
    (381 :rpl-youreoper)
    (382 :rpl-rehashing)
    (391 :rpl-time)
    (392 :rpl-usersstart)
    (393 :rpl-users)
    (394 :rpl-endofusers)
    (395 :rpl-nousers)
    (200 :rpl-tracelink)
    (201 :rpl-traceconnecting)
    (202 :rpl-tracehandshake)
    (203 :rpl-traceunknown)
    (204 :rpl-traceoperator)
    (205 :rpl-traceuser)
    (206 :rpl-traceserver)
    (208 :rpl-tracenewtype)
    (261 :rpl-tracelog)
    (211 :rpl-statslinkinfo)
    (212 :rpl-statscommands)
    (213 :rpl-statscline)
    (214 :rpl-statsnline)
    (215 :rpl-statsiline)
    (216 :rpl-statskline)
    (218 :rpl-statsyline)
    (219 :rpl-endofstats)
    (241 :rpl-statslline)
    (242 :rpl-statsuptime)
    (243 :rpl-statsoline)
    (244 :rpl-statshline)
    (221 :rpl-umodeis)
    (251 :rpl-luserclient)
    (252 :rpl-luserop)
    (253 :rpl-luserunknown)
    (254 :rpl-luserchannels)
    (255 :rpl-luserme)
    (256 :rpl-adminme)
    (257 :rpl-adminloc1)
    (258 :rpl-adminloc2)
    (259 :rpl-adminemail)))

(defun decode-command (line)
  "Explode a line into (prefix command parameters...)."
  ;; <message>  ::= [':' <prefix> <SPACE> ] <command> <params> <crlf>
  ;; <prefix>   ::= <servername> | <nick> [ '!' <user> ] [ '@' <host> ]
  ;; <command>  ::= <letter> { <letter> } | <number> <number> <number>
  ;; <SPACE>    ::= ' ' { ' ' }
  ;; <params>   ::= <SPACE> [ ':' <trailing> | <middle> <params> ]
  (let ((prefix nil)
        (offset 0)
        (command nil)
        (parameters '()))
    (when (and (not (zerop (length line)))
               (eql (char line 0) #\:))
      ;; Prefix present, read up to a space.
      (do () ((or (>= offset (length line))
                  (eql (char line offset) #\Space)))
        (incf offset))
      (setf prefix (subseq line 1 offset)))
    ;; Eat leading spaces.
    (do () ((or (>= offset (length line))
                (not (eql (char line offset) #\Space))))
      (incf offset))
    ;; Parse a command, reading until space or the end.
    (let ((start offset))
      (do () ((or (>= offset (length line))
                  (eql (char line offset) #\Space)))
        (incf offset))
      (setf command (subseq line start offset)))
    (when (and (= (length command) 3)
               (every (lambda (x) (find x "1234567890")) command))
      (setf command (parse-integer command))
      (setf command (or (second (assoc command *numeric-replies*))
                        command)))
    ;; Read parameters.
    (loop
       ;; Eat leading spaces.
       (do () ((or (>= offset (length line))
                   (not (eql (char line offset) #\Space))))
         (incf offset))
       (cond ((>= offset (length line)) (return))
             ((eql (char line offset) #\:)
              (push (subseq line (1+ offset)) parameters)
              (return))
             (t (let ((start offset))
                  (do () ((or (>= offset (length line))
                              (eql (char line offset) #\Space)))
                    (incf offset))
                  (push (subseq line start offset) parameters)))))
    (values prefix command (nreverse parameters))))

(defun parse-command (line)
  (cond ((and (>= (length line) 1)
              (eql (char line 0) #\/)
              (not (and (>= (length line) 2)
                        (eql (char line 1) #\/))))
         (let ((command-end nil)
               (rest-start nil)
               (rest-end nil))
           (dotimes (i (length line))
             (when (eql (char line i) #\Space)
               (setf command-end i
                     rest-start i)
               (return)))
           (when rest-start
             ;; Eat leading spaces.
             (do () ((or (>= rest-start (length line))
                         (not (eql (char line rest-start) #\Space))))
               (incf rest-start)))
           (values (subseq line 1 command-end)
                   (subseq line (or rest-start (length line)) rest-end))))
        (t (values "say" line))))

(defun send (stream control-string &rest arguments)
  "Buffered FORMAT."
  (declare (dynamic-extent argument))
  (write-sequence (apply 'format nil control-string arguments) stream))

(defvar *command-table* (make-hash-table :test 'equal))

(defmacro define-server-command (name (state . lambda-list) &body body)
  (let ((args (gensym)))
    `(setf (gethash ,(if (and (symbolp name) (not (keywordp name)))
                         (symbol-name name)
                         name)
                    *command-table*)
           (lambda (,state ,(first lambda-list) ,args)
             (declare (system:lambda-name (irc-command ,name)))
             (destructuring-bind ,(rest lambda-list) ,args
               ,@body)))))

(define-server-command privmsg (irc from channel message)
  ;; ^AACTION [msg]^A is a /me command.
  (cond ((and (>= (length message) 9)
              (eql (char message 0) (code-char #x01))
              (eql (char message (1- (length message))) (code-char #x01))
              (string= "ACTION " message :start2 1 :end2 8))
         (format t "[~A]* ~A ~A~%" channel from
                 (subseq message 8 (1- (length message)))))
        (t (format t "[~A]<~A> ~A~%" channel from message))))

(define-server-command ping (irc from message)
  (send (irc-connection irc) "PONG :~A~%" message))

(defvar *known-servers*
  '((:freenode (64 32 24 176) 6667))
  "A list of known/named IRC servers.")

(defun resolve-server-name (name)
  (let ((known (assoc name *known-servers* :key 'symbol-name :test 'string-equal)))
    (cond (known
           (values (second known) (third known)))
          (t (error "Unknown server ~S~%" name)))))

(defclass server-disconnect-event ()
  ())

(defclass server-line-event ()
  ((%line :initarg :line :reader line)))

(defun irc-receive (irc)
  (let ((connection (irc-connection irc))
        (fifo (fifo irc)))
    (loop
       (let ((line (read-line connection nil)))
         (when (not line)
           (mezzanine.supervisor:fifo-push (make-instance 'server-disconnect-event) fifo)
           (return))
         (mezzanine.supervisor:fifo-push (make-instance 'server-line-event :line line) fifo)))))

(defvar *top-level-commands* (make-hash-table :test 'equal))

(defmacro define-command (name (irc text) &body body)
  `(setf (gethash ',(string-upcase (string name))
                  *top-level-commands*)
         (lambda (,irc ,text)
           (declare (system:lambda-name (irc-command ,name)))
           ,@body)))

(define-command quit (irc text)
  (when (irc-connection irc)
    (send (irc-connection irc) "QUIT :~A~%" text))
  (throw 'quit nil))

(define-command raw (irc text)
  (when (irc-connection irc)
    (write-string text (irc-connection irc))
    (terpri (irc-connection irc))))

(define-command eval (irc text)
  (let ((*standard-output* (display-pane irc)))
    (format t "[eval] ~A~%" text)
    (eval (read-from-string text))
    (fresh-line)))

(define-command say (irc text)
  (cond ((and (irc-connection irc) (current-channel irc))
         (format (display-pane irc) "[~A]<~A> ~A~%" (current-channel irc) (nickname irc) text)
         (send (irc-connection irc) "PRIVMSG ~A :~A~%"
               (current-channel irc) text))
        (t (error "Not connected or not joined to a channel."))))

(define-command me (irc text)
  (cond ((and (irc-connection irc) (current-channel irc))
         (format (display-pane irc) "[~A]* ~A ~A~%" (current-channel irc) (nickname irc) text)
         (send (irc-connection irc) "PRIVMSG ~A :~AACTION ~A~A~%"
               (current-channel irc) (code-char 1) text (code-char 1)))
        (t (error "Not connected or not joined to a channel."))))

(define-command nick (irc text)
  (format (display-pane irc) "~&Changing nickname to ~A.~%" text)
  ;; FIXME: Check status.
  (setf (nickname irc) text)
  (when (irc-connection irc)
    (send (irc-connection irc) "NICK ~A~%" (nickname irc))))

(define-command connect (irc text)
  (cond ((not (nickname irc))
         (error "No nickname set. Use /nick to set a nickname before connecting."))
        ((irc-connection irc)
         (error "Already connected to ~S." (irc-connection irc)))
        (t (multiple-value-bind (address port)
               (resolve-server-name text)
             (format (display-pane irc) "Connecting to ~A (~A:~A).~%" text address port)
             (setf (mezzanine.gui.widgets:frame-title (frame irc)) (format nil "IRC - ~A" text))
             (mezzanine.gui.widgets:draw-frame (frame irc))
             (mezzanine.gui.compositor:damage-window (window irc)
                                                     0 0
                                                     (mezzanine.gui.compositor:width (window irc))
                                                     (mezzanine.gui.compositor:height (window irc)))
             (setf (irc-connection irc) (sys.net::tcp-stream-connect address port)
                   (receive-thread irc) (mezzanine.supervisor:make-thread (lambda () (irc-receive irc))
                                                                          :name "IRC receive"))
             (send (irc-connection irc) "USER ~A hostname servername :~A~%" (nickname irc) (nickname irc))
             (send (irc-connection irc) "NICK ~A~%" (nickname irc))))))

(define-command join (irc text)
  (cond ((find text (joined-channels irc) :test 'string-equal)
         (error "Already joined to channel ~A." text))
        ((irc-connection irc)
         (send (irc-connection irc) "JOIN ~A~%" text)
         (push text (joined-channels irc))
         (unless (current-channel irc)
           (setf (current-channel irc) text)))
        (t (error "Not connected."))))

(define-command chan (irc text)
  (when (irc-connection irc)
    (if (find text (joined-channels irc) :test 'string-equal)
        (setf (current-channel irc) text)
        (error "Not joined to channel ~A." text))))

(define-command part (irc text)
  (when (and (irc-connection irc) (current-channel irc))
    (send (irc-connection irc) "PART ~A :~A~%" (current-channel irc) text)
    (setf (joined-channels irc) (remove (current-channel irc) (joined-channels irc)))
    (setf (current-channel irc) (first (joined-channels irc)))))

(defclass irc-client ()
  ((%fifo :initarg :fifo :reader fifo)
   (%window :initarg :window :reader window)
   (%frame :initarg :frame :reader frame)
   (%display-pane :initarg :display-pane :reader display-pane)
   (%input-pane :initarg :input-pane :reader input-pane)
   (%input-buffer :initarg :input-buffer :accessor input-buffer)
   (%current-channel :initarg :current-channel :accessor current-channel)
   (%joined-channels :initarg :joined-channels :accessor joined-channels)
   (%nickname :initarg :nickname :accessor nickname)
   (%connection :initarg :connection :accessor irc-connection)
   (%receive-thread :initarg :receive-thread :accessor receive-thread))
  (:default-initargs :current-channel nil :joined-channels '() :nickname nil :connection nil))

(defun reset-input (irc)
  (setf (input-buffer irc) (make-array 100 :element-type 'character :adjustable t :fill-pointer 0))
  (mezzanine.gui.widgets:reset (input-pane irc))
  (format (input-pane irc) "~A] " (or (current-channel irc) "")))

(defgeneric dispatch-event (irc event)
  (:method (irc event)))

(defmethod dispatch-event (irc (event mezzanine.gui.compositor:window-activation-event))
  (setf (mezzanine.gui.widgets:activep (frame irc)) (mezzanine.gui.compositor:state event))
  (mezzanine.gui.widgets:draw-frame (frame irc)))

(defmethod dispatch-event (irc (event mezzanine.gui.compositor:mouse-event))
  (handler-case
      (mezzanine.gui.widgets:frame-mouse-event (frame irc) event)
    (mezzanine.gui.widgets:close-button-clicked ()
      (throw 'quit nil))))

(defmethod dispatch-event (irc (event mezzanine.gui.compositor:window-close-event))
  (throw 'quit nil))

(defmethod dispatch-event (irc (event mezzanine.gui.compositor:key-event))
  ;; should filter out strange keys?
  (when (not (mezzanine.gui.compositor:key-releasep event))
    (let ((ch (mezzanine.gui.compositor:key-key event)))
      (cond ((eql ch #\Newline)
             (let ((line (input-buffer irc)))
               (reset-input irc)
               (multiple-value-bind (command rest)
                   (parse-command line)
                 (let ((fn (gethash (string-upcase command) *top-level-commands*)))
                   (if fn
                       (funcall fn irc rest)
                       (error "Unknown command ~S." command))))))
            ((eql ch #\Backspace)
             (when (not (zerop (fill-pointer (input-buffer irc))))
               (decf (fill-pointer (input-buffer irc)))
               (mezzanine.gui.widgets:reset (input-pane irc))
               (format (input-pane irc) "~A] ~A" (or (current-channel irc) "") (input-buffer irc))))
            (t (vector-push-extend ch (input-buffer irc))
               (write-char ch (input-pane irc)))))))

(defmethod dispatch-event (irc (event server-disconnect-event))
  (format (display-pane irc) "Disconnected.~%"))

(defmethod dispatch-event (irc (event server-line-event))
  (let ((line (line event)))
    (multiple-value-bind (prefix command parameters)
        (decode-command line)
      (let ((fn (gethash command *command-table*)))
        (cond (fn (funcall fn irc prefix parameters))
              ((keywordp command)
               (format (display-pane irc) "[~A] -!- ~A~%" prefix (car (last parameters))))
              ((integerp command)
               (format (display-pane irc) "[~A] ~D ~A~%" prefix command parameters))
              (t (write-line line (display-pane irc))))))))

(defun irc-main ()
  (catch 'quit
    (mezzanine.gui.font:with-font (font mezzanine.gui.font:*default-monospace-font* mezzanine.gui.font:*default-monospace-font-size*)
      (let ((fifo (mezzanine.supervisor:make-fifo 50)))
        (mezzanine.gui.compositor:with-window (window fifo 640 480)
          (let* ((framebuffer (mezzanine.gui.compositor:window-buffer window))
                 (frame (make-instance 'mezzanine.gui.widgets:frame
                                       :framebuffer framebuffer
                                       :title "IRC"
                                       :close-button-p t
                                       :damage-function (mezzanine.gui.widgets:default-damage-function window)))
                 (display-pane (make-instance 'mezzanine.gui.widgets:text-widget
                                              :font font
                                              :framebuffer framebuffer
                                              :x-position (nth-value 0 (mezzanine.gui.widgets:frame-size frame))
                                              :y-position (nth-value 2 (mezzanine.gui.widgets:frame-size frame))
                                              :width (- (mezzanine.gui.compositor:width window)
                                                        (nth-value 0 (mezzanine.gui.widgets:frame-size frame))
                                                        (nth-value 1 (mezzanine.gui.widgets:frame-size frame)))
                                              :height (- (mezzanine.gui.compositor:height window)
                                                         (nth-value 2 (mezzanine.gui.widgets:frame-size frame))
                                                         (nth-value 3 (mezzanine.gui.widgets:frame-size frame))
                                                         2
                                                         (mezzanine.gui.font:line-height font))
                                              :damage-function (mezzanine.gui.widgets:default-damage-function window)))
                 (input-pane (make-instance 'mezzanine.gui.widgets:text-widget
                                            :font font
                                            :framebuffer framebuffer
                                            :x-position (nth-value 0 (mezzanine.gui.widgets:frame-size frame))
                                            :y-position (+ (nth-value 2 (mezzanine.gui.widgets:frame-size frame))
                                                           (- (mezzanine.gui.compositor:height window)
                                                              (nth-value 2 (mezzanine.gui.widgets:frame-size frame))
                                                              (nth-value 3 (mezzanine.gui.widgets:frame-size frame))
                                                              (mezzanine.gui.font:line-height font)
                                                              1))
                                            :width (- (mezzanine.gui.compositor:width window)
                                                      (nth-value 0 (mezzanine.gui.widgets:frame-size frame))
                                                      (nth-value 1 (mezzanine.gui.widgets:frame-size frame)))
                                            :height (mezzanine.gui.font:line-height font)
                                            :damage-function (mezzanine.gui.widgets:default-damage-function window)))
                 (irc (make-instance 'irc-client
                                     :fifo fifo
                                     :window window
                                     :frame frame
                                     :display-pane display-pane
                                     :input-pane input-pane)))
            ;; Line seperating display and input panes.
            (mezzanine.gui:bitset 1 (- (mezzanine.gui.compositor:width window)
                                       (nth-value 0 (mezzanine.gui.widgets:frame-size frame))
                                       (nth-value 1 (mezzanine.gui.widgets:frame-size frame)))
                                  #xFF808080
                                  framebuffer
                                  (+ (nth-value 2 (mezzanine.gui.widgets:frame-size frame))
                                     (- (mezzanine.gui.compositor:height window)
                                        (nth-value 2 (mezzanine.gui.widgets:frame-size frame))
                                        (nth-value 3 (mezzanine.gui.widgets:frame-size frame))
                                        (mezzanine.gui.font:line-height font)
                                        2))
                                  (nth-value 0 (mezzanine.gui.widgets:frame-size frame)))
            (mezzanine.gui.widgets:draw-frame frame)
            (mezzanine.gui.compositor:damage-window window
                                                    0 0
                                                    (mezzanine.gui.compositor:width window)
                                                    (mezzanine.gui.compositor:height window))
            (reset-input irc)
            (unwind-protect
                 (loop
                    (handler-case
                        (dispatch-event irc (mezzanine.supervisor:fifo-pop fifo))
                      (error (c)
                        (ignore-errors
                          (format (display-pane irc) "~&Error: ~A~%" c)))))
              (when (irc-connection irc)
                (close (irc-connection irc))))))))))

(defun spawn ()
  (mezzanine.supervisor:make-thread 'irc-main
                                    :name "IRC"))
