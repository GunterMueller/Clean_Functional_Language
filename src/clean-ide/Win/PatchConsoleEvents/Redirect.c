// Redirect.c : implementation file
//

#define	CcWmCONSOLEQUIT							141
#define	CcWmCONSOLEOUT							142
#define	CcWmCONSOLEERR							143

#define	WM_CONSOLEQUIT							0x0407
#define	WM_CONSOLEOUT							0x0408
#define	WM_CONSOLEERR							0x0409

/********************************************************************************************
	Include section.
********************************************************************************************/

#include "cCrossCall_121.h"
#include "cAcceleratorTable_121.h"					// Contains the implementation of accelerator tables.
#include "cCrossCallCursor_121.h"					// Contains the implementation of cursors.
#include <commctrl.h>

void VERIFY(BOOL bl)
{ return;
}

void ASSERT(BOOL bl)
{ return;
}

//extern HANDLE ghMainWindow;

void OnChildStdOutWrite(char *buffer)
{
	char *commandstring;
	int len;
//	SendMessage ((HWND) ghMainWindow, WM_CONSOLEOUT, (WPARAM)cleanstring(buffer), (LPARAM)NULL);
	len = lstrlen (buffer) + 1;
	commandstring = rmalloc (len);	/* this pointer is passed to and freed in the Clean code. */
	lstrcpyn (commandstring, buffer, len);

	PostMessage ((HWND) ghMainWindow, WM_CONSOLEOUT, (WPARAM)commandstring, (LPARAM)NULL);
//	PostMessage(ghMainWindow,0x0
}
void OnChildStdErrWrite(char *buffer)
{
//	SendMessage ((HWND) ghMainWindow, WM_CONSOLEERR, (WPARAM)cleanstring(buffer), (LPARAM)NULL);
	char *commandstring;
	int len;

	len = lstrlen (buffer) + 1;
	commandstring = rmalloc (len);	/* this pointer is passed to and freed in the Clean code. */
	lstrcpyn (commandstring, buffer, len);

	PostMessage ((HWND) ghMainWindow, WM_CONSOLEERR, (WPARAM)commandstring, (LPARAM)NULL);
}
void OnChildStarted()
{}
void OnChildTerminate()
{
//	SendMessage ((HWND) ghMainWindow, WM_CONSOLEQUIT, (WPARAM)NULL, (LPARAM)NULL);
	PostMessage ((HWND) ghMainWindow, WM_CONSOLEQUIT, (WPARAM)NULL, (LPARAM)NULL);
}

#define BUFFER_SIZE	256

static int StdOutThread(HANDLE );
static int StdErrThread(HANDLE );
static int ProcessThread();

HANDLE PrepAndLaunchRedirectedChild(LPCSTR lpszCmdLine,
	HANDLE hStdOut, HANDLE hStdIn, HANDLE hStdErr,
	BOOL bShowChildWindow);
/*
#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif
*/
// This class is build from the following MSDN article.
// Q190351 HOWTO: Spawn Console Processes with Redirected Standard Handles.

HANDLE m_hExitEvent;

// Child input(stdin) & output(stdout, stderr) pipes
HANDLE m_hStdIn, m_hStdOut, m_hStdErr;
// Parent output(stdin) & input(stdout) pipe
HANDLE m_hStdInWrite, m_hStdOutRead, m_hStdErrRead;
// stdout, stderr write threads
HANDLE m_hStdOutThread, m_hStdErrThread;
// Monitoring thread
HANDLE m_hProcessThread;
// Child process handle
HANDLE m_hChildProcess;
static BOOL m_bRunThread;
/////////////////////////////////////////////////////////////////////////////
// API Function

BOOL WINAPI IsWinNT()
{
  // get windows version
  DWORD WindowsVersion = GetVersion();
  DWORD WindowsMajorVersion = (DWORD)(LOBYTE(LOWORD(WindowsVersion)));
  DWORD WindowsMinorVersion = (DWORD)(HIBYTE(LOWORD(WindowsVersion)));

  // Running on WIN9x ?
  if (WindowsVersion >= 0x80000000) return FALSE;
  
  // Running on NT
  return TRUE;
}

