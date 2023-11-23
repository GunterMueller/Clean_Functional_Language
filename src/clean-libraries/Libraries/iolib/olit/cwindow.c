/*
   This module implements support functions for creating and handling
   scrollable and fixed size document windows (the document in fact
   being a picture) in Concurrent Clean Event I/O.

   The interface functions for Clean for this module can be found in
   xwindow.fcl. These functions are used in the Clean modules
   windowDevice and deltaWindow.

   Last change, 1.3.1993, Synchronize added when scrolling through
   window contents.

   1992: Leon Pillich
*/

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <X11/keysym.h>
#include <X11/Xlib.h>

#include <Xol/OpenLook.h>
#include <Xol/BaseWindow.h>
#include <Xol/ControlAre.h>
#include <Xol/Form.h>
#include <Xol/ScrolledWi.h>
#include <Xol/Scrollbar.h>
#include <Xol/Stub.h>
#include <Xol/DrawArea.h>

#include <Xol/OlCursors.h>
#include <X11/cursorfont.h>

#include "clean_devices.h"
#include "mackeys.h"
#include "windowdata.h"

#include <stdio.h>

#define MAXIMUM(a,b)	(((a)>=(b))?(a):(b))
#define MINIMUM(a,b)	(((a)>=(b))?(b):(a))
#define ABS(a)		((a>0)?(a):(-(a)))

#define Scrollable 0
#define FixedSize  1

extern char *cstring(CLEAN_STRING s);

/* the global device to be passed to Clean */
extern CLEAN_DEVICE global_device;
extern Widget global_widget;

/* the special window event */
int my_window_event;

/* mouse state info */
int my_local_mouse_x;
int my_local_mouse_y;
int my_mouse_x;
int my_mouse_y;
int my_mouse_event;
CleanModifiers my_state;
ButtonDownState button_down;
Widget my_last_window;

/* information needed for multiclicks */
Time time_of_last_click;
int last_click_x, last_click_y;
ClickCount click_count;
Time multi_click_time;

/* keyboard state info */
char my_key;
CleanModifiers my_key_state;
int my_key_event; /* KeyPress or KeyRelease */
Boolean my_key_repeat;

/* update info */
Region upd_region;
XRectangle upd_rect;
XRectangle upd_rect_next;
int upd_state;

/* the active window*/
Widget my_active_window;

/* the default screen/display values */
extern Widget toplevel;
extern Widget base;
extern Display *display;

/* internally defined functions */
void handle_mouse_events();
void handle_focus_events();
void handle_keyboard();
void handle_keypress();
void handle_expose();
/* RWS */
# ifdef SOLARIS
static void handle_exposeCB(Widget w, XEvent *event, Region region);
# endif
/* */
Widget activate_window(Widget window);
Widget set_window_cursor();
void verify_scrollbar();
void stub_resize(Widget widget);
void calc_keystate(unsigned int state,CleanModifiers *m);

/* keeping track of the current window */
int current_window;

/* the default and standard Graphics Contexts */
extern GC standard_gc;

/* the extra popup menu (mirror) for each window */
extern Widget global_popup;
extern Boolean MenuPresent;

/* initialize global window data */
void init_window(void)
{ my_active_window = NULL;
  my_key_repeat    = 0;
  button_down      = 0;

  click_count      = NoClick;
  multi_click_time = (Time)XtGetMultiClickTime(display);
}

/* Callbacks for catching window (close) events. OL specific.
*/
void CloseWindowCB(w,clientData,callData)
Widget w;
XtPointer clientData;
OlWMProtocolVerify *callData;
{ 
  if((callData->msgtype)==OL_WM_DELETE_WINDOW)
  { 
#ifdef DEBUG
  fprintf(stderr," .... window close.\n");
#endif

    global_device = CLEAN_WINDOW_DEVICE;
    global_widget = w;
    my_window_event = CLEAN_WINDOW_CLOSED;
  };
}


/* When a window is being destroyed, several things have to
   be cleaned up.
*/
void DestroyWindowCB(Widget window, WindowData *wdata, XtPointer calldata)
{ char *t;
  extern void FreePictureData(WindowData *);

  XtVaGetValues(window, XtNtitle, &t, NULL);
  XtFree(t);
  FreePictureData(wdata); 
}

/* Create a scrollable window with all parameters set according to the
   Clean specification of the picture domain, minimum and intial size,
   thumb and scrollvalues etc.
*/
void create_window(type,x,y,x0,y0,name,hthumb,hscroll,
                   vthumb,vscroll,width,height,
                   width_min,height_min,
                   width_init,height_init,
                   work,window)
