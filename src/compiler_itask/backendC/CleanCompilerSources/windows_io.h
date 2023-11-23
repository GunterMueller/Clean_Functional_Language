
#define SizeT		unsigned long
#define SizeOf(A)	((SizeT) sizeof (A))

#include <limits.h>

#define _VARARGS_

#include <string.h>
#include <stdlib.h>

#if defined (__MWERKS__) || defined (_WINDOWS_)
#	include <stdio.h>
#else
#	include <unix.h>
#endif

#include <setjmp.h>

typedef FILE *File;

#ifndef CLEAN_FILE_IO
# ifdef _MSC_VER
extern FILE *std_out_file_p,*std_error_file_p;
#  define StdOut std_out_file_p
#  define StdError std_error_file_p
# else
#  define StdOut stdout
#  define StdError stderr
# endif

# define FPutC(c,f) fputc(c,f)
#endif
