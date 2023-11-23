/*

   This module implements support functions for creating and handling
   scrollable and fixed size document windows (the document in fact
   being a picture) in Concurrent Clean Event I/O.

   The interface functions for Clean for this module can be found in
   xwindow.fcl. These functions are used in the Clean modules
   windowDevice and deltaWindow.

   Next to last change, 1.3.1993, Synchronize added when scrolling through
   window contents.

   1992: Leon Pillich
   1994: Sven Panne
*/


typedef int MyBoolean;

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <X11/cursorfont.h>

#include <xview/xview.h>
#include <xview/frame.h>
#include <xview/canvas.h>
#include <xview/defaults.h>
#include <xview/xv_xrect.h>

#include <xview/win_notify.h>

#include <stdio.h>
#include <stdlib.h>

#include "interface.h"
#include "clean_devices.h"
#include "mackeys.h"
#include "windowdata.h"
#include "ckernel.h"
#include "cpicture.h"
#include "cwindow.h"
#include "cdialog.h"
#include "cmenu.h"

#define MAXIMUM(a,b)    (((a) >= (b)) ? (a) : (b))
#define MINIMUM(a,b)    (((a) >= (b)) ? (b) : (a))
#define ABS(a)          ((a > 0) ? (a) : (-(a)))

#define Scrollable 0
#define FixedSize  1

int UserDataKey;

/* mouse state info */
int my_local_mouse_x;
int my_local_mouse_y;
ButtonDownState button_down;
Xv_Window my_last_window;

/* information needed for multiclicks */
static ClickCount click_count;
int double_down_distance;

/* keyboard state info */
static MyBoolean my_key_repeat;

/* update info */
#define MAX_EXPOSE_AREAS 64 /* power of 2 */

static XRectangle expose_areas[MAX_EXPOSE_AREAS];
static int first_expose_area=0,n_expose_areas=0;

static unsigned int n_expose_areas_in_event[MAX_EXPOSE_AREAS];
static int last_expose_areas=0,next_expose_areas=0,n_n_expose_areas=0;

static Xv_xrectlist upd_xrectlist;

/* internally defined functions */
int activate_window(int window);

/* initialize global window data */
void
init_window(void)
{
  my_key_repeat        = FALSE;
  button_down          = ButtonUp;

  click_count          = NoClick;
  double_down_distance = 1;
#ifdef DEBUG
  fprintf(stderr,"init_window: multi click timeout = %d msecs\n", multi_click_time);
#endif

  UserDataKey = xv_unique_key();
}

/* Called from paint_window_event_proc when ACTION_DISMISSED occured */
static void
close_window(Xv_Window window)
{
#ifdef DEBUG
  fprintf(stderr, " .... window 0x%X close.\n", (int)window);
#endif

  set_global_event(CLEAN_WINDOW_DEVICE, (int)window, CLEAN_WINDOW_CLOSED, 0, 0, 0, 0, 0);
}

/* Set distance mouse can be moved during double click.  */
int
set_dd_distance(int distance)
{
  double_down_distance = (distance < 0) ? 0 : distance;
  return distance;
}

/* Called from paint_window_event_proc when a keyboard event occured.
   We are interested both in KeyPress and KeyRelease events.
   NOTE: This routine is called with all kinds of X events, so we must test for these here.
*/
static void
handle_keyboard_events(Xv_Window window, XEvent *event)
{
  WindowData *wdata;
  char buffer[16];
  KeySym keysym;
  XComposeStatus compose;
  int event_type;
  int my_key;

  event_type = event->type;

  /* if there is a menu shortcut associated with this key, just return. */
  if ((event_type == KeyPress) && (handle_shortcut((XKeyEvent *)event) != 0))
    return;

  if ((event_type == KeyPress) || (event_type == KeyRelease)) {

    XLookupString((XKeyEvent *)event, buffer, sizeof(buffer), &keysym, &compose);

    /* check all keypresses */
    if ((keysym >= XK_Shift_L) && (keysym <= XK_Hyper_R)) {
      /* do nothing this is just a modifier key */
    } else {
      if (((keysym >= XK_space   ) && (keysym <= XK_asciitilde)) ||
          ((keysym >= XK_KP_Space) && (keysym <= XK_KP_9))) {
        my_key = buffer[0];
      } else {
        switch(keysym) {
        case XK_BackSpace: my_key = MacBackSp; break;
        case XK_Tab:       my_key = MacTab;    break;
        case XK_Return:    my_key = MacReturn; break;
        case XK_Escape:    my_key = MacEscape; break;
        case XK_Delete:    my_key = MacDel /* MacBackSp */; break; /* why ? */
        case XK_Left:      my_key = MacLeft;   break;
        case XK_Up:        my_key = MacUp;     break;
        case XK_Right:     my_key = MacRight;  break;
        case XK_Down:      my_key = MacDown;   break;
        case XK_Prior:     my_key = MacPgUp;   break;
        case XK_Next:      my_key = MacPgDown; break;
        case XK_Begin:     my_key = MacBegin;  break;
        case XK_End:       my_key = MacEnd;    break;
        case XK_Linefeed:  my_key = MacReturn; break;
        case XK_Help:      my_key = MacHelp;   break;
        default:           return;
        }
      }
      wdata = (WindowData *)xv_get(window, XV_KEY_DATA, UserDataKey);
      set_global_event(CLEAN_WINDOW_DEVICE, (int)(wdata->frame),
                       CLEAN_WINDOW_KEYBOARD, my_key,
                       event_type, 0, 0, (event->xkey).state);
#ifdef DEBUG
      fprintf(stderr, "%s event on window 0x%X, frame 0x%X, char <%c>\n",
              (event_type == KeyPress) ? "KeyPress" : "KeyRelease",
              (int)window, (int)(wdata->frame),
              ((my_key >= ' ') && (my_key <= '~')) ? my_key : ' ');
#endif
    }
  }
}

