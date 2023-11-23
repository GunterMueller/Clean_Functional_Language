definition module TRACE

//	TRACE value will print value iff TRACE_ON
TRACE :: !value_to_print !.y -> .y

//	DO_TRACE value will always print value
DO_TRACE :: !value_to_print !.y -> .y
