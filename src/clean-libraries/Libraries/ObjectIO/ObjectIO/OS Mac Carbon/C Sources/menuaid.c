#ifdef __MACH__
#include <Carbon/Carbon.h>
#else
#include <Script.h>
#endif

/* vgl Inside Mac: Text p C-24 */

long getMenuEvent (long keycode)
{
	unsigned long state	= 0;
	void *kchrPtr	= (void *)GetScriptManagerVariable(smKCHRCache);	// should update when script changes...

	return KeyTranslate (kchrPtr,keycode,&state);
//	*char1 = (state && 0x000000FF);
//	*char2 = (state && 0x00FF0000) >> 16;
}