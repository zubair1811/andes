;; Author(s):
;;   Mike Ringenberg (mr) <
;;   Linwood H. Taylor (lht) <lht@lzri.com>
;;   Anders Weinstein (a?w) <andersw+@pitt.edu>
;; Modified:
;;   unknown - created
;;   7 February 2001 - (lht) - editing for documentation and new help dialog
;;   ?????????? 2001 - (a?w) - added fucntionality fro debugging and added
;;                             support for symbol table processing
;;   23 April 2001 - (lht) - renamed from tcp-wb.lsp to Andes-Main.cl
;;                           adding some polishing to support final code
;;    5 June 2001 - (lht) - editied to load/initialize new parseing/etc.
;;; Modifications by Brett van de Sande, 2005-2008
;;; Copyright 2009 by Kurt Vanlehn and Brett van de Sande
;;;  This file is part of the Andes Intelligent Tutor Stystem.
;;;
;;;  The Andes Intelligent Tutor System is free software: you can redistribute
;;;  it and/or modify it under the terms of the GNU Lesser General Public 
;;;  License as published by the Free Software Foundation, either version 3 
;;;  of the License, or (at your option) any later version.
;;;
;;;  The Andes Solver is distributed in the hope that it will be useful,
;;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;  GNU Lesser General Public License for more details.
;;;
;;;  You should have received a copy of the GNU Lesser General Public License
;;;  along with the Andes Intelligent Tutor System.  If not, see 
;;;  <http:;;;www.gnu.org/licenses/>.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Andes-Main.lsp/cl - functions that setup, maintain, terminate, and generally
;;   handle the communication between the workbench and the Andes2 help system
;;   using TCP/IP sockets and streams.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(in-package :cl-user)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; from sockets.lisp by Kevin M. Rosenberg
(eval-when (:compile-toplevel :load-toplevel :execute)
  #+sbcl (require :sb-bsd-sockets)
  #+lispworks (require "comm")
  #+allegro (require :socket))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Global Variables 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; *andes-path* -- pathname of directory in which Andes files are installed
;;                 as logical pathname object
;; In the runtime image this will be set on startup to the working directory 
;; of the Lisp process -- see top of andes-start.  The workbench sets process 
;; working directory when it launches the help system.

(defun andes-path (relative-path)
"merge relative path with *andes-dir* returning new pathname"
    (merge-pathnames relative-path *andes-path*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Global Variables -- TCP socket and stream variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defvar *andes-socket* nil
  "The TCP/IP socket that this application sets up to service help requests.")

(defvar *andes-stream* nil
  "The stream that represents the character socket that serves help requests.")

(defvar *debug-help* t
  "The stream showing help system runtime activities.")

(defparameter &andes-port& 12345 ;; default port number from workbench code.
  "The port where the help system listens for help requests.")

;; Command designators on the TCP stream
(defparameter &exec& #\?) ;; client -> server, want result
(defparameter &reply& #\<) ;; client <- server EXEC reply
(defparameter &NACK& #\*) ;; client <- server EXEC failure reply
(defparameter &NOTIFY& #\!) ;; client -> server, no result
(defparameter &cmd& #\!) ;; client <- server, no result (same as NOTIFY)

;; used by event loop:
(defvar *task-list* nil)		;queue of background tasks -- unused in Andes2
(defvar *andes-stop* nil		;exit flag to shut down event loop
  "startAll will loop main-event-loop until this is true")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function Definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; initiate-server -- To setup the help server.  Use in system initialization.
;; argument(s):
;;   NONE
;; returns:
;;   nil
;; note(s):
;;   creates passive socket on &andes-port& port on machine running on.
;;   a dynamic port would be better but there is no easy way to tell WB
;;     what port is
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Stolen from sockets.lisp by Kevin M. Rosenberg
#+sbcl
(defun listen-to-inet-port (&key (port 0) (kind :stream) (reuse nil))
  "Create, bind and listen to an inet socket on *:PORT.
setsockopt SO_REUSEADDR if :reuse is not nil"
  (let ((socket (make-instance 'sb-bsd-sockets:inet-socket
			       :type :stream
			       :protocol :tcp)))
    (if reuse
        (setf (sb-bsd-sockets:sockopt-reuse-address socket) t))
    (sb-bsd-sockets:socket-bind 
     socket (sb-bsd-sockets:make-inet-address "0.0.0.0") port)
    (sb-bsd-sockets:socket-listen socket 15)
    socket))

;; Stolen from sockets.lisp by Kevin M. Rosenberg
(defun close-passive-socket (socket)
  #+allegro (close socket)
  #+clisp (close socket)
  #+cmu (unix:unix-close socket)
  #+sbcl (sb-unix:unix-close
	  (sb-bsd-sockets:socket-file-descriptor socket))
  #+openmcl (close socket)
  #-(or allegro clisp cmu sbcl openmcl)
  (warn "close-passive-socket not supported on this implementation")
  )

(defun initiate-server ()
  "Sets-up the TCP socket on the local machine at the &andes-port& port."
  (setq *andes-stop* nil) ;; so it doesn't immediately shutdown
  (if (not *andes-socket*)
      (setq *andes-socket*
	;; see create-inet-listener in sockets.lisp by Kevin M. Rosenberg
	#+allegro
	(socket:make-socket :connect :passive
	                    :backlog 1
			    :reuse-address &andes-port&
			    :local-port &andes-port&)
	#+cmu (ext:create-inet-listener &andes-port&)
	#+sbcl
	(listen-to-inet-port :port &andes-port& :reuse &andes-port&)
	#+clisp (ext:socket-server &andes-port&)
	#+openmcl 
	(ccl:make-socket :connect :passive :local-port &andes-port&
			 :reuse-address  &andes-port&)
	#-(or allegro clisp cmu sbcl openmcl)
	(warn "create-inet-listener not supported on this implementation")
	))
  (format *debug-help* "~&Opened socket: ~S~%" *andes-socket*) t)

(defun await-passive-connection ()
"start listening server and wait until a connection"
    (initiate-server)
    (connection-started))

(defun make-active-connection (port)
"connect actively to the given port"
  (setq *andes-stop* nil) ;; so it doesn't immediately shutdown
  (format *debug-help* "~&Attempting connection to workbench on port ~A~%" port)
  (handler-case		; socket calls throw errors on failure to connect
     (setq *andes-stream*
	   #+allegro
	   (socket:make-socket :remote-host "127.0.0.1" :remote-port port)
	   #-allegro 
	   (error "Andes2-main.cl: make-active-connection only implemented for Allegro"))
   (error (c) 
    	(error-message (format nil "~A Quitting" c))
	(andes-stop))  ; set flag to quit event loop immediately
   (:no-error (c)
         (declare (ignore c))
         (format *debug-help* "~&Opened stream: ~S~%" *andes-stream*))))
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; terminate-server -- closes the open stream and socket to the workbench
;;    as gracefully as we can.
;; argument(s):
;;   NONE
;; returns: nil
;; note(s): Closes *andes-stream* and *andes-socket*.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun terminate-server ()
  "Closes *andes-stream* and *andes-socket* gracefully."
  (when (and *andes-stream* (open-stream-p *andes-stream*))
    (finish-output *andes-stream*)
    (close *andes-stream*))
  (setq *andes-stream* nil)
  (if *andes-socket* (close *andes-socket*)) ;Close the socket.
  (setq *andes-socket* nil))		;leaves *andes-stop* true

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; run - runs main event handling loop for the server process
;; argument(s): nil
;; returns: Garbage
;; Execute after server initialized and connection established with client.
;; Interleaves execution of delayed tasks with polling for and dispatching
;; input events. This loop doesn't normally terminate until some event
;; handler sets the *andes-stop* termination flag
;; Note: In the Lisp IDE, hitting return to get a top-loop prompt for debugging
;; unwinds out of the event handler. Can call "run" again to restart loop.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun andes-run ()
  "Executes delayed tasks and listens for new events on the stream to process."
  (unless *andes-stop*
     (format *debug-help* "~&Running server event processing loop~%"))
  (unwind-protect
      ;; outer loop just repeats forever until server termination flag gets 
      ;; set or connection no longer exists.
      (loop until (or *andes-stop* 
                      (not (connection-running)))
	  do
	    ;; 1: loop to drain all pending work from our queue by interleaving
	    ;; execution of delayed tasks from task queue with polling and 
	    ;; dispatching of ready input events from the command stream.
	    (loop until (null *task-list*)
		do (eval (pop *task-list*)) ;tasks can have side-effects
		   ;; handle input events while draining the task queue.
		   (process-stream-event :blocking nil))
	    ;; 2: no work to do right now
	    ;; Do blocking wait on next command so lisp process does not domi- 
	    ;; nate the system's resources busy-waiting when no work to do.
	    (process-stream-event :blocking t))

    ;; protected post-loop cleanup: Note could have unwound out of loop to here
    ;; after error.  In runtime image, always just terminate
    #+allegro-cl-runtime (andes-terminate)
    ;; Otherwise make sure session was normally ended before we terminate 
    ;; server instance.  In interactive Lisp can restart loop after throwing 
    ;; out of error to continue.
    #-allegro-cl-runtime 
    (if (not *andes-stop*)
       (format *debug-help* 
              "~&Exited server event loop! Call \"andes-run\" to resume event processing~%")
     (andes-terminate)))) 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; process-stream-event - Listens for message on *andes-stream* and then exe-
;;    cutes it as a command.
;; argument(s):
;;    &key :blocking : if true, function will wait for an event. default nil.
;; returns: Garbage
;; note(s): If there is an error on the stream, it tries to handle it. 
;;          It starts the process of executing the command on the stream.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun process-stream-event (&key blocking)
  "Listens for a message on *andes-stream* and then executes it as a command."
  (let ((fbd-message nil))
    ;; determines if it should wait for a message or just return unless
    ;; there is a message.
    (when (or blocking (listen *andes-stream*))
      (setq fbd-message 
	(handler-case (read-line *andes-stream*) ;; get command string
	  ; we normally terminate on the "exit-andes" API call before we 
	  ; read EOF on the socket, so have never seen this happen:
	  (end-of-file (condition) 
	    (error-message
	     (format
	      nil
	      "stream termination on ~S.~%Exiting Andes help gracefully.~%"
	      (stream-error-stream condition)))
	    (andes-stop)	; sets stop flag to andes-run loop
	    NIL)		; no message to process in this case
          ; Can happen for connection reset; remote crash, net failure:
	  (error (condition) 
	    (error-message 
	      (format NIL "Unexpected error: ~A~%Andes help quitting."
	              condition))
	     (andes-stop)	; sets stop flag to andes-run loop
	     NIL)))		; no message to process in this case

      ; if got message OK, then execute it 
      (when fbd-message
        (execute-stream-event fbd-message)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function: execute-stream-event
;; Parameters: str: a string containing the message from the workbench
;; Purpose: This function determines what to do with a command message string 
;;          based on the tag at the head of the string.  It is also
;;          responsible for removing the tag.
;; returns: Garbage
;; Side Effects: If the string is a notify command, it attempts to execute it.
;;               If it is a execute command, it will execute it and return the
;;               results to *andes-stream*.  Gives an error message on unknown
;;               command types.  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun execute-stream-event (str)
  "Determines from the 1st char of string how to handle the message"
  (format *debug-help* "Stream-event ~A~%" str)
  (cond ((string= str &notify& :end1 1)	;Workbench does not expect a reply
	 (dispatch-stream-event (remove &notify& str :count 1)))
	((string= str &exec& :end1 1)	;Workbench expects reply
	 (dispatch-and-return-stream-event (remove &exec& str :count 1)))
	(t (error-message
	    (format nil "unrecognized command: ~A" str)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function: dispatch-stream-event
;; Parameters: command-string: a string containing a lisp function call
;;             dde:  t/nil indicating whether this is a dde (needs reply
;;                   or a dde-post (no reply needed).
;; Purpose: To safely execute a command from the workbench, return the result
;;          of the function call, and to do some book-keeping.
;; returns: Results of the function call or :error if failed.
;; Side Effects: Signals errors when execution fails, executes command in the
;;               command-string which might have side effects, records the
;;               time the command was executed, and updates the help system's
;;               records.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun dispatch-stream-event (command-string &key (dde Nil))
  "Reads the string and tries to execute it, returns the result of the execution while also performing some bookkeeping."
  ;; AW: we used to preprocess command string to ensure it could be passed safely through
  ;; Lisp reader, which we use to parse it into a list of Lisp objects. This was particularly
  ;; an issue for equation box contents, which could contain characters like quotes that confuse read.
  ;; Now we just it to the workbench to ensure all arguments in command strings are properly
  ;; escaped for Lisp.  Still, wrap the work in safe-apply to recover in case of error in Lisp read.
  (safe-apply 'do-dispatch-stream-event (list command-string dde)))

(defun do-dispatch-stream-event (command-string dde)
  (let ((cmd-obj (read-from-string command-string))) 
    (format *debug-help* "~&~%Executing ~A~%(Apply ~W ~W)~%" command-string (first cmd-obj) (rest cmd-obj))
    ;; Pass parsed call to to the main dispatch wrapper in interface.cl
    (execute-andes-command (first cmd-obj) (rest cmd-obj) dde)))


     
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; For runtime dist, trap all Lisp errors and return special :error value
;; instead. When debugging, just use apply to debug on errors.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#+allegro-cl-runtime 
(defvar *ignore-errors* T)	; T => trap LISP errors in command execution
#-allegro-cl-runtime 
(defvar *ignore-errors* NIL)    

;; Apply function to args, trapping Lisp errors and returning :error in this
;; case as controlled by *ignore-errors* flag
(defun safe-apply (fn &optional (args nil)) 
  (if (not *ignore-errors*) 
      (apply fn args)
  ; else trap errors
  (let (result)
    (handler-case 
	(setf result (apply fn args))
      (error (c) 
    	(error-message (format nil "Executing command: ~A" c))
        :error)
      (:no-error (c) 
	(declare (ignore c))
    	result)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function: dispatch-and-return-stream-event
;; Parameters: command-string: a string containing a lisp function call
;; Purpose: To execute the command and return the results on *andes-stream*
;; returns: garbage
;; Side Effects: Signals errors when there was a caught error on the execution
;;               of the command, makes sure that the stream is not being
;;               buffered, and writes the results of the execution onto the
;;               stream with the message id and type identifier.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun dispatch-and-return-stream-event (command-string)
  "Dissects a command string to pull out the message id, executes the command, and prints the results with id to *andes-stream*"
  (let* ((id (subseq command-string 0 (position #\: command-string)))
	 (cmd (subseq command-string (+ (position #\: command-string) 1)))
	 ;; Execute the DDE passing the fact that it is a dde on to the
	 ;; Dispatch-stream-event call.
	 (results (dispatch-stream-event cmd :DDE t)))
    (cond ((eq results :error) ;; If there was a problem executing the string
	   (format *debug-help* "~&Returned: ~A~A: for ~A~%"
		   &nack& id command-string)
	   (format *andes-stream* "~A~A:~%" &nack& id)) ;; return negative ack
	  (t ;; otherwise, simply print the results to the stream.
	   (format *debug-help* "~&Returned: ~A~A:~A~%" &reply& id results)
	   (format *andes-stream* "~A~A:~A~%" &reply& id results)))
    ;; push the text onto the stream to prevent buffering
    (force-output *andes-stream*)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function: send-fbd-command
;; Parameters: command: a string containing a command that the workbench
;;                      understands.
;; Purpose: To send an unsolicited command to the workbench.
;; returns: Garbage (nil)
;; Side Effects: Prints the command to *andes-stream* and then lushes the
;;               output buffer.
;; IMPORTANT: Do not use this method to send a command 
;; that will put the interface in a modal loop (such as opening a
;; dialog box) if it is waiting for a return result from the 
;; help system. This will result in losing the help system's return
;; value. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun send-fbd-command (command)
  "Sends a command to the workbench using *andes-stream*."
  (format *debug-help* "Sending: ~A~A~%" &cmd& command)
  (format *andes-stream* "~A~A~%" &cmd& command)
  (finish-output *andes-stream*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; connection-started -- checks to see if *andes-socket* has a connection
;;  request and waits until a connection is established.
;;  Sets *andes-stream* if a connection to *andes-socket* was established.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun connection-started ()
  "Checks to see if *andes-socket* has a connection request. Optionally waits until a connection is established."
  (if 
      (setq *andes-stream* 
	;; See accept-tcp-connection in sockets.lisp by Kevin M. Rosenberg
	;; The default character encoding (in *locale*) works for "Amp`ere"
	#+allegro (socket:accept-connection *andes-socket* :wait t)
	#+clisp (ext:socket-accept *andes-socket* )
	#+cmu
	(progn (mp:process-wait-until-fd-usable *andes-socket* :input)
	       (sys:make-fd-stream
		(nth-value 0 (ext:accept-tcp-connection *andes-socket*)) 
		:input t :output t))
	#+sbcl
	(when (sb-sys:wait-until-fd-usable
	       (sb-bsd-sockets:socket-file-descriptor *andes-socket* ) :input)
	  (sb-bsd-sockets:socket-make-stream 
	   (sb-bsd-sockets:socket-accept  *andes-socket* )
	   :element-type 'base-char :input t :output t
	   ;; The workbench uses an older windows-specific 
	   ;; character encoding.  This is an issue for "Amp`ere"
	   :external-format :windows-1252))	
	#+openmcl 
	(ccl:accept-connection *andes-socket* :wait t) 
	#-(or allegro clisp cmu sbcl openmcl)
	(warn "accept-tcp-connection not supported on this implementation")
	)
      (progn 
	(format *debug-help* "~&Opened stream: ~S~%" *andes-stream*) 
	;; try to close the listening socket immediately, 
	;; since we only handle one connection -- you have to 
	;; start-andes again to run another session
	(close-passive-socket *andes-socket*)
	(setq *andes-socket* NIL)
	t)				;return success:
    (warn "No connection started")))	;return failure

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Function: connection-running
;; Parameters: nil
;; Purpose: To check *andes-stream* to see if the connection is still open.
;; returns: t: if stream is still open.
;;          nil: if the stream is nil or closed.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun connection-running ()
  "Checks to see if *andes-stream* is still open."
  (and *andes-stream* (open-stream-p *andes-stream*)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This was applied to incoming raw command strings as defense before passing 
;; it through read-from-string: escape comma and backslash, which will interfere
;; with parsing into objects by Lisp read. This simple method applies this blindly 
;; throughout the string, without taking into account whether it occurs within
;; vbar-delimited symbol, or quote-delimited string, for example. 
;;
;; This should not be necessary now that the workbench tries to ensure that 
;; arguments in all command strings are sent in a Lisp-readable form.
;; That was not done perfectly in past versions of Andes; in particular,
;; bad chars in student-typed-equation box contents used to crash the helpsys.
;; Should be safer now, and problems should be fixed on workbench side.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun escape-special-characters (string)
  (loop for i from 0 to (1- (length string))
      with special = '(#\, #\\)
      appending
	(let ((c (char string i)))
	  (if (member c special) (list #\\ c)
	    (list c)))
      into newstring
      finally (return (concatenate 'string newstring))))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; dummy 'main' or begin function
;;
;; if wb-port is specified, make an active connection to that port on
;; local host so as to attach to a running workbench listening on that port. 
;; Otherwise we listen for connections as a server on the default port
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun andes-start (&key wb-port)
  "initialize the andes help system server state"
  (andes-init)
  ; in runtime version: wb can pass a port number in to us on command line
  ; in which case we will actively connect to that port. 
  #+allegro-cl-runtime (when (>= (sys:command-line-argument-count) 2)
                         (setf wb-port
                           (read-from-string (sys:command-line-argument 1))))
  (if wb-port (make-active-connection wb-port)
     (await-passive-connection))
  (andes-run)
  ;; andes-run should always call andes-terminate when done so following 
  ;; shouldn't be necessary, but shouldn't hurt to be safe just in case
  #+allegro-cl-runtime (exit 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Andes-init (CL)
;; Initialize Andes for execution but do not start the tcp server.  This is 
;; called directly only when using the HelpDriver to execute Andes within the
;; same lisp process.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(defun andes-init ()
  "initialize the andes help system server state"
  ;; Set the base help system time
  (setq **base-Htime** (universal-time->htime (get-universal-time)))
  
  ;; Mainly for safety in runtime image: ensure Lisp reads floating point 
  ;; numbers into doubles, no matter what setting had been in effect before.
  (setq *read-default-float-format* 'double-float)
  
  ;; in runtime version only: set *andes-path* to process working directory
  #+allegro-cl-runtime (setf *andes-path* 
			     (make-pathname :host (pathname-host *default-pathname-defaults*)
					    :device (pathname-device *default-pathname-defaults*)
					    :directory (pathname-directory *default-pathname-defaults*)
					    :name nil :type nil))
  ;; We also fix up the AndesModule system's compiled-in base-name var 
  ;; (set when helpsys was built) so runtime use loads from the runtime 
  ;; Andes directory.
  #-asdf (setf *Base-Andes-Module-Path* (namestring *andes-path*))
  (format T "Starting Andes, *andes-path* = ~A~%" *andes-path*)
  (doSafety :in2pre)
  (solver-load)
  (solver-logging *solver-logging*)
  (physics-algebra-rules-initialize) ;initialize grammar
  (enable-errors)
  )

(defun andes-stop ()
"set the exit flag to cause the server to exit event loop"
  (setq *andes-stop* t))

(defun andes-terminate ()
"terminate this instance of the help server on session end"
  (terminate-server)
  (solver-unload)
  (format *debug-help* "~&Andes session finished!~%")
  ; in runtime version only: exit Lisp when session is done
  #+allegro-cl-runtime (exit 0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; end of file Andes-Main.lsp/cl
;; Copyright (C) 2001 by <Linwood H. Taylor's Employer> - All Rights Reserved.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;