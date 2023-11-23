/* This module implements an interface to the Xlib drawing routines
   for use in Concurrent Clean Event I/O.
   Drawing functions as well as attribute changing functions and
   font handling functions are provided.

   The interface for Clean to this module can be found in xpicture.fcl.
   These functions are all used by the Clean module picture.

   1992: Leon Pillich
   1994: Sven Panne
*/


typedef int MyBoolean;

#include <X11/Xlib.h>
#include <X11/Xmu/Drawing.h>
#include <stdio.h>
#include <memory.h>
#include <string.h>
#include <stdlib.h>
#include "interface.h"
#include "windowdata.h"
#include "ckernel.h"
#include "cwindow.h"

/* This is in _startup.o */
extern char **global_argv;

typedef Xv_Window Picture;

/* The Clean standard colours */
#define CleanBlackColor         1
#define CleanWhiteColor         2
#define CleanRedColor           3
#define CleanGreenColor         4
#define CleanBlueColor          5
#define CleanCyanColor          6
#define CleanMagentaColor       7
#define CleanYellowColor        8

/* The gcs and window/display pointers */
static GC my_gc;
static GC standard_gc;

/* current values for (relative) drawing mode */
static int base_x;
static int base_y;
static int curx;
static int cury;
static int pen;                     /* start with pen off */
static int my_depth;                /* depth of the picture */
static Window current_picture;
static MyBoolean AllFontsRead;      /* have we already read all fontnames? */


/***************************/
/* Some handy GC functions */
/***************************/

/* create a new graphics context */
GC
make_new_gc(void)
{
  XGCValues values;

  values.function   = GXcopy;
  values.foreground = BlackPixelOfScreen(screen);
  values.background = WhitePixelOfScreen(screen);
  values.line_width = 1;

  return XCreateGC(display, default_window,
                   (GCFunction | GCForeground | GCBackground | GCLineWidth), &values);
}


/************************/
/* Color initialisation */
/************************/

static Colormap my_colors;
static long clean_standard_colors[8+1];

long
named_color(char *color_name)
{
  XColor color, exact_color;

  XAllocNamedColor(display,my_colors, color_name, &color, &exact_color);

  return color.pixel;
}


static void
init_clean_colors(void)
{
  int i;

  clean_standard_colors[CleanBlackColor  ] = named_color("black");
  clean_standard_colors[CleanWhiteColor  ] = named_color("white");
  clean_standard_colors[CleanRedColor    ] = named_color("red");
  clean_standard_colors[CleanGreenColor  ] = named_color("forest green");
  clean_standard_colors[CleanBlueColor   ] = named_color("blue");
  clean_standard_colors[CleanCyanColor   ] = named_color("cyan");
  clean_standard_colors[CleanMagentaColor] = named_color("magenta");
  clean_standard_colors[CleanYellowColor ] = named_color("yellow");

  for (i = CleanRedColor;  i <= CleanYellowColor; i++)
    if (clean_standard_colors[i] == clean_standard_colors[CleanWhiteColor])
      clean_standard_colors[i]=clean_standard_colors[CleanBlackColor];
}


static void
init_colors(void)
{
  my_colors = DefaultColormapOfScreen(screen);

  init_clean_colors();
}


XFontStruct *default_font;


void
init_picture(void)
{
  void init_patterns(void);
  void init_fonts(void);

  init_colors();
  init_patterns();
  AllFontsRead = False;

  default_font = XLoadQueryFont(display, "*courier-medium-r-normal-*-*-120-*-*-*-*-*-*");
  if (default_font == (XFontStruct *)0) {
    fprintf(stderr,"%s: Cannot load default font (courier 12)!\n", global_argv[0]);
    abort();
  }
  standard_gc = make_new_gc();
  XSetGraphicsExposures(display, standard_gc, True);
}


/*******************************************/
/* Destroying data associated with picture */
/*******************************************/

void
FreePictureData(WindowData *wdata)
{
#ifdef DEBUG
  fprintf(stderr, "Freeing picture data 0x%X\n", (int)wdata);
#endif

  XFreeGC(display, wdata->window_gc);
  my_free(wdata->font_name);
  my_free(wdata->font_style);
  my_free(wdata->font_size);
}


/*****************************************/
/* Initialisation for bitmap patterns.   */
/*****************************************/

Pixmap pattern_75;
static char pattern_75_bitmap[2];
Pixmap pattern_50;
static char pattern_50_bitmap[2];
Pixmap pattern_25;
static char pattern_25_bitmap[2];
Pixmap pattern_0;
static char pattern_0_bitmap[2];


void
init_patterns(void)
{
  Drawable dr = default_window;

  pattern_75_bitmap[0] = (char)0x01;  pattern_75_bitmap[1] = (char)0x03;
  pattern_50_bitmap[0] = (char)0x01;  pattern_50_bitmap[1] = (char)0x02;
  pattern_25_bitmap[0] = (char)0x02;  pattern_25_bitmap[1] = (char)0x00;
  pattern_0_bitmap [0] = (char)0x00;  pattern_0_bitmap [1] = (char)0x00;

  pattern_75 = XCreateBitmapFromData(display, dr, pattern_75_bitmap, 2, 2);
  pattern_50 = XCreateBitmapFromData(display, dr, pattern_50_bitmap, 2, 2);
  pattern_25 = XCreateBitmapFromData(display, dr, pattern_25_bitmap, 2, 2);
  pattern_0  = XCreateBitmapFromData(display, dr, pattern_0_bitmap,  2, 2);
}


