;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; in2pre.cl -- routines for converting infix lists to prefix lists ... 
;;  facilities for special handling of unary, binary, stamp and other special 
;;  operators with additional functionality for supporting operator precedence.
;; Copyright (C) 2001 by <Linwood H. Taylor's Employer> -- All Rights Reserved.
;; Author(s):
;;  Linwood H. Taylor (lht) <lht@lzri.com>
;;  Collin Lynch (cl) <collinl@pitt.edu>
;; Modified:
;;  16 May 2001 - (lht) -- created
;;  12/6/2003 - (cl) -- removed unused vars that were causing compiler 
;;    warnings:
;;    in2pre-position-of-first now uses the Len variable.
;;    in2pre:  replaced "(if (not (null obj)) (let ((jnk nil))" statement 
;;             with a when.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; in2pre
;; argument(s):
;;  expression -- a list with infixed operators; an example of such a list:
;;           '((3 + 4) * 17 = 10 * 7 + 7 * 7)
;;  leaveAlone -- a list of atoms that specify lists that are not to be 
;;           translated.   For example: leaveAlone = '(stamp) would cause 
;;           the expression (4 + (stamp this & that)) to become 
;;           '(+ 4 (stamp this & that))
;;  unary -- a list of unary operators or functions; for example: if unary is 
;;           '(+ - sin) then '((4 + - 3) * sin 30) will translate as: 
;;           '(* (+ 4 (- 3)) (sin 30)
;;  binary -- a list of lists -- each sublist will be a list of operators and 
;;           their associativity.  The order of the lists implies their 
;;           precedence.  For example, if binary has the value:
;;           '(((= r)) ((+ r) (- r)) ((* r) (/ r)) ((^ l))) then we are 
;;           stating that ^ has the highest precedence and that the left-most 
;;           ^ should be considered first, the next highest in precedence will 
;;           be * and / with equal precedence and the right-most should be 
;;           considered first, and so on.
;;  special -- a list of symbols that are also the names of functions that will
;;           be called when encountered; the argument of the functions will be 
;;           a list of 5 elements: the first is the list which contains a 
;;           symbol in special and the remaining 4 are the same as the last
;;           four arguments sent to in2pre: as an example: we have a function 
;;           defined as:  (defun ditto (x) (car x)); special contains '(ditto)
;;           and the expression is:  '((5 + 4) * (ditto 30)) -- we will get 
;;           back '(* (+ 5 4) (ditto 30)) ... while this example seems to 
;;           duplicate both the functionality of unary and leaveAlone, special 
;;           provides a mechanism for treating subexpression in any fashion 
;;           whatsoever.
;;  returns a transformed expression the exact nature of this expression 
;;  relise heavily on the arguments specified
(defun in2pre (expression leaveAlone unary binary special)
  (Tell :in2pre "Begin ~W #~W #~W #~W #~W" expression 
	leaveAlone unary binary special)
  (let ((r nil));r is the final infixed expression
    (dolist (obj expression)
      (if (consp obj)
	  (cond
	   ((member (car obj) leaveAlone)
	    (Tell :in2pre "LeaveAlone ~W" obj)
	    (setf r (append r (list obj)))
	    (Tell :in2pre "  result ~W" r))
	   ((member (car obj) special)
	    (Tell :in2pre "Special ~W -- <~W>" obj r)
	    (setf r (append r (doSafe :in2pre (car obj) obj 
				      leaveAlone unary binary special)))
	    (Tell :in2pre "  result ~W" r))
	   ((member (car obj) unary)
	    (Tell :in2pre "Unary ~W" obj)
	    (setf r (append r (list
			       (cons (car obj)
				     (in2pre (rest obj) 
					     leaveAlone unary binary special)))))
	    (Tell :in2pre "  result ~W" r))
	   (t 
	    (Tell :in2pre "Binary ~W" obj)
	    (setf r (append r (in2pre obj leaveAlone unary binary special)))
	    (Tell :in2pre "  result ~W" r)))
	(when (not (null obj))
	  ;;  Formerly (if (not (null obj))
	  ;;  Jnk not needed  (let ((jnk nil))
	  (Tell :in2pre "Not List ~W" obj)
	  (setf r (append r (list obj)))
	  (Tell :in2pre "  result ~W" r))))
    (Tell :in2pre "Loop finished: ~W~%" r)
    (setf r (in2pre-support r leaveAlone unary binary special))
    (setf r (clean r))
    r))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; in2pre-support -- deals with binary operators primarily as all other issues 
;; are dealt with in
;;   in2pre
;; argument(s): as in2pre above
(defun in2pre-support (expression leaveAlone unary binary special)
  (Tell :in2pre-support "One ~W # ~W # ~W # ~W # ~W~%"
	expression leaveAlone unary binary special)
  (cond
   ((null binary) expression)
   (t
    (let* ((pl (in2pre-position-of-first (car binary) expression)) 
	   (p (if pl (first pl) nil)))
      (Tell :in2pre-support "<~W> ~W~%" p pl)
      (if p
	  (list (append (list (second pl))
			(in2pre-support (subseq expression 0 p) 
					leaveAlone unary binary special)
			(in2pre-support (subseq expression (+ p 1)) 
					leaveAlone unary binary special)))
	(in2pre-support expression leaveAlone unary (rest binary) special))))))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; in2pre-position-of-first returns the position of the operator to consider
;; argument(s):
;;  ops -- list of operators and their left-right associativity, '((+ r) (- r))
;;  expression -- the expression being searched.
;; returns:
;;  a list of the form (position(0-indexed) operator-matched 
;;                                          operators-associativity)
;; example(s):
;;  (position-of-first '((+ r) (- r)) '(a = b - c + 6)) will return (3 - r)
;; note:  if the operators have differing associativity the operators with 
;; right 
;; associativity are given preference
(defun in2pre-position-of-first (ops expression)
  (if ops
      (let ((p nil) (pt nil))
	(dolist (op ops)
	  (Tell :in2pre-position-of-first "~W" op)
	  (setf pt
	    (if (equal 'r (second op))
		(list (position (first op) expression)
		      (position (first op) expression)
		      (first op)
		      (second op))
	      (let* ((len (length expression))
		     (pos (position (first op) expression :from-end Len)))
		(if pos
		    (list (- Len (position (first op) 
					   expression :from-end Len) 1)
			  (position (first op) expression :from-end Len)
			  (first op)
			  (second op))
		  (list nil nil (first op) (second op))))))
	  (Tell :in2pre-position-of-first "In ~W" pt)
	  (if (not (first pt)) (setf pt nil))
	  (Tell :in2pre-position-of-first "Out ~W" pt)
	  (if pt (if p
		     (if (< (first pt) (first p))
			 (setf p pt))
		   (setf p pt)))
	  (Tell :in2pre-position-of-first "Out2 ~W" p))
	(if (and p (first p)) (rest p) nil))))
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; end of file in2pre.cl
;; Copyright (C) 2001 by <Linwood H. Taylor's Employer> -- All Rights Reserved.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