/* Called from paint_window_event_proc when a focus change event occured,
   which in terms of Clean Event IO events means activation/decativation events.
   We are only interested in Nonlinear notify events, don't ask me why.
*/
static void
handle_focus_events(Xv_Window window, XEvent *event)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);

/* RWS
	if ((wdata->active && event->type == FocusIn) || (!wdata->active && event->type == FocusOut))
	  fprintf (stderr, "Focus no effect\n");
	else
	  fprintf (stderr, "Focus with effect\n");
*/
  switch (event->type) {
  case FocusIn:
    if (((event->xfocus).detail) == NotifyNonlinear) {
      /* this window has been activated */
      if (wdata->active == False) {
        set_global_event(CLEAN_WINDOW_DEVICE, (int)(wdata->frame), CLEAN_WINDOW_ACTIVATE, 0,
                         0, 0, 0, 0);
        wdata->active    = True;
      }
    }
    break;
  case FocusOut:
    if (((event->xfocus).detail) == NotifyNonlinear) {
      /* this window has been deactivated */
    if (wdata->active == True) {
        set_global_event(CLEAN_WINDOW_DEVICE, (int)(wdata->frame), CLEAN_WINDOW_DEACTIVATE, 0,
                         0, 0, 0, 0);
        wdata->active    = False;
      }
    }
    break;
  }

#ifdef DEBUG
  fprintf(stderr, "Focus i/o event on window 0x%X, frame 0x%X, ",
          (int)window, (int)(wdata->frame));
  switch (event->type) {
  case FocusIn:  fprintf(stderr, "FocusIn");  break;
  case FocusOut: fprintf(stderr, "FocusOut"); break;
  }
  fprintf(stderr," detail %d %s\n",
          (event->xfocus).detail,
          (((event->xfocus).detail) == NotifyNonlinear) ? "(NotifyNonlinear)" : "");
#endif
}


/* Called from paint_window_event_proc when a mouse event occured. We are
   interested in ButtonPress, ButtonRelease and MotionNotify events.
*/
static void
handle_mouse_events(Xv_Window window, XEvent *event)
{
  static Time time_of_last_click;
  static int last_click_x, last_click_y;
  WindowData *wdata;
  Frame frame;
  int x, y;
  Time time;
  int my_mouse_event;

  my_mouse_event = BUTTONDOWN; /* to avoid warning about uninitialized variable */
  wdata = (WindowData *)xv_get(window, XV_KEY_DATA, UserDataKey);
  frame = wdata->frame;

  switch (event->type) {
    /* mouse events */
  case ButtonPress:
    time = (event->xbutton).time;
    my_local_mouse_x = x = (event->xbutton).x;
    my_local_mouse_y = y = (event->xbutton).y;

    /* check for multiclicks */
    switch (click_count) {
    case NoClick:
      my_mouse_event = BUTTONDOWN;
      last_click_x   = x;
      last_click_y   = y;
      click_count    = OneClick;
      break;
    case OneClick:
      if ((time - time_of_last_click <= multi_click_time) &&
          (abs(x - last_click_x) <= double_down_distance) &&
          (abs(y - last_click_y) <= double_down_distance)) {
        my_mouse_event = DOUBLECLICK;
        click_count    = TwoClicks;
      } else {
        my_mouse_event = BUTTONDOWN;
        last_click_x   = x;
        last_click_y   = y;
        click_count    = OneClick;
      }
      break;
    case TwoClicks:
      if ((time - time_of_last_click <= multi_click_time) &&
          (abs(x - last_click_x) <= double_down_distance) &&
          (abs(y - last_click_y) <= double_down_distance)) {
        my_mouse_event = TRIPLECLICK;
        click_count    = NoClick;
      } else {
        my_mouse_event = BUTTONDOWN;
        last_click_x   = x;
        last_click_y   = y;
        click_count    = OneClick;
      }
    }
    button_down = ButtonStillDownWindow;
    my_last_window = frame;
    time_of_last_click = time;

/* RWS, activate window before sending mouse event to Clean */
    activate_window((int)frame);


    set_global_event(CLEAN_WINDOW_DEVICE, (int)frame, CLEAN_WINDOW_MOUSE, 0,
                     my_mouse_event,
			x + wdata->x0,
			y + wdata->y0,
                     (event->xbutton).state);
/* RWS, window now activated before mouse event */
/*    activate_window((int)frame); */
/* */
    break;

  case ButtonRelease:
    button_down = ButtonUp;
    my_last_window  = frame;
    set_global_event(CLEAN_WINDOW_DEVICE, (int)frame, CLEAN_WINDOW_MOUSE, 0,
                     BUTTONUP,
			(event->xbutton).x + wdata->x0,
			     (event->xbutton).y + wdata->y0,
			(event->xbutton).state);
    break;

  case MotionNotify:
    if (button_down == ButtonStillDownWindow) {
      my_local_mouse_x = (event->xmotion).x;
      my_local_mouse_y = (event->xmotion).y;
      set_global_event(CLEAN_WINDOW_DEVICE, frame, CLEAN_WINDOW_MOUSE, 0,
                       BUTTONSTILLDOWN, my_local_mouse_x + wdata->x0,
                       my_local_mouse_y + wdata->y0,
				(event->xmotion).state);
      my_last_window   = frame;
    }
    break;
  }

#ifdef DEBUG
  fprintf(stderr,"Mouse event catched on window 0x%X, frame 0x%X, type %d, time %d\n",
          (int)window, (int)frame, event->type, (event->xbutton).time);

#endif
}


/* the main event dispatcher for a frame
*/
static void
frame_event_proc(Xv_Window window, Event *event, Notify_arg arg)
{
  switch (event_action(event)) {

  case WIN_RESIZE:
    {
      XConfigureEvent conf_event = (event_xevent(event))->xconfigure;
      WindowData *wdata          = (WindowData *)xv_get(window, XV_KEY_DATA, UserDataKey);
      wdata->width  = conf_event.width  - wdata->both_pixels;
      wdata->height = conf_event.height - wdata->both_pixels;
#ifdef DEBUG
      fprintf(stderr, "Resized frame 0x%X to width %d, height %d\n",
              (int)window, wdata->width, wdata->height);
#endif
    }
    break;

  case ACTION_DISMISS:
    close_window(window);
#ifdef DEBUG
    fprintf(stderr, "Frame 0x%X dismissed\n", (int)window);
#endif
    break;

  default:
#ifdef DEBUG
    fprintf(stderr, "Frame 0x%X, event %d, action %d\n",
            (int)window, event_id(event), event_action(event));
#endif
    break;
  }
}


