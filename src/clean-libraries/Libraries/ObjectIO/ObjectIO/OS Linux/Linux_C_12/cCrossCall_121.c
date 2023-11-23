/********************************************************************************************
	Clean OS Windows library module version 1.2.1.
	This module is part of the Clean Object I/O library, version 1.2.1,
	for the Windows platform.
********************************************************************************************/

/********************************************************************************************
	About this module:
	cCrossCall_121 defines the infrastructure required by the Object I/O library to call
	system procedures that interact with the Windows callback mechanism.

	The basic principle in cCrossCall_121 is to have a minimal cross call kernel. If Clean
	code requires extension of the functionality of the OS thread, then this functionality
	must be	registered before being applicable.

	In this version the request codes are still statically fixed and are assumed to be
	globally available both in the OS thread and the Clean thread. In a future version this
	will probably be replaced by a dynamic allocation of cross call request codes.
********************************************************************************************/


/********************************************************************************************
	Include section.
********************************************************************************************/

#include "cCrossCall_121.h"
#include "cCrossCallWindows_121.h"		/* Contains the implementation of cursors. */
#include <gdk/gdkkeysyms.h>
#include <pthread.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>
#include <stdlib.h>

char** global_argv;
int global_argc = 0;

#define _MAX_PATH 255

/**********************************************************************************************
	External global data section.
**********************************************************************************************/
CrossCallInfo gCci;									/* The global cross call information struct. */
GtkTooltips *gTooltip              = NULL;			/* The tooltip control. */
CrossCallProcedureTable gCrossCallProcedureTable;

/**********************************************************************************************
	Internal global data section.
**********************************************************************************************/

static pthread_mutex_t gCleanMutex;
static pthread_mutex_t gOSMutex;
static pthread_t gOSThread;
static gboolean gOSThreadIsRunning = FALSE;
static gboolean gEventsInited = FALSE; /* What is this? */

static CrossCallInfo *MakeQuitCci (CrossCallInfo * pcci);


/*	GetModifiers returns the modifiers that are currently pressed.
*/
int GetModifiers (void)
{
	int mods = 0;
	GdkModifierType state;

    /*printf("GetModifiers\n");*/

	gdk_event_get_state(gtk_get_current_event(), &state);

	if (state & GDK_SHIFT_MASK) {
		mods |= SHIFTBIT;
    }
	if (state & GDK_CONTROL_MASK) {
		mods |= CTRLBIT;
    }
	if (state & GDK_MOD1_MASK) {
		mods |= ALTBIT;
    }

	return mods;
}


/*	Translate virtual key codes to the codes shared with Clean.
	This procedure has been filtered from TranslateKeyboardMessage.
	If the keycode could not be translated, zero is returned.
*/
int CheckVirtualKeyCode (int keycode)
{
	int c = 0;
    /* printf("CheckVirtualKeyCode\n");*/
	switch (keycode)
	{
		case GDK_Up:
			c = WinUpKey;
			break;
		case GDK_Down:
			c = WinDownKey;
			break;
		case GDK_Left:
			c = WinLeftKey;
			break;
		case GDK_Right:
			c = WinRightKey;
			break;
		case GDK_Page_Up:
			c = WinPgUpKey;
			break;
		case GDK_Page_Down:
			c = WinPgDownKey;
			break;
		case GDK_End:
			c = WinEndKey;
			break;
		case GDK_Begin:
			c = WinBeginKey;
			break;
		case GDK_BackSpace:
			c = WinBackSpKey;
			break;
		case GDK_Delete:
			c = WinDelKey;
			break;
		case GDK_Tab:
			c = WinTabKey;
			break;
		case GDK_Return:
			c = WinReturnKey;
			break;
		case GDK_Escape:
			c = WinEscapeKey;
			break;
		case GDK_Help:
			c = WinHelpKey;
			break;
		case GDK_F1:
			c = WinF1Key;
			break;
		case GDK_F2:
			c = WinF2Key;
			break;
		case GDK_F3:
			c = WinF3Key;
			break;
		case GDK_F4:
			c = WinF4Key;
			break;
		case GDK_F5:
			c = WinF5Key;
			break;
		case GDK_F6:
			c = WinF6Key;
			break;
		case GDK_F7:
			c = WinF7Key;
			break;
		case GDK_F8:
			c = WinF8Key;
			break;
		case GDK_F9:
			c = WinF9Key;
			break;
		case GDK_F10:
			c = WinF10Key;
			break;
		case GDK_F11:
			c = WinF11Key;
			break;
		case GDK_F12:
			c = WinF12Key;
			break;
	}
	return c;
}

