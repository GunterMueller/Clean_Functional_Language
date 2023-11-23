definition module runtime_system;

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

ints_to_real :: !(!Int,!Int) -> Real;
