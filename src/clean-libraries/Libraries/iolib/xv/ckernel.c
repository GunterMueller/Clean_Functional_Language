/*
   This is the kernel module for the Concurrent Clean Event I/O
   system. It offers initialisation functions for X and the XView
   toolkit as well as creation of a toplevel application window.
   Furthermore the inner part of the Clean Event I/O event loop
   can be found in this module (single_event_catch).

   The interface functions for Clean for this module can be found
   in xkernel.fcl. These functions are used in the Clean modules
   deltaEventIO and ioState.

   1991/1992: Leon Pillich
   1994: Sven Panne
*/

typedef int MyBoolean;

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string.h>
#include <signal.h>

#include <X11/Xlib.h>
#include <xview/xview.h>
#include <xview/frame.h>
#include <xview/panel.h>
#include <xview/screen.h>
#include <xview/notify.h>
#include <xview/defaults.h>

#include "interface.h"
#include "clean_devices.h"
#include "ckernel.h"
#include "ctimer.h"
#include "cpicture.h"
#include "cwindow.h"
#include "cmenu.h"
#include "cfileselect.h"
#include "cdialog.h"

/* Toplevel base frame and associated flag */
Frame toplevel;
MyBoolean toplevel_created = FALSE;

/* global information associated with the current window */
Display *display;
Screen *screen;
Window default_window;

/* These are in _startup.o */
extern unsigned int global_argc;
extern char **global_argv;

int ToplevelPanelKey;
int ToplevelAboutCanvasKey;
int ToplevelHelpPanelKey;
Time multi_click_time;

static void clear_queue(void);

/* Memory management with checks */

#ifdef DEBUG_ALLOC
int total_alloc = 0;
#endif

void *
my_malloc(size_t size)
{
  void *tmp;

#ifdef DEBUG_ALLOC
	{
		int *p;
	
		p = malloc (size+sizeof (int));
		*p = size;
		tmp=p+1;

		total_alloc += size;

		printf ("malloc %d %d %d\n",size,(int)tmp,total_alloc);
	}
#else
  tmp = malloc(size);
#endif

  if (tmp == NULL) {
    fprintf(stderr, "%s (my_malloc): Out of memory...\n", global_argv[0]);
    abort();
  }

  return tmp;
}

void *
my_realloc(void *ptr, size_t size)
{
  void *tmp;

#ifdef DEBUG_ALLOC
	printf ("realloc %d\n",(int)ptr);
#endif

  tmp = realloc(ptr, size);
  if (tmp == NULL) {
    fprintf(stderr, "%s (my_realloc): Out of memory...\n", global_argv[0]);
    abort();
  }

  return tmp;
}

void
my_free(void *ptr)
{
#ifdef DEBUG_ALLOC
	total_alloc -= ((int*)ptr)[-1];

	printf ("free %d %d %d\n",((int*)ptr)[-1],(int)ptr,total_alloc);

	ptr=(void*)(((int*)ptr)-1);
#endif
/* RWS */
  free (ptr);
}

/* Convert Clean string to C string, shifted right, padded with spaces */
char *
cstring_shift(const CLEAN_STRING s, int shift)
{
  /* CLEAN_STRINGs don't have to end with 0, so we have to make
     a copy of the clean string and end it with a 0. */
  char *cstr;

  cstr = (char *)my_malloc((s->length) + 1 + shift);
  strncpy(cstr + shift, s->characters, s->length);
  cstr[s->length + shift] = '\0';
  while (shift > 0) {
    cstr[--shift] = ' ';
  }
  return cstr;
}

/* Convert Clean string to C string */
char *
cstring(const CLEAN_STRING s)
{
  return cstring_shift(s, 0);
}

#define SMALL_RESULT_CLEAN_STRING_LENGTH 64
#define CLEAN_STR_SIZE(len) (len + offsetof(struct clean_string, characters) + 1)

/* Convert C string to Clean string. */
CLEAN_STRING
cleanstring (const char *s)
{
  static CLEAN_STRING result_clean_string = (CLEAN_STRING)0;
  static char small_result_clean_string[CLEAN_STR_SIZE(SMALL_RESULT_CLEAN_STRING_LENGTH)];
  int length;
  CLEAN_STRING clean_s;

  if (result_clean_string != (CLEAN_STRING)0)
    my_free(result_clean_string);

  length = strlen(s);

  if (length <= SMALL_RESULT_CLEAN_STRING_LENGTH) {
    clean_s = (CLEAN_STRING)small_result_clean_string;
    result_clean_string = (CLEAN_STRING)0;
  } else {
    clean_s = (CLEAN_STRING)my_malloc(CLEAN_STR_SIZE(length));
    result_clean_string = clean_s;
  }

  clean_s->length = length;
  memcpy(clean_s->characters, s, length + 1);

  return clean_s;
}

