/*
   This is the kernel module for the Concurrent Clean Event I/O
   system. It offers initialisation functions for X and the Olit
   toolkit as well as creation of a toplevel application window.
   Furthermore the inner part of the Clean Event I/O event loop
   can be found in this module (single_event_catch).

   The interface functions for Clean for this module can be found
   in xkernel.fcl. These functions are used in the Clean modules
   deltaEventIO and ioState.

   Last change, 1.3.1993 process_one_event now handles timer
   events correctly.

   1991/1992: Leon Pillich
*/

#include <X11/Intrinsic.h>
#include <X11/Xlib.h>
#include <Xol/OpenLook.h>
#include <Xol/BaseWindow.h>
#include <X11/StringDefs.h>
#include <Xol/BulletinBo.h>
#include <Xol/StaticText.h>
#include "clean_devices.h"
#include <stdio.h>
#include <string.h>

#define NOWIDGET -42
#define NODEVICE -42

/* from clean types */
typedef struct clean_string
{
        int     length;
        char    characters[0];
} *CLEAN_STRING;

Widget toplevel;
Widget base; /* base widget is mother widget */

/* global information associated with the current window */
Display *display;
Screen *screen;
Window default_window;

/* global information to be accessed from Clean */
int global_widget;
CLEAN_DEVICE global_device;

/* is a timer or null device installed, if not we can
   save lots of time                                  */
extern Boolean timer_able;
extern Boolean null_able;

/* is a menu bar already present or not */
extern Boolean MenuPresent;

extern unsigned int global_argc;
extern char **global_argv;


/* clean_strings don't have to end with 0, so we have to make
   copy the clean string and end it with a 0. */
char *cstr;

/* global variable used for conversion from c strings to clean strings */
CLEAN_STRING result_clean_string;

#define SMALL_RESULT_CLEAN_STRING_LENGTH 64

static char small_result_clean_string[SMALL_RESULT_CLEAN_STRING_LENGTH+4+1];

char *cstring(CLEAN_STRING s)
{ 
  cstr = (char *)XtMalloc((s->length)+1);
  strncpy(cstr, s->characters, s->length);
  cstr[s->length] = 0;

  return cstr;
}

CLEAN_STRING cleanstring (char *s)
{
	int length;
	CLEAN_STRING clean_s;
	
	length=strlen (s);

	if (result_clean_string!=NULL)
		XtFree((XtPointer)result_clean_string);

	if (length<=SMALL_RESULT_CLEAN_STRING_LENGTH)
		clean_s=(CLEAN_STRING) small_result_clean_string;
	else {
		clean_s=(CLEAN_STRING)XtMalloc(sizeof(int)+length+1);
		result_clean_string=clean_s;
	}
	
	clean_s->length=length;
	memcpy (clean_s->characters,s,length+1);

	return clean_s;
}

/* Initialize the X environment for use in Clean */
int init_toplevelx(int dummy)
{ extern void make_gc (void);
  extern void init_timer (void);
  extern void init_picture (void);
  extern void init_file_selector (void); 

  /* Create the toplevel base window if not already present. */
  if (!toplevel)
     toplevel = OlInitialize("top","Top",NULL,0,&global_argc,global_argv);
  display=XtDisplay(toplevel);
  screen=XtScreen(toplevel);
  default_window=RootWindowOfScreen(screen);
  make_gc();
  init_timer();
  init_picture();
  init_file_selector();
  result_clean_string=NULL;

  return dummy;
}

/* Halbe: environment access rules must have X environment initialized. */
void check_init_toplevelx (void)
{ int dummy;

  if (!toplevel)
     dummy=init_toplevelx(0);
}

int set_toplevelname(CLEAN_STRING name)
{ XtVaSetValues(toplevel, XtNtitle, cstring(name), NULL);
  return 0;
}

int close_toplevelx(int dummy)
{
  /* Unrealize the toplevel widget and destroy the base widget. */
  XtDestroyWidget(base);

  return dummy;
}

extern Boolean IOTimerEnabled;

int open_toplevelx(int dummy)
{ 
  extern void init_window (void);

/*  Arg args[10];   Halbe: not used */
/*  int n=0;        Halbe: not used */

  base = XtVaCreateManagedWidget("b",bulletinBoardWidgetClass,toplevel,
                                  NULL);

  /* miscellaneous init stuff */
  IOTimerEnabled=False;
  MenuPresent=False;
  init_window();

  result_clean_string=NULL;

  return dummy;
}

/* show the toplevel window */
int show_toplevelx(int dummy)
{ XtRealizeWidget(toplevel);
  return dummy;                  /* Halbe*/
}

int hide_toplevelx(int dummy)
{ XtUnrealizeWidget(toplevel);
  return dummy;                  /* Halbe*/
}

/* await a single event and return the widget for which the event was
   meant. */
void process_one_event(void)
{ XEvent event;

  XtNextEvent(&event);

  if((event.type == ClientMessage) &&
     (strcmp(event.xclient.data.b, "timer")==0))
  { global_device = CLEAN_TIMER_DEVICE;
  } 
  else XtDispatchEvent(&event);
}

void single_event_catch(dummy,widget,device)
int dummy;
int *widget;
CLEAN_DEVICE *device;
{ extern Boolean ButtonStillDown(void);
  extern void ButtonStillDownEvent(void);

  global_device=NODEVICE;
  
  if(ButtonStillDown())
  {
    while(global_device==NODEVICE)
    { if(!XtPending())
        ButtonStillDownEvent();
      else
        process_one_event();
    };
  } else
  if(null_able)
  { while(global_device==NODEVICE)
    { if(!XtPending())
        global_device=CLEAN_NULL_DEVICE; 
      else
        process_one_event();
    };
  }
  else /* now we only wait for "real" events -> 0% cpu time */
  { while(global_device==NODEVICE)
      process_one_event();
  }

#ifdef DEBUG
  fprintf(stderr,"Event on device:%d\n",global_device);
  fprintf(stderr,"%u\n",global_widget);
#endif

  *widget = global_widget;
  *device = global_device;
}

int destroy_widget(w)
int w;
{ 
  XtDestroyWidget((Widget)w);

#ifdef DEBUG
  fprintf(stderr,"Widget %d destroyed\n",w);fflush(stderr);
#endif

  return w;
}

/* actually drawing a widget means managing it. */
Widget manage(w)
Widget w;
{ XtManageChild(w);
  
  return w;
}

/* sometimes we have to undraw a widget, because it has to be hidden 
   from the user in case of nested io.
*/
Widget unmanage(w)
Widget w;
{ XtUnmanageChild(w);
  return w;
}

/* Deallocating arbitrary data on a widget.
*/
void DestroyWidgetInfoCB(Widget w,XtPointer to_be_deallocated, XtPointer cdata)
{ XtFree(to_be_deallocated);
}
