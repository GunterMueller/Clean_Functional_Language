/********************************************************************************************
	Clean OS Windows library module version 1.2.1.
	This module is part of the Clean Object I/O library, version 1.2.1, 
	for the Windows platform.
********************************************************************************************/

/********************************************************************************************
	About this module:
	Routines useful for debugging. 
********************************************************************************************/
#include "cdebug_121.h"
#include "time.h"

int Rand (void)
{
	static int holdrand;
	static int randinited = 0;
    printf("Rand\n");

	if (!randinited)
	{
		holdrand = (int) 0; //GetTickCount ();
		randinited = -1;
	}

	holdrand = holdrand * 214013 + 2531011;

	return ((holdrand >> 16) & 0x7fff);
}

OS ConsolePrint (CLEAN_STRING cleanstr, OS os)
{
	char *cstr;
    printf("ConsolePrint\n");

	cstr = cstring (cleanstr);
	rprintf (cstr);
	return os;
}
