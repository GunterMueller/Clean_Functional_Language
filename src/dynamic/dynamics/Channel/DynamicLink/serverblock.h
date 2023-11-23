#ifndef SERVERBLOCKH
#define SERVERBLOCKH

#include <windows.h>

/*
** Assumptions:
** 1) MAXIMUM_WAIT_OBJECTS is a multiple of two
*/
#define MAXIMUM_CLIENTS	(MAXIMUM_WAIT_OBJECTS / 2)
#define CLIENT_KILLED	0
#define CLIENT_READY	1

// Special InitialBlock-entries:
// - hGlobalServerReady (a semephore)
// - hDummy to the server proces (unused, required by WaitForMultipleObjects)
// - hLocalServerReady (equally named)
// - hLocalClientReady (equally named)

#define GLOBAL_SERVER_READY	0
#define LOCAL_CLIENT_READY	1
#define LOCAL_SERVER_READY	0

#define N_OF_RESERVED_ENTRIES_INITIAL_BLOCK		2

#define GLOBAL_SERVER_READY_NAME	"GlobalServerReady"
#define LOCAL_SERVER_READY_NAME		"LocalServerReady"
#define LOCAL_CLIENT_READY_NAME		"LocalClientReady"
#define GLOBAL_BUFFER_NAME			"GlobalBuffer"

/* Reservations of the global buffer */
#define GLOBAL_BUFFER_START			(sizeof(DWORD))
#define GLOBAL_BUFFER_SERVER_ID		0 

/*
** Indicates that synchronization objects for the named channel need
** not be set
*/
#define UNKNOWN_CLIENT_ID			0

/*
Thus the first entry of the initial block is reserved. WaitForMultiple
Objects in this block should be called with 
&(pSIB->hClientKilledOrReady[hLocalClientReady])
because of its special structure
*/
typedef struct _SERVERINFOBLOCK {
	// synchronisation
	HANDLE hServerReady[MAXIMUM_CLIENTS];
	HANDLE hClientKilledOrReady[MAXIMUM_WAIT_OBJECTS];

	// buffer
	HANDLE hFileMapping[MAXIMUM_CLIENTS];
	char *hView[MAXIMUM_CLIENTS];

	// process id
	DWORD ProcessId[MAXIMUM_CLIENTS];

	// Administration data
	int n_Clients;	// pointer refers to vacant position
} SERVER_INFO_BLOCK, *PSERVER_INFO_BLOCK;

PSERVER_INFO_BLOCK Empty_ServerInfoBlock();
BOOL AddClient_to_ServerInfoBlock( PSERVER_INFO_BLOCK pSIB, DWORD *dwServerId, HANDLE *hServerReady, HANDLE *hClientReady, HANDLE *hFileMapping);
BOOL UpdateClient_in_ServerInfoBlock( PSERVER_INFO_BLOCK pSIB, HANDLE hClient, DWORD dwClientId);
BOOL AddInitialSyncs_to_ServerInfoBlock( PSERVER_INFO_BLOCK pSIB );
BOOL RemoveClient_from_ServerInfoBlock( PSERVER_INFO_BLOCK pSIB, int Client_i );

#endif 
