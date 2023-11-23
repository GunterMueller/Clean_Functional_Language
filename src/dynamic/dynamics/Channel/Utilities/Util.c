#include "util.h"
#include <stdarg.h>

#include "..\DynamicLink\utilities.h"

/*	since we don't use the C runtime library, here are some simple
  routines that would normally come from the C runtime lib.
*/

int numallocated = 0;


HGLOBAL 
rmalloc (DWORD bytes)
{
	HGLOBAL ptr;

	numallocated++;
	ptr = GlobalAlloc (GPTR, bytes);
	/* rprintf(" ALLOC(%d); %d\n", bytes, numallocated ); */
	if (!ptr)
	{
            //    msg( "rmalloc" );
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		ExitProcess (255);
	}

	return ptr;
}

void 
rfree (HGLOBAL ptr)
{
	numallocated--;

	/* rprintf(" FREE(); %d\n", numallocated ); */
	if (GlobalFree (ptr))
	{
               // msg( "rfree" );
               // error();
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		MessageBeep (0xFFFFFFFF);
		ExitProcess (255);
	}
}

int 
rstrlen (char *s)
{
	int l;

	for (l = 0; s[l] != 0; l++)
		;
	return l;
}

void 
rsncopy (char *d, const char *s, int n)
{
	int i;
	for (i = 0; i < n; i++)
	{
		d[i] = s[i];
	}
}

void 
rscopy (char *d, const char *s)
{
	int i;
	for (i = 0; s[i] != 0; i++)
	{
		d[i] = s[i];
	}
	d[i] = s[i];
}

BOOL 
strequal (char *s1, char *s2)
{
	int i = 0;
	while (s1[i] == s2[i])
	{
		if (s1[i] == 0)
			return TRUE;
		i++;
	}
	return FALSE;
}

int 
rabs (int i)
{
	if (i < 0)
		return -i;
	else
		return i;
}


/*	clean_strings don't have to end with 0, so we have to make
	copy the clean string and end it with a 0.
	global variables used for conversion from c strings to clean strings
*/



char *
cstring (CLEAN_STRING s)
{
	static char *cstr = (char *) NULL;

/* rprintf("{cstring"); */
	if (cstr)
	{
		rfree (cstr);
	}

	cstr = (char *) rmalloc ((s->length) + 1);
	rsncopy (cstr, s->characters, s->length);
	cstr[s->length] = 0;
/* rprintf("}\n"); */
	return cstr;
}



CLEAN_STRING 
cleanstring (char *s)
{
	static CLEAN_STRING result_clean_string = NULL;
/* rprintf("[cleanstring"); */
	if (result_clean_string)
		rfree (result_clean_string);

	result_clean_string = (CLEAN_STRING) rmalloc (sizeof (int) + rstrlen (s) +1);
	result_clean_string->length = rstrlen (s);
	rsncopy (result_clean_string->characters, s, rstrlen (s) + 1);
/* rprintf("]\n"); */
	return result_clean_string;
}

/*
** Extra:
*/
CLEAN_STRING 
cleanstringn (char *s, int length) 
{
	static CLEAN_STRING result_clean_string = NULL;
/* rprintf("[cleanstring"); */
	if (result_clean_string)
		rfree (result_clean_string);

	result_clean_string = (CLEAN_STRING) rmalloc (sizeof (int) + length);
	result_clean_string->length = length;
	rsncopy (result_clean_string->characters, s, length);
/* rprintf("]\n"); */
	return result_clean_string;
}

extern EXPORT_TO_CLEAN OS 
WinReleaseCString (PSTR cs, OS ios)
{
/*		rprintf("(RCS: \"%s\"", cs); */

	if (cs)
		rfree (cs);

/*		rprintf(")\n"); */

	return ios;
}

extern EXPORT_TO_CLEAN void 
WinGetCString (PSTR cs, OS ios, CLEAN_STRING * cls, OS * oos)
{
/*	("<Gcs"); */

	*cls = cleanstring (cs);
	*oos = ios;
/*	rprintf(">\n"); */
}

