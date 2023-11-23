#ifndef CHANNEL_H
#define CHANNEL_H

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

#define SERVER_KILLED	0
#define SERVER_READY	1
#define CLIENT_OK		2

__declspec(dllexport) HANDLE GetHandleToServer();
 
__declspec(dllexport) char *CreateChannel(int isClient);
__declspec(dllexport) void CloseChannel();
__declspec(dllexport) int Send();
__declspec(dllexport) int Receive();
__declspec(dllexport) CLEAN_STRING GetDynamicLinkerPath();
__declspec(dllexport) char *GetSendBuffer (int size, int smallBufferSize, char *smallBuffer, HANDLE hReceivingProcess);
__declspec(dllexport) void ReleaseSendBuffer (char *buffer, char *smallBuffer);
__declspec(dllexport) char *GetReceiveBuffer (char *smallBuffer);
__declspec(dllexport) void ReleaseReceiveBuffer (char *buffer, char *smallBuffer);

__declspec(dllexport) void SetHandleToServer (HANDLE hServer);
__declspec(dllexport) CLEAN_STRING DoReqS (CLEAN_STRING s);
__declspec(dllexport) char *extract_dlink_path (char *path);
__declspec(dllexport) BOOL replace_command_line (CLEAN_STRING s);
__declspec(dllexport) BOOL CleanNewKey (CLEAN_STRING key,CLEAN_STRING value);

typedef struct _BufferInfo {
	char *hView;
	HANDLE hMapping;
} BufferInfo, *PBufferInfo;

__declspec(dllexport) void CreateBuffer(char *name, int size, BOOL open_buffer, BufferInfo *info);
__declspec(dllexport) void CloseBuffer(BufferInfo *info);

__declspec(dllexport) void InitClientDLL();

#endif
