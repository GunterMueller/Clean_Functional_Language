
#if defined (__MWERKS__) && defined (_X86_)
# define _WINDOWS_
#endif

#define KBYTE		1024L

typedef unsigned Bool;
	enum {
		False = 0, True, MightBeTrue
	};