/* the main event dispatcher for a canvas window
*/
static void
paint_window_event_proc(Xv_Window window, Event *event, Notify_arg arg)
{
#ifdef DEBUG
  fprintf(stderr, "Paint Window 0x%X, event %d, action %d\n",
          (int)window, event_id(event), event_action(event));
#endif
	{
		WindowData *wdata;

		  wdata	= (WindowData *)xv_get(window, XV_KEY_DATA, UserDataKey);
	}

  /* Even if there is a semantic action associated with a key, we like to know about it!
     NOTE: This may cause multiple events within a single call of notify_start.
            This case is already handled in ckernel.c */
  handle_keyboard_events(window, event_xevent(event));
  switch (event_action(event)) {

  case ACTION_DISMISS:
    close_window(window);
    break;

  case KBD_USE:
  case KBD_DONE:
    handle_focus_events(window, event_xevent(event));
    break;

  case ACTION_MENU:
    /* It maybe a menu popup? */
    if (event_is_down(event)) {
      activate_window(window);
      if (MenuPresent) {
        menu_show(global_popup, window, event, NULL);
      }
    } else {
      handle_mouse_events(window, event_xevent(event));
    }
    break;

  case ACTION_ADJUST:
  case ACTION_SELECT:
  case LOC_MOVE:
  case LOC_DRAG:
    handle_mouse_events(window, event_xevent(event));
    break;

  default:
    break;
  }
}


/* When a window is being destroyed, several things have to be cleaned up. */
static Notify_value
destroy_window(Notify_client client, Destroy_status status)
{
#ifdef DEBUG
  fprintf(stderr, "destroying window 0x%X, status %d\n", (int)client, (int)status);
#endif

  switch (status) {
  case DESTROY_CLEANUP:
    FreePictureData((WindowData *)xv_get(client, XV_KEY_DATA, UserDataKey));
    notify_next_destroy_func(client, status);
    break;
  case DESTROY_SAVE_YOURSELF:
  case DESTROY_PROCESS_DEATH:
  case DESTROY_CHECKING:
    break;
  }
    return NOTIFY_DONE;
}

/* This function handles repainting of a canvas. For every sequence of
   exposures this function is called only once. After this, the subsequent
   exposures are collected with get_expose_area().
*/
static void canvas_repaint_proc (Canvas canvas, Xv_Window paint_window, Display *dpy,
                			     Window xwin, Xv_xrectlist *area)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get(canvas, XV_KEY_DATA, UserDataKey);

#ifdef DEBUG
  fprintf(stderr,"Repainting canvas 0x%X, paint window 0x%X, frame 0x%X, %d rects\n",
          (int)canvas, (int)paint_window, (int)(wdata->frame), area->count);
#endif

	if (n_n_expose_areas<MAX_EXPOSE_AREAS){
		int ln;

		ln=last_expose_areas;
		last_expose_areas=(ln+1) & (MAX_EXPOSE_AREAS-1);
		++n_n_expose_areas;
  	
		set_global_event (CLEAN_WINDOW_DEVICE,(int)(wdata->frame),CLEAN_WINDOW_UPDATE,ln,0,0,0,0);
		
		n_expose_areas_in_event[ln]=0;

		if (area!=NULL){
			int i,n_areas;
	
			n_areas=area->count;

			for (i=0; i<n_areas; ++i){
				if (n_expose_areas<MAX_EXPOSE_AREAS){
					int l;

					l=(first_expose_area+n_expose_areas) & (MAX_EXPOSE_AREAS-1);
					++n_expose_areas;

					expose_areas[l]=area->rect_array[i];
					++n_expose_areas_in_event[ln];
				}
			}
		}
	}
}

static int next_rectangle_id=0;

/* Handling the expose events means setting the right clipping area in
   the windows gc (my_gc for the moment).
*/
void get_expose_area (int frame, int *x, int *y, int *xx, int *yy, int *more)
{
  XRectangle *rect_p,dummyRect;
  WindowData *wdata;

	while (next_rectangle_id!=next_expose_areas && n_n_expose_areas!=0){
		int n;

		n=n_expose_areas_in_event[next_expose_areas];
		first_expose_area=(first_expose_area+n) & (MAX_EXPOSE_AREAS-1);
		n_expose_areas-=n;

		--n_n_expose_areas;
		next_expose_areas=(next_expose_areas+1) & (MAX_EXPOSE_AREAS-1);
	}

  if (n_n_expose_areas!=0){
	if (n_expose_areas_in_event[next_expose_areas]==0){
    	rect_p = &dummyRect;
    	rect_p->x = rect_p->y = rect_p->width = rect_p->height = 0;
		*more=0;
		--n_n_expose_areas;
		next_expose_areas=(next_expose_areas+1) & (MAX_EXPOSE_AREAS-1);
	} else {
		int l;

		l=first_expose_area;
		first_expose_area=(l+1) & (MAX_EXPOSE_AREAS-1);
		--n_expose_areas;

   		rect_p = &expose_areas[l];

		if (upd_xrectlist.count<XV_MAX_XRECTS)
			upd_xrectlist.rect_array[upd_xrectlist.count++]=*rect_p;

		if (upd_xrectlist.count<n_expose_areas_in_event[next_expose_areas])
			*more=2;
		else {
			--n_n_expose_areas;
			next_expose_areas=(next_expose_areas+1) & (MAX_EXPOSE_AREAS-1);
			*more=1;
		}
	}
  } else {
	/* This should not happen
	fprintf (stderr, "get_exposed_area: it happened!\n");
	exit (1);
	*/ 

	n_expose_areas=0;
	
    rect_p = &dummyRect;
    rect_p->x = rect_p->y = rect_p->width = rect_p->height = 0;
	*more = 0;
  }

  wdata  = (WindowData *)xv_get((Frame)frame, XV_KEY_DATA, UserDataKey);

  *x     = rect_p->x + wdata->x0;
  *y     = rect_p->y + wdata->y0;
  *xx    = rect_p->width + *x;
  *yy    = rect_p->height + *y;

#ifdef DEBUG
  fprintf(stderr, "Get expose area on window 0x%X: (%d %d) (%d %d), more=%d\n",
          (int)frame, *x, *y, *xx, *yy, *more);
#endif
}

