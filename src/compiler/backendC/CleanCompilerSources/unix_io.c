
#include "types.t"
#include "system.h"

#if !defined (applec) || defined (__MWERKS__)
#	include <sys/types.h>
#	include <sys/file.h>
#	include <sys/param.h>
#endif

#if !(defined (applec) || defined (_PC_))
#	include <unistd.h>
#endif

#include <sys/time.h>
#include <sys/resource.h>
#include <sys/stat.h>

File FOpen (char *fname, char *mode)
{
	return (File) fopen (fname, mode);
}

int FClose (File f)
{
	return fclose ((FILE *) f);
} /* FClose */

int FDelete (char *fname)
{
	return remove (fname);
}

#ifndef FPutC
int FPutC (int c, File f)
{
	return fputc (c, (FILE *) f);
}
#endif

int FPutS (char *s, File f)
{
	return fputs (s, (FILE *) f);
} /* FPutS */