static gboolean TimerCallback (gpointer data)
{
    /*printf("TimerCallback\n");*/
	SendMessage0ToClean (CcWmIDLETIMER);
    return TRUE;
}

void HandleCleanRequest (CrossCallInfo * pcci)
{
    /*printf("HandleCleanRequest: Message = %d\n", pcci->mess);*/
	switch (pcci->mess)
	{
		case CcRqDOMESSAGE: 	/* idleTimerOn, sleeptime; no result. */
			{
				gboolean gIdleTimerOn = (gboolean) pcci->p1;
				gint interval = (gint) pcci->p2;
                /*printf("CcRqDOMESSAGE\n");*/

				if (gIdleTimerOn)
				{
					GSource *source = g_timeout_source_new(interval);
					g_source_set_callback(source,TimerCallback,NULL,NULL);
					g_source_attach(source,NULL);

					gtk_main_iteration();

					g_source_destroy(source);
				}
				else
				{
					gtk_main_iteration();
				}

				MakeReturn0Cci (pcci);
			}
			break;
		default:
			{
				CrossCallProcedure action;

				action = FindCrossCallEntry (gCrossCallProcedureTable, pcci->mess);
                /*printf("Handle Request for action logged for: %d\n", pcci->mess);*/

				if (action == NULL)
				{	/* Cross call request code not installed. */
					/*printf("\'HandleCleanRequest\' got uninstalled CcRq request code from Haskell: %d\n", pcci->mess);*/
					exit(1);
				}
				else
				{	/* Cross call request code found. Apply it to pcci. */
                    /*printf("Action Requested: %d\n", pcci->mess);*/
					action (pcci);
				}
			}
	}
	KickCleanThread (pcci);
}	/* HandleCleanRequest */

void InitGTK()
{
	static gboolean gInitiated = FALSE;

    /*printf("InitGTK\n"); */
	if (!gInitiated)
	{
		gtk_set_locale();
		gtk_init(&global_argc,&global_argv);
	    gInitiated = TRUE;
	};
}	/* InitGTK */

static gpointer OsThreadFunction (gpointer param);

OS WinStartOsThread(OS os)
{
	pthread_attr_t attr;
    /* rprintf ("WinStartOSThread\n"); */

	InitGTK();

	/*	The cross call procedure table is set to the empty table. */
	gCrossCallProcedureTable = EmptyCrossCallProcedureTable ();
    /* rprintf ("Created CC Table\n"); */

	pthread_mutex_init(&gCleanMutex,NULL);
	pthread_mutex_lock(&gCleanMutex);
	pthread_mutex_init(&gOSMutex,NULL);
	pthread_mutex_lock(&gOSMutex);
	gOSThreadIsRunning = TRUE;
    /* rprintf ("OS is running.\n"); */

	pthread_attr_init(&attr);
	pthread_create(&gOSThread,&attr,OsThreadFunction,NULL);
	pthread_attr_destroy(&attr);
    /* rprintf ("Exiting initializer.\n"); */

    return os;
}	/* WinStartOsThread */

OS WinKillOsThread (OS os)
{
    /* printf("WinKillOsThread\n"); */
	if (gOSThread != FALSE)
	{
		gOSThreadIsRunning = FALSE;
		gOSThread = FALSE;

		DeleteCursors();

		if (gCrossCallProcedureTable)
			FreeCrossCallProcedureTable (gCrossCallProcedureTable);
	}
    return os;
}	/*WinKillOsThread*/

#undef PRINTCROSSCALLS