extern EXPORT_TO_CLEAN void 
WinGetCStringAndFree (PSTR cs, OS ios, CLEAN_STRING * cls, OS * oos)
{
/*	rprintf("{GcsF"); */
	*cls = cleanstring (cs);
	*oos = ios;
	rfree (cs);
/*	rprintf("}\n"); */
}


extern EXPORT_TO_CLEAN void 
WinMakeCString (CLEAN_STRING s, OS ios, PSTR * cs, OS * oos)
{
/*		rprintf("(MCS: \""); */
	*cs = (char *) rmalloc ((s->length) + 1);

	rsncopy (*cs, s->characters, s->length);
	(*cs)[s->length] = 0;

	*oos = ios;
/*	  rprintf("\"%s)\n",*cs); */
}

/*	The following routines are used to write to the console, or convey runtime errors
	with message boxes.
*/

static char mbuff[_RPRINTBUFSIZE];
static HANDLE hLogFile = NULL;
static BOOL LogFileInited = FALSE;

#ifdef LOGFILE
void 
rprintf (char *format,...)
{
	va_list arglist;
	int len;
	int cWritten;

	if (!LogFileInited)
	{
		hLogFile = CreateFile (LOGFILE, /* filename 	   */
							   GENERIC_WRITE,	/* acces mode	   */
							   0,		/* share mode	   */
							   NULL,	/* security 	   */
							   CREATE_ALWAYS,	/* how to create   */
							   FILE_ATTRIBUTE_NORMAL,	/* file attributes */
							   NULL);	/* template file   */
		if (hLogFile == INVALID_HANDLE_VALUE)
		{
			MessageBox (NULL, "Could not open logfile.", NULL, MB_OK | MB_ICONSTOP);
			ExitProcess (1);
		};
		LogFileInited = TRUE;
	}

	va_start (arglist, format);
	len = wvsprintf (mbuff, format, arglist);
	va_end (arglist);

	if (!WriteFile (hLogFile,	/* output handle  */
					mbuff,		/* prompt string  */
					len,		/* string length  */
					&cWritten,	/* bytes written  */
					NULL))		/* not overlapped */
	{
		MessageBox (NULL, "Cannot write to stdout --write error.", NULL, MB_OK | MB_ICONSTOP);
		return;
	};
};

#endif

void 
rMessageBox (HWND owner, UINT style, char *title, char *format,...)
{
	va_list arglist;

	va_start (arglist, format);
	wvsprintf (mbuff, format, arglist);
	va_end (arglist);

	MessageBox (owner, mbuff, title, style);

}

void 
CheckF (BOOL theCheck, char *checkText, char *checkMess,
		char *filename, int linenum)
{
	if (!theCheck)
	{
		rMessageBox (NULL, MB_OK | MB_ICONSTOP,
			 "Internal check failed", "%s\n\ncheck: %s\nfile: %s\nline: %d",
					 checkMess, checkText, filename, linenum);
		ExitProcess (1);
	}
}

void 
ErrorExit (char *format,...)
{
	va_list arglist;

	va_start (arglist, format);
	wvsprintf (mbuff, format, arglist);
	va_end (arglist);

	MessageBox (NULL, mbuff, NULL, MB_OK | MB_ICONSTOP);
	ExitProcess (1);
}

void 
DumpMem (int *ptr, int lines)
{
	char *cp;
	int i, j, k;

	rprintf ("DUMP FROM %d\n", ptr);

	for (i = 0; i < lines; i++)
	{
		rprintf ("%4d:	", i);
		cp = (char *) ptr;
		for (j = 0; j < 4; j++)
		{
			rprintf ("%08x ", *ptr);
			ptr++;
		};
		rprintf ("- ");
		for (j = 0; j < 4; j++)
		{
			for (k = 0; k < 4; k++)
			{
				char c;
				c = *cp;
				if (c < 32 || c > 127)
					c = '.';
				rprintf ("%C", c);
				cp++;
			};
			rprintf (" ");
		};
		rprintf ("\n");
	}
}

 /*-----------------------------------/*
/*	support for printing messages	 /*
/*-----------------------------------*/

char *
BOOLstring (BOOL b)
{
	if (b)
		return "TRUE";
	else
		return "FALSE";
}

