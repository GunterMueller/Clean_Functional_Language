/* This c header file contains the typedefinition for the WindowData type,
   an data structure containing all necessary window information needed
   in a Clean program.
   Furthermore some auxiliary types are declared.
   Leon Pillich, October 1992

   1993 (Sven Panne) : added ifndef, some components of WindowData and keys
*/

#ifndef windowdata_DEFINED
#define windowdata_DEFINED

#include <X11/Xlib.h>
#include <xview/xview.h>
#include <xview/frame.h>
#include <xview/canvas.h>
#include <xview/scrollbar.h>

typedef struct _WindowData {
  /* Data primarily associated with the window */
  Frame frame;
  Canvas canvas;
  Scrollbar hscrollbar;
  Scrollbar vscrollbar;
  int both_pixels;      /* size of border and scrollbars in pixels */

  /* Data associated with the picture domain */
  Xv_Window picture;    /* XView paint window */
  int width, height;    /* actual viewable size of paint window */
  int x0, y0;           /* upper left coordinates of the picture domain */

  /* Data associated with the actual picture */
  GC window_gc;
  int curx, cury;       /* actual position of pen */
  int pen;              /* 0: pen hidden,  1: pen visible */

  /* Font information for the pictures gc */
  XFontStruct *font_info;
  char *font_name;
  char *font_style;
  char *font_size;

  /* Is this window active? */
  MyBoolean active;

} WindowData;

/* Keeping track of multiclicks */
typedef enum {NoClick, OneClick, TwoClicks} ClickCount;

/* Keeping track of button still down events. */
typedef enum {ButtonUp, ButtonStillDownWindow, ButtonStillDownDialog} ButtonDownState;

#endif
