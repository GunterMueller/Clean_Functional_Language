/*
   This module implements timer (and null device) handling for use in
   Concurrent Clean Event I/O and it cooperaties tightly with ckernel.c.
   The timer is implemented with a unix SIGALRM signal function that
   writes to a pipe whenever it is invoked for the first time.
   X is capable of reading from this pipe in its event loop. This however
   might not be the case with all unix systems. In such cases the pipe
   has to be replaced by a socket.

   Interfacing from Clean to this module is provided by xtimer.fcl
   These functions are primarily used by timerDevice and deltaTimer.

   Last addition, 1.3.1993, the TimerCallback now generates an artificial
   X Event (ClientMessage), which is checked in the event loop.

   1992: Leon Pillich
*/

#include <X11/Intrinsic.h>
#include <X11/Xlib.h>
#include "clean_devices.h"
#include <stdio.h>
#include <signal.h>
#include <time.h>

extern void ualarm (int, int);
extern Widget toplevel;
extern Display *display;
extern CLEAN_DEVICE global_device;

int TimerCount;
unsigned TimerInterval;
Boolean null_able;
Boolean IOTimerEnabled;
XtIntervalId my_timer;
int TimerPipe[2];

/* Our own artificial timer event */
XClientMessageEvent OurTimerEvent ;
  

void TimerCallback(XtPointer client_data,int *source,XtInputId *id)
{ char buf[1];

  /* make pipe empty */
  read(TimerPipe[0],buf,1);

  /* Send our own artificial timer event to the X server */
  XSendEvent(display, XtWindow(toplevel), True, 0L, (XEvent *)(&OurTimerEvent));
}

void init_timer(void)
{ IOTimerEnabled=False;

  if(pipe(TimerPipe)==-1)
  { fprintf(stderr, "Fatal error: Cannot open pipe for Timer device\n");
    exit(-1);
  }
  else
    XtAddInput(TimerPipe[0],(XtPointer)XtInputReadMask,TimerCallback,NULL);
                            /* Halbe added (XtPointer) before XtInputReadMask */
  OurTimerEvent.type = ClientMessage;
  OurTimerEvent.format = 8;
  strcpy(OurTimerEvent.data.b, "timer");
}

static void timer_routine2()
{ TimerCount++;
/* Halbe JVG */
  signal (SIGALRM,timer_routine2);
/* */
}

static void timer_routine()
{ char buf[1];
  buf[0]='t';

  signal(SIGALRM, timer_routine2);
  TimerCount++;

  /* send timer event, i.e. write to the Timer pipe */
  write(TimerPipe[1],buf,1);
}

int install_timer(int interval)
{ 
  TimerCount=0; 
  IOTimerEnabled=False;
  TimerInterval=1000*(unsigned)interval;

  return interval;
}

int change_timer_interval(int new_interval)
{
  TimerInterval=1000*(unsigned)new_interval;
  TimerCount=0;
  if(IOTimerEnabled) ualarm(TimerInterval,TimerInterval);

  return new_interval;
}

int get_timer_count(int dummy)
{ int r;
  r=TimerCount;

  TimerCount=0; 
  signal(SIGALRM, timer_routine);
  
  return r;
}
   

int enable_timer(int dummy)
{  
  if(!IOTimerEnabled)
  { IOTimerEnabled=True;
    TimerCount=0;
    signal(SIGALRM, timer_routine);
    ualarm(TimerInterval,TimerInterval);
  };

  return dummy;
}

int disable_timer(int dummy)
{ 
  if(IOTimerEnabled)
  { IOTimerEnabled=False; 
    TimerCount=0;
    ualarm(0,0);
  };
  return dummy;   /* Halbe */
}

int enable_null(int dummy)
{ null_able=TRUE;
  return dummy;
}

int disable_null(int dummy)
{ null_able=FALSE;
  return dummy;
}

void get_current_time(int dummy, int *hours, int *minutes, int *seconds)
{ time_t thistime;

  thistime=time(NULL);
  if(!thistime)
    *hours=*minutes=*seconds=0;
  else
  { struct tm *current_time=localtime(&thistime);
    *hours  =current_time->tm_hour;
    *minutes=current_time->tm_min;
    *seconds=current_time->tm_sec;
  };
}

void get_current_date(int dummy, int *year, int *month, int *day, int *wday)
{ time_t thistime;

  thistime=time(NULL);
  if(!thistime)
    *year=*month=*day=0;
  else
  { struct tm *current_time=localtime(&thistime);
    *year =current_time->tm_year + 1900;
    *month=current_time->tm_mon + 1;
    *day  =current_time->tm_mday;
    *wday =current_time->tm_wday + 1;
  };
}

int wait_mseconds(int mseconds)
{
/* RWS */
# ifndef SOLARIS
  unsigned useconds=(unsigned)mseconds*1000;

  usleep(useconds);
# endif
/* */

  return mseconds;
}

/* RWS */
# ifdef SOLARIS
void
ualarm (int value, int interval)
{
  struct itimerval	timer_interval;

  timer_interval.it_interval.tv_sec		= interval / 1000000;
  timer_interval.it_interval.tv_usec	= interval % 1000000;
  timer_interval.it_value.tv_sec		= value / 1000000;
  timer_interval.it_value.tv_usec		= value % 1000000;

  setitimer (ITIMER_REAL, &timer_interval, NULL);
}
# endif
/* */
