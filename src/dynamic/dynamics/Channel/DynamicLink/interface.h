
#ifndef INTERFACEH
#define INTERFACEH

#include <windows.h>

#include "..\Utilities\Util.h"
#include "clean_bool.h"

#define RESOURCEAPI	__declspec(dllexport)

RESOURCEAPI void SetCurrentLibrary(CLEAN_STRING clstring, CLEAN_BOOL *result, DWORD *lib); 
RESOURCEAPI int CloseLibrary(DWORD lib);
RESOURCEAPI void GetFuncAddress (CLEAN_STRING clstring, DWORD base_of_client_dll, DWORD lib0, DWORD *address, DWORD *lib1); 

RESOURCEAPI CLEAN_BOOL GenerateObjectFileOld(CLEAN_STRING cg, CLEAN_STRING CmdLine);

#endif
