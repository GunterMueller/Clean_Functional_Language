#include "intrface_121.h"
#include "util_121.h"

extern OS WinBeep (OS);
extern void WinGetTime (OS,int*,int*,int*,OS*);
extern void WinGetDate (OS,int*,int*,int*,int*,OS*);
extern OS   WinWait (int,OS);
extern void WinGetBlinkTime (OS,int*,OS*);
extern void WinGetTickCount (OS,int*,OS*);
extern void WinPlaySound (CLEAN_STRING,OS,Bool*,OS*);
