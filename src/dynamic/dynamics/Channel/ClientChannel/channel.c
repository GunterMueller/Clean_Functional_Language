
#include <windows.h>
#include <shlobj.h>
#include <winbase.h>

#include "channel.h"
#include "..\Utilities\Util.h"
#include "..\DynamicLink\utilities.h"

#include <winreg.h>
#include "..\DynamicLink\serverblock.h"
#include "..\DynamicLink\clean_bool.h"
#include "select_dynamic_linker_folder.h"

#define SERVER_KILLED	0
#define SERVER_READY	1
#define CLIENT_OK		2

static HANDLE hServerKilledOrReady[2] = { NULL, NULL };
static HANDLE hClientReady = NULL;

__declspec(dllexport) void StartDynamicLinker();

static char *Buffer = NULL;
static DWORD BufferSize;
static BufferInfo LargeReceiveBufferInfo;
static	BufferInfo LargeSendBufferInfo;

HANDLE GetHandleToServer()
{
	InitClientDLL();

	return hServerKilledOrReady[SERVER_KILLED];
}
 
void SetHandleToServer(HANDLE hServer)
{
	hServerKilledOrReady[SERVER_KILLED] = hServer;
}

char *GetSendBuffer (int size, int smallBufferSize, char *smallBuffer, HANDLE hReceivingProcess)
{
	if (size > smallBufferSize){
		BOOL ok;
		HANDLE hReceivingMapping;

		CreateBuffer (NULL, size, FALSE, &LargeSendBufferInfo);
		ok = DuplicateHandle (GetCurrentProcess(), LargeSendBufferInfo.hMapping,
								hReceivingProcess, &hReceivingMapping,
								0, FALSE, DUPLICATE_SAME_ACCESS);

		if (!ok){
			error();
			msg ("DuplicateHandle failed in function GetSendBuffer in channel.c");
			ExitProcess(-1);
		}
		
		smallBuffer[MESSAGE_TYPE] = LARGE_MESSAGE;
		*((DWORD *) (smallBuffer+SIZE_OF_MESSAGE)) = size;
		*((HANDLE *) (smallBuffer+DATA_START)) = hReceivingMapping;

		return LargeSendBufferInfo.hView;
	} else
		return smallBuffer;
}

void ReleaseSendBuffer (char *buffer, char *smallBuffer)
{
	if (buffer == LargeSendBufferInfo.hView){
		CloseBuffer (&LargeSendBufferInfo);
		LargeSendBufferInfo.hMapping = NULL;
		LargeSendBufferInfo.hView = NULL;
	} else if (buffer != smallBuffer) {
		msg("ReleaseSendBuffer: unrecognised buffer");
		ExitProcess(-1);
	}
}

char * GetReceiveBuffer (char *smallBuffer)
{
	if (smallBuffer[MESSAGE_TYPE] == LARGE_MESSAGE){
		LargeReceiveBufferInfo.hMapping = *((HANDLE *) (smallBuffer+DATA_START));
		LargeReceiveBufferInfo.hView = (char *) MapViewOfFile( LargeReceiveBufferInfo.hMapping,
											FILE_MAP_READ, 0, 0, *((DWORD *) (smallBuffer+SIZE_OF_MESSAGE)));

		if (LargeReceiveBufferInfo.hView == NULL){
			error();
			msg ( "GetReceiveBuffer: could not open file mapping" );
			ExitProcess(-1);
		}

		return LargeReceiveBufferInfo.hView;
	} else
		return smallBuffer;
}

void ReleaseReceiveBuffer (char *buffer, char *smallBuffer)
{
	if (buffer == LargeReceiveBufferInfo.hView){	
		UnmapViewOfFile (LargeReceiveBufferInfo.hView);
		CloseHandle (LargeReceiveBufferInfo.hMapping);
		LargeReceiveBufferInfo.hView = NULL;
		LargeReceiveBufferInfo.hMapping = NULL;
	} else if (buffer != smallBuffer){
		msg ("ReleaseReceiveBuffer: unrecognised buffer");
		ExitProcess(-1);
	}
}