int type;
int x,y,x0,y0;
CLEAN_STRING name;
int hthumb,hscroll,vthumb,vscroll;
int width,height;
int width_min,height_min;
int width_init,height_init;
Widget *work;
Widget *window;
{
  Widget shell;
  Widget form;
  Widget stub;
  Widget scroll_hor,scroll_vert;
  Widget corner;
  Dimension vscroll_width,hscroll_height;
  /* Dimension border_width;   Halbe: unused */
  WindowData *wdata;
  Arg args[5];
  int n=0;
  extern GC make_new_gc();
  extern void set_default_font(WindowData *wdata);

  scroll_hor	= scroll_vert	= NULL;
#ifdef DEBUG
  fprintf(stderr,"htumb:%d,hscroll:%d,vthumb:%d,vscroll:%d\n",
                  hthumb,hscroll,vthumb,vscroll);
  fprintf(stderr,"x:%d,y:%d,width:%d,height:%d\n",x,y,width,height);
  fprintf(stderr,"width_min:%d,height_min:%d\n",width_min,height_min);
  fprintf(stderr,"width_init:%d,height_init:%d",width_init,height_init);
#endif

  XtSetArg(args[n], XtNwmProtocolInterested, OL_WM_DELETE_WINDOW);n++;
  XtSetArg(args[n], XtNx, x);n++; /* is not supported on all systems */
  XtSetArg(args[n], XtNy, y);n++;
  XtSetArg(args[n], XtNtitle, cstring(name));n++;
  if(type==FixedSize) XtSetArg(args[n], XtNresizeCorners, False);
  else XtSetArg(args[n], XtNresizeCorners, True);
  n++;
  shell = XtCreatePopupShell("window",baseWindowShellWidgetClass,
                             toplevel,args,n);

  /* add a callback to deal with window closing */
  OlAddCallback(shell, XtNwmProtocol, CloseWindowCB, NULL);
 
  /* add a callback to handle keyboard events */
  form = XtVaCreateManagedWidget("work",formWidgetClass,shell,NULL);

  /* Create a scrollable window */
  stub=XtVaCreateManagedWidget("picture", stubWidgetClass, form,
                               XtNxResizable,TRUE,
                               XtNyResizable,TRUE,
                               XtNborderWidth, 1,
/* RWS */
# ifdef SOLARIS
							   XtNexpose, handle_exposeCB,
# endif
/* */
                               XtNwidth, (Dimension)width_init,
                               XtNheight, (Dimension)height_init, NULL);

  if(type==Scrollable)
  { XtVaSetValues(stub, XtNresize, stub_resize, NULL);
    scroll_vert=XtVaCreateManagedWidget("sv", scrollbarWidgetClass, form,
                                      XtNxRefWidget, stub,
                                      XtNxOffset, 2,
                                      XtNxAddWidth, TRUE,
                                      XtNxAttachRight, TRUE,
                                      XtNxVaryOffset, FALSE, 
                                      XtNheight,(Dimension)height_init,
                                      XtNyResizable, TRUE,
                                      XtNxResizable, FALSE,
                                      XtNgranularity, vscroll,
                                      XtNorientation,OL_VERTICAL,
                                      XtNproportionLength,
                                               (height_init/vscroll)*vscroll,
                                      XtNsliderMin, y0,
                                      XtNsliderMax, y0+height, 
                                      XtNsliderValue, vthumb,
                                      XtNdragCBType,OL_GRANULARITY,
                                      XtNstopPosition,OL_GRANULARITY,
                                      XtNuseSetValCallback, TRUE,
                                      XtNtraversalOn, FALSE,
                                      NULL);
    XtVaGetValues(scroll_vert, XtNwidth,  &vscroll_width,  NULL);
    scroll_hor =XtVaCreateManagedWidget("sh", scrollbarWidgetClass, form,
                                      XtNyRefWidget, stub,
                                      XtNyOffset, 2,
                                      XtNyAddHeight, TRUE,
                                      XtNyAttachBottom, TRUE,
                                      XtNyVaryOffset, FALSE,
                                      XtNwidth,(Dimension)width_init,
                                      XtNyResizable, FALSE,
                                      XtNxResizable, TRUE,
                                      XtNgranularity, hscroll,
                                      XtNorientation,OL_HORIZONTAL,
                                      XtNproportionLength, 
                                               (width_init/hscroll)*hscroll,
                                      XtNsliderMin, x0,
                                      XtNsliderMax, x0+width, 
                                      XtNsliderValue, hthumb,
                                      XtNdragCBType,OL_GRANULARITY,
                                      XtNstopPosition,OL_GRANULARITY,
                                      XtNuseSetValCallback, TRUE,
                                      XtNtraversalOn, FALSE,
                                      NULL);
    XtVaGetValues(scroll_hor, XtNheight, &hscroll_height, NULL);
    corner = XtVaCreateManagedWidget("corner", stubWidgetClass, form,
                                   XtNxRefWidget, scroll_hor,
                                   XtNyRefWidget, scroll_vert,
                                   XtNxAddWidth, TRUE,
                                   XtNyAddHeight, TRUE,
                                   XtNxOffset, 2,
                                   XtNyOffset, 2,
                                   XtNxAttachRight, TRUE,
                                   XtNyAttachBottom, TRUE,
                                   XtNxVaryOffset, FALSE,
                                   XtNyVaryOffset, FALSE,
                                   XtNheight, hscroll_height,
                                   XtNwidth, vscroll_width,
                                   XtNxResizable, FALSE,
                                   XtNyResizable, FALSE, NULL);
    XtAddCallback(scroll_vert, XtNsliderMoved, verify_scrollbar, shell);
    XtAddCallback(scroll_hor , XtNsliderMoved, verify_scrollbar, shell);
  };
  
  /* Add an event handler for mouse, focus, keyboard and expose events */
  XtAddEventHandler(stub,ButtonPressMask|ButtonReleaseMask|
                         ButtonMotionMask,
                    False,handle_mouse_events,(XtPointer)shell);
  XtAddEventHandler(stub, KeyReleaseMask|KeyPressMask, False,
                    handle_keyboard, (XtPointer)shell); 
  XtAddEventHandler(shell, FocusChangeMask, False, handle_focus_events, shell);

/* RWS The Exposure event handler doesn't get called under Solaris (don't
		know why). We handle the updates through an exposure call back
		(see XtNexposure above) */
# ifndef SOLARIS
  XtAddEventHandler(stub,ExposureMask,True,handle_expose,(XtPointer)shell);
# endif

#ifdef DEBUG
  fprintf(stderr,"Event handlers installed on window....\n");
#endif

  /* set up return values */
  *work = stub;
  *window = shell;
  current_window=XtWindow(stub);

  /* set the correct minimum and maximum sizes 
     (6 and 7 are additional borderwidths) and windowdata     */
  wdata=(WindowData *)XtMalloc(sizeof(WindowData));
  wdata->hscrollbar=scroll_hor;
  wdata->vscrollbar=scroll_vert;
  wdata->picture=stub;
/* RWS */
  wdata->shell=shell;
/* */
  wdata->height=height_init;
  wdata->width=width_init;
  wdata->x0=hthumb;
  wdata->y0=vthumb;
  wdata->window_gc=make_new_gc();
  wdata->curx=x0;
  wdata->cury=y0;
  wdata->pen=0;
  wdata->active=False;
  set_default_font(wdata);
  switch(type)
  { case Scrollable:
      XtVaSetValues(shell, XtNminWidth, (Dimension)width_min+vscroll_width+2,
                       XtNminHeight, (Dimension)height_min+hscroll_height+2,
                       XtNmaxWidth, 
                           MINIMUM((Dimension)width+vscroll_width+2,
                              DisplayWidth(display, DefaultScreen(display))-50),
                       XtNmaxHeight, 
                           MINIMUM((Dimension)height+hscroll_height+2,
                              DisplayHeight(display,DefaultScreen(display))-50),
                       XtNwidth, (Dimension)width_init+vscroll_width+2,
                       XtNheight, (Dimension)height_init+hscroll_height+2,
                       XtNuserData, wdata,
                       NULL);
      break;
    case FixedSize:
      XtVaSetValues(shell, XtNminWidth, width_init+2,     /* Halbe: added +2's */
                           XtNminHeight, height_init+2,
                           XtNmaxWidth, width_init+2,
                           XtNmaxHeight, height_init+2,
                           XtNwidth, width_init+2,
                           XtNheight, height_init+2,
                           XtNuserData, wdata,
                           NULL);
      break;
  };
  XtAddCallback(shell, XtNdestroyCallback,
                (XtCallbackProc)DestroyWindowCB, wdata);
  XtVaSetValues(stub, XtNuserData, wdata, NULL);

  /* Realize the shell */
  XtPopup(shell, XtGrabNone);
/*
  activate_window(shell);
*/
}



