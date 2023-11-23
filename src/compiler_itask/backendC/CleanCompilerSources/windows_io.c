
#ifdef __MWERKS__
#	define _WINDOWS_
#endif

#include "compiledefines.h"
#include "types.t"
#include "system.h"
#include <stdio.h>

File FOpen (char *fname,char *mode)
{
	return fopen (fname,mode);
}

int FClose (File f)
{
	return fclose ((FILE *) f);
}

int FDelete (char *fname)
{
	return remove (fname);
}

int FPutS (char *s, File f)
{
	return fputs (s, (FILE *) f);
}