static int first_time = 1;

CLEAN_STRING DoReqS (CLEAN_STRING s)
{
	int code_size = 0;
	int data_size = 0;
	int *code,*data;
	BufferInfo server_info,client_info;
	char *hClientView,*hServerView,*buffer;
	int i;
	HANDLE h;
	static CLEAN_STRING clean_string = NULL;

	code = NULL;
	data = NULL;

	if (clean_string != NULL){
		rfree(clean_string);
		clean_string = NULL;
	}

	if (first_time){
		first_time = 0;
		StartDynamicLinker();
	}

	buffer = GetSendBuffer (DATA_START+sizeof(DWORD)+s->length+1, BufferSize, Buffer, hServerKilledOrReady[SERVER_KILLED]);
	// message header
	buffer [MESSAGE_TYPE] = (char) ADDRESS_REQUEST;
	*((DWORD *) (buffer+SIZE_OF_MESSAGE)) = s->length;

	*((DWORD *) (buffer+DATA_START)) = GetCurrentProcessId();
	
	// Copy module/label-string
	rsncopy (buffer + DATA_START + sizeof(DWORD), s->characters, s->length);
	buffer[(s->length)+ DATA_START + sizeof(DWORD)] = 0; /* why the '\0' termination ? */

	Send();
	ReleaseSendBuffer (buffer, Buffer);

	// Receive code and data sizes 
	if( (Receive()) == SERVER_KILLED) {
		ExitProcess(-1);
	}

	while (Buffer[MESSAGE_TYPE]==ADDRESS_UNKNOWN){		
		// Allocate code
		code_size = *((int *) (Buffer+DATA_START));
		if (code_size!=0){
			code = (int *) VirtualAlloc (NULL, code_size, MEM_RESERVE | MEM_COMMIT, PAGE_EXECUTE_READWRITE );
			if (!code){
				error();
				msg ("DoReq 1");
				ExitProcess (-1);
			}
	
			*((int**)(Buffer+DATA_START)) = code;
		}

		// Allocate data
		data_size = *((int *) (Buffer+DATA_START+sizeof(int)));
		if (data_size!=0){
			data = (int *) VirtualAlloc (NULL, data_size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE );
			if (!data){
				error();
				ExitProcess (-1);
			}

			*((int**) (Buffer+DATA_START+sizeof(int))) = data;
		}

		Send();

		// Receive a label or a request to return the base
		// addresses of used libraries
		if (Receive() == SERVER_KILLED){
			msg ("server killed");
			ExitProcess(-1);
		}

		// Need base addresses of libraries
		if (Buffer[MESSAGE_TYPE] == NEED_BASE_OF_LIBRARIES){
			int n_libraries, s_buffer;

			n_libraries = *((int *) (Buffer+DATA_START));
			s_buffer = *((int *) (Buffer+DATA_START+sizeof(int)));

			// Open the server buffer containing the names of the
			// needed libraries

			CreateBuffer ("ServerLibraryBuffer", s_buffer, TRUE, &server_info);
			hServerView = server_info.hView;

			// Allocate a client buffer to contain the base addresses
			// of all libraries
			CreateBuffer ("ClientLibraryBuffer", n_libraries * sizeof(HINSTANCE), FALSE, &client_info);
			hClientView = client_info.hView;

			for (i = 0; i < n_libraries; i++ ){
				HINSTANCE library;

				library = LoadLibrary (hServerView);
				if (library==NULL){
					error();
					msg ("LoadLibrary in DoReqS in channel.c failed");
					msg (hServerView);
					ExitProcess(-1);
				}

				*((HANDLE*)hClientView) = library;

				hServerView += rstrlen(hServerView) + 1;
				hClientView += sizeof(HINSTANCE); 
			}

			Send();

			CloseBuffer (&server_info);

			/* Receive label */
			Receive();

			CloseBuffer (&client_info);
		} 
	}

	buffer = GetReceiveBuffer (Buffer);

	if (buffer[MESSAGE_TYPE] == ADDRESS_KNOWN){
		int length;

		length = *((DWORD *) (buffer+SIZE_OF_MESSAGE));
		clean_string = (CLEAN_STRING) rmalloc (sizeof(int) + length);
		clean_string->length = length;

		rsncopy(clean_string->characters, buffer + DATA_START, length);

		ReleaseReceiveBuffer (buffer, Buffer);

		return clean_string;
	} else {
		ExitProcess(-1);
	}

	return NULL;
}

