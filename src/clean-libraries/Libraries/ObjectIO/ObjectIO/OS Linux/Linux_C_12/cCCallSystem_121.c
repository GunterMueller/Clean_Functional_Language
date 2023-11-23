/********************************************************************************************
	Clean OS Windows library module version 1.2.1.
	This module is part of the Clean Object I/O library, version 1.2.1,
	for the Windows platform.
********************************************************************************************/

/********************************************************************************************
	About this module:
	Routines related to system handling that is not part of standard cross call handling.
********************************************************************************************/
#include "cCCallSystem_121.h"
#include <time.h>
#include <sys/time.h>
#include <unistd.h>

OS WinBeep (OS ios)
{
    rprintf("WinBeep\n");
    gdk_beep();
    return ios;
}

void WinGetBlinkTime(OS ios, int* blinktime, OS *oos)
{
/*	return (int) GetCaretBlinkTime(); */
    rprintf("WinGetBlinkTime -> not implemented\n");
    *oos = ios;
}

void WinGetTickCount (OS ios, int *tickCount, OS *oos)
{
    static struct timeval s;
    static gboolean f = TRUE;
    struct timeval r;
    
    rprintf("WinGetTickCount\n");
    if (f)
    {
        gettimeofday(&s,NULL);
        f = FALSE;
        *oos = ios;
        *tickCount = 0;
        return;
    }    
    
    gettimeofday(&r,NULL);
    *tickCount = (r.tv_sec-s.tv_sec)*1000 + (r.tv_usec-s.tv_usec)/1000;
    *oos = ios;
}

void WinPlaySound (CLEAN_STRING filename, OS ios, Bool *ook, OS *oos)
{
/*	return PlaySound(filename, NULL, SND_FILENAME | SND_SYNC); */
    rprintf("WinPlaySound -> not implemented");
    *ook = FALSE;
    *oos = ios;
}

OS WinWait (int delay, OS ios)
{
    rprintf("WinWait: %d\n", delay);
    sleep(delay);
    return ios;
}

void WinGetTime (OS ios, int *hr, int *min, int *second, OS *oos)
{
    struct timeval t;
    struct tm theTime;

    printf("WinGetTime\n");
    
    gettimeofday(&t,NULL);
    gmtime_r(&t.tv_sec,&theTime);

    *hr = theTime.tm_hour;
    *min = theTime.tm_min;
    *second = theTime.tm_sec;

    printf("Time: %d:%d:%d\n", *hr, *min, *second);

    *oos = ios;
}

void WinGetDate (OS ios, int *year, int *month, int *day,
                int *weekday, OS *oos)
{
    struct timeval t;
    struct tm theTime;

    printf("WinGetDate\n");
    
    gettimeofday(&t,NULL);
    gmtime_r(&t.tv_sec,&theTime);
	*year = 1900 + theTime.tm_year;
	*month   = 1 + theTime.tm_mon;
	*day     = theTime.tm_mday;
    /* Clean treats 1 == Weekend, 2 == Weekday */
	*weekday = ((theTime.tm_wday == 0) || (theTime.tm_wday == 6)) ? 1 : 2;

    printf("Date: %d-%d-%d\n",*month, *day, *year);
	*oos = ios;
}

        