/******************************************************/
/* Initialisation and end-initialisation for drawing  */
/******************************************************/

void
my_grab_server(Display *display)
{
#ifdef DEBUG
  fprintf(stderr, "I would like to grab the server...\n");
#else
  XGrabServer(display);
#endif
}


void
my_ungrab_server(Display *display)
{
#ifdef DEBUG
  fprintf(stderr, "I would like to ungrab the server...\n");
#else
  XUngrabServer(display);
#endif
}

/* RWS */
static struct
{
	MyBoolean		xor_on;
	unsigned long	xor_saveForegroundColour;
	unsigned long	xor_saveBackgroundColour;
} DrawXorState = {False, 0, 0};

static void XorSet (void)
{
	XGCValues gcvalues;

	XGetGCValues (display, my_gc, GCForeground | GCBackground, &gcvalues);

	DrawXorState.xor_saveBackgroundColour	= gcvalues.background;
	DrawXorState.xor_saveForegroundColour	= gcvalues.foreground;

	XSetBackground (display, my_gc, (unsigned long) 0);
	XSetForeground (display, my_gc, gcvalues.foreground ^ gcvalues.background);

	my_grab_server (display);

	DrawXorState.xor_on	= True;
} /* XorSet */

static void XorReset (void)
{
	my_ungrab_server (display);

	XSetBackground(display, my_gc, DrawXorState.xor_saveBackgroundColour);
	XSetForeground(display, my_gc, DrawXorState.xor_saveForegroundColour);

	DrawXorState.xor_on	= False;
} /* XorReset */

static MyBoolean XorMode (MyBoolean xorOn)
{
	MyBoolean	xorWasOn;

	xorWasOn	= DrawXorState.xor_on;

	if (xorOn != xorWasOn)
	{
		if (xorOn)
			XorSet ();
		else
			XorReset ();
	}

	return (xorWasOn);
} /* XorMode */
/* */

int
start_drawing(int window)
{
  WindowData *wdata;
  XGCValues gcvalues;

  wdata               = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);
  base_x              = wdata->x0;
  base_y              = wdata->y0;
  current_picture     = (Window)xv_get(wdata->picture, XV_XID);
  my_gc               = wdata->window_gc;
  curx                = wdata->curx;
  cury                = wdata->cury;
  pen                 = wdata->pen;
  my_depth            = (int)xv_get(wdata->picture, XV_DEPTH);
  XGetGCValues(display, wdata->window_gc, GCFunction, &gcvalues);

  XorMode (gcvalues.function == GXxor);

#ifdef DEBUG
  fprintf(stderr, "start drawing in window 0x%x, wdata 0x%X, picture 0x%X:  x0:%d, y0:%d\n",
          (int) window, (int) wdata, (int) wdata->picture, base_x, base_y);
#endif

  return window;
}

int
end_drawing(int window)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)window, XV_KEY_DATA, UserDataKey);
  wdata->curx = curx;
  wdata->cury = cury;
  wdata->pen  = pen;

  XorMode (False);

  XFlush(display); /* make sure the user sees everything immediately */

#ifdef DEBUG
  fprintf(stderr, "end drawing in picture 0x%X\n", (int)(wdata->picture));
#endif

  return window;
}

/****************************************************/
/* Pen and line drawing primitives for use in Clean */
/****************************************************/

/* RWS
	Routines that imitate the Mac QuickDraw drawing model, only work
	for vertical and horizontal lines and rectangles.
*/

static struct
{
	int height;
	int width;
	int size;
} pen_info = {1,1,1};

static void DrawLine (Display *display,Drawable current_picture, GC my_gc,
            int curx, int cury,int newx, int newy)
{
	int	size;

	if (curx == newx)
	{
		newx = curx += pen_info.width / 2;
		newy += pen_info.height;
		size = pen_info.width;
	}
	else if (cury == newy)
	{
		newx += pen_info.width;
		newy = cury += pen_info.height / 2;
		size = pen_info.height;
	}
	else
		size	= pen_info.size;

	XSetLineAttributes(display,my_gc,size, LineSolid,CapButt,JoinMiter);
#ifdef DEBUG
	printf ("XDrawLine %d %d %d %d %d\n",curx,cury,newx,newy,pen_info.height);
#endif
	XDrawLine (display, current_picture, my_gc, curx,cury,newx, newy);
	XSetLineAttributes(display,my_gc,pen_info.size, LineSolid,CapButt,JoinMiter);
}

