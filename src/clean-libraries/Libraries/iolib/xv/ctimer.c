/*
   This module implements timer handling for use in Concurrent Clean Event I/O
   and it cooperaties tightly with ckernel.c.

   Interfacing from Clean to this module is provided by xtimer.fcl
   These functions are primarily used by timerDevice and deltaTimer.

   1992: Leon Pillich
   1994: Sven Panne
*/

typedef int MyBoolean;

/* sigmask, sigblock and sigsetmask are BSD'isms */
#define _BSD_SOURCE

#include <X11/Xlib.h>
#include <xview/xview.h>
#include <xview/notify.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <time.h>
#include "interface.h"
#include "clean_devices.h"
#include "ctimer.h"
#include "ckernel.h"

#define ITIMER_CLIENT ((Notify_client)321123)

static int TimerCount;
static unsigned TimerInterval; /* in microseconds */
MyBoolean TimerEnabled;
static int timer_events_allowed;

void
init_timer(void)
{
  TimerCount = 0;
  TimerEnabled = FALSE;
  timer_events_allowed = TRUE;

#ifdef DEBUG
  fprintf(stderr, "init_timer\n");
#endif
}


void
allow_timer(int allowed)
{
  /* Is it possible that we missed something while timer events were not allowed?
     If yes, generate a timer event. */
  if ((TimerEnabled == TRUE) &&
      (timer_events_allowed == FALSE) &&
      (allowed == TRUE) &&
      (TimerCount > 0)) {
    /* widget isn't used for timer device */
    set_global_event(CLEAN_TIMER_DEVICE, NOWIDGET, 0, 0, 0, 0, 0, 0);
  }
  timer_events_allowed = allowed;
}


/* Split milliseconds into seconds and microseconds */
static void
set_timeval(struct timeval *tv, unsigned mseconds)
{
  tv->tv_sec  = (mseconds / 1000);
  tv->tv_usec = (mseconds % 1000) * 1000;
}


/* Call "timer_func" every "interval" microseconds */
static void
my_set_itimer(Notify_func timer_func, unsigned interval)
{
  static struct itimerval itv;

  set_timeval(&(itv.it_interval), interval);
  set_timeval(&(itv.it_value), interval);

  notify_set_itimer_func(ITIMER_CLIENT, timer_func, ITIMER_REAL, &itv, NULL);

#ifdef DEBUG
  fprintf(stderr, "set itimer to %u msecs\n", interval);
#endif
}


static Notify_value
timer_routine(Notify_client client, int which)
{
#ifdef DEBUGxxx
  fprintf(stderr, "timer_routine: %s, client 0x%X, which 0x%X\n",
          (TimerCount == 0) ? "normal" : "OVERRAN", (int)client, which);
#endif

  /* TimerCount is reset by get_timer_count every time the timer event is handled. */
  if (TimerCount == 0) {

    TimerCount++;

    if (timer_events_allowed == TRUE) {
      /* widget isn't used for timer device */
      set_global_event(CLEAN_TIMER_DEVICE, NOWIDGET, 0, 0, 0, 0, 0, 0);
    }
  }
  return NOTIFY_DONE;
}


int
install_timer(int interval)
{
  TimerCount = 0;
  TimerEnabled = FALSE;
  TimerInterval = (unsigned)interval;

  return interval;
}


int
change_timer_interval(int new_interval)
{
  TimerInterval = (unsigned)new_interval;
  TimerCount = 0;
  if (TimerEnabled == TRUE) {
    my_set_itimer(timer_routine, TimerInterval);
  }

  return new_interval;
}


int
get_timer_count(int dummy)
{
  int r;

  r = TimerCount;
  TimerCount = 0;

  return r;
}


int
enable_timer(int dummy)
{
  if (TimerEnabled == FALSE) {
    TimerEnabled = TRUE;
    TimerCount = 0;
    my_set_itimer(timer_routine, TimerInterval);
  }

  return dummy;
}


int
disable_timer(int dummy)
{
  if (TimerEnabled == TRUE) {
    TimerEnabled = FALSE;
    TimerCount = 0;
    my_set_itimer(NOTIFY_FUNC_NULL, 0);
  }

  return dummy;
}


void
get_current_time(int dummy, int *hours, int *minutes, int *seconds)
{
  time_t thistime;

  thistime = time(NULL);
  if (!thistime) {
    *hours = *minutes = *seconds = 0;
  } else {
    struct tm *current_time = localtime(&thistime);
    *hours   = current_time->tm_hour;
    *minutes = current_time->tm_min;
    *seconds = current_time->tm_sec;
  }
}


void
get_current_date(int dummy, int *year, int *month, int *day, int *wday)
{
  time_t thistime;

  thistime = time(NULL);
  if (!thistime) {
    *year = *month = *day = 0;
  } else {
    struct tm *current_time=localtime(&thistime);
    *year  = current_time->tm_year + 1900;
    *month = current_time->tm_mon + 1;
    *day   = current_time->tm_mday;
    *wday  = current_time->tm_wday + 1;
  }
}


/* A call to sleep/usleep would cause problems with the Notifier, so we simulate it.
   See chapter 20.11 of the XView programming manual */
int
wait_mseconds(int mseconds)
{
# ifndef SOLARIS
  int oldmask, mask;
  struct timeval tv;

  set_timeval(&tv, mseconds);

  mask = sigmask(SIGIO);
  mask |= sigmask(SIGALRM);
  oldmask = sigblock(mask);

  if ((select(0, 0, 0, 0, &tv)) == -1) {
    perror("select");
  }

  sigsetmask(oldmask);
# endif

  return mseconds;
}