/* RWS */
# ifndef SOLARIS
/* */

/* This function handles expose (update events) for the stub
   widget (the window's work area). We create a region for clipping.
   For every sequence of exposures this function is called only once.
   After this the subsequent exposures are collected with
   get_expose_area().
*/
void handle_expose(w,window,event,done)
Widget w;
XtPointer window;
XEvent *event;
Boolean *done;
{ /* Widget scrollbar;    Halbe: unused */

  switch(event->type)
  { case NoExpose:
     #ifdef DEBUG
     fprintf(stderr,"NoExpose\n");
     #endif
     break;
    case GraphicsExpose:
     #ifdef DEBUG
     fprintf(stderr,"GraphicsExpose\n");
     #endif
     /* no break */
    case Expose:
     upd_region=XCreateRegion();
     global_device=CLEAN_WINDOW_DEVICE;
     global_widget=(Widget)window;
     my_window_event=CLEAN_WINDOW_UPDATE;
     upd_rect.x=(event->xexpose).x;
     upd_rect.y=(event->xexpose).y;
     upd_rect.width=(event->xexpose).width;
     upd_rect.height=(event->xexpose).height;
     XUnionRectWithRegion(&upd_rect,upd_region,upd_region);
     upd_state=(event->xexpose).count;
#ifdef DEBUG
     fprintf(stderr,"Expose event, %d to follow, window 0x%X, widget 0x%X\n",
			event->xexpose.count, window, w);
#endif
   };
}

/* RWS */

# else /* #ifdef SOLARIS */

static void handle_exposeCB(Widget w, XEvent *event, Region region)
{
	WindowData *wdata;

	XtVaGetValues(w, XtNuserData, &wdata, NULL);

	upd_region=XCreateRegion();
	global_device=CLEAN_WINDOW_DEVICE;
	global_widget=wdata->shell;
	my_window_event=CLEAN_WINDOW_UPDATE;
	upd_rect.x=(event->xexpose).x;
	upd_rect.y=(event->xexpose).y;
	upd_rect.width=(event->xexpose).width;
	upd_rect.height=(event->xexpose).height;
	XUnionRectWithRegion(&upd_rect,upd_region,upd_region);
	upd_state=(event->xexpose).count;

#ifdef DEBUG
	fprintf(stderr,"Expose event2\n");
#endif
}

# endif
/* */