static void DrawRectangle (Display *display,Drawable current_picture, GC my_gc,
            int x1, int y1,int x2, int y2)
{
	int	x, y, height, width;

	if (x1 > x2)
	{
		x	= x1;
		x1	= x2;
		x2	= x;
	}

	if (y1 > y2)
	{
		y	= y1;
		y1	= y2;
		y2	= y;
	}

	height	= pen_info.height;
	width	= pen_info.width;
	if (2 * width >= x2-x1 || 2 * height >= y2-y1)
	{
		if (x1 != x2 && y1 != y2)
			XFillRectangle(display,current_picture,my_gc, x1,y1, x2-x1,y2-y1);
	}
	else if (height == width)
	{
		XSetLineAttributes(display,my_gc,height, LineSolid,CapButt,JoinMiter);

		y1 += height / 2;
		y2 -= (height - 1) / 2;
		x1 += width / 2;
		x2 -= (width - 1) / 2;

		XDrawRectangle (display,current_picture,my_gc, x1,y1,x2-x1-1,y2-y1-1);
	}
	else
	{
		XSetLineAttributes(display,my_gc,height, LineSolid,CapButt,JoinMiter);

		y = y1 + height / 2;
		XDrawLine (display, current_picture, my_gc, x1, y, x2 - width, y);

		y = y2 - (height + 1) / 2;
		XDrawLine (display, current_picture, my_gc, x1 + width, y, x2, y);

		XSetLineAttributes(display,my_gc,width, LineSolid,CapButt,JoinMiter);

		x = x1 + width / 2;
		XDrawLine (display, current_picture, my_gc, x, y1 + height, x, y2);

		x = x2 - (width + 1) / 2;
		XDrawLine (display, current_picture, my_gc, x, y1, x, y2 - height);
	}

	XSetLineAttributes(display,my_gc,pen_info.size,
											LineSolid,CapButt,JoinMiter);
}

/* */

/* pen and line drawing */
int
hide_pen(int p)
{
  pen = 0;
  return p;
}


int
show_pen(int p)
{
  pen = 1;
  return p;
}

void
get_pen(int p, int *x, int *y)
{
/* RWS:
	This function is not used, but was wrong anyway
  *x = curx;
  *y = cury;
*/
  *x = curx+base_x;
  *y = cury+base_y;
/* */
}

int pen_size(int /* RWS size */ width, int height ,int p)
{
/* RWS */
  int size;

  pen_info.height=height;
  pen_info.width=width;
  size=(height+width)/2; /* this doesn't make sense, but it's the
							same on OS/2 */
  pen_info.size=size;

/* */

#ifdef DEBUG
	printf ("pen_size %d %d %d\n",pen_info.height,pen_info.width,pen_info.size);
#endif

  XSetLineAttributes(display,my_gc,size, LineSolid,CapButt,JoinMiter);

  return p;
}  

int
pen_mode(int mode, int p)
{
#ifdef DEBUG
  fprintf(stderr, "Setting pen mode to %d in picture 0x%X\n", mode, p);
#endif

  XSetFunction(display, my_gc, mode);

  XorMode (mode == GXxor);
  
  return p;
}

int
pen_pattern(int pattern, int p)
{
  switch(pattern) {
  case 100:
    XSetFillStyle(display, my_gc, FillSolid);
    break;
  case 75:
    XSetFillStyle(display, my_gc, FillOpaqueStippled);
    XSetStipple(display, my_gc, pattern_75);
    break;
  case 50:
    XSetFillStyle(display, my_gc, FillOpaqueStippled);
    XSetStipple(display, my_gc, pattern_50);
    break;
  case 25:
    XSetFillStyle(display, my_gc, FillOpaqueStippled);
    XSetStipple(display, my_gc, pattern_25);
    break;
  case 0:
    XSetFillStyle(display, my_gc, FillOpaqueStippled);
    XSetStipple(display, my_gc, pattern_0);
    break;
  default:
	break;
  }

  return p;
}

int
pen_normal(int p)
{
  pen_size(1, /* RWS */ 1, p);
  pen_mode(GXcopy, p);

  return p;
}

int
line_to(int x, int y, int p)
{
  int new_x, new_y;

  new_x = x - base_x;
  new_y = y - base_y;

#ifdef DEBUG
  fprintf(stderr, "Drawing line from (%d,%d) to (%d,%d) in window 0x%X\n",
          curx, cury, new_x, new_y, p);
#endif

  /* Sven: A line of length zero is NOT drawn by some X servers (most notably mine ;-),
     so we draw a point instead in these cases. */
  if ((curx != new_x) || (cury != new_y)) {
/* RWS
    XDrawLine(display, current_picture, my_gc, curx, cury, new_x, new_y); */
    DrawLine(display, current_picture, my_gc, curx, cury, new_x, new_y);
/* */
    curx = new_x;
    cury = new_y;
  } else {
    XDrawPoint(display, current_picture, my_gc, curx, cury);
  }
  return p;
}