__declspec(dllexport) void InitClientDLL ()
{
	LPTSTR cmdline;
	DWORD dwServerId;
	HANDLE hFileMapping,hFileMapping2;
	BOOL ok;
	int i;
	char buffer[100];
	DWORD result;
	char *charp;

	if (first_time){
		first_time = 0;

	// dwServerId
		result = GetEnvironmentVariable ("dwServerId",buffer,100);
		if( !result ) {
			msg( "DllMain: ClientChannel.dll  could not find environment variable1!" );
			charp = GetEnvironmentStrings();
			msg( charp);
			ExitProcess(-1);
		}
		result = sscanf( buffer, "%u", &dwServerId);
		if( !result ) {
			msg ("conversion failed");
			ExitProcess(-1);
		}

		// hServerReady
		result = GetEnvironmentVariable ("hServerReady",buffer,100);
		if( !result ) {
			msg( "DllMain: ClientChannel.dll could not find environment variabale2 " );
			ExitProcess(-1);
		}
		sscanf( buffer, "%u", &(hServerKilledOrReady[SERVER_READY]));

		// hClientReady
		result = GetEnvironmentVariable ("hClientReady",buffer,100);
		if( !result ) {
			msg( "DllMain: ClientChannel.dll could not find environment variabale3" );
			ExitProcess(-1);
		}
		sscanf( buffer, "%u", &hClientReady);

		// hFileMapping
		result = GetEnvironmentVariable ("hFileMapping",buffer,100);
		if( !result ) {
			msg( "DllMain: ClientChannel.dll could not find environment variabale4" );
			ExitProcess(-1);
		}
		sscanf( buffer, "%u", &hFileMapping);

		// MESSAGE_SIZE
		result = GetEnvironmentVariable ("MESSAGE_SIZE",buffer,100);
		if( !result ) {
			msg( "DllMain: ClientChannel.dll could not find environment variabale6" );
			ExitProcess(-1);
		}
		sscanf( buffer, "%u", &BufferSize);

		Buffer = (char *) MapViewOfFile( hFileMapping, FILE_MAP_WRITE, 0, 0, BufferSize);
		if( Buffer == NULL ) {
			error();
			msg ( "Channel.c" );
			ExitProcess(-1);
		}

		hServerKilledOrReady[SERVER_KILLED] = OpenProcess(STANDARD_RIGHTS_REQUIRED | PROCESS_ALL_ACCESS, FALSE, dwServerId);
		if( hServerKilledOrReady[SERVER_KILLED] == NULL ) {		
			error();
			msg( "OK" );
			ExitProcess(-1);
		}

		CloseHandle( hFileMapping );
	}
} 

void CloseChannel()
{
}

int Send()
{
	DWORD dwObject;

	dwObject = WaitForSingleObject(hServerKilledOrReady[SERVER_KILLED],0);

	if (dwObject == WAIT_OBJECT_0)
		return SERVER_KILLED;
	else {
		SetEvent (hClientReady);
		return CLIENT_OK;
	}
}
	
int Receive()
{
	DWORD dwObject;

	if (hServerKilledOrReady[SERVER_KILLED] == NULL)
		msg ("CLIENT: server not init");

	dwObject = WaitForMultipleObjects (2, hServerKilledOrReady, FALSE, INFINITE);

	if (dwObject == WAIT_FAILED){
		error();
		msg ("CLIENT: wait failed; handle not set");
	}

	return( dwObject );
}

/* Named buffers */
void CloseBuffer (BufferInfo *info)
{
	UnmapViewOfFile (info->hView);
	CloseHandle (info->hMapping);
}