/* Get the first rectangle to update if there is one.  */
void get_first_update (int w, int *wreturn, int *state)
{
  WindowData *wdata;
  Window xwin;
  XEvent report;

  wdata    = (WindowData *)xv_get((Xv_Window)w, XV_KEY_DATA, UserDataKey);
  xwin     = (Window)xv_get(wdata->picture, XV_XID);
 
  XSync(display, False);

  if (XCheckTypedWindowEvent (display, xwin, Expose, &report) ||
      XCheckTypedWindowEvent (display, xwin, GraphicsExpose, &report))
  {
/* RWS
	This doesn't work during scrolling, because the update must
	be handled immediately and not in canvas_repaint_proc

    XPutBackEvent(display, &report);   \* expose events are collapsed by xview *\
*/

	if (n_n_expose_areas<MAX_EXPOSE_AREAS){
		int ln;

		ln=last_expose_areas;
		last_expose_areas=(ln+1) & (MAX_EXPOSE_AREAS-1);
		++n_n_expose_areas;
  	
		n_expose_areas_in_event[ln]=0;
		next_rectangle_id=ln;

		if (n_expose_areas<MAX_EXPOSE_AREAS){
			int l;
			XRectangle *rect_p;

			l=(first_expose_area+n_expose_areas) & (MAX_EXPOSE_AREAS-1);
			++n_expose_areas;

			rect_p=&expose_areas[l];
		    rect_p->x=report.xexpose.x;
    		rect_p->y=report.xexpose.y;
   			rect_p->width=report.xexpose.width;
    		rect_p->height=report.xexpose.height;

			++n_expose_areas_in_event[ln];
		}
    	*state = 1;
	} else
		*state = 0;
  } else {
    *state = 0;
  }
  
  *wreturn = (int)(wdata->frame);

#ifdef DEBUG
  fprintf(stderr, "Get first update: window 0x%X, state %d\n", *wreturn, *state);
#endif
}

/* This function is used to prevent a single window from eating up backing store
   on the X Server.  The values are all a little bit arbitrary... :-] */
static int
should_retain(int width, int height)
{
  return ((width > 10000) || (height > 10000) || ((width * height) > 500000)) ? FALSE : TRUE;
}