int
move_to(int x, int y, int p)
{
#if 0
  if (pen) { /* we should draw! */
    return (line_to(x, y, p));
  } else {
#endif
    curx = x - base_x;
    cury = y - base_y;
#ifdef DEBUG
  fprintf(stderr, "Move pen to (%d,%d)\n", curx, cury);
#endif
    return p;
/*  } */
}

int
move_relative(int x, int y, int p)
{
  curx += x;
  cury += y;

  return p;
}


int
line_relative(int x, int y, int p)
{
  int xd, yd;

  xd = curx + x;
  yd = cury + y;
/* RWS
  XDrawLine(display, current_picture, my_gc, curx, cury, xd, yd); */
  DrawLine(display, current_picture, my_gc, curx, cury, xd, yd);
/* */
  curx = xd;
  cury = yd;

  return p;
}


/***************************/
/* Text drawing primitives */
/***************************/

int
draw_string(CLEAN_STRING s, int p)
{
  char *cs;
  int function;
  XGCValues gcvalues;
  WindowData *wdata;

  cs = cstring(s);
  wdata = (WindowData *)xv_get((Xv_Window)p, XV_KEY_DATA, UserDataKey);
#ifdef DEBUG
  fprintf(stderr, "Drawing string <%s> into window 0x%X at (%d, %d)\n", cs, p,
				curx, cury);
  {
    fprintf(stderr, "frame (%d, %d)\n",
		xv_get (wdata->frame, XV_X), xv_get (wdata->frame, XV_Y));
    fprintf(stderr, "canvas (%d, %d)\n",
		xv_get (wdata->canvas, XV_X), xv_get (wdata->canvas, XV_Y));
    fprintf(stderr, "picture (%d, %d)\n",
		xv_get (wdata->picture, XV_X), xv_get (wdata->picture, XV_Y));
  }

#endif
  XGetGCValues(display, my_gc, GCFunction, &gcvalues);
  function = gcvalues.function;

  /* We only allow or/xor/clear/copy textmode drawing, otherwise we will use or textmode. */
  if (!(function == GXor || function == GXxor || function == GXclear
		|| function == GXcopy)) /* RWS: added copy mode */
    XSetFunction(display, my_gc, GXcopy);

  XDrawString(display, current_picture, my_gc, curx, cury, cs, s->length);

  curx += XTextWidth(wdata->font_info, cs, s->length);

  /* Set drawing mode back. */
  XSetFunction(display, my_gc, function);

  my_free(cs);
  return p;
}

/********************/
/* Drawing in color */
/********************/

int
get_color(int index)
{
  return (int)clean_standard_colors[index];
}


int
foreground_color(int c, int p)
{
  MyBoolean xorMode;

#ifdef DEBUG
  fprintf(stderr, "setting foreground color to %lu in picture 0x%X\n", (unsigned long)c, p);
#endif

  xorMode	= XorMode (False);
  XSetForeground(display, my_gc, (unsigned long)c);
  XorMode (xorMode);

  return p;
}


int
background_color(int c, int p)
{
  MyBoolean xorMode;

#ifdef DEBUG
  fprintf(stderr, "setting background color to %lu in picture 0x%X\n", (unsigned long)c, p);
#endif

  xorMode	= XorMode (False);
  XSetBackground(display, my_gc, (unsigned long)c);
  XorMode (xorMode);

  return p;
}


int
rgb_fg_color(double r, double g, double b, int p)
{
  XColor color;

  color.red   = (short)(r * 65535.0);
  color.green = (short)(g * 65535.0);
  color.blue  = (short)(b * 65535.0);
  color.flags = DoRed | DoGreen | DoBlue; /* which color components */

  XAllocColor(display, my_colors, &color);
#ifdef DEBUG
  fprintf(stderr, "setting rgb foreground color to %lu in picture 0x%X\n", color.pixel, p);
#endif
  XSetForeground(display, my_gc, color.pixel);

  return p;
}

int
rgb_bg_color(double r, double g, double b, int p)
{
  XColor color;

  color.red   = (short)(r * 65535.0);
  color.green = (short)(g * 65535.0);
  color.blue  = (short)(b * 65535.0);
  color.flags = DoRed | DoGreen | DoBlue; /* which color components */
	
  XAllocColor(display, my_colors, &color);
#ifdef DEBUG
  fprintf(stderr, "setting rgb background color to %lu in picture 0x%X\n", color.pixel, p);
#endif
  XSetBackground(display, my_gc, color.pixel);

  return p;
}


/**************************************/
/* Graphic operations with lines etc. */
/**************************************/

int
draw_line(int x1, int y1, int x2, int y2, int p)
{
/* RWS
  XDrawLine(display, current_picture, my_gc,
            x1 - base_x, y1 - base_y, x2 - base_x, y2 - base_y); */
  DrawLine(display, current_picture, my_gc,
            x1 - base_x, y1 - base_y, x2 - base_x, y2 - base_y);
/* */
  return p;
}


int
draw_point(int x, int y, int p)
{
  XDrawPoint(display, current_picture, my_gc, x - base_x, y - base_y);
  return p;
}


/**************************************/
/* Graphic operations with rectangles */
/**************************************/

int
frame_rectangle(int x1, int y1, int x2, int y2, int p)
{
#ifdef DEBUG
  fprintf(stderr,"Frame rectangle: (%d,%d) (%d,%d) in picture 0x%X\n", x1, y1, x2, y2, p);
#endif

  /* RWS XDrawRectangle(display, current_picture, my_gc,
                 x1 - base_x, y1 - base_y, x2 - x1 - 1, y2 - y1 - 1); */
  DrawRectangle(display, current_picture, my_gc,
                 x1 - base_x, y1 - base_y, x2 - base_x, y2 - base_y);
/* */

  return p;
}


int
paint_rectangle(int x1, int y1, int x2, int y2, int p)
{
#ifdef DEBUG
  fprintf(stderr, "Paint rectangle: (%d,%d) (%d,%d) in picture 0x%X\n", x1, y1, x2, y2, p);
#endif

  XFillRectangle(display, current_picture, my_gc,
                 x1 - base_x, y1 - base_y, x2 - x1, y2 - y1);
/* RWS */
#ifdef DEBUG
  XFlush (display);
#endif
/* */
   return p;
}


int
erase_rectangle(int x1, int y1, int x2, int y2, int p)
{
  XGCValues gc_values;

#ifdef DEBUG
  fprintf(stderr, "Erase rectangle: (%d,%d) (%d,%d) in picture 0x%X\n", x1, y1, x2, y2, p);
#endif

  XGetGCValues(display, my_gc, GCBackground | GCFunction | GCForeground, &gc_values);

  XSetForeground(display, my_gc, gc_values.background);
  XSetFunction(display, my_gc, GXcopy);
  paint_rectangle(x1, y1, x2, y2, p);
  XSetFunction(display, my_gc, gc_values.function);
  XSetForeground(display, my_gc, gc_values.foreground);

  return p;
}


int
invert_rectangle(int x1, int y1, int x2, int y2, int p)
{
  XGCValues gc_values;

#ifdef DEBUG
  fprintf(stderr, "Invert rectangle: (%d,%d) (%d,%d) in picture 0x%X\n", x1, y1, x2, y2, p);
#endif

  XGetGCValues(display, my_gc, GCFunction, &gc_values);
  XSetFunction(display, my_gc, GXxor);
  paint_rectangle(x1, y1, x2, y2, p);
  XSetFunction(display, my_gc, gc_values.function);

  return p;
}


int
move_rectangle(int x1, int y1, int x2, int y2, int xd, int yd, int p)
{
  unsigned int w, h;
  Pixmap pixmap;

#ifdef DEBUG
  fprintf(stderr, "Move rectangle (%d,%d) (%d,%d) to (%d,%d) in picture 0x%X\n",
          x1, y1, x2, y2, xd, yd, p);
#endif

  w = x2 - x1;
  h = y2 - y1;

  if((w != 0) && (h != 0)) {
    pixmap = XCreatePixmap(display, current_picture, w, h, my_depth);
    /* NOTE: Because of clipping, we have to use the standard GC here */
    XCopyArea(display, current_picture, pixmap, standard_gc,
              x1 - base_x, y1 - base_y, w, h, 0, 0);
    /* The following statement was:
       XClearArea(display, current_picture, x1 - base_x, y1 - base_y, w, h, False);
       But this way, the area is painted in the WINDOW's background colour, not the GC's!! */
    erase_rectangle(x1, y1, x2, y2, p);
    XCopyArea(display, pixmap, current_picture, my_gc, 0, 0, w, h, xd - base_x, yd - base_y);
    XFreePixmap(display, pixmap);
  }

  return p;
}


int
copy_rectangle(int x1, int y1, int x2, int y2, int xd, int yd, int p)
{
  XGCValues gc_values;
  unsigned int w, h;

#ifdef DEBUG
  fprintf(stderr, "Copy rectangle (%d,%d) (%d,%d) to (%d,%d) in picture 0x%X\n",
          x1, y1, x2, y2, xd, yd, p);
#endif

  w = x2 - x1;
  h = y2 - y1;

  if((w != 0) && (h != 0)) {
    XGetGCValues(display, my_gc, GCGraphicsExposures, &gc_values);
    XSetGraphicsExposures(display, my_gc, True);
    XCopyArea(display, current_picture, current_picture, my_gc,
              x1 - base_x, y1 - base_y, w, h, xd - base_x, yd - base_y);
    XSetGraphicsExposures(display, my_gc, gc_values.graphics_exposures);
  }

  return p;
}


/***********************************************/
/* Graphics operations with rounded rectangles */
/***********************************************/

int
frame_round_rectangle(int x1, int y1, int x2, int y2, int width, int height, int p)
{
  XmuDrawRoundedRectangle(display, current_picture, my_gc, x1 - base_x, y1 - base_y,
                          x2 - x1 - 1, y2 - y1 - 1, width >> 1, height >> 1);
  return p;
}


int
paint_round_rectangle(int x1, int y1, int x2, int y2, int width, int height, int p)
{
  XmuFillRoundedRectangle(display, current_picture, my_gc, x1 - base_x, y1 - base_y,
                          x2 - x1, y2 - y1, width >> 1,height >> 1);
  return p;
}


int
erase_round_rectangle(int x1, int y1, int x2, int y2, int width, int height, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCBackground | GCFunction | GCForeground, &gc_values);

  XSetForeground(display, my_gc, gc_values.background);
  XSetFunction(display, my_gc, GXcopy);
  paint_round_rectangle(x1, y1, x2, y2, width, height, p);
  XSetFunction(display, my_gc, gc_values.function);
  XSetForeground(display, my_gc, gc_values.foreground);

  return p;
}


