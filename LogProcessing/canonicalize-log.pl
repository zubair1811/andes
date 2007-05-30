#!/usr/bin/perl
#
#   Modify log file to a canonical form for comparision via diff
#   Some of the canonicalizations are only needed for comparision with
#   logs generated by older versions of Andes.
#

while (<>) {   # loop over lines in all Andes sessions
    # canonicalize unbound variables that should have
    # been bound, fixed May 2007
    if(m/^([\d:]+)\tDDE-COMMAND assoc \(GOAL /) {
	s/\(VARIABLE [^ ]+ /\(VARIABLE \*VAR\* /;
	s/\(FORCES ([^ ]+ [^ ]+) [^ )]+/\(FORCES $1 \*VAR\*/;
        s/\(TORQUES ([^ ]+ [^ ]+ [^ ]+) [^ )]+/\(TORQUES $1 \*VAR\*/;
        # hard to match this, so kill rest of line
	s/\(COMPO-EQN-SELECTED [^\r]+/\(COMPO-EQN-SELECTED \*REST\*))/;
	s/\(EQN [^ (]+ /\(EQN \*VAR\* /;
        s/\(VECTOR-DIAGRAM [^ ]+ /\(VECTOR-DIAGRAM \*VAR\* /;
    }


    # canonicalize randomized phrases.  This should be fixed
    # by explicit problem-specific seed to random-elt, March 2007.
    if(m/^([\d:]+)\tDDE-RESULT |!show-hint /) {
        # random-positive-feedback
	s/Good!|Right\.|Correct\.|Yes\.|Yep\.|That's right\.|Very good\.|Right indeed\./\*YES\*/;
        # random-goal prefix
        s/Try |You should be |A good step would be |Your goal should be /\*TRY\* /;
    }

    print;
} #loop over lines in all sessions