/* Create a window with all parameters set according to the Clean specification.
   The parent of the new window is toplevel. Let the picture domain be
   ((px0, py0), (px1, py1)). The parameters have the following meaning:

      type                    : Scrollable or FixedSize
      x, y                    : initial position of window on root window
                                (only a hint for the window manager)
      x0, y0                  : upper left coordinates of picture domain (= (px0, py0))
      name                    : window title
      hthumb                  : initial position of the horizontal scrollbar (px0 is left)
      hscroll                 : horizontal scrolling step
      vthumb                  : initial position of the vertical scrollbar (py0 is top)
      vscroll                 : vertical scrolling step
      width, height           : size of the picture domain (= px1-px0, py1-py0)
      width_min, height_min   : minimum size of the viewable part of the picture domain
                                (0, 0 means no minimum size)
      width_init, height_init : initial size of the viewable part of the picture domain
      work                    : return paint window handle
      window                  : returns frame window handle
*/
void
create_window(int type, int x, int y, int x0, int y0, CLEAN_STRING name,
              int hthumb, int hscroll, int vthumb, int vscroll,
              int width, int height, int width_min, int height_min,
              int width_init, int height_init, int *work, int *window)
{
  char *tmp_name;
  Frame frame;
  Canvas canvas;
  Xv_Window paint_window;
  WindowData *wdata;
  Scrollbar scroll_vert, scroll_hor;
  int border_pixels, scrollbar_pixels, both_pixels;

#ifdef DEBUG
  fprintf(stderr, "Creating Window:\n");
  fprintf(stderr, "   x:%d,  y:%d,  x0:%d,  y0:%d\n", x, y, x0, y0);
  fprintf(stderr, "   hthumb:%d, hscroll:%d, vthumb:%d, vscroll:%d\n",
          hthumb, hscroll, vthumb, vscroll);
  fprintf(stderr, "   width:%d, height:%d\n", width, height);
  fprintf(stderr, "   width_min:%d, height_min:%d\n",width_min, height_min);
  fprintf(stderr, "   width_init:%d, height_init:%d\n",width_init, height_init);
#endif

  /* Sven: The following is only correct for standard sizes... */
  border_pixels    = 2;
  scrollbar_pixels = (type == FixedSize) ? 0 : 19;
  both_pixels      = border_pixels + scrollbar_pixels;


#ifdef DEBUG
  fprintf(stderr, "Going to create frame...");
#endif

  tmp_name = cstring(name);

  frame = (Frame)xv_create(toplevel, FRAME,
                           XV_X,                     x,
                           XV_Y,                     y,
                           FRAME_LABEL,              tmp_name, /* XView copies contents! */
                           FRAME_SHOW_RESIZE_CORNER, (type == FixedSize) ? FALSE : TRUE,
                           FRAME_MIN_SIZE,           width_min  + both_pixels,
                                                     height_min + both_pixels,
                           FRAME_MAX_SIZE,           width      + both_pixels,
                                                     height     + both_pixels,
                           WIN_EVENT_PROC,           frame_event_proc,
                           NULL);
  my_free(tmp_name);

#ifdef DEBUG
  fprintf(stderr, "Frame 0x%X created\nGoing to create canvas...", (int)frame);
#endif

    canvas = (Canvas)xv_create(frame, CANVAS,
                               CANVAS_RETAINED,        should_retain(width, height),
                               CANVAS_AUTO_SHRINK,     FALSE,
                               CANVAS_AUTO_EXPAND,     FALSE,
                               CANVAS_WIDTH,           width,
                               CANVAS_HEIGHT,          height,
                               XV_WIDTH,               width_init  + both_pixels,
                               XV_HEIGHT,              height_init + both_pixels,
                               CANVAS_X_PAINT_WINDOW,  TRUE,
                               WIN_COLLAPSE_EXPOSURES, TRUE,
                               CANVAS_REPAINT_PROC,    canvas_repaint_proc,
                               NULL);
#ifdef DEBUG
    fprintf(stderr, "Canvas 0x%X created\n", (int)canvas);
#endif

    paint_window = (Xv_Window)xv_get(canvas, CANVAS_NTH_PAINT_WINDOW, 0);
    xv_set(paint_window,
           WIN_EVENT_PROC,     paint_window_event_proc,
           WIN_CONSUME_EVENTS, WIN_ASCII_EVENTS, KBD_USE, KBD_DONE, LOC_DRAG,
                               WIN_MOUSE_BUTTONS, ACTION_DISMISS,
                               NULL,
           NULL);

  if (type == FixedSize) {

    scroll_vert = scroll_hor  = (Scrollbar)0;

  } else {

#ifdef DEBUG
    fprintf(stderr, "Going to create scrollbars...");
#endif
    scroll_hor  = (Scrollbar)xv_create(canvas, SCROLLBAR,
                                       SCROLLBAR_DIRECTION,       SCROLLBAR_HORIZONTAL,
                                       SCROLLBAR_SPLITTABLE,      FALSE,
                                       SCROLLBAR_PIXELS_PER_UNIT, hscroll,
                                       SCROLLBAR_OBJECT_LENGTH,   (width         / hscroll),
                                       SCROLLBAR_VIEW_LENGTH,     (width_init    / hscroll),
                                       SCROLLBAR_VIEW_START,      0, /* RWS ((hthumb - x0) / hscroll), */
                                       NULL);
    scroll_vert = (Scrollbar)xv_create(canvas, SCROLLBAR,
                                       SCROLLBAR_DIRECTION,       SCROLLBAR_VERTICAL,
                                       SCROLLBAR_SPLITTABLE,      FALSE,
                                       SCROLLBAR_PIXELS_PER_UNIT, vscroll,
                                       SCROLLBAR_OBJECT_LENGTH,   (height        / vscroll),
                                       SCROLLBAR_VIEW_LENGTH,     (height_init   / vscroll),
                                       SCROLLBAR_VIEW_START,      0, /* RWS ((vthumb - y0) / vscroll), */
                                       NULL);
#ifdef DEBUG
    fprintf(stderr, "Scrollbars (vert = 0x%X, hor = 0x%X) created\n",
            (int)scroll_vert, (int)scroll_hor);
    fprintf(stderr, "            vert %d, %d    hor %d, %d\n",
            (int)xv_get(scroll_vert, XV_WIDTH), (int)xv_get(scroll_vert, XV_HEIGHT),
            (int)xv_get(scroll_hor , XV_WIDTH), (int)xv_get(scroll_hor, XV_HEIGHT));
#endif
  }

  /* set up return values */
  *work   = (int)paint_window;
  *window = (int)frame;

  /* set the correct minimum and maximum sizes
     (6 and 7 are additional borderwidths) and windowdata     */

  wdata = (WindowData *)my_malloc(sizeof(WindowData));

  wdata->frame       = frame;
  wdata->canvas      = canvas;
  wdata->hscrollbar  = scroll_hor;
  wdata->vscrollbar  = scroll_vert;
  wdata->picture     = paint_window;
  wdata->height      = height_init;
  wdata->width       = width_init;
  wdata->both_pixels = both_pixels;
  wdata->x0          = x0;
  wdata->y0          = y0;
  wdata->window_gc   = make_new_gc();
  wdata->curx        = x0;
  wdata->cury        = y0;
  wdata->pen         = 0;
  wdata->active      = False;

  set_default_font(wdata);

  xv_set(frame,         XV_KEY_DATA, UserDataKey, wdata, NULL);
  xv_set(canvas,        XV_KEY_DATA, UserDataKey, wdata, NULL);
  xv_set(paint_window,  XV_KEY_DATA, UserDataKey, wdata, NULL);
  notify_interpose_destroy_func(frame, destroy_window);
  window_fit(frame);

/* RWS: bug in xv?
	When SCROLLBAR_VIEW_START is set at creation of a scrollbar the
	origin of the picture with respect to its canvas is not changed.
	That's why we change it here.
*/
  if (scroll_hor != NULL)
    xv_set(scroll_hor, SCROLLBAR_VIEW_START, (hthumb-x0) / hscroll, NULL);
  if (scroll_vert != NULL)
    xv_set(scroll_vert, SCROLLBAR_VIEW_START, (vthumb-y0) / vscroll, NULL);
/* */

#ifdef DEBUG
  fprintf(stderr, "Window created\n");
#endif
}

/* Getting the special window event specification.  */
int
get_window_event (int dummy)
{
#ifdef DEBUG
  fprintf(stderr, "my_window_event fetched:%d\n", last_event);
#endif

	next_rectangle_id=last_sub_widget;

  return last_event;
}