int
invert_round_rectangle(int x1, int y1, int x2, int y2, int width, int height, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCFunction, &gc_values);
  XSetFunction(display, my_gc, GXxor);
  paint_round_rectangle(x1, y1, x2, y2, width, height, p);
  XSetFunction(display, my_gc, gc_values.function);

  return p;
}


/**********************************/
/* Graphics operations with ovals */
/**********************************/

int
frame_oval(int x1, int y1, int x2, int y2, int p)
{
  XDrawArc(display, current_picture, my_gc, x1 - base_x, y1 - base_y,
           x2 - x1 - 1, y2 - y1 - 1, 0, 64 * 360);

  return p;
}


int
paint_oval(int x1, int y1, int x2, int y2, int p)
{
   XFillArc(display, current_picture, my_gc, x1 - base_x, y1 - base_y,
            x2 - x1, y2 - y1, 0, 64 * 360);

   return p;
}


int
erase_oval(int x1, int y1, int x2, int y2, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCBackground | GCFunction | GCForeground, &gc_values);

  XSetForeground(display, my_gc, gc_values.background);
  XSetFunction(display, my_gc,GXcopy);
  paint_oval(x1, y1, x2, y2, p);
  XSetFunction(display, my_gc, gc_values.function);
  XSetForeground(display, my_gc, gc_values.foreground);

  return p;
}