#ifdef _WIN64
static void my_zero_memory (void *a,size_t n)
{
	unsigned char *p;
	size_t i;
	
	p=a;
	for (i=0; i<n; ++i)
		p[i]=0;
}
#endif

// Create standard handles, try to start child from command line.

BOOL StartChildProcess(LPCSTR lpszCmdLine, BOOL bShowChildWindow)
{
	HANDLE hProcess;
	SECURITY_ATTRIBUTES sa;
	HANDLE hStdInWriteTmp, hStdOutReadTmp, hStdErrReadTmp;
	DWORD dwThreadID;

	// Initialisation.
	m_hStdIn = NULL;
	m_hStdOut = NULL;
	m_hStdErr = NULL;
	m_hStdInWrite = NULL;
	m_hStdOutRead = NULL;
	m_hStdErrRead = NULL;
	m_hChildProcess = NULL;
	m_hStdOutThread = NULL;
	m_hStdErrThread = NULL;
	m_hProcessThread = NULL;
	m_hExitEvent = NULL;
	m_bRunThread = FALSE;
	hProcess = GetCurrentProcess();

	// Set up the security attributes struct.
#ifdef _WIN64
	my_zero_memory (&sa,sizeof(SECURITY_ATTRIBUTES));
#else
	ZeroMemory(&sa, sizeof(SECURITY_ATTRIBUTES));
#endif
	sa.nLength= sizeof(SECURITY_ATTRIBUTES);
	sa.lpSecurityDescriptor = NULL;
	sa.bInheritHandle = TRUE;

	// Create the child stdin pipe.
	VERIFY(CreatePipe(&m_hStdIn, &hStdInWriteTmp, &sa, 0));

	// Create the child stdout pipe.
	VERIFY(CreatePipe(&hStdOutReadTmp, &m_hStdOut, &sa, 0));

	// Create the child stderr pipe.
	VERIFY(CreatePipe(&hStdErrReadTmp, &m_hStdErr, &sa, 0));

	// Create new stdin write, stdout and stderr read handles.
	// Set the properties to FALSE. Otherwise, the child inherits the
	// properties and, as a result, non-closeable handles to the pipes
	// are created.
	
	VERIFY(DuplicateHandle(hProcess, hStdInWriteTmp,
		hProcess, &m_hStdInWrite, 0, FALSE, DUPLICATE_SAME_ACCESS));

	VERIFY(DuplicateHandle(hProcess, hStdOutReadTmp,
		hProcess, &m_hStdOutRead, 0, FALSE, DUPLICATE_SAME_ACCESS));

	VERIFY(DuplicateHandle(hProcess, hStdErrReadTmp,
		hProcess, &m_hStdErrRead, 0, FALSE, DUPLICATE_SAME_ACCESS));

	// Close inheritable copies of the handles you do not want to be
	// inherited.

	VERIFY(CloseHandle(hStdInWriteTmp));
	VERIFY(CloseHandle(hStdOutReadTmp));
	VERIFY(CloseHandle(hStdErrReadTmp));

	// Start child process with redirected stdout, stdin & stderr
	m_hChildProcess = PrepAndLaunchRedirectedChild(lpszCmdLine,
		m_hStdOut, m_hStdIn, m_hStdErr, bShowChildWindow);

	if (m_hChildProcess == NULL)
	{
		TCHAR lpszBuffer[BUFFER_SIZE];
		//		sprintf(lpszBuffer, "Unable to start %s\n", lpszCmdLine);
		// replace by something that works..
		OnChildStdOutWrite(lpszBuffer);

		// close all handles and return FALSE
		VERIFY(CloseHandle(m_hStdIn));
		m_hStdIn = NULL;
		VERIFY(CloseHandle(m_hStdOut));
		m_hStdOut = NULL;
		VERIFY(CloseHandle(m_hStdErr));
		m_hStdErr = NULL;

		return FALSE;
	}

	m_bRunThread = TRUE;

	// Create Exit event
	m_hExitEvent = CreateEvent(NULL, TRUE, FALSE, NULL);
	VERIFY(m_hExitEvent != NULL);

	// Launch the thread that read the child stdout.
	m_hStdOutThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)StdOutThread,
		(LPVOID)m_hStdOutRead, 0, &dwThreadID);
	VERIFY(m_hStdOutThread != NULL);

	// Launch the thread that read the child stderr.
	m_hStdErrThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)StdErrThread,
		(LPVOID)m_hStdErrRead, 0, &dwThreadID);
	VERIFY(m_hStdErrThread != NULL);

	// Launch the thread that monitoring the child process.
	m_hProcessThread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)ProcessThread,
		(LPVOID)0, 0, &dwThreadID);
	VERIFY(m_hProcessThread != NULL);

	// Virtual function to notify derived class that the child is started.
	OnChildStarted(lpszCmdLine);

	return TRUE;
}

