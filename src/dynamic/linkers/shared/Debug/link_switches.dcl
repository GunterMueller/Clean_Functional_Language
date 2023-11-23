definition module link_switches

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