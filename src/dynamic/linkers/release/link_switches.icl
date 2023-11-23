implementation module link_switches

// --------------------------
// switches for static linker

// switch dynamics (only if Link Method is set to eager):
// False		- create an executable and a complement
// True			- create a .lib and a .typ file 
dynamics :== True;

// switch for input/output
debug_static_linker normal_mode debug_mode :== normal_mode;

// ---------------------------
// switches for dynamic linker
test_dynamic_linker :== True

debug_dump_dynamic normal debug :== normal;

ALLOW_LAZY_LIBRARY_REFERENCES yes no :== yes;

OUTPUT_UNIMPLEMENTED_FEATURES_WARNINGS yes no :== no;

ALLOW_UNUSED_UNDEFINED_SYMBOLS yes no :== yes;

ALLOW_LIBRARY_REDIRECTIONS yes no :== yes;

MAKE_INTERNAL_TYPES_USE_SINGLE_IMPLEMENTATION yes no :== yes;

USE_ENTER_NEW_TYPE_EQUATIONS yes no :== yes;

USE_NEW_SCOPE_RESOLUTION_METHOD yes no :== yes;					// if this work, scope searching can be removed from type_io_static.icl

TEXT_DUMP_DYNAMIC yes no :== yes;

IS_TEXT_DUMP_DYNAMIC :== TEXT_DUMP_DYNAMIC True False;

CONSTRUCTOR_SHARING yes no :== yes;

IS_CONSTRUCTOR_SHARING :== CONSTRUCTOR_SHARING True False;

SAFETY_CHECK yes no :== yes;

USE_SAFETY_CHECK :== SAFETY_CHECK True False;

ENABLE_DYNAMIC_LINKER_GUI yes no :== yes;

DEBUG_DYNAMICALLY_LINKED_CODE yes no :== no;