// Check if the child process is running. 
// On NT/2000 the handle must have PROCESS_QUERY_INFORMATION access.

BOOL IsChildRunning()
{
	DWORD dwExitCode;
    if (m_hChildProcess == NULL) return FALSE;
	GetExitCodeProcess(m_hChildProcess, &dwExitCode);
	return (dwExitCode == STILL_ACTIVE) ? TRUE: FALSE;
}

void TerminateChildProcess()
{
	// Tell the threads to exit and wait for process thread to die.
	m_bRunThread = FALSE;
	SetEvent(m_hExitEvent);
	Sleep(500);

	// Check the process thread.
	if (m_hProcessThread != NULL)
	{
		VERIFY(WaitForSingleObject(m_hProcessThread, 1000) != WAIT_TIMEOUT);
		m_hProcessThread = NULL;
	}

	// Close all child handles first.
	if (m_hStdIn != NULL)
		VERIFY(CloseHandle(m_hStdIn));
	m_hStdIn = NULL;
	if (m_hStdOut != NULL)
		VERIFY(CloseHandle(m_hStdOut));
	m_hStdOut = NULL;
	if (m_hStdErr != NULL)
		VERIFY(CloseHandle(m_hStdErr));
	m_hStdErr = NULL;
    Sleep(100);

	// Close all parent handles.
	if (m_hStdInWrite != NULL)
		VERIFY(CloseHandle(m_hStdInWrite));
	m_hStdInWrite = NULL;
	if (m_hStdOutRead != NULL)
		VERIFY(CloseHandle(m_hStdOutRead));
	m_hStdOutRead = NULL;
	if (m_hStdErrRead != NULL)
		VERIFY(CloseHandle(m_hStdErrRead));
	m_hStdErrRead = NULL;
    Sleep(100);

    // Stop the stdout read thread.
	if (m_hStdOutThread != NULL)
	{
		if (!IsWinNT())
			TerminateThread(m_hStdOutThread, 1);
		VERIFY(WaitForSingleObject(m_hStdOutThread, 1000) != WAIT_TIMEOUT);
		m_hStdOutThread = NULL;
	}

    // Stop the stderr read thread.
	if (m_hStdErrThread != NULL)
	{
		if (!IsWinNT())
			TerminateThread(m_hStdErrThread, 1);
		VERIFY(WaitForSingleObject(m_hStdErrThread, 1000) != WAIT_TIMEOUT);
		m_hStdErrThread = NULL;
	}
    Sleep(100);

	// Stop the child process if not already stopped.
	// It's not the best solution, but it is a solution.
	// On Win98 it may crash the system if the child process is the COMMAND.COM.
	// The best way is to terminate the COMMAND.COM process with an "exit" command.

	if (IsChildRunning())
    {
		VERIFY(TerminateProcess(m_hChildProcess, 1));
		VERIFY(WaitForSingleObject(m_hChildProcess, 1000) != WAIT_TIMEOUT);
    }
	m_hChildProcess = NULL;

	// cleanup the exit event
	if (m_hExitEvent != NULL)
		VERIFY(CloseHandle(m_hExitEvent));
	m_hExitEvent = NULL;
}

// Launch the process that you want to redirect.