static void
usage_proc(char *name)
{
  extern void xv_usage(char *);

  fprintf(stderr, "usage of %s generic application options:\n\
-h size   heap size is 'size' bytes                        (default 2MB)\n\
-s size   stack size is 'size' bytes                       (default 512kB)\n\
-b        basic only\n\
-nr       don't show the result of the program\n\
-t        show execution times                             (default)\n\
-nt       don't show execution times\n\
-gc       show heap size after garbage collection\n\
-ngc      don't show heap size after garbage collection    (default)\n\
-st       show stack sizes before garbage collection\n\
-nst      don't show stack sizes before garbage collection (default)\n\n", name);

  xv_usage(name);
  exit(-1);   /* xv_usage doesn't return, but anyway... */
/*  exit(EXIT_FAILURE);   RWS *//* xv_usage doesn't return, but anyway... */
}

#ifdef DEBUG

static Xv_opaque
my_error_proc(Xv_object object, Attr_avlist avlist)
{
  char buf[100];

  fprintf(stderr, "%s\nDump core (Y/N)? ", xv_error_format(object, avlist));
  fflush(stderr);
  if (gets(buf) && (buf[0] == 'y' || buf[0] == 'Y')) {
    abort();
  }
  return XV_OK;
}

#endif

/* Initialize the X environment for use in Clean */
int
init_toplevelx(int dummy)
{
  Panel panel;

  clear_queue();

  /* Create the toplevel base frame if not already present. */
  if (toplevel == FALSE) {
    xv_init(XV_INIT_ARGS, global_argc, global_argv,
            XV_USAGE_PROC, usage_proc,
#ifdef DEBUG
            XV_ERROR_PROC, my_error_proc,
#endif
            NULL);

    ToplevelPanelKey       = xv_unique_key();
    ToplevelAboutCanvasKey = xv_unique_key();
    ToplevelHelpPanelKey   = xv_unique_key();

    toplevel = (Frame)xv_create(XV_NULL, FRAME, NULL);
    panel    = (Panel)xv_create(toplevel, PANEL,
/*                                XV_SHOW, FALSE, */
                                NULL);
    xv_set(toplevel, XV_KEY_DATA, ToplevelPanelKey, panel, NULL);
    toplevel_created = TRUE;
  }
  multi_click_time = 100 * defaults_get_integer("openWindows.multiClickTimeout",
                                                "OpenWindows.MultiClickTimeout",
                                                3);
  display = (Display *)xv_get(toplevel, XV_DISPLAY);
  screen  = ScreenOfDisplay(display, (int)xv_get((Xv_Screen)xv_get(toplevel, XV_SCREEN),
                                                 SCREEN_NUMBER));
  default_window = RootWindowOfScreen(screen);
  init_timer();
  init_picture();
  init_file_selector();
  init_dialog();

  return dummy;
}

/* Halbe: environment access rules must have X environment initialized. */
void
check_init_toplevelx (void)
{
  if (toplevel_created == FALSE)
     (void)init_toplevelx(0);
}

int
set_toplevelname(CLEAN_STRING name)
{
  char *tmp;

  tmp = cstring(name);

#ifdef DEBUG
  fprintf(stderr, "setting toplevel name to %s\n", tmp);
#endif

  xv_set(toplevel, FRAME_LABEL, tmp, NULL);  /* XView copies label */
  my_free(tmp);
  return 0;
}

int
close_toplevelx(int dummy)
{
#ifdef DEBUG
  fprintf(stderr, "close_toplevelx (toplevel = 0x%X)\n", (int)toplevel);
#endif

  xv_destroy(toplevel);

  return dummy;
}

int
open_toplevelx(int dummy)
{
  /* miscellaneous init stuff */
  TimerEnabled = FALSE;
  init_menu();
  init_window();

  return dummy;
}

/* show the toplevel window */
int
show_toplevelx(int dummy)
{
  Panel panel;
  Canvas about_canvas;
  Panel help_panel;
  Panel_button_item help_button;
  int width;
  int button_width;

#ifdef DEBUG
  fprintf(stderr, "show_toplevelx (toplevel = 0x%X)\n", (int)toplevel);
#endif

  panel        = (Panel)xv_get(toplevel, XV_KEY_DATA, ToplevelPanelKey);
  about_canvas = (Canvas)xv_get(toplevel, XV_KEY_DATA, ToplevelAboutCanvasKey);
  help_panel   = (Panel)xv_get(toplevel, XV_KEY_DATA, ToplevelHelpPanelKey);
  window_fit(panel);
  if (about_canvas != (Canvas)0) {
    xv_set(about_canvas, WIN_BELOW, panel, NULL);
    if (help_panel != (Panel)0) {
      xv_set(help_panel, WIN_BELOW, about_canvas, NULL);
      window_fit(help_panel);
    }
  }
  window_fit(toplevel);
  width = (int)xv_get(toplevel, XV_WIDTH);
  xv_set(panel, XV_WIDTH, width, NULL);
  if (help_panel != (Panel)0) {
    xv_set(help_panel, XV_WIDTH, width, NULL);
    help_button = (Panel_button_item)xv_get(help_panel, PANEL_FIRST_ITEM);
    button_width = (int)xv_get(help_button, XV_WIDTH);
    xv_set(help_button, XV_X, (width - button_width) / 2, NULL);
  }
  xv_set((Xv_Server)xv_get((Xv_Screen)xv_get(toplevel, XV_SCREEN), SCREEN_SERVER),
	 SERVER_SYNC_AND_PROCESS_EVENTS, NULL);
  xv_set(toplevel, XV_SHOW, TRUE, NULL);
  return dummy;
}