/* This function handles focus changes, which in terms of 
   Clean Event IO events means activation/decativation events.
   We are only interested in Nonlinear notify events, 
   don't ask me why.
*/
void handle_focus_events(w,window,event,done)
Widget w;
XtPointer window;
XEvent *event;
int *done;
{ WindowData *wdata;

  switch(event->type)
  { case FocusIn:
      if(((event->xfocus).detail)==NotifyNonlinear)
      { /* this window has been activated */
        XtVaGetValues(window, XtNuserData, &wdata, NULL);
        if(!(wdata->active))
        { global_device=CLEAN_WINDOW_DEVICE;
          global_widget=(Widget)window;
          my_window_event=CLEAN_WINDOW_ACTIVATE;
          my_active_window=(Widget)window;
          wdata->active=True;
        };
      };
      break;
    case FocusOut:
      if(((event->xfocus).detail)==NotifyNonlinear)
      { /* this window has been deactivated */
        XtVaGetValues(window, XtNuserData, &wdata, NULL);
        if(wdata->active)
        { global_device=CLEAN_WINDOW_DEVICE;
          global_widget=(Widget)window;
          my_window_event=CLEAN_WINDOW_DEACTIVATE;
          my_active_window=NULL;
          wdata->active=False;
        };
      };
      break;
  };

#ifdef DEBUG
  if(((event->xfocus).detail)==NotifyNonlinear)
    fprintf(stderr,"Focus i/o event\n");
#endif
}


/* RWS, dummy */
int
set_dd_distance(int distance)
{
  return distance;
}
/* */

/* This function handles the keyboard events. It is added to 
   a widget capable of receiving keyboard input (i.e. a form widget).
   We are interested both in KeyPress and KeyRelease events.
*/
void handle_keyboard(w,window,event,done)
Widget w;
XtPointer window;
XEvent *event;
int *done;
{ char buffer[10];
  KeySym keysym;
  XComposeStatus compose;
  int event_type=event->type;

  if((event_type==KeyPress)||(event_type==KeyRelease))
  { XLookupString((XKeyEvent *)event,buffer,10,&keysym,&compose);
 
    /* check all keypresses */
    if ((keysym >= XK_Shift_L) && (keysym <= XK_Hyper_R))
    { /* do nothing this is just a modifier key */
    }  
    else
    if(
       ((keysym >= XK_space) && (keysym <= XK_asciitilde)) ||
       ((keysym >= XK_KP_Space) && (keysym <= XK_KP_9))
      )
    { my_key=buffer[0];
      calc_keystate((event->xkey).state,&my_key_state);
      my_key_event=event_type;
      global_device=CLEAN_WINDOW_DEVICE;
      my_window_event=CLEAN_WINDOW_KEYBOARD;
      global_widget=(Widget)window;
#ifdef DEBUG
      if(event_type==KeyPress)
        fprintf(stderr, "KeyPress event:%c\n",my_key);
      else
        fprintf(stderr, "KeyRelease event:%c\n",my_key);
#endif
    }
    else
    { switch(keysym)
      { case XK_BackSpace: my_key=MacBackSp; break;
        case XK_Tab: my_key=MacTab; break;
        case XK_Return: my_key=MacReturn; break;
        case XK_Escape: my_key=MacEscape; break;
        case XK_Delete: my_key=MacBackSp; break; /* why ? */
        case XK_Left: my_key=MacLeft; break;
        case XK_Up: my_key=MacUp; break;
        case XK_Right: my_key=MacRight; break;	
        case XK_Down: my_key=MacDown; break;
        case XK_Prior: my_key=MacPgUp; break;
        case XK_Next: my_key=MacPgDown; break;
        case XK_Begin: my_key=MacBegin; break;
        case XK_End: my_key=MacEnd; break;
        case XK_Linefeed: my_key=MacReturn; break;
        case XK_Help: my_key=MacHelp; break;
        default: my_key=(char)0;
      }; 
      if(my_key!=0)
      { calc_keystate((event->xkey).state,&my_key_state);
        my_key_event=event_type;
        global_device=CLEAN_WINDOW_DEVICE;
        my_window_event=CLEAN_WINDOW_KEYBOARD;
        global_widget=(Widget)window;
      };
    };
  };
}