HANDLE PrepAndLaunchRedirectedChild(LPCSTR lpszCmdLine,
	HANDLE hStdOut, HANDLE hStdIn, HANDLE hStdErr,
	BOOL bShowChildWindow)
{
	BOOL bResult;
	HANDLE hProcess = GetCurrentProcess();

	PROCESS_INFORMATION pi;
	LPVOID lpSD;
	LPSECURITY_ATTRIBUTES lpSA;

	char path[_MAX_PATH];
	char *thepath;
	int i;

	// Set up the start up info struct.
	STARTUPINFO si;
#ifdef _WIN64
	my_zero_memory (&si, sizeof(STARTUPINFO));
#else
	ZeroMemory(&si, sizeof(STARTUPINFO));
#endif
	si.cb = sizeof(STARTUPINFO);
	si.dwFlags = STARTF_USESTDHANDLES|STARTF_USESHOWWINDOW;
	si.hStdOutput = hStdOut;
	si.hStdInput  = hStdIn;
	si.hStdError  = hStdErr;
	
	// Use this if you want to show the child.
	si.wShowWindow = bShowChildWindow ? SW_SHOW: SW_HIDE;
	// Note that dwFlags must include STARTF_USESHOWWINDOW if you want to
	// use the wShowWindow flags.

	// Create the NULL security token for the process
	lpSD = NULL;
	lpSA = NULL;

	// On NT/2000 the handle must have PROCESS_QUERY_INFORMATION access.
	// This is made using an empty security descriptor. It is not the same
	// as using a NULL pointer for the security attribute!

	if (IsWinNT())
	{
/*		lpSD = GlobalAlloc(GPTR, SECURITY_DESCRIPTOR_MIN_LENGTH);
		VERIFY(InitializeSecurityDescriptor(lpSD, SECURITY_DESCRIPTOR_REVISION));
		VERIFY(SetSecurityDescriptorDacl(lpSD, -1, 0, 0));

		lpSA = (LPSECURITY_ATTRIBUTES)GlobalAlloc(GPTR, sizeof(SECURITY_ATTRIBUTES));
		lpSA->nLength = sizeof(SECURITY_ATTRIBUTES);
		lpSA->lpSecurityDescriptor = lpSD;
		lpSA->bInheritHandle = TRUE;
*/	}

	// try to get startupdir info in order...
	lstrcpy (path, lpszCmdLine);

	for (i = lstrlen (path); path[i] != '\\' && i >= 0; i--)
		path[i] = 0;

	if (i == 0)
		thepath = NULL;
	else
	{	/* path[i] = '\"'; */
		thepath = path + 1;
	}
//	thepath = NULL;
	// Try to spawn the process.
	bResult = CreateProcess
			(NULL					/* pointer to name of executable module		*/
			, (char*)lpszCmdLine	/* pointer to command line string			*/
			, lpSA					/* pointer to process security attributes	*/
			, NULL					/* pointer to thread security attributes	*/
			, TRUE					/* handle inheritance flag					*/
			, CREATE_NEW_CONSOLE	/* creation flags							*/
			, NULL					/* pointer to new environment block			*/
			, thepath				/* pointer to current directory name		*/
			, &si					/* pointer to STARTUPINFO					*/
			, &pi					/* pointer to PROCESS_INFORMATION			*/
			);

	// Cleanup memory allocation
	if (lpSA != NULL)
		GlobalFree(lpSA);
	if (lpSD != NULL)
		GlobalFree(lpSD);

	// Return if an error occurs.
	if (!bResult) return FALSE;

	// Close any unnecessary handles.
	VERIFY(CloseHandle(pi.hThread));

	// Save global child process handle to cause threads to exit.
	return pi.hProcess;
}

BOOL m_bRunThread = TRUE;

// Thread to read the child stdout.

static int StdOutThread(HANDLE hStdOutRead)
{
	DWORD nBytesRead;
	CHAR lpszBuffer[BUFFER_SIZE+1];

	while (m_bRunThread)
	{
		Sleep(50);
		if (!ReadFile(hStdOutRead, lpszBuffer, BUFFER_SIZE,
			&nBytesRead, NULL) || !nBytesRead)
		{
			if (GetLastError() == ERROR_BROKEN_PIPE)
				break;			// pipe done - normal exit path.
			else
				break;//ASSERT(FALSE);	// Something bad happened.
		}
		if (nBytesRead)
		{
			// Virtual function to notify derived class that
			// characters are writted to stdout.
			lpszBuffer[nBytesRead] = '\0';
			OnChildStdOutWrite(lpszBuffer);
		}
	}
	return 0;
}

