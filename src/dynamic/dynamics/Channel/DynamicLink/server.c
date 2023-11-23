
#include "server.h"
#include "serverblock.h"
#include "channel_for_dynamic_link.h"
#include "utilities.h"
#include "global.h"

static char *Buffer = NULL;
static HANDLE ClientProcessHandle = NULL;

#define INIT_SERVER				0
#define INIT_CHANNEL			1
#define PROCESS_REQUESTS		2
#define SET_GLOBAL_SERVER_READY	3

static State = INIT_SERVER;

#define TEXT	0
#define DATA	1

static int *CodeBuffer = NULL;
static int *DataBuffer = NULL;
static int CodeStart   = 0;
static int DataStart   = 0;
static int CodeSize		= 0;
static int DataSize		= 0;

CLEAN_BOOL StoreLong (int pvMem, int l)
{
	char *dest;

	dest = (((char*) CodeBuffer) + (pvMem - CodeStart));

	*((int *) dest) = l;

    return CLEAN_TRUE;
}

int mwrites (int kind, int offset, CLEAN_STRING s, int address)
{
	char *dest;
	int i;

	if (kind == TEXT) {
		dest = ((char*) CodeBuffer) + offset;
	} else {
		dest = ((char*) DataBuffer) + offset;
	}

	for (i = 0; i < s->length; ++i)
		dest[i] = s->characters[i];

	return address + s->length;
}

// ServerInfoBlock
static PSERVER_INFO_BLOCK PServerInfoBlock = NULL;

static void
SetEnvInt (char *name, int value)
{
	char env[sizeof(int) * 3 + 2]; /* buffer size conservatively estimated */

	(void) sprintf(env, "%d", value);
	SetEnvironmentVariableA (name, env);
}

void StartProcess (CLEAN_STRING current_directory, CLEAN_STRING file_name, CLEAN_STRING commandline, CLEAN_BOOL *ok, int *client_id)
{
	// ServerInfoBlock
	DWORD dwServerId;
	HANDLE hServerReady,hClientReady,hFileMapping;
	PROCESS_INFORMATION pi;
	STARTUPINFO si;
	BOOL fSuccess;					// Process information

	// ServerInfoBlock
	AddClient_to_ServerInfoBlock (PServerInfoBlock, &dwServerId, &hServerReady, &hClientReady,&hFileMapping);

	/* set these environment variable in the current process, which means
	   that they are inherited by the child */
	SetEnvInt ("dwServerId", dwServerId);
	SetEnvInt ("hServerReady", (int)hServerReady);
	SetEnvInt ("hClientReady", (int)hClientReady);
	SetEnvInt ("hFileMapping", (int)hFileMapping);
	SetEnvInt ("MESSAGE_SIZE", MESSAGE_SIZE);

	ZeroMemory (&si, sizeof(si));
	si.cb = sizeof(si);

	si.lpTitle = file_name->characters;
	si.wShowWindow = SW_SHOWNORMAL;
	si.dwFlags = STARTF_USESHOWWINDOW;

	fSuccess = CreateProcess( 
		NULL,							// Executable
		commandline->characters,		// Commandline
		NULL,							// Standard security (Proces)
		NULL,							// Standard security (Thread)
		TRUE,							// No handle inherited by child
		CREATE_NEW_CONSOLE,				// Plain process
		NULL,							// Environment of parent
		current_directory->characters,	// Current directory
		&si,							// Startup information
		&pi);							// Process information

	if (!fSuccess){
		*ok = 0;
		*client_id = 0;
	} else {
		CloseHandle (pi.hThread);

		UpdateClient_in_ServerInfoBlock (PServerInfoBlock, pi.hProcess, pi.dwProcessId);

		*ok = CLEAN_TRUE;
		*client_id = pi.dwProcessId;
	}
}

