
#define ALLOC_INTERFACEH
#include "interface.h"

#include "global.h"
#include "utilities.h"

HINSTANCE Mouse = NULL;

void SetCurrentLibrary(
	CLEAN_STRING clstring, 
	CLEAN_BOOL *result, 
	DWORD *lib) {

	HINSTANCE library = NULL;

	//library = LoadLibraryEx( cstring(clstring), NULL, DONT_RESOLVE_DLL_REFERENCES );

	library = LoadLibrary( cstring(clstring) );
	if( library == NULL) {
		error(); 
		msg( cstring(clstring) );
		msg("SetCurrentLibrary: library not loaded");
		ExitProcess(-1);
	}

	*result = CLEAN_TRUE;
	*lib = (DWORD) library;

	Mouse = library;
}

int CloseLibrary(DWORD lib)
{
	return 1;
}

void GetFuncAddress (CLEAN_STRING clstring, 
					 DWORD base_of_client_dll, 
					 DWORD lib0, 
					 
					 DWORD *address, 
					 DWORD *lib1) {
	
	FARPROC p = NULL;
	static i = 0;

//	if( lib0 == NULL ) {
//		msg("GetFuncAddress: library not loaded");
//		ExitProcess(-1);
//	}

	/*
	** Compute the client address of the DLL-object  
	*/
//	*address = ((int) GetProcAddress( lib0, cstring(clstring)) );

//	msg( cstring(clstring) );

	if( GetProcAddress ((HMODULE)lib0, cstring(clstring) ) == NULL){
		msg( "GetFuncAddress: foutje" );
 		error();
	}

// voor nt:
	*address = ((int) GetProcAddress ((HMODULE)lib0, cstring(clstring)) - lib0) + base_of_client_dll;

//	*address = GetProcAddress(  /*(HMODULE) lib0 */ Mouse , cstring(clstring) );

	*lib1 = lib0;
}

CLEAN_BOOL GenerateObjectFileOld(CLEAN_STRING cg, CLEAN_STRING CmdLine)
{
	PROCESS_INFORMATION pi;
	DWORD dwExitCode;
	STARTUPINFO si;	
	BOOL fSuccess;					// Process information
	char *cmdline;
	CLEAN_BOOL result;
	int i;

	// Set once a path to the codegenerator (cg)
	char *cg_path = (char *) NULL;

	result = CLEAN_FALSE;

/*
	cg_path = (char *) rmalloc ((cg->length) + 1);
	rsncopy (cg_path,cg->characters, cg->length);
	cg_path[cg->length] = 0;

    // convert commandline
	cmdline = (char *) rmalloc ((CmdLine->length) + 1);
	rsncopy (cmdline,CmdLine->characters, CmdLine->length);
	cmdline[CmdLine->length] = 0;
*/

	ZeroMemory(&si, sizeof(si));
	si.cb = sizeof(si);

	/*
	si.lpTitle = NULL; //dir;
	si.wShowWindow = SW_SHOWNORMAL;
	si.dwFlags = STARTF_USESHOWWINDOW;
	*/

	// Create new process
	fSuccess = CreateProcess( cg->characters,	 	//cg_path,	// Executable
							  CmdLine->characters,	//cmdline,	// Commandline
							  NULL,					// Standard security (Proces)
						      NULL,					// Standard security (Thread)
							  FALSE,				// No handle inherited by child
							  0,					// Plain process
							  NULL,					// Environment of parent
							  NULL, //dir,			// Current directory
							  &si,					// Startup information
							  &pi);					// Process information

	if (fSuccess) {
		CloseHandle(pi.hThread);

		WaitForSingleObject(pi.hProcess, INFINITE);

		GetExitCodeProcess(pi.hProcess, &dwExitCode);

		CloseHandle(pi.hProcess);

		result = (dwExitCode == 0) ? CLEAN_TRUE : CLEAN_FALSE;
	} else 
		error();

//	rfree(cg_path);
//	rfree(cmdline);

	return result;
}
