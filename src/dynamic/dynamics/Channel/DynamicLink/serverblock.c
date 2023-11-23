#include "serverblock.h"
#include "..\ClientChannel\channel.h"

#include "..\Utilities\Util.h"
#include "..\DynamicLink\utilities.h"

#ifndef TESTCOMPILE
//#include "..\User2ResourceDLL\global.h"
#include "..\DynamicLink\global.h"
#else
// mess
// Display error
void error() {
	LPVOID lpMsgBuf;
		
	FormatMessage( 
		FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,    NULL,
		GetLastError(),
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &lpMsgBuf,    0,    NULL );// Display the string.

	MessageBox( NULL, lpMsgBuf, "GetLastError", MB_OK|MB_ICONINFORMATION );
	LocalFree( lpMsgBuf );
}

void msg(char *lpMsgBuf)
{
	MessageBox( NULL, lpMsgBuf, "wwGetLastError", MB_OK|MB_ICONINFORMATION );
}
#endif

// Buffer
// Create buffer, needs optimilisation. hFileMapping is inheritable
BOOL AllocBuffer( DWORD length, HANDLE *hFileMapping, char **hView, char *BufferName ) {

	SECURITY_ATTRIBUTES sa;
	
	sa.nLength = sizeof(SECURITY_ATTRIBUTES);
	sa.lpSecurityDescriptor = NULL;
	sa.bInheritHandle = TRUE;

	*hFileMapping = CreateFileMapping((HANDLE)0xFFFFFFFF,&sa,PAGE_READWRITE,0,length,BufferName);
	if ((*hFileMapping) == NULL) {
		error();
		msg( "AllocBuffer: hFileMapping" );
		ExitProcess(-1);
	}

	*hView = (char *) MapViewOfFile(*hFileMapping, FILE_MAP_WRITE, 0, 0, length);
	if ((*hView) == NULL) {
		error();
		msg( "AllocBuffer: hView" );
		CloseHandle(hFileMapping);
		ExitProcess(-1);
	}

	return( TRUE );
}

PSERVER_INFO_BLOCK Empty_ServerInfoBlock()
{
	PSERVER_INFO_BLOCK pServerInfoBlock;

	pServerInfoBlock = (PSERVER_INFO_BLOCK) rmalloc (sizeof(SERVER_INFO_BLOCK));
	if (pServerInfoBlock == NULL){
		msg( "Empty_ServerInfoBlock" );
	}

	pServerInfoBlock->n_Clients = 0;

	return pServerInfoBlock;
}

BOOL AddClient_to_ServerInfoBlock (PSERVER_INFO_BLOCK pSIB, DWORD *dwServerId, HANDLE *hServerReady, HANDLE *hClientReady, HANDLE *hFileMapping)
{
	BOOL ok;
	int Client_n;
	SECURITY_ATTRIBUTES sa;

	if( (pSIB->n_Clients) == MAXIMUM_CLIENTS ) {
		msg( "AddClient_to_ServerInfoBlock: too many clients" );
		ExitProcess(-1);
	}

	Client_n = pSIB->n_Clients;
	sa.nLength = sizeof(SECURITY_ATTRIBUTES);
	sa.lpSecurityDescriptor = NULL;
#ifdef COMPILATION_FOR_WINNT
	sa.bInheritHandle = TRUE;
#else
	sa.bInheritHandle = TRUE;
#endif

	// Synchronisation
	pSIB->hServerReady[Client_n] = CreateEvent (&sa, FALSE, FALSE, NULL);
	if (!(pSIB->hServerReady[Client_n])){
		msg( "AddClient_to_ServerInfoBlock: error" );
		ExitProcess(-1);
	}

	//pSIB->hClientKilledOrReady[Client_n + CLIENT_KILLED] = hClient;
	// hClient unknown
	pSIB->hClientKilledOrReady[Client_n * 2 + CLIENT_READY] = CreateEvent (&sa, FALSE, FALSE, NULL);
	if( !(pSIB->hClientKilledOrReady[(Client_n * 2) + CLIENT_READY]) ) {
		msg( "AddClient_to_ServerInfoBlock: error" );
		ExitProcess(-1);
	}

	// Buffer
	ok = AllocBuffer (MESSAGE_SIZE, &pSIB->hFileMapping[Client_n], &pSIB->hView[Client_n], NULL);
	if (!ok){
		msg ( "AddClient_to_ServerInfoBlock: error" );
		ExitProcess(-1);
	}

	// Client Process ID
	// Unknown at this point

	// Administration data
	++pSIB->n_Clients;

	// Return results
	*dwServerId = GetCurrentProcessId();	
	*hServerReady = pSIB->hServerReady[Client_n];
	*hClientReady = pSIB->hClientKilledOrReady[(Client_n * 2) + CLIENT_READY];
	*hFileMapping = pSIB->hFileMapping[Client_n];

	return TRUE;
}