/* This function handles the mouse events on the stub widget,
   i.e. the work area of the window. We are interested in
   ButtonPress, ButtonRelease and MotionNotify events.
*/
void handle_mouse_events(w,window,event,done)
Widget w;
XtPointer window;
XEvent *event;
int *done;
{ WindowData *wdata;
  int x,y;
  Time time;

  XtVaGetValues(window, XtNuserData, &wdata, NULL);

  /* It maybe a menu popup? */
  if( ((event->type)==ButtonPress) && 
      (((event->xbutton).button)==Button3)
    )
  { activate_window(window);
    if(MenuPresent) OlMenuPost(global_popup);
    return;
  };
     

  switch(event->type)
  { /* mouse events */ 
    case ButtonPress:
      time = (event->xbutton).time;
      my_local_mouse_x = x = (event->xbutton).x;
      my_local_mouse_y = y = (event->xbutton).y;
      my_mouse_x = x+(wdata->x0);
      my_mouse_y = y+(wdata->y0);

      /* check for multiclicks */
      switch(click_count)
      { case NoClick:
          my_mouse_event = BUTTONDOWN;
          last_click_x = x;
          last_click_y = y;
          click_count = OneClick;
          break;
        case OneClick:
          if( (time-time_of_last_click <= multi_click_time) &&
              (x == last_click_x) &&
              (y == last_click_y) )
          { my_mouse_event = DOUBLECLICK;
            click_count = TwoClicks;
          }
          else
          { my_mouse_event = BUTTONDOWN;
            last_click_x = x;
            last_click_y = y;
            click_count = OneClick;
          };
          break; 
        case TwoClicks:
          if( (time-time_of_last_click <= multi_click_time) &&
              (x == last_click_x) &&
              (y == last_click_y) )
          { my_mouse_event = TRIPLECLICK;
            click_count = NoClick;
          }
          else
          { my_mouse_event = BUTTONDOWN;
            last_click_x = x;
            last_click_y = y;
            click_count = OneClick;
          };
      };

      time_of_last_click = time;
      calc_keystate((event->xbutton).state,&my_state);
      button_down=ButtonStillDownWindow;
      global_device=CLEAN_WINDOW_DEVICE;
      global_widget=(Widget)window;
      my_last_window=global_widget;
      my_window_event=CLEAN_WINDOW_MOUSE;
      activate_window(window);

      break;

    case ButtonRelease:
      my_mouse_event=BUTTONUP;
      my_mouse_x=(event->xbutton).x+(wdata->x0);
      my_mouse_y=(event->xbutton).y+(wdata->y0);
      calc_keystate((event->xbutton).state,&my_state);
      button_down=ButtonUp;
      global_device=CLEAN_WINDOW_DEVICE;
      global_widget=(Widget)window;
      my_last_window=global_widget;
      my_window_event=CLEAN_WINDOW_MOUSE;
      break;

    case MotionNotify:
      if(button_down==ButtonStillDownWindow)
      { my_local_mouse_x = (event->xmotion).x;
        my_local_mouse_y = (event->xmotion).y;
        my_mouse_x=my_local_mouse_x+(wdata->x0);
        my_mouse_y=my_local_mouse_y+(wdata->y0);
        my_mouse_event=BUTTONSTILLDOWN;
        calc_keystate((event->xmotion).state,&my_state);
        global_device=CLEAN_WINDOW_DEVICE;
        global_widget=(Widget)window;
        my_last_window=global_widget;
        my_window_event=CLEAN_WINDOW_MOUSE;
      };
      break;
  };

#ifdef DEBUG
  fprintf(stderr,"Mouse event catched\n");
#endif
}


/* Getting the special window event specification.
*/
int get_window_event(dummy)
int dummy;
{ 
#ifdef DEBUG
  fprintf(stderr, "my_window_event fetched:%d\n",my_window_event);
#endif  
  return my_window_event;
}

/* Getting mouse event information after a mouse event has occurred.
*/
void get_mouse_state(int dummy,int *x,int *y,int *e,int *shift,int *option,
                     int *command, int *control)
{ 
  *x      =my_mouse_x;
  *y      =my_mouse_y;
  *e      =my_mouse_event;
  *shift  =my_state.shift;
  *option =my_state.option;
  *command=my_state.command;
  *control=my_state.control;

#ifdef DEBUG 
  fprintf(stderr,"Mouse coordinates: %d,%d\n",my_mouse_x,my_mouse_y);
  fprintf(stderr,"Mouse event: %d\n",my_mouse_event);
#endif
}

/* Handling the expose events means setting the right clipping area in 
   the windows gc (my_gc for the moment).
*/
Widget get_expose_area(Widget window,int *x,int *y,int *xx,int *yy,int *state)
{ XEvent report;
  WindowData *wdata;
  Window w;

  XtVaGetValues(window, XtNuserData, &wdata, NULL);

  *x=upd_rect.x+(wdata->x0);
  *y=upd_rect.y+(wdata->y0);
  *xx=upd_rect.width+(*x);
  *yy=upd_rect.height+(*y);

#ifdef DEBUG
  fprintf(stderr, "Get expose area: %d %d %d %d\n", *x,*y,*xx,*yy);
#endif

  w=XtWindow(wdata->picture);
  if(XCheckTypedWindowEvent(display,w,Expose,&report) ||
     XCheckTypedWindowEvent(display,w,GraphicsExpose,&report))
  {
    upd_rect.x=report.xexpose.x;
    upd_rect.y=report.xexpose.y;
    upd_rect.width=report.xexpose.width;
    upd_rect.height=report.xexpose.height;
    XUnionRectWithRegion(&upd_rect,upd_region,upd_region);
    upd_state=report.xexpose.count;
    *state=1;
  } else *state=0;

  return window;
}

/* Starting an update action -> set clipping mask to region.
*/
Widget start_update(Widget window)
{ WindowData *wdata;

  XtVaGetValues(window, XtNuserData, &wdata, NULL);
  XSetRegion(display,wdata->window_gc,upd_region);

#ifdef DEBUG
  fprintf(stderr, "Start update...\n");
#endif

  return window;
}

/* Ending updating a region -> destroy region reset clipping mask.
*/
Widget end_update(Widget window)
{ WindowData *wdata;

  XtVaGetValues(window, XtNuserData, &wdata, NULL);
  XDestroyRegion(upd_region);
  XSetClipMask(display,wdata->window_gc,None);

#ifdef DEBUG
  fprintf(stderr, "End update...\n");
#endif

  return window;
}

/* Getting keyboard event information after such an event did occur.
*/
void get_key_state(int dummy,int *key,int *shift,int *option,
                   int *command, int *control, int *event_type)
{
  *key       = (int)my_key;
  if(my_key_event==KeyPress)
  { if(my_key_repeat) 
      *event_type=KEYSTILLDOWN;
    else
    { my_key_repeat=TRUE;
      *event_type=KEYDOWN;
    };
  }
  else
  { my_key_repeat=FALSE;
    *event_type=KEYUP;
  };
  *shift=my_key_state.shift;
  *option=my_key_state.option;
  *command=my_key_state.command;
  *control=my_key_state.control;
}

