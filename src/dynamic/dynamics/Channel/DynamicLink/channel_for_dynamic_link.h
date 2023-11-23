
#include <windows.h>

#include "..\Utilities\Util.h"

// Reserved message bytes, data at s[DATA_START]
#define DATA_START			6
#define MESSAGE_SIZE		4096

// Reserved fiels
#define MESSAGE_TYPE		1
#define SIZE_OF_MESSAGE		2

#define CLIENT	0
#define SERVER	1

// Field 1
// all other values are invalid
#define ADDRESS_REQUEST			0
#define ADDRESS_KNOWN			1
#define ADDRESS_UNKNOWN			2
#define NEED_BASE_OF_LIBRARIES	3
#define ADD_CLIENT				4
#define LARGE_MESSAGE			5

// buffers
#define BUFFER_SIZE_UNKNOWN		0

#define CLIENT_KILLED	0
#define CLIENT_READY	1
#define SERVER_OK		2

#define IS_CLIENT_KILLED(i)		(((i) % 2) == CLIENT_KILLED)
#define IS_CLIENT_READY(i)		(((i) % 2) == CLIENT_READY)

#define INDEX_CLIENT_KILLED(i)	( ((i) / 2 ) * 2 + CLIENT_KILLED)
#define INDEX_CLIENT_READY(i)	( ((i) / 2 ) * 2 + CLIENT_READY)

#define INDEX(i)	((i) / 2)

typedef struct _BufferInfo {
	char *hView;
	HANDLE hMapping;
} BufferInfo, *PBufferInfo;

int Send();
int Receive();
char *GetSendBuffer (int size, int smallBufferSize, char *smallBuffer, HANDLE hReceivingProcess);
void ReleaseSendBuffer (char *buffer, char *smallBuffer);
char *GetReceiveBuffer (char *smallBuffer);
void ReleaseReceiveBuffer (char *buffer, char *smallBuffer);
void SetHandlesToClient (HANDLE hserver_ready, HANDLE hclient_killed, HANDLE hclient_ready);
void CreateBuffer(char *name, int size, BOOL open_buffer, BufferInfo *info);
void CloseBuffer(BufferInfo *info);

__declspec(dllexport) CLEAN_STRING GetDynamicLinkerPath ();
