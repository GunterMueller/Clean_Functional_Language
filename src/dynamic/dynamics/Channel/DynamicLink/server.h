
#ifndef SERVERH
#define SERVERH

#include <windows.h>

#include "..\Utilities\Util.h"
#include "clean_bool.h"

#define RESOURCEAPI	__declspec(dllexport)

RESOURCEAPI void StartProcess (CLEAN_STRING current_directory, CLEAN_STRING file_name, CLEAN_STRING commandline, CLEAN_BOOL *ok, int *client_id);
RESOURCEAPI CLEAN_BOOL StoreLong(int pvMem, int l);
RESOURCEAPI int mwrites(int kind, int offset, CLEAN_STRING s, int address);
RESOURCEAPI void ReceiveReq(CLEAN_BOOL static_application_as_client, int *client_id, CLEAN_STRING *result);
RESOURCEAPI void ReceiveCodeDataAdr(int code_size, int data_size, CLEAN_BOOL *result, int *code_start, int *data_start);
RESOURCEAPI void NeedBaseLibraries(CLEAN_STRING clstring, int n_libraries,CLEAN_BOOL *result,CLEAN_STRING *s);
RESOURCEAPI int ReplyReq(int num);
RESOURCEAPI CLEAN_BOOL KillClient(int client_id);
RESOURCEAPI int ReplyReqS(CLEAN_STRING message);
RESOURCEAPI void ReceiveReqWithTimeOut(CLEAN_BOOL static_application_as_client, CLEAN_BOOL *timeout,int *client_id, CLEAN_STRING *result);
RESOURCEAPI int FlushBuffers();

#endif