void WinKickOsThread (int imess,
					  int ip1, int ip2, int ip3,
					  int ip4, int ip5, int ip6,
                      OS ios,
					  int *omess,
					  int *op1, int *op2, int *op3,
					  int *op4, int *op5, int *op6,
                      OS *oos
					 )
{
#ifdef PRINTCROSSCALLS
        rprintf("WinKickOsThread (");
        printCCI (&gCci);
        rprintf(")\n");
#endif
	gCci.mess = imess;
	gCci.p1 = ip1;
	gCci.p2 = ip2;
	gCci.p3 = ip3;
	gCci.p4 = ip4;
	gCci.p5 = ip5;
	gCci.p6 = ip6;

	if (gOSThread != FALSE)
	{
#ifdef PRINTCROSSCALLS
        rprintf("Unlocking Clean mutex.\n");
#endif
		pthread_mutex_unlock(&gCleanMutex);
#ifdef PRINTCROSSCALLS
        rprintf("Locking OS mutex.\n");
#endif
		pthread_mutex_lock(&gOSMutex);
#ifdef PRINTCROSSCALLS
        rprintf("OS mutex locked.\n");
#endif

		*omess = gCci.mess;
		*op1 = gCci.p1;
		*op2 = gCci.p2;
		*op3 = gCci.p3;
		*op4 = gCci.p4;
		*op5 = gCci.p5;
		*op6 = gCci.p6;
        *oos = ios;
        /* printf("Data: %d, %d, %d, %d, %d, %d, %d",
                        gCci.p1, gCci.p2, gCci.p3, gCci.p4,
                        gCci.p5, gCci.p6, ios); */
	}
	else
	{
		*omess = CcWASQUIT;
		*op1 = 0;
		*op2 = 0;
		*op3 = 0;
		*op4 = 0;
		*op5 = 0;
		*op6 = 0;
        *oos = ios;
	}
}	/* WinKickOsThread */


#ifdef PRINTCROSSCALLS
static CrossCallInfo osstack[10];
static CrossCallInfo clstack[10];
static int ossp = -1;
static int clsp = -1;
#endif

void KickCleanThread (CrossCallInfo * pcci)
{
    /* rprintf("KickCleanThread\n"); */
#ifdef PRINTCROSSCALLS
	if (ossp == -1)
	{
		for (ossp = 0; ossp < 10; ossp++)
		{
			osstack[ossp].mess = -1;
		}
		ossp = 1;
		osstack[ossp].mess = -2;
	}

	if (clsp == -1)
	{
		for (clsp = 0; clsp < 10; clsp++)
		{
			clstack[clsp].mess = -1;
		}
		clsp = 1;
		clstack[clsp].mess = -2;
	}
#endif

	if (pcci != &gCci)
    {
		gCci = *pcci;
    }

#ifdef PRINTCROSSCALLS
	rprintf ("KCT: started\n");
	if (gCci.mess < 20)
	{
		rprintf ("	-- %d --> OS returning <", clsp + ossp - 2);
		printCCI (&gCci);
		rprintf ("> from <");
		printCCI (&(clstack[clsp]));
		rprintf (">\n");
		clsp--;
	}
	else
	{
		ossp++;
		osstack[ossp] = gCci;
		rprintf ("	-- %d --> OS calling with <", clsp + ossp - 2);
		printCCI (&gCci);
		rprintf (">\n");
	}

	rprintf ("KCT: setting event\n");
#endif
	pthread_mutex_unlock(&gOSMutex);
#ifdef PRINTCROSSCALLS
	rprintf ("KCT: starting wait\n");
#endif
	pthread_mutex_lock(&gCleanMutex);
#ifdef PRINTCROSSCALLS
	rprintf ("KCT: wait done.\n");
#endif

	if (pcci != &gCci)
		*pcci = gCci;

#ifdef PRINTCROSSCALLS
	if (gCci.mess < 20)
	{
		rprintf (" <-- %d --  Clean returning <", clsp + ossp - 2);
		printCCI (&gCci);
		rprintf ("> from <");
		printCCI (&(osstack[ossp]));
		rprintf (">\n");
		ossp--;
	}
	else
	{
		clsp++;
		clstack[clsp] = gCci;
		rprintf (" <-- %d --  Clean calling with <", clsp + ossp - 2);
		printCCI (&gCci);
		rprintf (">\n");
	}
#endif
}	/* KickCleanThread */