void ReceiveReqWithTimeOut(CLEAN_BOOL static_application_as_client, CLEAN_BOOL *timeout,int *client_id, CLEAN_STRING *result)
{
	char *s;
	static CLEAN_STRING cs = NULL;
	int clientId;
	DWORD dwResult;
	int client_i;
	DWORD dwServerId;
	HANDLE hServerReady,hClientReady,hFileMapping,hClient,hServer;
	BOOL ok;
	int length;
	char *buffer;

	*timeout = CLEAN_FALSE;

	if (cs != NULL){
		rfree (cs);
		cs = NULL;
	}

	if (State == INIT_SERVER){
		State = INIT_CHANNEL;

		// ServerInfoBlock
		PServerInfoBlock = Empty_ServerInfoBlock();
		AddInitialSyncs_to_ServerInfoBlock (PServerInfoBlock);

		if (static_application_as_client == CLEAN_FALSE){
			cs = (CLEAN_STRING) rmalloc (sizeof(int)+12+rstrlen(GetCommandLine()) + 1);

			//                         0123456789 * 0 
			rsprintf( cs->characters, "AddClient\n%s\n\n", GetCommandLine() );
			cs->length = rstrlen (cs->characters);

			*client_id = 0;
			*result = cs;
			return;
		}

		/*
		** Static application as client
		*/
	} else if (State == INIT_CHANNEL){
		State = PROCESS_REQUESTS;
	} else if (State == SET_GLOBAL_SERVER_READY){
		/*
		** Settings this flag later guarantees round-robin fashion
		** of serving clients. Not doing this, guarantees that 
		** registering clients take priority.
		*/
		SetEvent (PServerInfoBlock->hClientKilledOrReady[GLOBAL_SERVER_READY]);
		State = PROCESS_REQUESTS;
	}

	// ServerInfoBlock, only initial block
	dwResult = WaitForMultipleObjects (PServerInfoBlock->n_Clients * 2 - 1,
										&PServerInfoBlock->hClientKilledOrReady[LOCAL_CLIENT_READY], FALSE, 10); //INFINITE );
	if (dwResult == WAIT_TIMEOUT){
		*timeout = CLEAN_TRUE;

		cs = (CLEAN_STRING) rmalloc (sizeof(int)+ 12);
		cs->length = 0;

		*result = cs;
		*client_id = 0;
		return;
	}
	
	if (dwResult == WAIT_FAILED){
		error();
		msg( "ReceiveReqWithTimeOut: WaitForMultipleObjects failed" );
		ExitProcess(-1);
	}

	client_i = dwResult - WAIT_OBJECT_0 + 1;
#ifdef DEBUG
	rsprintf( q, "Client #%d with %d", Client_i / 2, Client_i  % 2);
	msg( q );
#endif DEBUG

	/* Protocol message has been received, the following code handles the messages */

	if (client_i < 2){
		if (client_i != LOCAL_CLIENT_READY){
			msg ("local client should be ready");
			ExitProcess(-1);
		}

		Buffer = PServerInfoBlock->hView[INDEX(client_i)];
		buffer = GetReceiveBuffer (Buffer);

		clientId = *((DWORD *) (buffer+GLOBAL_BUFFER_START));

		cs = (CLEAN_STRING) rmalloc (sizeof(int) + rstrlen (buffer + sizeof(DWORD) + GLOBAL_BUFFER_START) + 1);
		cs->length = rstrlen (buffer + sizeof(DWORD) + GLOBAL_BUFFER_START);
		rscopy (cs->characters, buffer + sizeof(DWORD) + GLOBAL_BUFFER_START);

		State = SET_GLOBAL_SERVER_READY;

		if (clientId != UNKNOWN_CLIENT_ID){
			/* An AddAndInit--protocol. Reply by sending the handles to the required synchronization objects. */
			// ServerInfoBlock
			AddClient_to_ServerInfoBlock (PServerInfoBlock, &dwServerId, &hServerReady, &hClientReady, &hFileMapping);

			hClient = OpenProcess (STANDARD_RIGHTS_REQUIRED | PROCESS_ALL_ACCESS, FALSE, clientId);
			if (hClient == NULL){
				error();
				msg( "ReceiveReq: could not open handle to statically linked client" );
				ExitProcess(-1);
			}

			UpdateClient_in_ServerInfoBlock (PServerInfoBlock, hClient, clientId);

			/* Open handle to itself */
			hServer = OpenProcess (STANDARD_RIGHTS_REQUIRED | PROCESS_ALL_ACCESS, FALSE, dwServerId);
			if (hServer == NULL){
				error();
				msg( "ReceiveReq: could not open handle to itself, the dynamic linker" );
				ExitProcess(-1);
			}

			/* Fill buffer */
			*((DWORD *) (buffer+GLOBAL_BUFFER_START)) = dwServerId;
			ok = DuplicateHandle (hServer, hServerReady, hClient,
				((HANDLE *) (buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) )), 0, FALSE, DUPLICATE_SAME_ACCESS);
			if (!ok){
				error();
				msg ("Receivereq: could not dup handle");
				ExitProcess(-1);
			}

			ok = DuplicateHandle (hServer, hClientReady, hClient,
				((HANDLE *) (buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) + sizeof(HANDLE) )), 0, FALSE, DUPLICATE_SAME_ACCESS);
			if (!ok){
				error();
				msg ("Receivereq: could not dup handle");
				ExitProcess(-1);
			}

			ok = DuplicateHandle (hServer, hFileMapping, hClient,
				((HANDLE *) (buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) + 2 * sizeof(HANDLE) )), 0, FALSE, DUPLICATE_SAME_ACCESS);
			if (!ok){
				error();
				msg ("Receivereq: could not dup handle");
				ExitProcess(-1);
			}

			*((DWORD *) (buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) + 3 * sizeof(HANDLE) )) = MESSAGE_SIZE;
			
			// Send to client
			SetEvent (PServerInfoBlock->hServerReady[LOCAL_SERVER_READY]);

			// Wait for confirmation that Client processed buffer
			WaitForSingleObject (PServerInfoBlock->hClientKilledOrReady[LOCAL_CLIENT_READY], INFINITE);

			// Signal Client
			SetEvent (PServerInfoBlock->hServerReady[LOCAL_SERVER_READY]);
		} else 
			SetEvent (PServerInfoBlock->hServerReady[LOCAL_SERVER_READY]);

		*client_id = clientId;
		*result = cs;

		ReleaseReceiveBuffer (buffer, Buffer);
		return;
	}

	if (IS_CLIENT_KILLED (client_i)){
		*client_id = PServerInfoBlock->ProcessId[ INDEX( client_i ) ];

		RemoveClient_from_ServerInfoBlock( PServerInfoBlock, (INDEX( client_i )) );

		cs = (CLEAN_STRING) rmalloc(sizeof(int) + 7 );
		cs->length = 7;
		//						  012345 6
		rsncopy( cs->characters, "Close\n\n", 7);
		*result = cs;
		return; 
	}

	if( IS_CLIENT_READY(client_i) )
		;

