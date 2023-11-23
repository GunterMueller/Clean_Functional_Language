#include <windows.h>
#include <shlobj.h>

#include "..\Utilities\Util.h"
#include "..\DynamicLink\utilities.h"

static int CALLBACK BrowseCallbackProc( HWND hwnd, UINT uMsg, LPARAM lParam, LPARAM lpData ) {

	char buffer[MAX_PATH];
	char dfile_name[MAX_PATH];
	WIN32_FIND_DATA FindFileData;
	HANDLE hFindFile;

	switch( uMsg ) {		
		case BFFM_SELCHANGED:
			SHGetPathFromIDList ((ITEMIDLIST*)/*(PCIDLIST_ABSOLUTE)*/lParam, buffer);

			sprintf( dfile_name, "%s\\DynamicLinker.exe", buffer );

			hFindFile = FindFirstFile( dfile_name, &FindFileData );
			SendMessage( hwnd, BFFM_ENABLEOK, 0, hFindFile != INVALID_HANDLE_VALUE );
		
			if( hFindFile != INVALID_HANDLE_VALUE )
				FindClose( hFindFile );
			break;

		default:
			break;
	}

	return( 0 );
}
 
char *SelectDynamicLinkerFolder() {

	char buffer[MAX_PATH];
	LPITEMIDLIST pidlReturn; 
	BROWSEINFO bi;

	static char *s = NULL;

	if( s != NULL ) {
		rfree( s ); 
		s = NULL;
	}

	bi.hwndOwner = NULL;
	bi.pidlRoot = NULL;
	bi.pszDisplayName = buffer;
	bi.lpszTitle = "Select folder containing DynamicLinker.exe";
	bi.ulFlags = BIF_RETURNONLYFSDIRS;
	bi.lpfn = BrowseCallbackProc;
	bi.lParam = 0;

	CoInitialize( NULL );

	pidlReturn = SHBrowseForFolder( &bi );
	if( pidlReturn ) {
		s = (char *) rmalloc (MAX_PATH+1);
		SHGetPathFromIDList( pidlReturn, s);
		CoTaskMemFree( pidlReturn );
		return( s );
	}
	else
		return( NULL );
}