/* Getting mouse event information after a mouse event has occurred.  */
void
get_mouse_state(int dummy, int *x, int *y, int *e, int *shift, int *option,
                int *command, int *control)
{
  *x       = last_mouse_x;
  *y       = last_mouse_y;
  *e       = last_mouse_event;
  *shift   = (last_key_state & ShiftMask)   ? 1 : 0;
  *option  = (last_key_state & Mod1Mask)    ? 1 : 0;
  *command = *control = (last_key_state & ControlMask) ? 1 : 0;

#ifdef DEBUG
  fprintf(stderr,"get_mouse_state: coord. (%d, %d), event %d, Modifiers (%d,%d,%d,%d)\n",
          *x, *y, *e, *shift, *option, *command, *control);
#endif
}

/* Starting an update action -> set clipping mask to region.  */
int start_update (int window)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);

  if (upd_xrectlist.count==0)
     XSetClipMask (display, wdata->window_gc, None);
  else
    XSetClipRectangles (display, wdata->window_gc, 0, 0, upd_xrectlist.rect_array,
                        upd_xrectlist.count, Unsorted);

	upd_xrectlist.count=0;

#ifdef DEBUG
  fprintf(stderr, "Starting update for window 0x%X...\n", window);
#endif

  return window;
}

/* Ending updating a region -> reset clipping mask.
*/
int
end_update(int window)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);
  XSetClipMask(display, wdata->window_gc, None);
  XFlush(display);  /* make sure the user sees everything immediately */
#ifdef DEBUG
  fprintf(stderr, "Ending update for window 0x%X...\n", window);
#endif

  return window;
}


/* Getting keyboard event information after such an event did occur.
*/
void
get_key_state(int dummy, int *key, int *shift, int *option,
              int *command, int *control, int *event_type)
{
  *key = last_sub_widget;
  if (last_mouse_event == KeyPress) {
    if (my_key_repeat)
      *event_type   = KEYSTILLDOWN;
    else {
      my_key_repeat = TRUE;
      *event_type   = KEYDOWN;
    }
  } else {
    my_key_repeat   = FALSE;
    *event_type     = KEYUP;
  }
  *shift   =            (last_key_state & ShiftMask)   ? 1 : 0;
  *option  =            (last_key_state & Mod1Mask)    ? 1 : 0;
  *command = *control = (last_key_state & ControlMask) ? 1 : 0;

#ifdef DEBUG
  fprintf(stderr, "get_key_state: key %d, event type %d, Modifiers (%d,%d,%d,%d)\n",
          *key, *event_type, *shift, *option, *command, *control);
#endif
}


/* Setting the cursor to some predefined shape,
   keeping in mind the own OpenLook cursor specification.
*/
int
set_window_cursor(int clean_cursor, int window)
{
  Cursor cursor;
  WindowData *wdata;
  Window win;
  Display *dpy;

  wdata = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);
  win   = (Window)xv_get(wdata->picture, XV_XID);
  dpy   = (Display *)xv_get(wdata->picture, XV_DISPLAY);

  switch(clean_cursor) {
  case STANDARDCURSOR:
    cursor = XCreateFontCursor(dpy, XC_top_left_arrow);
    break;
  case BUSYCURSOR:
    cursor = XCreateFontCursor(dpy, XC_watch);
    break;
  case IBEAMCURSOR:
    cursor = XCreateFontCursor(dpy, XC_xterm);
      break;
  case CROSSCURSOR:
    cursor = XCreateFontCursor(dpy, XC_crosshair);
    break;
  case FATCROSSCURSOR:
    cursor = XCreateFontCursor(dpy, XC_cross);
    break;
  case ARROWCURSOR:
    cursor = XCreateFontCursor(dpy, XC_arrow);
    break;
  default:
    cursor = XCreateFontCursor(dpy, XC_top_left_arrow);
  }
  XDefineCursor(dpy, win, cursor);

#ifdef DEBUG
  fprintf(stderr,"Cursor set: 0x%X for window 0x%X\n", clean_cursor, window);
#endif

  return window;
}


/* Getting the size of the entire display.
*/
void
get_screen_size(int dummy, int *width, int *height)
{
  *width  = (int)DisplayWidth (display, DefaultScreen(display));
  *height = (int)DisplayHeight(display, DefaultScreen(display));
}


/* Setting the "thumbs" on different places.
*/
void
set_scrollbars(int w, int x0, int y0, int hthumb, int hscroll,
               int vthumb, int vscroll, int *wreturn, int *state)
{
  WindowData *wdata;
  int unit;

  wdata = (WindowData *)xv_get((Xv_Window)w, XV_KEY_DATA, UserDataKey);
  if (hthumb != -1) {
    unit = (int)xv_get(wdata->hscrollbar, SCROLLBAR_PIXELS_PER_UNIT);
/* RWS
    xv_set(wdata->hscrollbar, SCROLLBAR_VIEW_START, (hthumb / unit), NULL);
*/
    xv_set(wdata->hscrollbar, SCROLLBAR_VIEW_START, (hthumb-x0) / unit, NULL);
  }

  if (vthumb != -1) {
    unit = (int)xv_get(wdata->vscrollbar, SCROLLBAR_PIXELS_PER_UNIT);
/* RWS
    xv_set(wdata->vscrollbar, SCROLLBAR_VIEW_START, (vthumb / unit), NULL);
*/
    xv_set(wdata->vscrollbar, SCROLLBAR_VIEW_START, (vthumb-y0) / unit, NULL);
  }

  if (hscroll != -1) {
    xv_set(wdata->hscrollbar, SCROLLBAR_PIXELS_PER_UNIT, hscroll, NULL);
  }

  if (vscroll != -1) {
    xv_set(wdata->vscrollbar, SCROLLBAR_PIXELS_PER_UNIT, vscroll, NULL);
  }

#ifdef DEBUG
  fprintf(stderr,"set scrollbar for window 0x%X: %d %d %d %d\n",
          (int)w, hthumb, hscroll, vthumb, vscroll);
#endif

  get_first_update(w, wreturn, state);
}


/* Retrieving the window size (i.e. the visible width and height
   of the picture in the window.
*/
void
get_window_size(int w, int *width, int *height)
{
  WindowData *wdata;

  wdata   = (WindowData *)xv_get((Xv_Window)w, XV_KEY_DATA, UserDataKey);
  *width  = wdata->width;
  *height = wdata->height;
}

