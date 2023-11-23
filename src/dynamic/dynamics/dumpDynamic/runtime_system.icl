implementation module runtime_system;

import StdEnv;
import ExtArray;
import RWSDebugChoice;

ALIGNMENT					:== 4;

// ARRAYS
ARRAY_DESC_DESCP			:== 0;
ARRAY_DESC_SIZE				:== 4;
ARRAY_DESC_ELEM_DESCP		:== 8;
ARRAY_DESC_ELEMS			:== 12;

// Element descriptor
ARRAY_DESC_BOXED_DESCP		:== 0;


// RECORDS
n_unboxed_arguments :: !String -> Int;
n_unboxed_arguments type_string
	| True <<- ("n_unboxed_arguments", type_string)
	= mapASt f type_string 0;
where {
	f 'i' counter	= inc counter;
	f 'b' counter	= inc counter;
	f 'c' counter 	= inc counter;
	f 'r' counter	= inc counter;
	f 'a' counter	= counter;
	f 'd' counter	= counter;
	f 'l' counter 	= counter;

	f s _			= abort ("n_unboxed_arguments: " +++ toString s);
};
	
ints_to_real :: !(!Int,!Int) -> Real;
ints_to_real r = code {
        pop_b 0
        };	

