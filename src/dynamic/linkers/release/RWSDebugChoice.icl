implementation module RWSDebugChoice;

(->>) :: !.a !.b -> .a;
(->>) value debugValue
	=	value;

(<<-) :: .a !.b -> .a;
(<<-) value debugValue
	=	value;

<<->> :: !.a -> .a;
<<->> value
	=	value;
	
DEBUG_MODE normal debug :== normal;

// not fully implemented because required but undefined
// symbols make the linker crash. The selective import
// and marking-function used in the dynamic linker should
// be used.
ALLOW_UNUSED_DEFINED_SYMBOLS	:== False;
