#ifndef DYNAMICLINKH
#define DYNAMICLINKH

#define RESOURCEAPI	__declspec(dllexport)

#include <windows.h>

#include "clean_bool.h"
#include "..\Utilities\Util.h"

BOOL WINAPI DllMain (HINSTANCE hinstDLL, DWORD fdwReason, LPVOID fImpLoad);

RESOURCEAPI int FirstInstanceOfServer2(int firstinstance);
RESOURCEAPI CLEAN_STRING DoReqS(CLEAN_STRING s);
RESOURCEAPI CLEAN_BOOL PassCommandLine(CLEAN_STRING s);

#endif