void SendMessageToClean (int mess, int p1, int p2, int p3, int p4, int p5, int p6)
{
    /* printf("SendMessageToClean -- Message: %d\n", mess);  */
	gCci.mess = mess;
	gCci.p1 = p1;
	gCci.p2 = p2;
	gCci.p3 = p3;
	gCci.p4 = p4;
	gCci.p5 = p5;
	gCci.p6 = p6;

	KickCleanThread (&gCci);
	while (!IsReturnCci (&gCci))
	{
		HandleCleanRequest (&gCci);
	}
}

CrossCallInfo *MakeReturn0Cci (CrossCallInfo * pcci)
{
	pcci->mess = CcRETURN0;
	return pcci;
}

CrossCallInfo *MakeReturn1Cci (CrossCallInfo * pcci, int v1)
{
	pcci->mess = CcRETURN1;
	pcci->p1 = v1;
	return pcci;
}

CrossCallInfo *MakeReturn2Cci (CrossCallInfo * pcci, int v1, int v2)
{
	pcci->mess = CcRETURN2;
	pcci->p1 = v1;
	pcci->p2 = v2;
	return pcci;
}

CrossCallInfo *MakeReturn3Cci (CrossCallInfo * pcci, int v1, int v2, int v3)
{
	pcci->mess = CcRETURN3;
	pcci->p1 = v1;
	pcci->p2 = v2;
	pcci->p3 = v3;
	return pcci;
}

CrossCallInfo *MakeReturn4Cci (CrossCallInfo * pcci, int v1, int v2, int v3, int v4)
{
	pcci->mess = CcRETURN4;
	pcci->p1 = v1;
	pcci->p2 = v2;
	pcci->p3 = v3;
	pcci->p4 = v4;
	return pcci;
}

CrossCallInfo *MakeReturn5Cci (CrossCallInfo * pcci, int v1, int v2, int v3, int v4, int v5)
{
	pcci->mess = CcRETURN5;
	pcci->p1 = v1;
	pcci->p2 = v2;
	pcci->p3 = v3;
	pcci->p4 = v4;
	pcci->p5 = v5;
	return pcci;
}

CrossCallInfo *MakeReturn6Cci (CrossCallInfo * pcci, int v1, int v2, int v3, int v4, int v5, int v6)
{
	pcci->mess = CcRETURN6;
	pcci->p1 = v1;
	pcci->p2 = v2;
	pcci->p3 = v3;
	pcci->p4 = v4;
	pcci->p5 = v5;
	pcci->p6 = v6;
	return pcci;
}

gboolean IsReturnCci (CrossCallInfo * pcci)
{
    /* printf("Checking message %d: ", pcci->mess);*/
	if (pcci->mess >= CcRETURNmin && pcci->mess <= CcRETURNmax)
    {
		return TRUE;
    }
	return FALSE;
}


static gpointer OsThreadFunction (gpointer param)
{
    /* printf("OsThreadFunction\n"); */
	gTooltip = gtk_tooltips_new();

	pthread_mutex_lock(&gCleanMutex);

	while (gOSThreadIsRunning)
	{
	    HandleCleanRequest (&gCci);
	}

	pthread_mutex_unlock(&gCleanMutex);

	pthread_mutex_destroy(&gOSMutex);
	pthread_mutex_destroy(&gCleanMutex);

	return NULL;
}	/* OsThreadFunction */

void WinInitOs (Bool* ok, OS* os)
{
    /* printf("WinInitOs\n"); */
    if (gEventsInited)
    {
       *ok = FALSE;                                                                    
       rprintf ("WIO: *ok = FALSE\n");
    }                                                                               
    else
    {
       *ok = TRUE;
       gEventsInited = TRUE;                                                           
       rprintf ("WIO: *ok = TRUE\n");
    }
    *os = 54321;
}   /* WinInitOs */

