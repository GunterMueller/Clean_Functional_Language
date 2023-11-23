# include <windows.h>
# include <stdio.h>

# define Clean(ignore)
typedef struct
{
	int	length;
	char chars [1];
} *CleanString;
# include "asynclaunch.h"

# define kMaxProcesses	32

static HANDLE gProcessHandles [kMaxProcesses];
static int gNumberOfCurrentProcesses;
static int gProcessSlots  [kMaxProcesses];

void
AsyncCallProcess (CleanString command, int slot, int *ok)
{
	STARTUPINFO si;
	PROCESS_INFORMATION pi;
	int r;

	if (slot >= kMaxProcesses)
	{
		*ok	= 0;
		return;
	}

	si.cb = sizeof (STARTUPINFO);
	si.lpReserved = NULL;
	si.lpReserved2 = NULL;
	si.cbReserved2 = 0;
	si.lpDesktop = NULL;
	si.lpTitle = NULL;
	si.dwFlags = 0;

	r=CreateProcess (NULL,command->chars,NULL,NULL,TRUE,DETACHED_PROCESS/*0*/,NULL,NULL,&si,&pi);

	if (r!=0){
		gProcessHandles[gNumberOfCurrentProcesses]=pi.hProcess;
		gProcessSlots[gNumberOfCurrentProcesses]=slot;
		gNumberOfCurrentProcesses++;
	} else {
		gProcessHandles[slot]=NULL;
	}

	*ok=r;
}

void
AsyncPollCompleted (int *ok, int *exitcode, int *slotP)
{
	int r;

	r=MsgWaitForMultipleObjects (gNumberOfCurrentProcesses,gProcessHandles,0,INFINITE,QS_ALLEVENTS);
	if (WAIT_OBJECT_0 <= r && r < WAIT_OBJECT_0+kMaxProcesses)
	{
		int	process;

		process=r-WAIT_OBJECT_0;

		GetExitCodeProcess (gProcessHandles[process], (unsigned long *) exitcode);

		*slotP=gProcessSlots[process];
		*ok = 1;

		for (;process<gNumberOfCurrentProcesses-1;process++)
		{
			gProcessHandles[process]=gProcessHandles[process+1];
			gProcessSlots[process]=gProcessSlots[process+1];

		}
		gProcessHandles[gNumberOfCurrentProcesses]=NULL;
		--gNumberOfCurrentProcesses;
	}

	else
	{
		*slotP=r;
		*ok = 0;
	}
}