/* JVG */

void get_window_position (int w,int *x_p,int *y_p)
{
	*x_p=(int)xv_get (toplevel,XV_X) + (int)xv_get (w,XV_X);
	*y_p=(int)xv_get (toplevel,XV_Y) + (int)xv_get (w,XV_Y);
}

/* Retrieving the current thumb values for a window.
*/
void
get_current_thumbs(int w, int *hthumb, int *vthumb)
{
  WindowData *wdata;
  Scrollbar hor, vert;

  wdata   = (WindowData *)xv_get((Xv_Window)w, XV_KEY_DATA, UserDataKey);
  hor     = wdata->hscrollbar;
  vert    = wdata->vscrollbar;

#ifdef DEBUG
  fprintf(stderr,"get_current_thumbs for window 0x%X, hor: %d,  vert: %d\n",
          w, wdata->hscrollbar, wdata->vscrollbar);
#endif

  *hthumb = wdata->x0 + ((hor == (Scrollbar)0) ?
                         0 :
                         ((int)xv_get(hor, SCROLLBAR_VIEW_START) *
                          (int)xv_get(hor, SCROLLBAR_PIXELS_PER_UNIT)));

  *vthumb = wdata->y0 + ((vert == (Scrollbar)0) ?
                         0 :
                         ((int)xv_get(vert, SCROLLBAR_VIEW_START) *
                          (int)xv_get(vert, SCROLLBAR_PIXELS_PER_UNIT)));
}


/* The picture domain of the window is changed and therefore we
   have to changes sizes, minimumsizes, thumbs or scrollvalues.
*/
int
change_window(int type, int window,
              int hthumb, int hscroll, int vthumb, int vscroll,
              int width_init, int height_init, int width_min, int height_min,
              int x0, int y0, int x1, int y1)
{
  WindowData *wdata;
  int width, height, border_pixels, scrollbar_pixels, both_pixels, screen_no;

#ifdef DEBUG
  fprintf(stderr,"Changing window 0x%X\n", window);
  fprintf(stderr,"   htumb:%d, hscroll:%d, vthumb:%d, vscroll:%d\n",
          hthumb, hscroll, vthumb, vscroll);
  fprintf(stderr,"   width_min:%d, height_min:%d\n", width_min, height_min);
  fprintf(stderr,"   width_init:%d, height_init:%d\n", width_init, height_init);
  fprintf(stderr,"   New picture domain x0:%d, y0:%d, x1:%d, y1:%d\n", x0, y0, x1, y1);
#endif

  wdata  = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);

  width  = x1 - x0;
  height = y1 - y0;

  /* Sven: The following is only correct for standard sizes... */
  border_pixels    = 2;
  scrollbar_pixels = (type == FixedSize) ? 0 : 19;
  both_pixels      = border_pixels + scrollbar_pixels;

  screen_no = (int)xv_get((Xv_Screen)xv_get(toplevel, XV_SCREEN), SCREEN_NUMBER);

  xv_set(wdata->frame,
         FRAME_SHOW_RESIZE_CORNER, (type == FixedSize) ? FALSE : TRUE,
         FRAME_MIN_SIZE, width_min  + both_pixels,
                         height_min + both_pixels,
         FRAME_MAX_SIZE, MINIMUM((width + both_pixels),
                                 (DisplayWidth (display, screen_no) - 50)),
                         MINIMUM((height + both_pixels),
                                 (DisplayHeight(display, screen_no) - 50)),
         NULL);

  xv_set(wdata->canvas,
         CANVAS_RETAINED, should_retain(width, height),
         CANVAS_WIDTH,    width,
         CANVAS_HEIGHT,   height,
         XV_WIDTH,        width_init  + both_pixels,
         XV_HEIGHT,       height_init + both_pixels,
         NULL);

  if (type == Scrollable) {

    if (wdata->hscrollbar == (Scrollbar)0) {

      wdata->hscrollbar  =
        (Scrollbar)xv_create(wdata->canvas, SCROLLBAR,
                             SCROLLBAR_DIRECTION,       SCROLLBAR_HORIZONTAL,
                             SCROLLBAR_SPLITTABLE,      FALSE,
                             SCROLLBAR_PIXELS_PER_UNIT, hscroll,
                             SCROLLBAR_OBJECT_LENGTH,   (width         / hscroll),
                             SCROLLBAR_VIEW_LENGTH,     (width_init    / hscroll),
                             SCROLLBAR_VIEW_START,      ((hthumb - x0) / hscroll),
                             NULL);
      wdata->vscrollbar =
        (Scrollbar)xv_create(wdata->canvas, SCROLLBAR,
                             SCROLLBAR_DIRECTION,       SCROLLBAR_VERTICAL,
                             SCROLLBAR_SPLITTABLE,      FALSE,
                             SCROLLBAR_PIXELS_PER_UNIT, vscroll,
                             SCROLLBAR_OBJECT_LENGTH,   (height        / vscroll),
                             SCROLLBAR_VIEW_LENGTH,     (height_init   / vscroll),
                             SCROLLBAR_VIEW_START,      ((vthumb - y0) / vscroll),
                             NULL);
#ifdef DEBUG
      fprintf(stderr, "Scrollbars (vert = 0x%X, hor = 0x%X) created\n",
              (int)(wdata->vscrollbar), (int)(wdata->hscrollbar));
      fprintf(stderr, "            vert %d, %d    hor %d, %d\n",
              (int)xv_get(wdata->vscrollbar, XV_WIDTH),
              (int)xv_get(wdata->vscrollbar, XV_HEIGHT),
              (int)xv_get(wdata->hscrollbar, XV_WIDTH),
              (int)xv_get(wdata->hscrollbar, XV_HEIGHT));
#endif
    } else {

      xv_set(wdata->hscrollbar,
             SCROLLBAR_PIXELS_PER_UNIT, hscroll,
             SCROLLBAR_OBJECT_LENGTH,   (width         / hscroll),
             SCROLLBAR_VIEW_LENGTH,     (width_init    / hscroll),
             SCROLLBAR_VIEW_START,      ((hthumb - x0) / hscroll),
             NULL);

      xv_set(wdata->vscrollbar,
             SCROLLBAR_PIXELS_PER_UNIT, vscroll,
             SCROLLBAR_OBJECT_LENGTH,   (height        / vscroll),
             SCROLLBAR_VIEW_LENGTH,     (height_init   / vscroll),
             SCROLLBAR_VIEW_START,      ((vthumb - y0) / vscroll),
             NULL);
    }
  } else {

    if (wdata->hscrollbar != (Scrollbar)0) {
      xv_destroy(wdata->hscrollbar);
      xv_destroy(wdata->vscrollbar);
      wdata->hscrollbar = wdata->vscrollbar = (Scrollbar)0;
    }
  }

  wdata->both_pixels = both_pixels;
  wdata->width       = width_init;
  wdata->height      = height_init;
  wdata->x0          = x0;
  wdata->y0          = y0;

  window_fit(wdata->frame);
  return window;
}