Bool WinCloseOs (OS os)                                                        
 {           
    if (gEventsInited)
    {       
         rprintf ("WCO: return TRUE\n");                                                 
         gEventsInited = FALSE;
         return TRUE;                                                                
     }                                                                               
     else
     {       
          rprintf ("WCO: return FALSE\n");                                                
          return FALSE;
     }
}   /* WinCloseOs */

void WinCallProcess (char* commandline, char* env, char* dir, char* in,
                char* out, char* err, OS ios, Bool* success, int* exitcode,
                OS* oos)
{
    printf("WinCallProcess --> Not Implemented\n");
    *oos = ios;
}

void WinLaunchApp2 (CLEAN_STRING commandline, CLEAN_STRING pathname,
                BOOL console, OS ios, Bool *success, OS *oos)
{
    pid_t pi;
    BOOL fsuccess;
    char path[_MAX_PATH];
    char *cl, *exname, *thepath;
    int i;
    int error;

    rprintf ("WLA: starting...\n");

    *success = FALSE;
    *oos = ios;

    rprintf ("WLA: step 2.\n");

    exname = cstring(pathname);
    cl = cstring (commandline);
    strcpy (path, cl);
    for (i = strlen (path); path[i] != '\\' && i >= 0; i--)
    {
        path[i] = 0;
    }

    if (i == 0)
    {
            thepath = NULL;
    }
    else
    {       /* path[i] = '\"'; */
            thepath = path + 1;
    }

    rprintf ("WLA: step 2a: directory = <%s>\n", thepath);

    rprintf ("WLA: step 3: calling process \"%s\".\n", cl);
    pi = fork();
    if (pi == 0)
    {
	    /* I'm a child -- launch the desired program. */
	    execlp(exname, cl);
    } else if (pi == -1) {
	    /* Error condition */
    	    error = errno;
            rprintf ("WLA: failure %d\n", error);
	    fsuccess = FALSE;
    } else {
            rprintf ("WLA: success\n");
	    fsuccess = TRUE;
    }

    rprintf ("WLA: step 5: returning\n");
    *success = fsuccess;
    *oos = ios;
    rprintf ("WLA: done...\n");
}

void WinLaunchApp (CLEAN_STRING commandline, BOOL console, OS ios,
                Bool *success, OS *oos)
{
    printf("WinLaunchApp --> Not implemented\n");
    *oos = ios;
}

char* WinGetAppPath (void)
{
    int idx, length;
    char *path = rmalloc(261);
    char *search = rmalloc(261);
    pid_t pid = getpid();

    /* printf("WinGetAppPath\n"); */

    /*
     * NOTE:  LINUX Only
     * 
     * Path to current executable is found by:
     * 
     * /proc/<pid>/exe (symlink to actual executable
     * 
     * stat this symlink to get the path
     */
     sprintf(search, "/proc/%d/exe", pid);
     length = readlink(search, path, 261);
     path[length] = 0x00;

     for (idx = length - 1;
         path[idx] != '/' &&                                                             path[idx] != '\\' &&
         path[idx] != ':';
         idx--)
        ;

    path[idx + 1] = 0;

    /* printf("App Path: %s\n", path); */

    return path;
    /* relying on the calling clean function to de-allocate path. */
}   /* WinGetAppPath */

CLEAN_STRING WinGetModulePath (void)
{
    char path[255 + 1];

    printf("WinGetModulePath -- Not Implemented.\n");

    return cleanstring(WinGetAppPath());
}

void WinFileModifiedDate (CLEAN_STRING name, gboolean* exists, int *yy,
                int *mm, int *dd, int *h, int *m, int *s)
{
    printf("WinFileModifiedDate --> Not implemented.\n");
    *exists = FALSE;
    *yy = 0;
    *mm = 0;
    *dd = 0;
    *h = 0;
    *m = 0;
    *s = 0;
}

gboolean WinFileExists (CLEAN_STRING string)
{
    printf("WinFileExists --> Not implemented\n");
    return FALSE;
}