int
invert_oval(int x1, int y1, int x2, int y2, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCFunction, &gc_values);
  XSetFunction(display, my_gc, GXxor);
  paint_oval(x1, y1, x2, y2, p);
  XSetFunction(display, my_gc, gc_values.function);

  return p;
}


/********************************/
/* Graphic operations with arcs */
/********************************/

int
frame_arc(int x1, int y1, int x2, int y2, int angle1, int angle2, int p)
{
  XDrawArc(display, current_picture, my_gc, x1 - base_x, y1 - base_y,
           x2 - x1 - 1, y2 - y1 - 1, angle1 << 6, angle2 << 6);

  return p;
}


int
paint_arc(int x1, int y1, int x2, int y2, int angle1, int angle2, int p)
{
   XFillArc(display, current_picture, my_gc, x1 - base_x, y1 - base_y,
            x2 - x1, y2 - y1, angle1 << 6, angle2 << 6);

   return p;
}


int
erase_arc(int x1, int y1, int x2, int y2, int angle1, int angle2, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCBackground | GCFunction | GCForeground, &gc_values);

  XSetForeground(display, my_gc, gc_values.background);
  XSetFunction(display, my_gc,GXcopy);
  paint_arc(x1, y1, x2, y2, angle1, angle2, p);
  XSetFunction(display, my_gc, gc_values.function);
  XSetForeground(display, my_gc,gc_values.foreground);

  return p;
}


int
invert_arc(int x1, int y1, int x2, int y2, int angle1, int angle2, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCFunction, &gc_values);
  XSetFunction(display, my_gc,GXxor);
  paint_arc(x1, y1, x2, y2, angle1, angle1, p);
  XSetFunction(display, my_gc, gc_values.function);

  return p;
}


/***************************************/
/* Graphic operations with polygons.   */
/***************************************/


int
alloc_polygon(int n)
{
  return (int)my_malloc(sizeof(XPoint) * n);
}


int
free_polygon(int p, int pic)
{
  my_free((XPoint *)p);
  return pic;
}


int
set_polygon_point(int p, int n, int x, int y)
{
  ((XPoint *)p)[n].x = (short)x;
  ((XPoint *)p)[n].y = (short)y;

  return p;
}


int
frame_polygon(int poly, int n, int x, int y, int p)
{
  ((XPoint *)poly)[0].x = (short)(x - base_x);
  ((XPoint *)poly)[0].y = (short)(y - base_y);

  XDrawLines(display, current_picture, my_gc, (XPoint *)poly, n, CoordModePrevious);

  return p;
}


int
paint_polygon(int poly, int n, int x, int y, int p)
{
  ((XPoint *)poly)[0].x = (short)(x - base_x);
  ((XPoint *)poly)[0].y = (short)(y - base_y);

  XFillPolygon(display, current_picture, my_gc, (XPoint *)poly, n, Complex, CoordModePrevious);

  return p;
}


int
erase_polygon(int poly, int n, int x, int y, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCBackground | GCFunction | GCForeground, &gc_values);

  XSetForeground(display, my_gc, gc_values.background);
  XSetFunction(display, my_gc, GXcopy);
  paint_polygon(poly, n, x, y, p);
  XSetFunction(display, my_gc, gc_values.function);
  XSetForeground(display, my_gc, gc_values.foreground);

  return p;
}


int
invert_polygon(int poly, int n, int x, int y, int p)
{
  XGCValues gc_values;

  XGetGCValues(display, my_gc, GCFunction, &gc_values);
  XSetFunction(display, my_gc, GXxor);
  paint_polygon(poly, n, x, y, p);
  XSetFunction(display, my_gc, gc_values.function);

  return p;
}


/****************************************/
/* Font functions.                      */
/****************************************/

char **all_fonts;
int NrOfAllFonts;

void
add_font(char *font)
{
  int i;
  int len;
  char *s;
  char *ss;

  s = strchr(font,'-');
  if (s == NULL)
  	return;
  s++;
  s = strchr(s, '-');
  if (s == NULL)
  	return;
  s++;
  ss = strchr(s,'-');
  if(ss==NULL)
  	return;
  len = ss - s;
  i = 0;
  while ((i < NrOfAllFonts) && (strncmp(s, all_fonts[i], len) != 0)) 
  	i++;
  if (i==NrOfAllFonts) {
    all_fonts[NrOfAllFonts] = ss = (char *)my_malloc(len + 1);
    strncpy(ss, s, len);
    ss[len] = (char)0;
    NrOfAllFonts++;
  }
}


void
retrieve_all_fonts(char **fonts, int count)
{
  int i;
  int current_max_fonts = 50;
  NrOfAllFonts=0;

  all_fonts=(char **)my_malloc(current_max_fonts * sizeof(char *));
  for (i = 0;  i < count;  i++) {
    if (NrOfAllFonts == current_max_fonts) {
      current_max_fonts += 50;
      all_fonts=(char **)my_realloc(all_fonts, current_max_fonts * sizeof(char*));
    }
    add_font(fonts[i]);
  }
}


