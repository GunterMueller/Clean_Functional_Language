definition module RWSDebugChoice;

import RWSDebug;

DEBUG_MODE normal debug :== debug;

// not fully implemented because required but undefined
// symbols make the linker crash. The selective import
// and marking-function used in the dynamic linker should
// be used.
ALLOW_UNUSED_DEFINED_SYMBOLS	:== True;
