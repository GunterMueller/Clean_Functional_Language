definition module RWSDebugChoice;

(->>) :: !.a !.b -> .a;
(<<-) :: .a !.b -> .a;
<<->> :: !.a -> .a;

DEBUG_MODE normal debug :== normal;

// FIXME: what's this macro doing in this module?

// not fully implemented because required but undefined
// symbols make the linker crash. The selective import
// and marking-function used in the dynamic linker should
// be used.
ALLOW_UNUSED_DEFINED_SYMBOLS	:== False;
