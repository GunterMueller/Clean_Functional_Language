#ifndef GLOBALH
#define GLOBALH

#include <windows.h>

#include "clean_bool.h"
#include "..\Utilities\Util.h"

// book, page 972
#define chINITSTRUCT(structure, fInitSize)						\
	(zeroMemory(&(structure), sizeof(structure)),				\
	fInitSize ? (*(int*) &(structure) = sizeof(structure)) : 0)

// book, page 970
#define chDIMOF(Array) (sizeof(Array) / sizeof(Array[0]))

// book, page 971
#define chHANDLE_DLGMSG(hwnd, message, fn)						\
	case (message): return (SetDlgMsgResult(hwnd, uMsg,			\
		HANDLE_##message((hwnd), (wParam), (lParam), (fn))))

#define TAIL(p,s)		((p) = (s), (s) = (s) + rstrlen(s) + 1) 

#define RESOURCEAPI	__declspec(dllexport)

#ifdef ALLOC_GLOBALH
#define CLASS	
#else
#define CLASS	extern
#endif

CLASS HINSTANCE hin;
CLASS CLEAN_STRING EmptyCleanString;

#undef CLASS

#endif 



