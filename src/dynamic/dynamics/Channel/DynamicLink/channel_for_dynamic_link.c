
#include <windows.h>
#include <shlobj.h>
#include <winbase.h>

#include "channel_for_dynamic_link.h"
#include "..\Utilities\Util.h"
#include "utilities.h"

#define CLIENT_KILLED	0
#define CLIENT_READY	1
#define SERVER_OK		2

static HANDLE hClientKilledOrReady[2] = { NULL, NULL };
static HANDLE hServerReady = NULL;

static BufferInfo LargeReceiveBufferInfo;
static	BufferInfo LargeSendBufferInfo;

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
			msg ("GetSendBuffer: could not dup handle");
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
	} else if (buffer != smallBuffer){
		msg ("ReleaseSendBuffer: unrecognised buffer");
		ExitProcess(-1);
	}
}

char *GetReceiveBuffer (char *smallBuffer)
{
	if (smallBuffer[MESSAGE_TYPE] == LARGE_MESSAGE){
		LargeReceiveBufferInfo.hMapping = *((HANDLE *) (smallBuffer+DATA_START));
		LargeReceiveBufferInfo.hView = (char *)
			MapViewOfFile (LargeReceiveBufferInfo.hMapping, FILE_MAP_READ, 0, 0, *((DWORD *) (smallBuffer+SIZE_OF_MESSAGE)));

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
	} else if (buffer != smallBuffer) {
		msg ("ReleaseReceiveBuffer: unrecognised buffer");
		ExitProcess(-1);
	}
}

void SetHandlesToClient (HANDLE hserver_ready,HANDLE hclient_killed,HANDLE hclient_ready)
{
	hServerReady = hserver_ready;
	hClientKilledOrReady[CLIENT_KILLED] = hclient_killed;
	hClientKilledOrReady[CLIENT_READY] = hclient_ready;
}

int Send()
{
	DWORD dwObject;

	dwObject = WaitForSingleObject (hClientKilledOrReady[CLIENT_KILLED], 0);

	if (dwObject == WAIT_OBJECT_0)
		return CLIENT_KILLED;
	else {
		SetEvent (hServerReady);
		return SERVER_OK;
	}
}

int Receive()
{
	DWORD dwObject;

	if (hClientKilledOrReady[CLIENT_KILLED] == NULL)
		msg ("SERVER: client not init");

	dwObject = WaitForMultipleObjects (2, hClientKilledOrReady, FALSE, INFINITE);

	if (dwObject == WAIT_FAILED)
		msg ("SERVER: wait failed; handle not set");

	return dwObject;
}

/* Named buffers */
void CloseBuffer (BufferInfo *info)
{
	UnmapViewOfFile(info->hView);
	CloseHandle(info->hMapping);
}

void CreateBuffer (char *name, int size, BOOL open_buffer, BufferInfo *info)
{
	char s[100];

	/* Create or open a buffer */
	if (open_buffer){
		info->hMapping = OpenFileMapping (FILE_MAP_WRITE, FALSE, name);
		if (info->hMapping == NULL){
			error();
			msg ("CreateBuffer: error opening file mapping");
			ExitProcess (-1);
		}
	} else {
		info->hMapping = CreateFileMapping ((HANDLE)0xFFFFFFFF,NULL,PAGE_READWRITE,0,size,name);
		if (info->hMapping == NULL){
			error();
			msg ("Client CreateBuffer: hLibraryBufferMapping");
			ExitProcess (-1);
		}
	}

	/* Create a view on the buffer */
	info->hView = (char *) MapViewOfFile(info->hMapping, FILE_MAP_WRITE, 0, 0, size);
	if (info->hView == NULL){
		error();
		sprintf (s, "CreateBuffer: hLibraryBufferView '%d' '%s'", size, name);
		msg (s);
		CloseHandle (info->hMapping);
		ExitProcess (-1);
	}
}

static char *GetPathOfDynamicLinker()
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

__declspec(dllexport) CLEAN_STRING GetDynamicLinkerPath ()
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