void
read_all_fonts(void)
{
  char **fonts;
  int count;

  fonts = XListFonts(display, "*", 2000, &count);
  if (count == 0) {
    fprintf(stderr,"Fatal error: no fonts available.\n");
    abort();
  }

  retrieve_all_fonts(fonts, count);
  XFreeFontNames(fonts);
  AllFontsRead=True;
}


int
get_number_fonts(int dummy)
{
  if (AllFontsRead == FALSE)
    read_all_fonts();
  return NrOfAllFonts;
}


/* Sven: extern CLEAN_STRING result_clean_string; */


CLEAN_STRING
get_font_name(int index)
{
/* Sven:
  char *s;
  int len;

  s = all_fonts[index];
  len = strlen(s);
  my_free(result_clean_string);
  result_clean_string = (CLEAN_STRING)my_malloc(sizeof(int) + len + 1);
  result_clean_string->length = len;
  memcpy(result_clean_string->characters, s, len + 1);

  return result_clean_string;
*/
  return cleanstring(all_fonts[index]);
}


void
get_font_info(int pic, int *ascent, int *descent, int *widmax,
              int *leading, int *rpic)
{
  XFontStruct *font_info;
  WindowData *wdata;

  wdata     = (WindowData *)xv_get((Xv_Window)pic, XV_KEY_DATA, UserDataKey);
  font_info = wdata->font_info;
  *ascent   = font_info->max_bounds.ascent;
  *descent  = font_info->max_bounds.descent;
  *widmax   = (int)font_info->max_bounds.width;
  *leading  = font_info->descent - *descent + font_info->ascent - *ascent;
  *rpic     = pic;
}


void
get_font_font_info(int font, int *ascent, int *descent, int *widmax, int *leading)
{
  XFontStruct *font_info;

  font_info = (XFontStruct *)font;
  *ascent   = font_info->max_bounds.ascent;
  *descent  = font_info->max_bounds.descent;
  *widmax   = (int)font_info->max_bounds.width;
/* RWS do the same thing as in get_font_info
  *leading  = (font_info->descent) - (*descent);
*/
  *leading  = font_info->descent - *descent + font_info->ascent - *ascent;
}


void
get_string_width(int pic, CLEAN_STRING cs, int *width, int *rpic)
{
  WindowData *wdata;
  char *s;

  s      = cstring(cs);
  wdata  = (WindowData *)xv_get((Xv_Window)pic, XV_KEY_DATA, UserDataKey);
  *width = XTextWidth(wdata->font_info, s, cs->length);
  *rpic  = pic;
  my_free(s);
}


int
get_font_string_width(int font, CLEAN_STRING cs)
{
  int width;
  char *s;

  s = cstring(cs);
  width = XTextWidth((XFontStruct *)font, s, cs->length);
  my_free(s);

  return width;
}


void
set_new_font(WindowData *wdata)
{
  char *new_font;
  int number_of_fonts;
  char **font_names;

  new_font=my_malloc(strlen(wdata->font_name)  +
                     strlen(wdata->font_style) +
                     strlen(wdata->font_size)  + 1);
  strcpy(new_font, wdata->font_name);
  strcat(new_font, wdata->font_style);
  strcat(new_font, wdata->font_size);

#ifdef DEBUG
  fprintf(stderr, "new font:%s\n", new_font);
#endif


  font_names = XListFonts(display, new_font, 1, &number_of_fonts);
#ifdef DEBUG
  fprintf(stderr, "matching fonts: %d\n", number_of_fonts);
#endif

  if (number_of_fonts > 0) {
    wdata->font_info = XLoadQueryFont(display, new_font);
    XSetFont(display, wdata->window_gc, wdata->font_info->fid);
    XFreeFontNames(font_names);
#ifdef DEBUG
    fprintf(stderr, "font ready\n");
#endif
  }

  my_free(new_font);
}


void
set_default_font(WindowData *wdata)
{
#ifdef DEBUG
  fprintf(stderr, "Setting default font\n");
#endif
  wdata->font_name  = my_malloc(strlen("*courier") + 1);
  wdata->font_style = my_malloc(strlen("-medium-r-normal-*-*-") + 1);
  wdata->font_size  = my_malloc(strlen("120-*-*-*-*-*-*") + 1);
  strcpy(wdata->font_name, "*courier");
  strcpy(wdata->font_style, "-medium-r-normal-*-*-");
  strcpy(wdata->font_size, "120-*-*-*-*-*-*");
  wdata->font_info = default_font;
  XSetFont(display, wdata->window_gc, default_font->fid);
}


int
select_default_font(int dummy)
{
  return (int)default_font;
}


int
set_font(int pic, int info, CLEAN_STRING font_name,
         CLEAN_STRING font_style, CLEAN_STRING font_size)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)pic, XV_KEY_DATA, UserDataKey);
  my_free(wdata->font_name);
  wdata->font_name = cstring(font_name);
  my_free(wdata->font_style);
  wdata->font_style = cstring(font_style);
  my_free(wdata->font_size);
  wdata->font_size = cstring(font_size);
  wdata->font_info = (XFontStruct *)info;
  XSetFont(display, wdata->window_gc, ((XFontStruct *)info)->fid);

  return pic;
}