/* calculate a modifier key mask from the keystate */
void calc_keystate(unsigned int state, CleanModifiers *ret)
{ ret->option=ret->shift=ret->control=ret->command=0;
 
  if(state&Mod1Mask)
  { ret->option=1;
    #ifdef DEBUG
    fprintf(stderr,"Modifier:Mod1 (Meta/Option/Alt)\n");
    #endif
  };
  if(state&ShiftMask)
  { ret->shift=1;
    #ifdef DEBUG
    fprintf(stderr,"Modifier:Shift\n");
    #endif
  };
  if(state&ControlMask)
  { ret->command=ret->control=1;
    #ifdef DEBUG
    fprintf(stderr,"Modifier:Control\n");
    #endif
  };
}

/* Setting the cursor to some predefined shape,
   keeping in mind the own OpenLook cursor specification. 
*/
Widget set_window_cursor(clean_cursor,window_shell)
int clean_cursor;
Widget window_shell; /* the shell associated with the window */
{ Cursor cursor;
  Widget window;
  WindowData *wdata;

  XtVaGetValues(window_shell,XtNuserData,&wdata,NULL);
  window=wdata->picture;
  
  switch(clean_cursor)
  { case STANDARDCURSOR:
      cursor=GetOlStandardCursor(XtScreen(window));
      break;
    case BUSYCURSOR:
      cursor=GetOlBusyCursor(XtScreen(window));
      break;
    case IBEAMCURSOR:
      cursor=XCreateFontCursor(XtDisplay(window),XC_xterm);
      break;
    case CROSSCURSOR:
      cursor=XCreateFontCursor(XtDisplay(window),XC_crosshair);
      break;
    case FATCROSSCURSOR:
      cursor=XCreateFontCursor(XtDisplay(window),XC_cross);
      break;
    case ARROWCURSOR:
      cursor=XCreateFontCursor(XtDisplay(window),XC_arrow);
      break;
    default: 
      cursor=GetOlStandardCursor(XtScreen(window));
  };
  XDefineCursor(XtDisplay(window),XtWindow(window),cursor);

#ifdef DEBUG
  fprintf(stderr,"Cursor set: %d\n",clean_cursor);
#endif

  return window_shell;
}

/* Getting the size of the entire display.
*/
void get_screen_size(dummy, width, height)
int dummy;
int *width;
int *height;
{ *width=(int)DisplayWidth(display, DefaultScreen(display));
  *height=(int)DisplayHeight(display,DefaultScreen(display));
}

/* Dragging the "thumb" causes parts of the window to scroll and parts
   to be updated. 
*/
void verify_scrollbar(w, window_shell, scroll_data)
Widget w;
Widget window_shell;
OlScrollbarVerify *scroll_data;
{ WindowData *wdata;
  OlDefine orientation;
  int delta,proportion_length;
  void get_first_update(Widget w, Widget *wreturn, int *state);
  
  /* if thumb not moved return immediatly */
  if(scroll_data->delta==0) return;

  XtVaGetValues(window_shell, XtNuserData, &wdata, NULL);
  XtVaGetValues(w, XtNorientation, &orientation,
                   XtNproportionLength, &proportion_length, NULL);

  /* set delta value, the value from OlScrollbarVerify is sometimes wrong &
     set new thumb values in window data */
  if(orientation==OL_VERTICAL)
  { delta=scroll_data->new_location - wdata->y0;
    wdata->y0=scroll_data->new_location;
  }
  else
  { delta=scroll_data->new_location - wdata->x0;
    wdata->x0=scroll_data->new_location;
  }
  delta=ABS(delta);

  /* scroll some parts if possible and clear and update the rest */
  if(delta>=proportion_length)
    XClearArea(display,XtWindow(wdata->picture),0,0,wdata->width,wdata->height,
               True);
  else if(orientation==OL_VERTICAL)
  { if(scroll_data->delta<0)
    { 
      XCopyArea(display, XtWindow(wdata->picture), XtWindow(wdata->picture),
                standard_gc, 0, 0, wdata->width, wdata->height-delta,
                0, 0+delta); 
      XClearArea(display, XtWindow(wdata->picture), 0, 0,
                 wdata->width,delta,True);
    }
    else
    { 
      XCopyArea(display, XtWindow(wdata->picture), XtWindow(wdata->picture),
                standard_gc, 0, 0+delta, wdata->width, wdata->height-delta,
                0,0);
      XClearArea(display, XtWindow(wdata->picture), 0, wdata->height-delta,
                 wdata->width,delta,True);
    };
  }
  else
  { if(scroll_data->delta<0)
    { XCopyArea(display, XtWindow(wdata->picture), XtWindow(wdata->picture),
                standard_gc, 0, 0, wdata->width-delta, wdata->height,
                0+delta, 0);
      XClearArea(display, XtWindow(wdata->picture), 0, 0,
                 delta,wdata->height,True);
    }
    else
    { XCopyArea(display, XtWindow(wdata->picture), XtWindow(wdata->picture),
                standard_gc, 0+delta, 0, wdata->width-delta, wdata->height,
                0,0);
      XClearArea(display, XtWindow(wdata->picture), wdata->width-delta,0,
                 delta,wdata->height,True);
    };
  }


  /* We need to sync the Xlib calls because we don't want to miss
     any expose events. 
  */
  XSync(display, False);

#ifdef DEBUG
  fprintf(stderr,"verify_scrollbar\n");
#endif
} 