/* We have to activate this window -> i.e. top it. and change the input focus */
int
activate_window(int window)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);

#ifdef DEBUG
  fprintf(stderr, "activating window 0x%X%s\n",
          window, (wdata->active == False) ? "" : " (was already active)\n");
#endif

/*
  if (wdata->active == False) {
*/
	xv_set (wdata->frame,XV_SHOW,TRUE,NULL);

	/* Sven: Setting the focus doesn't work in many ways:

       xv_set((Xv_Server)xv_get((Xv_Screen)xv_get(toplevel, XV_SCREEN), SCREEN_SERVER),
              SERVER_SYNC_AND_PROCESS_EVENTS, NULL); 
       xv_set(wdata->canvas, WIN_SET_FOCUS, NULL);

       XSetInputFocus(display, (Window)xv_get(wdata->frame, XV_XID), RevertToParent,
                      CurrentTime);

      win_set_kbd_focus(wdata->picture, xv_get(wdata->picture, XV_XID));

      win_post_id(window, KBD_USE, NOTIFY_IMMEDIATE);

      But, how DOES it work?  :'-(
	*/

	/*
    wdata->active = True;
    */
	
	xv_set (wdata->canvas,WIN_SET_FOCUS,NULL);
	
	/* RWS send an event to Clean to make sure the Clean administration is updated */
	set_global_event (CLEAN_WINDOW_DEVICE,(int)(wdata->frame),CLEAN_WINDOW_ACTIVATE,1,0,0,0,0);
  	/* */
  /*
  }
  */

  return window;
}

/* Changing a window title
*/
int
set_window_title(int window, CLEAN_STRING title)
{
  char *tmp;

  tmp = cstring(title);
  xv_set((Xv_Window)window, FRAME_LABEL, tmp, NULL);  /* Xview copies label */

#ifdef DEBUG
    fprintf(stderr, "Set title for window 0x%X to <%s>\n", window, tmp);
#endif

  my_free(tmp);
  return window;
}


/* Check for button still down, i.e. button not released.
*/
MyBoolean
ButtonStillDown(void)
{
  return (button_down != ButtonUp);
}


/* Generate ButtonStillDown event.
*/
void
ButtonStillDownEvent(void)
{
  WindowData *wdata;
  Window d;
  int dd;
  unsigned int keys_buttons;

#ifdef DEBUG
  fprintf(stderr, "~~~~~~~~~~~~~~~~~ButtonStillDownEvent: button_down = %d\n", button_down);
#endif

  switch(button_down) {

  case ButtonUp:
    break;

  case ButtonStillDownWindow:
    wdata = (WindowData *)xv_get(my_last_window, XV_KEY_DATA, UserDataKey);
    if (XQueryPointer(display, (Window)xv_get(wdata->frame, XV_XID), &d, &d,
                      &dd, &dd, &dd, &dd, &keys_buttons) == True)
    set_global_event(CLEAN_WINDOW_DEVICE, (int)my_last_window, CLEAN_WINDOW_MOUSE, 0,
                     BUTTONSTILLDOWN, my_local_mouse_x + wdata->x0,
                     my_local_mouse_y + wdata->y0,
					 keys_buttons);
    break;

  case ButtonStillDownDialog:
    wdata = (WindowData *)xv_get(my_last_window, XV_KEY_DATA, UserDataKey);
    if (XQueryPointer(display, (Window)xv_get(wdata->frame, XV_XID), &d, &d,
                      &dd, &dd, &dd, &dd, &keys_buttons) == True)
      set_global_event(CLEAN_DIALOG_DEVICE, (int)my_last_window, CLEAN_DIALOG_MOUSE, 0,
                       BUTTONSTILLDOWN, my_local_mouse_x + wdata->x0,
                       my_local_mouse_y + wdata->y0,
				 keys_buttons);
    break;
  }
}


int
discard_updates(int window)
{
  WindowData *wdata;
  XEvent report;
  Window xwin;

#ifdef DEBUG
    fprintf(stderr, "Discarding updates for window 0x%X...", window);
#endif

  wdata = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);
  xwin  = (Window)xv_get(wdata->picture, XV_XID);

  XSync(display,False);
  while (XCheckTypedWindowEvent(display, xwin, Expose, &report) ||
         XCheckTypedWindowEvent(display, xwin, GraphicsExpose, &report))
    ;

#ifdef DEBUG
    fprintf(stderr, "Discarding done.\n");
#endif

  return window;
}


int
popdown(int window)
{
#ifdef DEBUG
    fprintf(stderr, "Popping down window 0x%X\n", window);
#endif
  xv_set((Xv_Window)window, XV_SHOW, FALSE, NULL);
  return window;
}


int
popup(int window)
{
#ifdef DEBUG
    fprintf(stderr, "Popping up window 0x%X\n", window);
#endif
  xv_set((Xv_Window)window, XV_SHOW, TRUE, NULL);
  return window;
}
