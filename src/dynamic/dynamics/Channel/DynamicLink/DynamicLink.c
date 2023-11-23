#include <windows.h>
#include <commctrl.h>

#include "global.h"
#include "serverblock.h"
#include "channel_for_dynamic_link.h"
#include "DynamicLink.h"
#include "utilities.h"

BOOL WINAPI DllMain (HINSTANCE hinstDLL, DWORD fdwReason, LPVOID fImpLoad)
{
	switch (fdwReason){
	case DLL_PROCESS_ATTACH:
		hin = hinstDLL;

		EmptyCleanString = (CLEAN_STRING) rmalloc( sizeof(int) + 1);
		EmptyCleanString->length = 0;

		break;
	case DLL_THREAD_ATTACH:
		break;
	case DLL_THREAD_DETACH:
		break;
	case DLL_PROCESS_DETACH:
		break;
	}
	return TRUE;
}

RESOURCEAPI CLEAN_BOOL PassCommandLine (CLEAN_STRING s)
{	
	HANDLE hLocalServerReady, hGlobalServerReady, hLocalClientReady, hFileMapping;
	char *b;

	// 1. only to be called for non-first instance of dynamic linker.
	// 2. zero-terminated string.

	hLocalServerReady = CreateEvent( NULL, FALSE, FALSE, LOCAL_SERVER_READY_NAME);
	if( hLocalServerReady == NULL ) {
		error();
		msg( "FirstInstanceOfServer: hLocalServerReady" );
		ExitProcess(-1);
	}
	hGlobalServerReady = CreateEvent( NULL, FALSE, TRUE, GLOBAL_SERVER_READY_NAME);
	if( hGlobalServerReady == NULL ) {
		error();
		msg( "FirstInstanceOfServer: hGlobalServerReady" );
		ExitProcess(-1);
	}

	hLocalClientReady = CreateEvent( NULL, FALSE, FALSE, LOCAL_CLIENT_READY_NAME);
	if( hLocalClientReady == NULL ) {
		error();
		msg( "FirstInstanceOfServer: hLocalClientReady" );
		ExitProcess(-1);
	}

	// Open buffer
	hFileMapping = CreateFileMapping( (HANDLE)0xFFFFFFFF,NULL,PAGE_READWRITE,0,MESSAGE_SIZE,GLOBAL_BUFFER_NAME);
	if( hFileMapping == NULL ) {
		error();
		msg( "FirstInstanceOfServer: hFileMapping" );
		ExitProcess(-1);
	}

	b = (char *) MapViewOfFile(hFileMapping, FILE_MAP_WRITE, 0, 0, MESSAGE_SIZE);
	if( b == NULL ) {
		error();
		msg( "FirstInstanceOfServer: MapViewOfFile" );
		ExitProcess(-1);
	}

	// Communicate with server
	WaitForSingleObject( hGlobalServerReady, INFINITE );

	if( s->length + sizeof(DWORD) + GLOBAL_BUFFER_START > MESSAGE_SIZE ) {
		msg("PassCommandLine: command line too long");
		ExitProcess(-1);
	}

	*((DWORD *) (b + GLOBAL_BUFFER_START)) = UNKNOWN_CLIENT_ID;
//		rsprintf( (b + sizeof(DWORD) + GLOBAL_BUFFER_START), "AddClient\n%s\n\n", GetCommandLine() );
	rsprintf( (b + sizeof(DWORD) + GLOBAL_BUFFER_START), "MessageFromSecondOrLaterLinker\n%s\n\n", s->characters );

	// Send to server
	SetEvent (hLocalClientReady);

	// Wait for server to process request
	WaitForSingleObject (hLocalServerReady, INFINITE);

	// Quit instance, close all open handles
	UnmapViewOfFile (b);
	CloseHandle (hFileMapping);
	CloseHandle (hLocalClientReady);
	CloseHandle (hGlobalServerReady);
	CloseHandle (hLocalServerReady);

	ExitProcess (-1);

	return CLEAN_TRUE;
}

RESOURCEAPI CLEAN_STRING DoReqS (CLEAN_STRING s)
{
	msg ("DoReqS should not be called in Server");
	return NULL;
}