#ifdef DEBUG
	msg( "client ready" );
#endif

	// Prepare communication channel
	Buffer = PServerInfoBlock->hView[INDEX(client_i)];
	buffer = GetReceiveBuffer (Buffer);

	SetHandlesToClient(
		PServerInfoBlock->hServerReady[INDEX(client_i)],
		PServerInfoBlock->hClientKilledOrReady[INDEX_CLIENT_KILLED(client_i)],
		PServerInfoBlock->hClientKilledOrReady[INDEX_CLIENT_READY(client_i)] );

	length = *((DWORD *) (buffer+SIZE_OF_MESSAGE));

	ClientProcessHandle = PServerInfoBlock->hClientKilledOrReady[INDEX_CLIENT_KILLED(client_i)];

	s = buffer+DATA_START+sizeof(DWORD);	

	cs = (CLEAN_STRING) rmalloc (sizeof(int) + /*rstrlen(s) + 1*/ length );
	rsncopy( cs->characters, s, length);
	cs->length = length;  rstrlen(s);

	(*result) = cs;
	*client_id = PServerInfoBlock->ProcessId[ INDEX(client_i) ];

	ReleaseReceiveBuffer (buffer, Buffer);
}

void ReceiveCodeDataAdr (int code_size, int data_size, CLEAN_BOOL *result, int *code_start, int *data_start)
{
	if (State != PROCESS_REQUESTS){
		msg("ReceiveCodeDataAdr: no init");
		ExitProcess(-1);
	}

	// Reserve memory for server
	// Code
	if( code_size != 0 ) {
		CodeBuffer = (int *) VirtualAlloc( NULL,code_size,MEM_RESERVE | MEM_COMMIT,PAGE_READWRITE );

		if( !CodeBuffer ) {
			error();
			msg( "**CodeBuffer");
			ExitProcess(-1);
		}
	}

	// Data
	if( data_size != 0) {
		DataBuffer = (int *) VirtualAlloc( NULL,data_size,MEM_RESERVE | MEM_COMMIT,PAGE_READWRITE );

		if( (DataBuffer == NULL) && (data_size != 0)) {
			error();
			msg( "DataBuffer");
			ExitProcess(-1);
		}
	}

	// Make client reserve memory for code and data
	Buffer[MESSAGE_TYPE] = ADDRESS_UNKNOWN;

	*((int *) (Buffer+DATA_START)) = code_size;
	*((int *) (Buffer+DATA_START+sizeof(int))) = data_size;

#ifdef DEBUG
	msg( "ReceiveCodeDataAdr 2" );
#endif

	Send();

#ifdef DEBUG
	msg( "ReceiveCodeDataAdr 3" );
#endif

	// Receive message containing startaddresses
	if( (Receive()) == CLIENT_READY ) {
		CodeSize = code_size;
		CodeStart = *((int *) (Buffer+DATA_START));
		*code_start = CodeStart;

		DataSize = data_size;
		DataStart =	*((int *) (Buffer+DATA_START+sizeof(int))); 
		*data_start = DataStart;

		// Operation correctly performed
		*result = CLEAN_TRUE;
	} else { 
		*result = CLEAN_FALSE;

		// Free used server buffers (code,data)
 		if( !VirtualFree(CodeBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReceiveCodeDataAdr: 1" );
			ExitProcess(-1);
		}
		CodeBuffer = NULL;


		if( !VirtualFree(DataBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReceiveCodeDataAdr: 2" );
			ExitProcess(-1);
		}
		DataBuffer = NULL;
	}
}

void NeedBaseLibraries (CLEAN_STRING clstring, int n_libraries,CLEAN_BOOL *result,CLEAN_STRING *s) {

	char *hLibraryBufferView = NULL;
	BufferInfo server_info;
	BufferInfo client_info;

	if (n_libraries == 0) {
		*result = CLEAN_TRUE;
		return;
	}

	/* Allocate and fill buffer with library names */

	// Work						
	CreateBuffer( "ServerLibraryBuffer", clstring->length, FALSE, &server_info);

	hLibraryBufferView = server_info.hView;
	rsncopy(hLibraryBufferView, clstring->characters,clstring->length);

	/* Send a message demanding the bases of libraries */

	Buffer[MESSAGE_TYPE] = NEED_BASE_OF_LIBRARIES;
	*((int *) (Buffer+DATA_START)) = n_libraries;
	*((int *) (Buffer+DATA_START+sizeof(int))) = clstring->length;

#ifdef DEBUG
	rsprintf( bs, "SERVER: n_libraries: %d, string length: %d", n_libraries, clstring->length );
	msg( bs );
#endif

	Send();

#ifdef DEBUG
	msg( "NeedBaseLibraries 3a" );
#endif

	if( (Receive()) == CLIENT_READY ) {

		CloseBuffer( &server_info );

		/*
		** Answer received. Convert it to a string
		*/
#ifdef DEBUG
		msg( "NeedBaseLibraries 4" );
#endif

		CreateBuffer( "ClientLibraryBuffer",BUFFER_SIZE_UNKNOWN, TRUE, &client_info);
		hLibraryBufferView = client_info.hView;

		*result = CLEAN_TRUE;
		*s = cleanstringn(hLibraryBufferView,sizeof(int) * n_libraries);

		CloseBuffer( &client_info );
	} else {
		*result = CLEAN_FALSE;
		*s = EmptyCleanString;
		msg( "NeedBaseLibraries: client killed" );
	}
}

int FlushBuffers() {
	DWORD lpNumberOfBytesWritten;

	if( (CodeBuffer != NULL) && (CodeSize !=0 ) ) {
		
		if( !WriteProcessMemory(ClientProcessHandle,
							(LPVOID) CodeStart, //code,
							CodeBuffer, // source,
							CodeSize,
							&lpNumberOfBytesWritten) ) {
			error();
			msg( "mwrites");
			ExitProcess(-1);
		}

		if( !VirtualFree(CodeBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReplyReq: if( !VirtualFree(CodeBuffer,0,MEM_RELEASE) ) {" );
			ExitProcess(-1);
		}
		CodeBuffer = NULL;
	}

	if( (DataBuffer != NULL) && (DataSize != 0) ) {
		if( !WriteProcessMemory(ClientProcessHandle,
							(LPVOID) DataStart, //code,
							DataBuffer, // source,
							DataSize,
							NULL) ) {
			error();
			msg( "mwrites");
			ExitProcess(-1);
		}

		if( !VirtualFree(DataBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReplyReq: 1" );
			ExitProcess(-1);
		}
		DataBuffer = NULL;
	}

	return 1;
}

int ReplyReqS(CLEAN_STRING message)
{
	char	*buffer;

	if (State != PROCESS_REQUESTS){
		msg("ReplyReqS: no init");
		ExitProcess(-1);
	}

#ifdef DEBUG_MV
	if( (CodeBuffer != NULL) && (CodeSize !=0 ) ) {
		if( !WriteProcessMemory(ClientProcessHandle,
							(LPVOID) CodeStart, //code,
							CodeBuffer, // source,
							CodeSize,
							&lpNumberOfBytesWritten) ) {
			error();
			msg( "mwrites");
			ExitProcess(-1);
		}

		if( !VirtualFree(CodeBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReplyReq: if( !VirtualFree(CodeBuffer,0,MEM_RELEASE) ) {" );
			ExitProcess(-1);
		}
		CodeBuffer = NULL;
	}

	if( (DataBuffer != NULL) && (DataSize != 0) ) {
		if( !WriteProcessMemory(ClientProcessHandle,
							(LPVOID) DataStart, //code,
							DataBuffer, // source,
							DataSize,
							NULL) ) {
			error();
			msg( "mwrites");
			ExitProcess(-1);
		}

		if( !VirtualFree(DataBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReplyReq: 1" );
			ExitProcess(-1);
		}
		DataBuffer = NULL;
	}
#endif

	buffer	= GetSendBuffer (message->length + DATA_START, MESSAGE_SIZE, Buffer, ClientProcessHandle);

	buffer[MESSAGE_TYPE] = ADDRESS_KNOWN;
	*((DWORD *) (buffer+SIZE_OF_MESSAGE)) = message->length;

	rsncopy( buffer + DATA_START,message->characters, message->length);

	Send();

	ReleaseSendBuffer (buffer, Buffer);
#ifdef DEBUG
	msg( "returning from ReplyReqS" );
#endif

	return 1;
}

// -------
int ReplyReq(int num)
{
	DWORD lpNumberOfBytesWritten;

#ifdef DEBUG
	msg( "ReplyReq" );
#endif

	if( State != PROCESS_REQUESTS ) {
		msg("ReplyReq: no init");
		ExitProcess(-1);
	}

	if( (CodeBuffer != NULL) && (CodeSize !=0 ) ) {
		
		if( !WriteProcessMemory(ClientProcessHandle,
							(LPVOID) CodeStart, //code,
							CodeBuffer, // source,
							CodeSize,
							&lpNumberOfBytesWritten) ) {
			error();
			msg( "mwrites");
			ExitProcess(-1);
		}

		if( !VirtualFree(CodeBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReplyReq: if( !VirtualFree(CodeBuffer,0,MEM_RELEASE) ) {" );
			ExitProcess(-1);
		}
		CodeBuffer = NULL;
	}

	if( (DataBuffer != NULL) && (DataSize != 0) ) {
		if( !WriteProcessMemory(ClientProcessHandle,
							(LPVOID) DataStart, //code,
							DataBuffer, // source,
							DataSize,
							NULL) ) {
			error();
			msg( "mwrites");
			ExitProcess(-1);
		}

		if( !VirtualFree(DataBuffer,0,MEM_RELEASE) ) {
			error();
			msg( "ReplyReq: 1" );
			ExitProcess(-1);
		}
		DataBuffer = NULL;
	}

	Buffer[MESSAGE_TYPE] = ADDRESS_KNOWN;
	*((int *) (Buffer+DATA_START)) = num;

	Send();

#ifdef DEBUG
	msg( "returning from ReplyReq" );
#endif

	return 1;
}

CLEAN_BOOL KillClient(int client_id) {

	int i;

	i = (N_OF_RESERVED_ENTRIES_INITIAL_BLOCK / 2);
	
	while( i < ((N_OF_RESERVED_ENTRIES_INITIAL_BLOCK / 2) + (PServerInfoBlock->n_Clients)) )  {

		if( (PServerInfoBlock->ProcessId)[i] == client_id ) {
			
			TerminateProcess( PServerInfoBlock->hClientKilledOrReady[2 * i + CLIENT_KILLED], 0 );

			return( CLEAN_TRUE );
		}
		i++;
	}
	
	msg( "KillClient: internal error; could not kill client process" );
	ExitProcess(-1);
	return( CLEAN_FALSE );
}
