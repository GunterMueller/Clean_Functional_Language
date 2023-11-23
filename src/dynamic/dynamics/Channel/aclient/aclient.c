
#include <windows.h>
#include <stdio.h>

#include "..\Utilities\Util.h"
#include "..\ClientChannel\channel.h"

// Display error
void error()
{
	LPVOID lpMsgBuf;
		
	FormatMessage( 
		FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,    NULL,
		GetLastError(),
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), // Default language
		(LPTSTR) &lpMsgBuf,    0,    NULL );// Display the string.

	MessageBox( NULL, lpMsgBuf, "GetLastError", MB_OK|MB_ICONINFORMATION );
	LocalFree( lpMsgBuf );
}

void msg(char *lpMsgBuf)
{
	MessageBox( NULL, lpMsgBuf, "wwGetLastError", MB_OK|MB_ICONINFORMATION );
}

Bool CallFunction (int *func);

#ifdef GUICLIENT
int WINAPI WinMain(HINSTANCE hinstExe, HINSTANCE hinstExePrev,
				   LPSTR szCmdLine, int nCmdShow) {
#else
void main(int argc, char **argv) {
#endif
	char *s;
	int *a;

	InitClientDLL();

	s = (char*) DoReqS (cleanstring ("LibInit\n\n"));

	a = *((int**) (s + 4));

	if (a == NULL){
		msg ( "client: adres bestaat niet" );
		ExitProcess(-1);
	} else
		CallFunction(a);
}

Bool CallFunction (int *func)
{
	void (*MyFunc)();

	if (func == NULL){
		msg ( "CallFunction: adres is 0" );
		return 0;
	}

	MyFunc = (void (*)()) func;
	MyFunc();

	return 1;
}
