#ifdef _WIN32
# include <windows.h>

/* These functions are defined in the Clean run-time system; they print to
 * stderr. */
extern void ew_print_string (char*);
extern void ew_print_int (int);

static HANDLE StdErr=NULL;

DWORD WINAPI readFileInSeparateThread (HANDLE *args)
{
	HANDLE file=args[0];

	/* NB: without this WriteFile, readPipeBlockingMulti may hang... */
	if (StdErr==NULL)
		StdErr=GetStdHandle (STD_ERROR_HANDLE);
	WriteFile (StdErr,"",0,NULL,NULL);

	if (!ReadFile (file,NULL,0,NULL,NULL)){
		int err=GetLastError();

		if (err!=109){
			ew_print_string ("ReadFile failed (");
			ew_print_int (GetLastError());
			ew_print_string (")\n");
			return 1;
		}
	}

	return 0;
}
#endif