// Thread to read the child stderr.

static int StdErrThread(HANDLE hStdErrRead)
{
	DWORD nBytesRead;
	CHAR lpszBuffer[BUFFER_SIZE+1];

	while (m_bRunThread)
	{
		if (!ReadFile(hStdErrRead, lpszBuffer, BUFFER_SIZE,
			&nBytesRead, NULL) || !nBytesRead)
		{
			if (GetLastError() == ERROR_BROKEN_PIPE)
				break;			// pipe done - normal exit path.
			else
				break;//ASSERT(FALSE);	// Something bad happened.
		}
		if (nBytesRead)
		{
			// Virtual function to notify derived class that
			// characters are writted to stderr.
			lpszBuffer[nBytesRead] = '\0';
			OnChildStdErrWrite(lpszBuffer);
		}
	}
	return 0;
}

// Thread to monitoring the child process.

static int ProcessThread()
{
	HANDLE hWaitHandle[2];
	hWaitHandle[0] = m_hExitEvent;
	hWaitHandle[1] = m_hChildProcess;

	while (m_bRunThread)
	{
		switch (WaitForMultipleObjects(2, hWaitHandle, FALSE, 1))
		{
			case WAIT_OBJECT_0 + 0:	// exit on event
				ASSERT(m_bRunThread == FALSE);
				m_bRunThread = FALSE;
				break;

			case WAIT_OBJECT_0 + 1:	// child process exit
				ASSERT(m_bRunThread == TRUE);
				m_bRunThread = FALSE;
				break;
		}
	}
	// Virtual function to notify derived class that
	// child process is terminated.
	// Application must call TerminateChildProcess()
	// but not direcly from this thread!
	OnChildTerminate();
	return 0;
}

int my_strlen (const char *s)
{
	int l;

	for (l = 0; s[l]!='\0'; l++)
		;
	return l;
}

// Function that write to the child stdin.

int WriteChildStdIn(LPCSTR lpszInput)
{
	DWORD nBytesWrote;
	DWORD Length = my_strlen(lpszInput);
	if (m_hStdInWrite != NULL && Length > 0)
	{
		if (!WriteFile(m_hStdInWrite, lpszInput, Length, &nBytesWrote, NULL))
		{
			if (GetLastError() == ERROR_NO_DATA)
				return 1;				// Pipe was closed (do nothing).
			else
				//ASSERT(FALSE);	// Something bad happened.
				return 2;
		}
	}
	return 0;
}

//==========

WNDPROC g_pWndProc = NULL;

LRESULT CALLBACK SubClassWndProc(HWND p_hWnd,UINT p_uMsg,WPARAM p_wParam,LPARAM p_lParam)
{
	switch(p_uMsg)
	{
		case WM_CONSOLEQUIT:
			{
				SendMessage0ToClean (CcWmCONSOLEQUIT);
				return 0;
			}
			break;
		case WM_CONSOLEOUT:
			{
				SendMessage1ToClean (CcWmCONSOLEOUT,p_wParam);
				return 0;
			}
			break;
		case WM_CONSOLEERR:
			{
				SendMessage1ToClean (CcWmCONSOLEERR,p_wParam);
				return 0;
			}
			break;
	}
	return CallWindowProc(g_pWndProc,p_hWnd,p_uMsg,p_wParam,p_lParam);
}

BOOL AddMainWindowHook (BOOL dummy)
{
	if (g_pWndProc == NULL)
		{
#ifdef _WIN64
		g_pWndProc = (WNDPROC)SetWindowLongPtr(ghMainWindow,GWLP_WNDPROC,(LONG_PTR)SubClassWndProc);
#else
		g_pWndProc = (WNDPROC)SetWindowLong(ghMainWindow,GWL_WNDPROC,(LPARAM)SubClassWndProc);
#endif
		return TRUE;
		}
	return FALSE;
}