void CreateBuffer (char *name, int size, BOOL open_buffer, BufferInfo *info)
{
	char s[100];

	/* Create or open a buffer */
	if (open_buffer){
		info->hMapping = OpenFileMapping(FILE_MAP_WRITE, FALSE, name );
		if (info->hMapping==NULL){
			error();
			msg( "CreateBuffer: error opening file mapping ");
			ExitProcess(-1);
		}
	} else {
		info->hMapping = CreateFileMapping((HANDLE)0xFFFFFFFF,NULL,PAGE_READWRITE,0,size,name);
		if (info->hMapping==NULL){
			error();
			msg( "Client CreateBuffer: hLibraryBufferMapping" );
			sprintf( s, "Was opening: %s ", name );
			msg( s );
			ExitProcess(-1);
		}
	}

	/* Create a view on the buffer */
	info->hView = (char *) MapViewOfFile(info->hMapping, FILE_MAP_WRITE, 0, 0, size);
	if (info->hView==NULL){
		error(); 
		sprintf( s, "CreateBuffer: hLibraryBufferView '%d' '%s'", size, name );
		msg( s  );
		CloseHandle(info->hMapping);
		ExitProcess(-1);
	}
}

char *GetPathOfDynamicLinker()
{
	LONG lResult;
	HKEY hkResult;
	DWORD dwLength;

	static char szDynamicLinker[MAX_PATH+1];

	lResult = RegOpenKeyEx (HKEY_CURRENT_USER,"Software\\Clean\\dynamic link\\command",0,KEY_ALL_ACCESS,&hkResult);
	if (lResult != ERROR_SUCCESS)
		return NULL;
	
	dwLength = MAX_PATH+1;
	RegQueryValue (hkResult,NULL,szDynamicLinker,&dwLength);
	if (lResult != ERROR_SUCCESS)
		return NULL;
	
	RegCloseKey (hkResult);

	return szDynamicLinker;
}

CLEAN_STRING GetDynamicLinkerPath ()
{
	char *p;
	int length;

	static CLEAN_STRING r = NULL;

	if (r)
		rfree (r);

	// get dynamic linker path
	p = GetPathOfDynamicLinker();

	if (p!=NULL)
		length = rstrlen (p);
	else
		length = 0;

	r = (CLEAN_STRING) rmalloc (sizeof (int) + length);

	// copy path to clean string
	rsncopy (r->characters, p, length);
	
	// set length
	r->length = length;

	return r;
}

/*
** ------------------------------------------------------------------
** STATIC CLIENT CHANNEL
**
** If an CLEAN application is eagerly linked, the named channel is
** used to communicate with the server. The server responds by 
** sending synchronization objects etc.
*/

static char *replaced_command_line = NULL;

__declspec(dllexport) BOOL replace_command_line(CLEAN_STRING s)
{
	replaced_command_line = (char *) rmalloc (s->length + 1);

	rsncopy (replaced_command_line,s->characters,s->length);
	
	replaced_command_line[s->length] = '\0';

	return CLEAN_TRUE;
}

__declspec(dllexport) BOOL CleanNewKey (CLEAN_STRING key,CLEAN_STRING value)
{
	// key, value are null-terminated Clean strings
	return NewKey (key->characters, value->characters, REG_EXPAND_SZ) ? CLEAN_TRUE : CLEAN_FALSE;
}

BOOL NewKey (LPCTSTR keypath, LPCTSTR value, DWORD dwType)
{
	HKEY hkResult;
	DWORD dwDisposition;
	LONG lResult;

	lResult = RegCreateKeyEx (HKEY_CURRENT_USER, keypath, 0, "SZ_STRING_EXPAND", REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, NULL,
								&hkResult, &dwDisposition);
	if (lResult != ERROR_SUCCESS)
		return FALSE;

	lResult = RegSetValueEx (hkResult, NULL, 0, REG_SZ, value, strlen (value) + 1);
	if (lResult != ERROR_SUCCESS){
		RegCloseKey (hkResult);
		return FALSE;
	}

	lResult = RegCloseKey (hkResult);
	if (lResult != ERROR_SUCCESS)
		return FALSE;

	return TRUE;
}