/* Setting the "thumbs" on different places.
*/
void set_scrollbars(w, x0, y0, hthumb, hscroll, vthumb, vscroll, wreturn, state)
Widget w;
int x0,y0;
int hthumb,hscroll,vthumb,vscroll;
int *state;
Widget *wreturn;
{ WindowData *wdata;
/*  Window win;
    XEvent report;  Halbe: unused */
  void get_first_update(Widget w, Widget *wreturn, int *state);

  XtVaGetValues(w, XtNuserData, &wdata, NULL);
  if(hthumb!=-1)
    XtVaSetValues(wdata->hscrollbar, XtNsliderValue, hthumb, NULL);
  if(vthumb!=-1)
    XtVaSetValues(wdata->vscrollbar, XtNsliderValue, vthumb, NULL);
  if(hscroll!=-1)
    XtVaSetValues(wdata->hscrollbar, XtNgranularity, hscroll, NULL);
  if(vscroll!=-1)
    XtVaSetValues(wdata->vscrollbar, XtNgranularity, vscroll, NULL);

#ifdef DEBUG
  fprintf(stderr,"set scrollbar:%d %d %d %d\n",hthumb, hscroll, vthumb, vscroll);
#endif

  /* Get the first update area */
  get_first_update(w,wreturn,state);
}

/* Get the first rectangle to update if there is one.
*/
void get_first_update(Widget w, Widget *wreturn, int *state)
{ WindowData *wdata;
  Window win;
  XEvent report;

  XtVaGetValues(w,XtNuserData,&wdata,NULL);

  win=XtWindow(wdata->picture);
  XSync(display,False);
  if(XCheckTypedWindowEvent(display,win,Expose,&report) ||
     XCheckTypedWindowEvent(display,win,GraphicsExpose,&report))
  { upd_region=XCreateRegion();
    upd_rect.x=report.xexpose.x;
    upd_rect.y=report.xexpose.y;
    upd_rect.width=report.xexpose.width;
    upd_rect.height=report.xexpose.height;
    XUnionRectWithRegion(&upd_rect,upd_region,upd_region);
    *state=1;
  } else *state=0;

  *wreturn=w;
} 

/* Retrieving the window size (i.e. the visible width and height
   of the picture in the window.
*/
void get_window_size(w, width, height)
Widget w;
int *width;
int *height;
{ WindowData *wdata;
/*  Dimension hscroll_height,vscroll_width;
    Dimension shell_width,shell_height;      Halbe: unused */

  XtVaGetValues(w, XtNuserData, &wdata, NULL);

  *width = wdata->width;
  *height = wdata->height;

}
  
/* Retrieving the current thumb values for a window.
*/
void get_current_thumbs(Widget w, int *hthumb, int *vthumb)
{ WindowData *wdata;
  
  XtVaGetValues(w, XtNuserData, &wdata, NULL);

  *hthumb=wdata->x0;
  *vthumb=wdata->y0;
}

/* Whenever the window is resized we need to resize the proportion
   indicators of the scrollbars. We furthermore might need to adjust
   the "thumb" values.
*/
void stub_resize(Widget widget)
{ WindowData *wdata;
  Dimension w,h;
  int hslidersize,hslidermin,hslidermax,hthumb;
  int vslidersize,vslidermin,vslidermax,vthumb;
  int vscroll,hscroll;

  XtVaGetValues(widget, XtNheight, &h,
                        XtNwidth, &w,
                        XtNuserData, &wdata, NULL);

#ifdef DEBUG
  fprintf(stderr,"stub resize w:%d h:%d\n",(int)w,(int)h);
#endif

  /* adjust thumb values and slidersizes */
  XtVaGetValues(wdata->hscrollbar, XtNsliderMin, &hslidermin,
                                   XtNsliderMax, &hslidermax,
                                   XtNgranularity, &hscroll,
                                   XtNsliderValue, &hthumb, NULL);
  XtVaGetValues(wdata->vscrollbar, XtNsliderMin, &vslidermin,
                                   XtNsliderMax, &vslidermax,
                                   XtNgranularity, &vscroll,
                                   XtNsliderValue, &vthumb, NULL);
 
  hslidersize=(w/hscroll)*hscroll;
  vslidersize=(h/vscroll)*vscroll;
  XtVaSetValues(wdata->hscrollbar, XtNproportionLength,
                                   (w/hscroll)*hscroll, NULL);
  XtVaSetValues(wdata->vscrollbar, XtNproportionLength,
                                   (h/vscroll)*vscroll, NULL);
  if(hthumb > (hslidermax-hslidersize))
   XtVaSetValues(wdata->hscrollbar, XtNsliderValue, hslidermax-hslidersize,
                                    NULL);
  if(vthumb > (vslidermax-vslidersize))
   XtVaSetValues(wdata->vscrollbar, XtNsliderValue, vslidermax-vslidersize,
                                    NULL);

  /* set new window size */
  wdata->width=(int)w;
  wdata->height=(int)h;
}

