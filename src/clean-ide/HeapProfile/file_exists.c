#include <windows.h>

typedef struct clean_string
    {   size_t  length;
        char characters[1];
    } *CLEAN_STRING;

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
		// msg( "rmalloc" );
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
		//msg( "rfree" );
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

void 
rsncopy (char *d, const char *s, int n)
{
	int i;
	for (i = 0; i < n; i++)
	{
		d[i] = s[i];
	}
}

char *cstring (CLEAN_STRING s)
{
	static char *cstr = (char *) NULL;

	if (cstr)
	{
		rfree (cstr);
	}

	cstr = (char *) rmalloc ((s->length) + 1);
	rsncopy (cstr, s->characters, s->length);
	cstr[s->length] = 0;
	return cstr;
}

BOOL fileexists(char *s) {
	WIN32_FIND_DATA Win32_Find_Data;
	HANDLE hFindFirstFile;

	hFindFirstFile = FindFirstFile(s,&Win32_Find_Data);
	if( hFindFirstFile == INVALID_HANDLE_VALUE ) {
		return FALSE;
	}

	FindClose(hFindFirstFile);
	return TRUE;
}

BOOL FileExists(CLEAN_STRING s) {
	return( fileexists(cstring(s)) );
}