char *extract_dlink_path (char *path)
{
	static char buffer[MAX_PATH];
	int i;
	int pclose;

	if (path==NULL || path[0]=='\0')
		return NULL;

	i = 1;
	while (path[i]!='\0' && path[i]!='\"')
		buffer[i-1] = path[i++];

	if (path[i]=='\0')
		return NULL;

	buffer[i-1] = '\0';

	return buffer;
}

/*
** StartDynamicLinker
** If the DynamicLinker has already been started, the commandline of
** this instantion is sent to the first instance.
*/
__declspec(dllexport) void StartDynamicLinker()
{
	HANDLE hObjects[2];
	DWORD dwResult;
	// Path from registry to dynamic linker
	char *szDynamicLinker;
	// Needed for dynamic linker start
	PROCESS_INFORMATION pi;
	DWORD dwExitCode;
	STARTUPINFO si;
	BOOL fSuccess;
	char commandline[MAX_PATH*2];
	HANDLE hFileMapping, hGlobalServerReady;
	DWORD dwServerId;
	HANDLE hServerReady_new, hClientReady_new;
	DWORD length;
	HANDLE hFileMapping_new;
	// Temp
	char *s;
	char executable[MAX_PATH];

	first_time = 0;

	hFileMapping = OpenFileMapping (FILE_MAP_WRITE, FALSE, GLOBAL_BUFFER_NAME);
	if (hFileMapping == NULL){
		szDynamicLinker = extract_dlink_path( GetPathOfDynamicLinker() );

		ZeroMemory (&si,sizeof(si));
		si.cb = sizeof(si);

		fSuccess = 0;
		if (szDynamicLinker != NULL){
			// first try registry path
			sprintf (commandline, "\"%s\" /W", szDynamicLinker);

			fSuccess = CreateProcess (szDynamicLinker, commandline,	NULL, NULL,	FALSE, 0, NULL,	NULL, &si, &pi);
		}

		if (!fSuccess){
			// ask user
			szDynamicLinker = SelectDynamicLinkerFolder();
			if( szDynamicLinker == NULL )
				ExitProcess(-1);

			sprintf( executable, "%s\\DynamicLinker.exe", szDynamicLinker );
			sprintf( commandline, "\"%s\" /W", szDynamicLinker );

			fSuccess = CreateProcess (executable, commandline, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi);
			if (!fSuccess){
				msg ("StaticClientChannel: internal error");
				ExitProcess(-1);
			}
			// Dynamic start

			sprintf( commandline, "\"%s\" /S \"%%1\"", executable );
			if (NewKey ("Software\\Clean\\dynamic link\\command", commandline, REG_EXPAND_SZ) == FALSE)
				msg ("Setting a key in the registry failed");
		};

		/* Process created */
		CloseHandle (pi.hThread);

		// wait for dynamic linker to be ready to communicate
		hObjects[0] = pi.hProcess;
		hObjects[1] = NULL;

		while( !((dwResult = WaitForMultipleObjects (hObjects[1] == NULL ? 1 : 2, hObjects, FALSE, 0)) < 2))
			hObjects[1] = OpenEvent( EVENT_ALL_ACCESS , FALSE, GLOBAL_SERVER_READY_NAME );

		CloseHandle (pi.hProcess);

		if (dwResult - WAIT_OBJECT_0 == 0){
			msg ("StaticClientChannel: dynamic linker killed");
			ExitProcess(-1);
		} else
			hGlobalServerReady = hObjects[1];
		
		/*
		** It is guaranteed that the hGlobalServerReady--event only 
		** becomes signaled AFTER the buffer has been allocated and
		** initialized
		*/
		hFileMapping = OpenFileMapping (FILE_MAP_WRITE, FALSE, GLOBAL_BUFFER_NAME);
		if (hFileMapping == NULL){
			msg ("StartDynamicLinker: could not open mapping");
			ExitProcess(-1);
		}		
	} else {
		hGlobalServerReady = OpenEvent( EVENT_ALL_ACCESS , FALSE, GLOBAL_SERVER_READY_NAME );
		if( hGlobalServerReady == NULL ) {
			msg ("StartDynamicLinker: could not open global server ready-event");
			ExitProcess(-1);
		}
		WaitForSingleObject (hGlobalServerReady, INFINITE);
	}

	/* The hGlobalServerReady was ready and the buffer has been opened. */
	Buffer = (char *) MapViewOfFile (hFileMapping, FILE_MAP_WRITE, 0, 0, MESSAGE_SIZE);
	if (Buffer == NULL){
		error();
		msg ("StartDynamicLinker: could not open file mapping");
		ExitProcess(-1);
	}

	dwServerId = *((DWORD *) (Buffer+GLOBAL_BUFFER_SERVER_ID));
	hServerKilledOrReady[SERVER_KILLED] = OpenProcess (STANDARD_RIGHTS_REQUIRED | PROCESS_ALL_ACCESS, FALSE, dwServerId);
	if (hServerKilledOrReady[SERVER_KILLED]==NULL){
		error();
		msg ("StartDynamicLinker: could not open process handle of server");
		ExitProcess(-1);
	}

	hServerKilledOrReady[SERVER_READY] = OpenEvent (EVENT_ALL_ACCESS , FALSE, LOCAL_SERVER_READY_NAME);
	if( hServerKilledOrReady[SERVER_READY] == NULL ) {
		msg ("StartDynamicLinker: could not open lobal server ready-event");
		ExitProcess(-1);
	} 

	hClientReady = OpenEvent (EVENT_ALL_ACCESS, FALSE, LOCAL_CLIENT_READY_NAME);
	if (hClientReady==NULL){
		msg ("StartDynamicLinker: could not open local client ready--event");
		ExitProcess(-1);
	}

	// Protocol
	// AddAndInit <command_line>
	//
	// layout
	// GLOBAL_BUFFER_START		Contents
	// + 0						UNKNOWN_CLIENT or CLIENT_ID
	// + 4						AddAndInt\ncommand_line\n\n
	*((DWORD *) (Buffer+GLOBAL_BUFFER_START)) = GetCurrentProcessId();

	sprintf( Buffer + sizeof(DWORD) + GLOBAL_BUFFER_START, "AddAndInit\n%s\n%s\n\n", replaced_command_line ? replaced_command_line : GetCommandLine(), replaced_command_line ? "T" : "F");

	Send(); 

	Receive();

	dwServerId = *((DWORD *) (Buffer+GLOBAL_BUFFER_START));
	hServerReady_new = *((HANDLE *) (Buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) ));
	hClientReady_new = *((HANDLE *) (Buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) + sizeof(HANDLE) ));
	hFileMapping_new = *((HANDLE *) (Buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) + 2 * sizeof(HANDLE) ));
	length			 = *((DWORD  *) (Buffer+ GLOBAL_BUFFER_START + sizeof(DWORD) + 3 * sizeof(HANDLE) ));

	// Signal server that buffer contents is processed
	Send();
	
	Receive(); //make hClientReady signaled, hServerReady unsignaled

	/* Free resources */
	CloseHandle (hFileMapping);
	CloseHandle (hGlobalServerReady);
	CloseHandle (hServerKilledOrReady[SERVER_KILLED]);
	CloseHandle (hServerKilledOrReady[SERVER_READY]);
	CloseHandle (hClientReady);
	UnmapViewOfFile (Buffer);

	/* Initialize the channel using the received objects */
	hServerKilledOrReady[SERVER_READY] = hServerReady_new;
	hClientReady = hClientReady_new;

	Buffer = (char *) MapViewOfFile (hFileMapping_new, FILE_MAP_WRITE, 0, 0, length);
	if (Buffer==NULL){
		error();
		msg ("Channel.c");
		ExitProcess(-1);
	}

	hServerKilledOrReady[SERVER_KILLED] = OpenProcess (STANDARD_RIGHTS_REQUIRED | PROCESS_ALL_ACCESS, FALSE, dwServerId);
	if (hServerKilledOrReady[SERVER_KILLED]==NULL){	
		error();
		msg ("OK");
		ExitProcess(-1);
	}

	CloseHandle (hFileMapping_new);
}