int
hide_toplevelx(int dummy)
{
#ifdef DEBUG
  fprintf(stderr, "hide_toplevelx (toplevel = 0x%X)\n", (int)toplevel);
#endif

  xv_set(toplevel, XV_SHOW, FALSE, NULL);
  return dummy;
}

#define MAX_EVENTS 100

struct event_struct {
  int ev_device;
  int ev_widget;
  int ev_event;
  int ev_sub_widget;
  int ev_mouse_event;
  int ev_mouse_x;
  int ev_mouse_y;
  int ev_key_state;
};

static struct event_struct event_queue[MAX_EVENTS];
static int head, tail;

static void
clear_queue(void)
{
  head = tail = 0;
}

static int
queue_empty(void)
{
  return head == tail;
}

int last_event;
int last_sub_widget;
int last_mouse_event;
int last_mouse_x;
int last_mouse_y;
int last_key_state;

static void
dequeue(int *device, int *widget)
{
  if (head == tail) {
    fprintf(stderr, "Event queue underflow\n");
    abort();
  } else {
  	struct event_struct *event_p;

	event_p=&event_queue[head];

    *device          = event_p->ev_device;
    *widget          = event_p->ev_widget;
    last_event       = event_p->ev_event;
    last_sub_widget  = event_p->ev_sub_widget;
    last_mouse_event = event_p->ev_mouse_event;
    last_mouse_x     = event_p->ev_mouse_x;
    last_mouse_y     = event_p->ev_mouse_y;
    last_key_state   = event_p->ev_key_state;

    head = (head + 1) % MAX_EVENTS;
  }
}

void
set_global_event(int device, int widget, int event, int sub_widget,
                 int mouse_event, int mouse_x, int mouse_y, int key_state)
{
  int next;

  next = (tail + 1) % MAX_EVENTS;
  if (next == head) {
    fprintf(stderr, "Event queue overflow\n");
    abort();
  } else {
  	struct event_struct *event_p;

	event_p=&event_queue[tail];

    event_p->ev_device      = device;
    event_p->ev_widget      = widget;
    event_p->ev_event       = event;
    event_p->ev_sub_widget  = sub_widget;
    event_p->ev_mouse_event = mouse_event;
    event_p->ev_mouse_x     = mouse_x;
    event_p->ev_mouse_y     = mouse_y;
    event_p->ev_key_state   = key_state;
    tail = next;
    notify_stop();
  }
}

/* await a single event and return the widget for which the event was meant. */
static void
process_one_event(void)
{
#ifdef DEBUGxx
  fprintf(stderr, "********** Starting Notifier\n");
#endif

  XFlush(display);
  notify_start();
  XFlush(display);

#ifdef DEBUGxx
  fprintf(stderr, "********** Notifier stopped, ");
#endif
}

void
single_event_catch(int dummy, int *widget, CLEAN_DEVICE *device)
{
  if (ButtonStillDown()) {
    while (ButtonStillDown() && queue_empty()) {
      /* NOTE: There can be events already inside the notifier which haven't been
         delivered to us yet, so we go round the dispatcher loop once. */
#ifdef DEBUG
      fprintf(stderr, "Button still down, dispatching one time...\n");
#endif
      XFlush(display);
      notify_dispatch();
      if (queue_empty()) {
        ButtonStillDownEvent();
      } else {
        XFlush(display);
      }
    }
  } else {

    /* now we only wait for "real" events -> 0% cpu time */
    while(queue_empty())
      process_one_event();
  }

  dequeue(device, widget);

#ifdef DEBUGxx
  fprintf(stderr,"catched event on device %d, widget 0x%X\n", *device, *widget);
#endif

}

int
destroy_widget(int obj)
{
#ifdef DEBUG
  fprintf(stderr,"Destroying widget 0x%X\n", obj);
#endif

  xv_destroy((Xv_object)obj);
  return obj;
}

int get_argc (void)
{
	return global_argc;
}

CLEAN_STRING get_argv_n (int n)
{
	return cleanstring (global_argv[n]);
}