/* The picture domain of the window is changed and therefore we 
   have to changes sizes, minimumsizes, thumbs or scrollvalues.
*/
Widget change_window(int type, Widget w, 
                     int hthumb, int hscroll, int vthumb, int vscroll,
                     int width, int height, int mwidth, int mheight,
                     int x0, int y0, int x1, int y1)
{ WindowData *wdata;
  Dimension vscroll_width,hscroll_height;

#ifdef DEBUG
  fprintf(stderr,"window changed\n");
  fprintf(stderr,"htumb:%d,hscroll:%d,vthumb:%d,vscroll:%d\n",
                  hthumb,hscroll,vthumb,vscroll);
  fprintf(stderr,"width_min:%d,height_min:%d\n",mwidth,mheight);
  fprintf(stderr,"width_init:%d,height_init:%d",width,height);
#endif

  XtVaGetValues(w, XtNuserData, &wdata, NULL);
  if(type==Scrollable)
  { XtVaGetValues(wdata->hscrollbar, XtNheight, &hscroll_height, NULL);
    XtVaGetValues(wdata->vscrollbar, XtNwidth, &vscroll_width, NULL);

    XtVaSetValues(w,     XtNminWidth, (Dimension)mwidth+vscroll_width+2,
                         XtNminHeight, (Dimension)mheight+hscroll_height+2,
                         XtNmaxWidth, 
                           MINIMUM((Dimension)(x1-x0)+vscroll_width+2,
                              DisplayWidth(display, DefaultScreen(display))-50),
                         XtNmaxHeight, 
                           MINIMUM((Dimension)(y1-y0)+hscroll_height+2,
                              DisplayHeight(display,DefaultScreen(display))-50),
                         XtNwidth, (Dimension)width+vscroll_width+2,
                         XtNheight, (Dimension)height+hscroll_height+2,
                         NULL);
    XtVaSetValues(wdata->hscrollbar, XtNsliderMin, x0,
                                     XtNsliderMax, x1,
                                     XtNsliderValue, hthumb, 
                                     XtNproportionLength,
                                        (width/hscroll)*hscroll,
                                     XtNgranularity, hscroll,
                                     NULL);
    XtVaSetValues(wdata->vscrollbar, XtNsliderMin, y0,
                                     XtNsliderMax, y1,
                                     XtNsliderValue, vthumb,
                                     XtNgranularity, vscroll,
                                     XtNproportionLength,
                                        (height/vscroll)*vscroll,
                                     NULL);
  } else
  { XtVaSetValues(w,     XtNminWidth, (Dimension)width,
                         XtNminHeight, (Dimension)height,
                         XtNmaxWidth, (Dimension)width,
                         XtNmaxHeight, (Dimension)height,
                         XtNwidth, (Dimension)width,
                         XtNheight, (Dimension)height,
                         NULL);
   XtVaSetValues(wdata->picture, XtNwidth, width, XtNheight, height, NULL);
  };

  wdata->width=width;
  wdata->height=height;
  wdata->x0=hthumb;
  wdata->y0=vthumb;

  return w;
}

/* We have to activate this window ->
   i.e. top it. and change the input focus 
*/
Widget activate_window(Widget window)
{ WindowData *wdata;

  XtVaGetValues(window,XtNuserData,&wdata,NULL);

  if(!(wdata->active)) 
  { while(!OlCanAcceptFocus(window,CurrentTime));
    XRaiseWindow(display, XtWindow(window));
    OlCallAcceptFocus(window,CurrentTime);
  };

  return window;
}

/* Changing a window title 
*/
Widget set_window_title(Widget window, CLEAN_STRING title)
{ char *old_title;

  XtVaGetValues(window, XtNtitle, &old_title, NULL);
  XtVaSetValues(window, XtNtitle, cstring(title), NULL);
  XtFree(old_title); 

  return window;
}

/* Check for button still down, i.e. button not released. 
*/
Boolean ButtonStillDown(void)
{
  return (button_down!=ButtonUp);
}

/* Generate ButtonStillDown event.
*/
void ButtonStillDownEvent(void)
{ WindowData *wdata;
  Window d;
  int dd;
  unsigned int keys_buttons;
  void ButtonDialogStillDownEvent(void);

  switch(button_down)
  { case ButtonStillDownWindow:
      XtVaGetValues(my_last_window, XtNuserData, &wdata, NULL);

      if(XQueryPointer(display,XtWindow(my_last_window),&d,&d,
                       &dd,&dd,&dd,&dd,&keys_buttons))
        calc_keystate(keys_buttons,&my_state);

      my_mouse_x = my_local_mouse_x + wdata->x0;
      my_mouse_y = my_local_mouse_y + wdata->y0; 
      my_mouse_event=BUTTONSTILLDOWN;
      global_widget=my_last_window;
      global_device=CLEAN_WINDOW_DEVICE;
      my_window_event=CLEAN_WINDOW_MOUSE;
      break;
    case ButtonStillDownDialog:
      ButtonDialogStillDownEvent();
  };
}

Widget discard_updates(Widget window)
{ WindowData *wdata;
  XEvent report;
  Window w;

  XtVaGetValues(window, XtNuserData, &wdata, NULL);
  w=XtWindow(wdata->picture);

  XSync(display,False);
  while(XCheckTypedWindowEvent(display,w,Expose,&report) ||
        XCheckTypedWindowEvent(display,w,GraphicsExpose,&report));

  return window;
}

Widget popdown(Widget w)
{ XtPopdown(w);
  return w;
}

/* RWS */
int popup (int window)
{
	return (popup_modelessdialog (window));
}
/* */
