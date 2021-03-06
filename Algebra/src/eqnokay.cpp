// neweqnokay.cpp    
//	new version of indyIsStudEqnOkay, 
//	new version of indyAddStudEq
// 	new function isEqnAnAssign
//        
// Copyright (C) 2001 by Joel A. Shapiro -- All Rights Reserved
// Modifications by Brett van de Sande, 2005-2008
//
//  This file is part of the Andes Solver.
//
//  The Andes Solver is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  The Andes Solver is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with the Andes Solver.  If not, see <http://www.gnu.org/licenses/>.

#include "decl.h"
#include "dbg.h"
#include "extstruct.h"
#include "unitabr.h"
#include <math.h>
#include "indysgg.h"
#include "extoper.h"
#include "valander.h"

using namespace std;

#define DBG(A) DBGF(INDYEMP,A)

// return values from 
#define UNPARSEABLE "not used"
#define OKAY 0
#define NOTANEQ 32
#define UNITSNG 8
#define NOTANSOK 4	// not within looser answer value error bars, see ANSERR
#define IMPREC 1
#define VERYNG 1
// note VERYNG is only added if IMPREC has already been

// Relative error used for answer values in Andes: Since +/- ANSERR*value is
// applied to BOTH sides of an answer giving equation, the effective range for
// answers winds up +/- 2*ANSERR*value.  Now want answer within 0.5% of calculated 
// value, to be closer to a 3-significant figures criterion. Perhaps better to
// provide way for caller to adjust this parameter, but for now define it here.
static const double ANSERR = 0.0025;

// return values from indyAddStudEq
#define ADDEDEQN 0
#define SLOTEMPTIED 1
#define NOSUCHSLOT 2
#define NOPARSE 3
// currently impossible - an exception is thrown instead
#define EQNNOTOK 4
#define SINGULAR "not used"
// SINGULAR currently causes an exception if gradient is undefined, so
//   SINGULAR is never returned

// in extstruct: canonvars, canoneqf, studeqf
extern vector<valander *> studgrads;
extern bool gotthevars;					// in indysgg.cpp
binopexp * getAnEqn(const string bufst, bool tight);	// in getaneqwu.cpp
bool getStudEqn(int slot, const string bufst);		// in getaneqwu.cpp
int checksol(const binopexp* const eqn, 		// in checksol.cpp
	     const vector<double>* const sols, const double reltverr);
numvalexp * getfromunits(const string & unitstr);	// in unitabr.cpp


/************************************************************************
 *  indyIsStudEqnOkay(equation)
 *     
 *         it doesn't evaluate a gradient
 *         it doesn't add anything to slots
 ************************************************************************/
int indyIsStudEqnOkay(const char * const equation) {
  DBG(cout << "indyIsStudentEquation asked about " << equation << endl;);
  // ensure that any variables to be added have been (as well as we can <g>)
  if (! gotthevars) {
    throw(string("indyIsStudEqnOkay called before indyDoneAddVar"));
  }
  int retval = OKAY;
  // check that all can be parsed --- should always be the case
  // otherwise implies bug in caller
  binopexp * theeqn =  getAnEqn(equation,true);
  // currently getAnEqn throws exceptions rather than returning NULL, 
  // so never returns UNPARSEABLE
  if (theeqn->op->opty != equalse) { return(NOTANEQ); }
  expr* eqexpr = (expr*)theeqn;
  expr * trouble = dimenchk(true,eqexpr);
  if (trouble != (expr *) 0L) {
    DBG(cout << "dimensional inconsistency at " << trouble->getInfix() 
             << endl;);
    retval += UNITSNG;
  }
  if (checksol((binopexp*)eqexpr, numsols, ANSERR) > 0) retval += NOTANSOK;
  if (checksol((binopexp*)eqexpr, numsols, RELERR) > 1) retval += IMPREC;
  if (checksol((binopexp*)eqexpr, numsols, 100 * RELERR) > 1) retval += VERYNG;

  if (retval >= UNITSNG)	// see if more lax units parsing would help
    {
      theeqn->destroy();
      theeqn =  getAnEqn(equation,false);
      eqexpr = (expr*)theeqn;
      trouble = dimenchk(true,eqexpr);
      if (trouble != (expr *) 0L) {
	DBG(cout << "bad dimensional inconsistency at " << trouble->getInfix() 
             << endl;);
	retval += UNITSNG;
      }
    }
  theeqn->destroy();
  DBG(cout << "Returning " << retval << " from indyIsStudEqnOkay" << endl;);
  return(retval);
}

/************************************************************************
 * indyAddStudEq(int slot, const char* const equation)			*
 *     places the student equation given in Lisp form in canonical      *
 *     variables by the string equation, into the student slot slot.	*
 *   Aborts if indyDoneAddVar has not already been called		*
 *   Each equation is inserted in studeqsorig[slot], although this is	*
 *     currently not used. If the string is empty, we clear the slot	*
 *     in studeqf and studgrads. Otherwise				*
 *   equation is converted to expr form and placed in studeqf[slot],	*
 *      by a call to getStudEqn, and its gradient at the solution point *
 *      is calculated and stored in studgrads[slot]			*
 ************************************************************************/
int indyAddStudEq(int slot, const char* const equation) {
  DBG(cout << "indyAddStudEq asked to add to slot " << slot
      << " the equation" << endl;);

  // ensure that any variables to be added have been (as well as we can <g>)
  if (! gotthevars) {
    throw(string("indyAddStudEq called before indyDoneAddVar"));
  }

  // ensure slot specified is within bounds
  if ((slot < 0) || (slot > HELPEQSZ)) {
    DBG(cout << "indyAddStudEq returning NOSUCHSLOT" << endl;);
    return(NOSUCHSLOT);
  }

  studeqsorig[slot]->assign(equation);
  // if equation is an empty string (or a NIL) empty slot
  if ((strlen(equation) == 0) || 
      (strcmp(equation,"NIL")== 0)) { // if empty we'll delete
    if (studeqf[slot]) { // It really means empty out
      studeqf[slot]->destroy(); // what had been there.
      studeqf[slot] = 0L;
    }
    if (studgrads[slot]) {
      delete studgrads[slot]; // (lht) was studeqf[slot];
      studgrads[slot] = 0L;
    }
    DBG(cout << "indyAddStudEq returning SLOTEMPTIED" << endl;);
    return(SLOTEMPTIED);
  }

  // check that all can be parsed --- should always be the case
  // otherwise implies bug in caller
  if (! getStudEqn(slot, equation)) {
    DBG(cout << "indyAddStudEq returning NOPARSE" << endl;);
    return(NOPARSE); // throw(string("Couldn't parse ") + string(equation));
  }

  // equation is not an equation
  if ((studeqf[slot]->etype != binop) || 
      ((binopexp*)studeqf[slot])->op->opty != equalse) {
    DBG(cout << "indyAddStudEq returning EQNNOTOK" << endl;);
    return(EQNNOTOK);
  }
  // What if derivative is singular at numsol?
  studgrads[slot] = getvnd(studeqf[slot], canonvars, numsols);
  DBG(cout << "indyAddStudEq returning OKAY" << endl);
  return(OKAY);
}

//   not done Linn is doing it      bool isEqnAnAssign(slotID) {

  
