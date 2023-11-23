
#if defined (__MWERKS__) && defined (_X86_)
#	define _WINDOWS_
#endif

#if defined (applec) || (defined (__MWERKS__) && !defined (_X86_)) || defined (__MRC__)
#	define _MAC_
#endif

#define _DEBUG_

#if defined (_MAC_)
# include "mac.h"
#elif defined (_WINDOWS_)
# include "windows_io.h"
#else
# include "sun.h"
#endif

extern File FOpen (char *fname, char *mode);
extern int FDelete (char *fname);
extern int FClose (File f);

extern int FPutS (char *s, File f);

#define ReSize(A) (((A)+3) & ~3)