BOOL UpdateClient_in_ServerInfoBlock (PSERVER_INFO_BLOCK pSIB, HANDLE hClient, DWORD dwClientId)
{
	int Client_n;
#ifdef COMPILATION_FOR_WINNT
	BOOL ok;
#endif

	if (pSIB->n_Clients == 0){
		msg( "UpdateClient_in_ServerInfoBlock: empty" );
		ExitProcess(-1);
	}

	Client_n = pSIB->n_Clients - 1;

	// Set additional information
	pSIB->hClientKilledOrReady[(Client_n * 2) + CLIENT_KILLED] = hClient;
	pSIB->ProcessId[Client_n] = dwClientId;

#ifdef COMPILATION_FOR_WINNT
	// Undo inheritance of events
	ok = SetHandleInformation (pSIB->hServerReady[Client_n], HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
	if( !ok ) {
		error();
		msg( "UpdateClient_in_ServerInfoBlock: 1" );
		ExitProcess(-1);
	}

	ok = SetHandleInformation (pSIB->hClientKilledOrReady[(Client_n * 2) + CLIENT_READY], HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
	if( !ok ) {
		error();
		msg( "UpdateClient_in_ServerInfoBlock: 2" );
		ExitProcess(-1);
	}

	ok = SetHandleInformation (pSIB->hFileMapping[Client_n], HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);
	if( !ok ) {
		msg( "UpdateClient_in_ServerInfoBlock: 3" );
		error();
		ExitProcess(-1);
	}
#else

	// A Win95/98 Solution needed. The problem is that not all handles
	// should be inherited by child processes. Only these are needed 
	// because otherwise unnecessary resources could be keeped 
	// occupied.

#endif

	return TRUE;
}

BOOL RemoveClient_from_ServerInfoBlock (PSERVER_INFO_BLOCK pSIB, int Client_i)
{
	int i;

	if (!((0 <= Client_i) && (Client_i < (pSIB->n_Clients)))){
		msg( "RemoveClient_from_ServerInfoBlock: no clients to remove" );
		ExitProcess(-1);
	}

	// 0 <= Client_i < pSIB->n_Clients
	// Buffer
	UnmapViewOfFile (pSIB->hView[Client_i]);
	CloseHandle (pSIB->hFileMapping[Client_i]);

	// Synchronisation
	CloseHandle (pSIB->hServerReady[Client_i]);
	CloseHandle (pSIB->hClientKilledOrReady[Client_i * 2 + CLIENT_READY]);
	CloseHandle (pSIB->hClientKilledOrReady[Client_i * 2 + CLIENT_KILLED]);

	// Administration
	//	pSIB->n_Clients = Client_n;

	// Movement
	for (i = Client_i + 1; i < pSIB->n_Clients; i++){
		pSIB->hServerReady[i-1] = pSIB->hServerReady[i];

		pSIB->hClientKilledOrReady[2*(i-1)+CLIENT_READY] = pSIB->hClientKilledOrReady[2*i+CLIENT_READY];
		pSIB->hClientKilledOrReady[2*(i-1)+CLIENT_KILLED] = pSIB->hClientKilledOrReady[2*i+CLIENT_KILLED];

		pSIB->hFileMapping[i-1] = pSIB->hFileMapping[i];
		pSIB->hView[i-1] = pSIB->hView[i];
		pSIB->ProcessId[i-1] = pSIB->ProcessId[i];
	}
	pSIB->n_Clients = pSIB->n_Clients - 1;

	return TRUE;
}

BOOL AddInitialSyncs_to_ServerInfoBlock (PSERVER_INFO_BLOCK pSIB)
{
	/*
	** It is guaranteed by the server that the buffer is allocated and
	** initialized immediately after the GLOBAL_SERVER_READY--event is
	** created.
	*/
	AllocBuffer (MESSAGE_SIZE,&(pSIB->hFileMapping[0]),&(pSIB->hView[0]),GLOBAL_BUFFER_NAME);

	// initialize buffer
	*((DWORD *) ((pSIB->hView[0])+GLOBAL_BUFFER_SERVER_ID)) = GetCurrentProcessId();

	pSIB->hServerReady[LOCAL_SERVER_READY] = CreateEvent (NULL, FALSE, FALSE, LOCAL_SERVER_READY_NAME);
	if( !(pSIB->hServerReady[LOCAL_SERVER_READY]) ) {
		msg( "AddInitialSyncs_to_ServerInfoBlock: error" );
		ExitProcess(-1);
	}

	pSIB->hClientKilledOrReady[GLOBAL_SERVER_READY] = CreateEvent (NULL, FALSE, TRUE, GLOBAL_SERVER_READY_NAME);
	if( !(pSIB->hClientKilledOrReady[GLOBAL_SERVER_READY]) ) {
		msg( "AddInitialSyncs_to_ServerInfoBlock: error" );
		ExitProcess(-1);		
	}

	pSIB->hClientKilledOrReady[LOCAL_CLIENT_READY] = CreateEvent (NULL, FALSE, FALSE, LOCAL_CLIENT_READY_NAME);
	if( !(pSIB->hClientKilledOrReady[LOCAL_CLIENT_READY]) ) {
		msg( "AddInitialSyncs_to_ServerInfoBlock: error" );
		ExitProcess(-1);		
	}

	pSIB->n_Clients = N_OF_RESERVED_ENTRIES_INITIAL_BLOCK / 2;

	return TRUE;
}
