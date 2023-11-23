#include "util_121.h"

extern OS WinInvalidateWindow (OSWindowPtr wnd, OS ios);
extern OS WinInvalidateRect (OSWindowPtr wnd, int left, int top, int right,
                int bottom, OS ios);
extern OS WinValidateRect (OSWindowPtr wnd, int left, int top, int right,
                int bottom, OS ios);
extern OS WinValidateRgn (OSWindowPtr wnd, OSRgnHandle rgn, OS ios);

/*	Win(M/S)DIClientToOuterSizeDims returns the width and height needed to add/subtract
	from the client/outer size to obtain the outer/client size.
	These values must be the same as used by W95AdjustClean(M/S)DIWindowDimensions!
*/
extern void WinMDIClientToOuterSizeDims (int styleFlags, OS ios, int *dw, int *dh, OS *oos);
extern void WinSDIClientToOuterSizeDims (int styleFlags, OS ios, int *dw, int *dh, OS *oos);

/*	UpdateWindowScrollbars updates any window scrollbars and non-client area if present.
*/
extern void UpdateWindowScrollbars (OSWindowPtr hwnd);

/*	Access procedures to dimensions:
*/
extern void WinScreenYSize (OS,int*,OS*);
extern void WinScreenXSize (OS,int*,OS*);
extern void WinMinimumWinSize (int *mx, int *my);
extern void WinScrollbarSize (OS ios, int *width, int *height, OS *oos);
extern void WinMaxFixedWindowSize (int *mx, int *my);
extern void WinMaxScrollWindowSize (int *mx, int *my);
