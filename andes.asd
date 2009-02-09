;;;; -*- Lisp -*-
;;;; above sets emacs major mode to Lisp
;;;;
;;;; Use this to compile:
;;;;  (asdf:operate 'asdf:load-op 'andes)
;;;; or use command (rkb) if it is defined.
;;;  To turn on solver logging:  :cd ~/Andes2/ 

(in-package :cl-user)
(defpackage :andes-asd (:use :cl :asdf))
(in-package :andes-asd)

;;;;   Load the source file, without compiling
;;;;   asdf:load-op reloads all files, whether they have been
;;;;   changed or not.

(defclass no-compile-file (asdf:cl-source-file) ())
(defmethod asdf:perform ((o asdf:compile-op) (s no-compile-file))
  nil)
(defmethod asdf:output-files ((o asdf:compile-op) (s no-compile-file))
  (list (component-pathname s)))

;;;
;;;  Add directory of problem files to  
;;;


(defsystem :andes
  :name "Andes"
  :description "Andes physics tutor system"
  :components (
;;;    this should eventually be removed
	       (:file "andes-path")
	       (:module "Base"
;;;			:description "Common Utilities"
			:components ((:file "Htime")
				     (:file "Unification")
				     (:file "auxiliary")
				     (:file "hash")
				     (:file "Utility")))
	       (:module "Algebra"
			;; this depends on uffi
			:components ((:file "solver")))
	       (:module "HelpStructs"
			:depends-on ("Base")
			:components ((:file "PsmGraph")
				     (:file "SystemEntry"
					    :depends-on ("PsmGraph"))
				     ))
	       (:module "Knowledge"
			:depends-on ("Base" "HelpStructs")
			:components ((:file "eqn")         
				     (:file "Nogood")    
				     (:file "Operators")  
				     (:file "qvar")
				     (:file "BubbleGraph" 
				     ;; also depends on HelpStructs
					    :depends-on ("qvar" "eqn"))  
				     (:file "ErrorClass")  
				     ;; NLG not defined
				     (:no-compile-file "Ontology")  
				     (:file "Problem") ;depends on HelpStructs
				     (:file "Solution")))	       
	       (:module "KB"
;;;	    	:description "Knowledge Base"
			:depends-on ("Knowledge" "Base")
			:default-component-class no-compile-file
  			:serial t  ;real dependancies would be better
			:components (
				     ;; treat these as normal lisp files
				     (:cl-source-file "Physics-Funcs")
				     (:cl-source-file "makeprob")        
				     
				     ;; must be before any ontology
				     (:file "reset-KB")
				     (:file "features")
				     (:file "principles")
				     (:file "constants")
				     ;; lots of outside dependencies:
				     (:cl-source-file "errors")
				     ;; TELL and NLG not defined
				     (:file "Ontology" )
				     (:file "circuit-ontology")  
				     ;; AXES-DRAWNP not defined
				     (:file "problem-solving")
				     (:file "kinematics")
				     (:file "dynamics")
				     (:file "vectors")
				     (:file "NewtonsNogoods")  
				     (:file "fluids")
				     (:file "waves")
				     (:file "work-energy")
				     (:file "optics")          
				     (:file "circuits")
				     (:file "momentum-impulse")
				     (:file "electromagnetism")          
				     ))
	       (:module "SGG"
;;;			:description "Solution Graph Generator" 
			:depends-on ("Base" "Knowledge" "HelpStructs" "Algebra")
			:components (
				     (:file "Qsolver") ;depends on HelpStructs
				     (:file "Exec" 
					    :depends-on ("Qsolver"))
				     (:file "Macros"
					    :depends-on ("Qsolver"))         
				     (:file "SolutionPoint")
				     (:file "GraphGenerator")
				     (:file "ProblemSolver")
				     (:file "print-solutions")
				     (:file "SolutionSets")))
))

;;;  make lisp source file extension "cl"  See asdf manual

(defmethod source-file-type ((c cl-source-file) (s (eql (find-system :andes))))
   "cl")
