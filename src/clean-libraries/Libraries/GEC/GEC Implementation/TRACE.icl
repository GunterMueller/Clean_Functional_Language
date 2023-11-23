implementation module TRACE

import Debug

TRACE_ON :== False		// Set this value to True for having TRACE values.

show	=
	debugShowWithOptions []
TRACE :: !value_to_print !.y -> .y
TRACE x y
	| TRACE_ON
		= KSTAR (debugValue show x) y
	| otherwise
		= y

DO_TRACE :: !value_to_print !.y -> .y
DO_TRACE x y = KSTAR (debugValue show x) y

KSTAR :: !value_printed !.y -> .y
KSTAR x y = y