int
set_font_name(int pic, CLEAN_STRING font_name)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)pic, XV_KEY_DATA, UserDataKey);
  my_free(wdata->font_name);
  wdata->font_name = cstring(font_name);
  set_new_font(wdata);

  return pic;
}


int
set_font_style(int pic, CLEAN_STRING font_style)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)pic, XV_KEY_DATA, UserDataKey);
  my_free(wdata->font_style);
  wdata->font_style = cstring(font_style);
  set_new_font(wdata);

  return pic;
}


int
set_font_size(int pic, CLEAN_STRING font_size)
{
  WindowData *wdata;

  wdata = (WindowData *)xv_get((Xv_Window)pic, XV_KEY_DATA, UserDataKey);
  my_free(wdata->font_size);
  wdata->font_size = cstring(font_size);
  set_new_font(wdata);

  return pic;
}

struct font_info_tree {
	XFontStruct *font;
	char *font_name;
	struct font_info_tree *left;
	struct font_info_tree *right;
};

struct font_info_tree *selected_fonts=NULL;

int
select_font(CLEAN_STRING font)
{
  char *s;
  XFontStruct *font_info;

  check_init_toplevelx();  /* Halbe: Initialize the toolkit, if necessary */

  s = cstring(font);

#if 1
	{
		struct font_info_tree **tree_h;

		tree_h=&selected_fonts;
		while (*tree_h!=NULL){
			struct font_info_tree *tree_p;
			int r;

			tree_p=*tree_h;
			r=strcmp (s,tree_p->font_name);
			if (r==0){
				my_free (s);
				return (int) tree_p->font;
			} else if (r<0)
				tree_h=&tree_p->left;
			else
				tree_h=&tree_p->right;
		}
  
  		font_info = XLoadQueryFont(display, s);
		if (font_info==NULL)
			my_free (s);
		else {
			struct font_info_tree *node_p;

			node_p=my_malloc (sizeof (struct font_info_tree));
			node_p->font=font_info;
			node_p->font_name=s;
			node_p->left=NULL;
			node_p->right=NULL;

			*tree_h=node_p;
		}
	}
#else
  font_info = XLoadQueryFont(display, s);

# if 0
	printf ("select_font %s %d\n",s,(int)font_info);
# endif

	my_free (s);
#endif

  return (int)font_info;
}


/*****************************************************/
/* Return the styles and sizes for a given font name */
/*****************************************************/

static char test_font[100];

void
get_font_styles(CLEAN_STRING font_name, int *normal, int *bold,
                int *demibold, int *italic, int *condensed)
{
  char *s;
  char **fonts;
  int n;

  s = cstring(font_name);

  /* check for normal style */
  strcpy(test_font, s);
  strcat(test_font, "-medium-r-normal*");
  fonts = XListFonts(display, test_font, 10, &n);
  if (n > 0) {
    *normal = 1;
    XFreeFontNames(fonts);
  }

  /* check for bold style */
  strcpy(test_font, s);
  strcat(test_font, "-bold-r-normal");
  fonts = XListFonts(display, test_font, 10, &n);
  if (n > 0) {
    *bold=1;
    XFreeFontNames(fonts);
  }

  /* checking for demibold style */
  strcpy(test_font, s);
  strcat(test_font, "-demibold-r-normal");
  fonts = XListFonts(display, test_font, 10, &n);
  if (n > 0) {
    *demibold=1;
    XFreeFontNames(fonts);
  }

  /* check for italic style */
  strcpy(test_font, s);
  strcat(test_font, "-medium-i-normal");
  fonts=XListFonts(display, test_font, 10, &n);
  if (n > 0) {
    *italic=1;
    XFreeFontNames(fonts);
  }

  /* check for condensed style */
  strcpy(test_font, s);
  strcat(test_font, "-medium-r-condensed");
  fonts = XListFonts(display, test_font, 10, &n);
  if(n>0) {
    *condensed=1;
    XFreeFontNames(fonts);
  }

  my_free(s);
}


static int font_sizes[100];
static int number_font_sizes;


int
font_size_cmp(const void *x, const void *y)
{
  return (*((int *)y)) < (*((int *)x));
}


void
retrieve_sizes(int len, char **fonts, int n)
{
  int j, i;
  int size;
  char *s;

  number_font_sizes = 0;
  for (i = 0;  i < n;  i++) {
    s = fonts[i];
    for (j = 0;  j < 8;  j++) {
      s=strchr(s, '-');
      s++;
    }
    size = atoi(s);
    j = 0;
    while ((j < number_font_sizes) && (font_sizes[j] != size)) j++;
    if (j == number_font_sizes) {
      font_sizes[j] = size;
      number_font_sizes++;
    }
  }

  qsort(font_sizes, number_font_sizes, sizeof(int), font_size_cmp);

}


int
get_font_sizes(CLEAN_STRING font_name)
{
  int n;
  char *s;
  char **fonts;

  s = cstring(font_name);
  strcpy(test_font, s);
  strcat(test_font, "-medium-r-normal-*-*-*");
  fonts = XListFonts(display, test_font, 100, &n);  /* Sven: make 100 dynamic */

  retrieve_sizes(strlen(test_font), fonts, n);

  my_free(s);
  XFreeFontNames(fonts);

  return number_font_sizes;
}


int
get_one_font_size(int index)
{
  if (index == number_font_sizes)  /* Sven: shouldn't that be >= ?? */
    return 0;
  else
    return font_sizes[index];
}
