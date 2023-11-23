
#define SizeT	unsigned long
#define SizeOf(A) ((SizeT) sizeof (A))

#include <string.h>
#include <sys/types.h>
#include <setjmp.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>

#define _VARARGS_

typedef FILE *File;

extern FILE *std_out_file_p,*std_error_file_p;
#define StdOut std_out_file_p 
#define StdError std_error_file_p

#define FGetC(f) fgetc(f)
#define FGetS(s,n,f) fgets(s,n,f)
#define FPutC(c,f) fputc(c,f)
