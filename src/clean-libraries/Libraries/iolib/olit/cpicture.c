/* This module implements an interface to the Xlib drawing routines
   for use in Concurrent Clean Event I/O.
   Drawing functions as well as attribute changing functions and
   font handling functions are provided.

   The interface for Clean to this module can be found in xpicture.fcl.
   These functions are all used by the Clean module picture.

   Last change, 1.3.1993, Empty rectangles are no longer copied or moved,
   since this resulted in a crash.

   1992: Leon Pillich
*/

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <X11/StringDefs.h>
#include <X11/Xatom.h>
#include <X11/Intrinsic.h>
#include <X11/Xmu/Drawing.h>
#include <Xol/OpenLook.h>
#include <stdio.h>
#include <memory.h>
#include <string.h>
#include <stdlib.h>
#include "windowdata.h"

#define Picture Widget

/* The Clean standard colours */
#define CleanBlackColor		1
#define CleanWhiteColor		2
#define CleanRedColor		3
#define CleanGreenColor		4
#define CleanBlueColor		5
#define CleanCyanColor		6
#define CleanMagentaColor	7
#define CleanYellowColor	8

extern char *cstring(CLEAN_STRING s);
extern char *cstr;

/* The gcs and window/display pointers */
GC my_gc;
GC standard_gc;
extern Display *display;
extern Screen *screen;
extern Window default_window;

/* current values for (relative) drawing mode */
int base_x;
int base_y;
Window current_picture;
int curx;
int cury;
int pen; /* start with pen off */
int my_depth; /* depth of the picture */

/* have we already read all fontnames? */
Boolean AllFontsRead;

/***************************/
/* Some handy GC functions */
/***************************/

/* create a new graphics context */
GC make_new_gc()
{ XGCValues values;

  values.function   = GXcopy;
  values.foreground = BlackPixelOfScreen(screen);
  values.background = WhitePixelOfScreen(screen);
  values.line_width = 1;

  return XCreateGC(display,default_window, 
                  (GCFunction|GCForeground|GCBackground|GCLineWidth), &values);
}

/* create a default graphics context */
void make_gc()
{ 
  standard_gc = make_new_gc();
}

/************************/
/* Color initialisation */
/************************/
XStandardColormap default_map;
Colormap my_colors;
long clean_standard_colors[8];

long named_color(char *color_name)
{ XColor color,exact_color;

  XAllocNamedColor(display,my_colors,color_name,&color,&exact_color);

  return color.pixel;
}

void init_clean_colors(void)
{ int i;

  clean_standard_colors[CleanBlackColor]  =named_color("black");
  clean_standard_colors[CleanWhiteColor]  =named_color("white");
  clean_standard_colors[CleanRedColor]    =named_color("red");
  clean_standard_colors[CleanGreenColor]  =named_color("forest green");
  clean_standard_colors[CleanBlueColor]   =named_color("blue");
  clean_standard_colors[CleanCyanColor]   =named_color("cyan");
  clean_standard_colors[CleanMagentaColor]=named_color("magenta");
  clean_standard_colors[CleanYellowColor] =named_color("yellow");

  for(i=CleanRedColor;i<=CleanYellowColor;i++)
   if(clean_standard_colors[i]==clean_standard_colors[CleanWhiteColor])
     clean_standard_colors[i]=clean_standard_colors[CleanBlackColor];
}

void init_colors()
{ 
  my_colors=XDefaultColormapOfScreen(screen);
  init_clean_colors();
}  

XFontStruct *default_font;

void init_picture(void)
{ void init_patterns(void);
  void init_fonts(void);

  init_colors();
  init_patterns();
  AllFontsRead=False;

  default_font=XLoadQueryFont(display,
             "*courier-medium-r-normal-*-*-120-*-*-*-*-*-*");
  if(default_font==0)
  { fprintf(stderr,"Cannot load default font (courier 12)!\n");
    exit(-1);
  };
}


/*******************************************/
/* Destroying data associated with picture */
/*******************************************/
void FreePictureData(WindowData *wdata)
{ XFreeGC(display, wdata->window_gc);
  XtFree(wdata->font_name);
  XtFree(wdata->font_style);
  XtFree(wdata->font_size);
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

void init_patterns(void)
{ Drawable dr = default_window;

  pattern_75_bitmap[0]=(char)0x01;pattern_75_bitmap[1]=(char)0x03;
  pattern_50_bitmap[0]=(char)0x01;pattern_50_bitmap[1]=(char)0x02;
  pattern_25_bitmap[0]=(char)0x02;pattern_25_bitmap[1]=(char)0x00;
  pattern_0_bitmap[0]=pattern_0_bitmap[1]=(char)0x00;

  pattern_75 =XCreateBitmapFromData(display, dr, pattern_75_bitmap,  2, 2);
  pattern_50 =XCreateBitmapFromData(display, dr, pattern_50_bitmap,  2, 2);
  pattern_25 =XCreateBitmapFromData(display, dr, pattern_25_bitmap,  2, 2);
  pattern_0  =XCreateBitmapFromData(display, dr, pattern_0_bitmap,   2, 2);
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

/* RWS ... */
static struct
{
	Boolean		xor_on;
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

static Boolean XorMode (Boolean xorOn)
{
	Boolean	xorWasOn;

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
/* ... RWS */

Widget start_drawing(Widget window)
{ WindowData *wdata;
/*  int mode;             Halbe: unused */
  XGCValues gcvalues;

  XtVaGetValues(window, XtNuserData, &wdata, NULL);
  base_x         = wdata->x0;
  base_y         = wdata->y0;
  current_picture= XtWindow(wdata->picture);
  my_gc          = wdata->window_gc;
  curx           = wdata->curx;
  cury           = wdata->cury;
  pen            = wdata->pen;
  XtVaGetValues(wdata->picture, XtNdepth, &my_depth, NULL);
  XGetGCValues(display,wdata->window_gc,GCFunction,&gcvalues);

  XorMode (gcvalues.function == GXxor);

#ifdef DEBUG
  fprintf(stderr,"start drawing: x0:%d,y0:%d\n",base_x,base_y);
#endif

  return window;
}

Widget end_drawing(Widget window)
{ WindowData *wdata;

  XtVaGetValues(window, XtNuserData, &wdata, NULL);
  wdata->curx=curx;
  wdata->cury=cury;
  wdata->pen=pen;

  XorMode (False);

  return window;
}


/****************************************************/
/* Pen and line drawing primitives for use in Clean */
/****************************************************/

/* pen and line drawing */

/* RWS
	Routines that imitate the Mac QuickDraw drawing model, only work
	for vertical and horizontal lines and rectangles.
*/

static struct
{
	int height, width, size;
} pen_info;

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

Picture hide_pen(p)
Picture p;
{ 
  pen=0;
  return p;
}

Picture show_pen(p)
Picture p;
{
  pen=1;
  return p;
}

void get_pen(p,x,y)
Picture p;
int *x;
int *y;
{
/* RWS:
	This function is not used, but was wrong anyway
  *x=curx;
  *y=cury;
*/
	*x=curx+base_x;
	*y=cury+base_y;
/* */
}

Picture pen_size(/* RWS size */ width, height ,p)
/* RWS
int size;
*/
int width;
int height;
Picture p;
{
/* RWS */
  int size;

  pen_info.height=height;
  pen_info.width=width;
  size=(height+width)/2; /* this doesn't make sense, but it's the
							same on OS/2 */
  pen_info.size=size;

/* */

  XSetLineAttributes(display,my_gc,size, LineSolid,CapButt,JoinMiter);

  return p;
}  

Picture pen_mode(mode,p)
int mode;
Picture p;
{
  XSetFunction(display,my_gc,mode);

  XorMode (mode == GXxor);

  return p;
}

Picture pen_pattern(int pattern, Picture p)
{ switch(pattern)
  { case 100:
      XSetFillStyle(display,my_gc,FillSolid);
      break;
    case 75: 
      XSetFillStyle(display,my_gc,FillOpaqueStippled);
      XSetStipple(display,my_gc,pattern_75);
      break;
    case 50:
      XSetFillStyle(display,my_gc,FillOpaqueStippled);
      XSetStipple(display,my_gc,pattern_50);
      break;
    case 25:
      XSetFillStyle(display,my_gc,FillOpaqueStippled);
      XSetStipple(display,my_gc,pattern_25);
      break;
    case 0:
      XSetFillStyle(display,my_gc,FillOpaqueStippled);
      XSetStipple(display,my_gc,pattern_0);
      break;
    default:
  };

  return p;
}

Picture pen_normal(p)
Picture p;
{
  pen_size(1);
  pen_mode(GXcopy);

  return p;
}

Picture line_to(x,y,p)
int x,y;
Picture p;
{
/* RWS
  XDrawLine(display,current_picture,my_gc,
            curx,cury,x-base_x,y-base_y);
*/
  DrawLine(display,current_picture,my_gc,
            curx,cury,x-base_x,y-base_y);
/* */
  curx=x-base_x;
  cury=y-base_y;

  return p;
}

Picture move_to(x,y,p)
int x,y;
Picture p;
{

  if(pen) /* we should draw! */
    return (line_to(x,y,p));
  else
  { 
    curx=x-base_x;
    cury=y-base_y;
    return p;
  };
}

Picture move_relative(x,y,p)
int x,y;
Picture p;
{
  curx+=x;
  cury+=y;

  return p;
}

Picture line_relative(x,y,p)
int x,y;
Picture p;
{
  int xd,yd;     
  xd=curx+x;
  yd=cury+y;
/* RWS
  XDrawLine(display,current_picture,my_gc,
            curx,cury,xd,yd);
*/
  DrawLine(display,current_picture,my_gc,
            curx,cury,xd,yd);
/* */
  curx=xd;
  cury=yd;

  return p;
}

/***************************/
/* Text drawing primitives */
/***************************/

Picture draw_string(s,p)
CLEAN_STRING s;
Picture p;
{ char *cs;
  int function;
  XGCValues gcvalues;
  WindowData *wdata;

  cs=cstring(s);
  XtVaGetValues(p,XtNuserData,&wdata,NULL);
  XGetGCValues(display,my_gc,GCFunction,&gcvalues);
  function=gcvalues.function;

  /* We only allow or/xor/clear textmode drawing, otherwise we
     will use or textmode. */
  if(!(function == GXor || function == GXxor || function == GXclear
		|| function == GXcopy))
    XSetFunction(display, my_gc, GXcopy);

  XDrawString(display,current_picture,my_gc,curx,cury,cs,s->length);
  curx+=XTextWidth(wdata->font_info,cs,s->length);

  /* Set drawing mode back. */
  XSetFunction(display, my_gc, function);

  XtFree(cs);

#ifdef DEBUG
  fprintf(stderr, "Drawing string <%s> into window 0x%X at (%d, %d)\n", cs, p,
                                curx, cury);
#endif

  return p;
}

/********************/
/* Drawing in color */
/********************/
int get_color(int index)
{ return (int)clean_standard_colors[index];
}
  
Picture foreground_color(c,p)
int c;
Picture p;
{ 
  Boolean xorMode;

  xorMode	= XorMode (False);
  XSetForeground(display,my_gc,(unsigned long)c);
  XorMode (xorMode);

#ifdef DEBUG
  fprintf(stderr, "Foregroundcolor:%ld\n", (unsigned long)c);
#endif

  return p;
}

Picture background_color(c,p)
int c;
Picture p;
{
  Boolean	xorMode;

  xorMode	= XorMode (False);
  XSetBackground(display,my_gc,(unsigned long)c);
  XorMode (xorMode);

  return p;
}

Picture rgb_fg_color(double r,double g,double b,Picture p)
{ 
  XColor color;

  color.red   = (short)(r*65535.0);
  color.green = (short)(g*65535.0);
  color.blue  = (short)(b*65535.0);
  color.flags = DoRed|DoGreen|DoBlue; /* which color components */

  XAllocColor(display,my_colors,&color);
  XSetForeground(display,my_gc,color.pixel);

  return p;
}

Picture rgb_bg_color(double r,double g,double b,Picture p)
{
  XColor color;

  color.red   = (short)(r*65535.0);
  color.green = (short)(g*65535.0);
  color.blue  = (short)(b*65535.0);
  color.flags = DoRed|DoGreen|DoBlue; /* which color components */

  XAllocColor(display,my_colors,&color);
  XSetBackground(display,my_gc,color.pixel);

  return p;
}

Picture set_color_pixel(int x,int y,double r,double g,double b,Picture p)
{ XGCValues gc_values;

  XGetGCValues(display, my_gc, GCForeground, &gc_values);
  rgb_fg_color(r,g,b,p);
  XDrawPoint(display,current_picture,my_gc,x,y);
  XSetForeground(display,my_gc,gc_values.foreground);

  return p;
}

/**************************************/
/* Graphic operations with lines etc. */
/**************************************/

Picture draw_line(int x1,int y1,int x2,int y2,Picture p)
{
/* RWS XDrawLine(display,current_picture,my_gc,x1-base_x,y1-base_y,
            x2-base_x,y2-base_y);
*/
	DrawLine(display,current_picture,my_gc,x1-base_x,y1-base_y,
            x2-base_x,y2-base_y);
/* */
  return p;
}

Picture draw_point(int x,int y,Picture p)
{ XDrawPoint(display,current_picture,my_gc,x-base_x,y-base_y);
  return p;
}

/**************************************/
/* Graphic operations with rectangles */
/**************************************/

Picture frame_rectangle(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{
/* RWS  XDrawRectangle(display,current_picture,my_gc,
                 x1-base_x,y1-base_y,x2-x1-1,y2-y1-1);
*/

  DrawRectangle (display, current_picture, my_gc,
                 x1 - base_x, y1 - base_y, x2 - base_x, y2 - base_y);

#ifdef DEBUG
  fprintf(stderr,"Rectangle drawn ....%d,%d,%d,%d\n",
          x1,y1,x2,y2);
#endif 

  return p;
}

Picture paint_rectangle(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{
   XFillRectangle(display,current_picture,my_gc,
                  x1-base_x,y1-base_y,x2-x1,y2-y1);

#ifdef DEBUG
  fprintf(stderr, "Paint rectangle: %d,%d,%d,%d)\n", x1, y1, x2, y2);
#endif

   return p;
}

Picture erase_rectangle(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCBackground|GCFunction|GCForeground,
               &gc_values);
  
  XSetForeground(display,my_gc,gc_values.background);
  XSetFunction(display,my_gc,GXcopy);
  paint_rectangle(x1,y1,x2,y2,p);
  XSetFunction(display,my_gc,gc_values.function);
  XSetForeground(display,my_gc,gc_values.foreground);

  return p;
}

Picture invert_rectangle(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCFunction,&gc_values);
  XSetFunction(display,my_gc,GXxor);
  paint_rectangle(x1,y1,x2,y2,p);
  XSetFunction(display,my_gc,gc_values.function);

  return p;
}

Picture move_rectangle(int x1,int y1,int x2,int y2, int xd, int yd,
                       Picture p)
{ XGCValues gc_values;
  unsigned int w,h;
  Pixmap pixmap;

  w=x2-x1;
  h=y2-y1;

  if(w!=0 && h!=0) 
  { pixmap=XCreatePixmap(display,current_picture,w,h,my_depth);
    XGetGCValues(display,my_gc,GCGraphicsExposures,&gc_values);
    XSetGraphicsExposures(display,my_gc,True);
    XCopyArea(display,current_picture,pixmap,my_gc,x1-base_x,y1-base_y,w,h,0,0);
    XClearArea(display,current_picture,x1-base_x,y1-base_y,w,h,False);
    XCopyArea(display,pixmap,current_picture,my_gc,0,0,w,h,xd-base_x,yd-base_y);
    XSetGraphicsExposures(display,my_gc,gc_values.graphics_exposures);
    XFreePixmap(display,pixmap);
  };

  return p;
}

Picture copy_rectangle(int x1,int y1,int x2,int y2, int xd, int yd,
                       Picture p)
{ XGCValues gc_values;
  unsigned int w,h;
 
  w=x2-x1;
  h=y2-y1;
  
  if(w!=0 && h!=0)
  { XGetGCValues(display,my_gc,GCGraphicsExposures,&gc_values);
    XSetGraphicsExposures(display,my_gc,True);
    XCopyArea(display,current_picture,current_picture,my_gc,
                    x1-base_x,y1-base_y,w,h,xd-base_x,yd-base_y);
    XSetGraphicsExposures(display,my_gc,gc_values.graphics_exposures);
  };
 
  return p;
}


/***********************************************/
/* Graphics operations with rounded rectangles */
/***********************************************/

Picture frame_round_rectangle(int x1,int y1, int x2, int y2, int width,
                              int height, Picture p)
{ 
  XmuDrawRoundedRectangle(display,current_picture,my_gc,x1-base_x,y1-base_y,
                          x2-x1-1,y2-y1-1,width>>1,height>>1);
  return p;
}

Picture paint_round_rectangle(int x1,int y1, int x2, int y2, int width,
                              int height, Picture p)
{
  XmuFillRoundedRectangle(display,current_picture,my_gc,x1-base_x,y1-base_y,
                          x2-x1,y2-y1,width>>1,height>>1);
  return p;
}

Picture erase_round_rectangle(int x1,int y1, int x2, int y2, int width,
                              int height, Picture p)
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCBackground|GCFunction|GCForeground,&gc_values);

  XSetForeground(display,my_gc,gc_values.background);
  XSetFunction(display,my_gc,GXcopy);
  paint_round_rectangle(x1,y1,x2,y2,width,height,p);
  XSetFunction(display,my_gc,gc_values.function);
  XSetForeground(display,my_gc,gc_values.foreground);

  return p;
}      

Picture invert_round_rectangle(int x1,int y1, int x2, int y2, int width,
                               int height, Picture p)
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCFunction,&gc_values);
  XSetFunction(display,my_gc,GXxor);
  paint_round_rectangle(x1,y1,x2,y2,width,height,p);
  XSetFunction(display,my_gc,gc_values.function);

  return p;
}


/**********************************/
/* Graphics operations with ovals */
/**********************************/

Picture frame_oval(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{
  XDrawArc(display,current_picture,my_gc,
                 x1-base_x,y1-base_y,x2-x1-1,y2-y1-1,0,64*360);

  return p;
}

Picture paint_oval(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{
   XFillArc(display,current_picture,my_gc,
                  x1-base_x,y1-base_y,x2-x1,y2-y1,0,64*360);

   return p;
}

Picture erase_oval(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCBackground|GCFunction|GCForeground,&gc_values);
  
  XSetForeground(display,my_gc,gc_values.background);
  XSetFunction(display,my_gc,GXcopy);
  paint_oval(x1,y1,x2,y2,p);
  XSetFunction(display,my_gc,gc_values.function);
  XSetForeground(display,my_gc,gc_values.foreground);

  return p;
}

Picture invert_oval(x1,y1,x2,y2,p)
int x1,y1,x2,y2;
Picture p;
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCFunction,&gc_values);
  XSetFunction(display,my_gc,GXxor);
  paint_oval(x1,y1,x2,y2,p);
  XSetFunction(display,my_gc,gc_values.function);

  return p;
}

/********************************/
/* Graphic operations with arcs */
/********************************/

Picture frame_arc(x1,y1,x2,y2,angle1,angle2,p)
int x1,y1,x2,y2;
int angle1,angle2;
Picture p;
{
  XDrawArc(display,current_picture,my_gc,
           x1-base_x,y1-base_y,x2-x1-1,y2-y1-1,angle1<<6,angle2<<6);

  return p;
}

Picture paint_arc(x1,y1,x2,y2,angle1,angle2,p)
int x1,y1,x2,y2;
int angle1,angle2;
Picture p;
{
   XFillArc(display,current_picture,my_gc,
            x1-base_x,y1-base_y,x2-x1,y2-y1,angle1<<6,angle2<<6);

   return p;
}

Picture erase_arc(x1,y1,x2,y2,angle1,angle2,p)
int x1,y1,x2,y2;
int angle1,angle2;
Picture p;
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCBackground|GCFunction|GCForeground,&gc_values);
  
  XSetForeground(display,my_gc,gc_values.background);
  XSetFunction(display,my_gc,GXcopy);
  paint_arc(x1,y1,x2,y2,angle1,angle2,p);
  XSetFunction(display,my_gc,gc_values.function);
  XSetForeground(display,my_gc,gc_values.foreground);

  return p;
}

Picture invert_arc(x1,y1,x2,y2,angle1,angle2,p)
int x1,y1,x2,y2;
int angle1,angle2;
Picture p;
{ XGCValues gc_values;

  XGetGCValues(display,my_gc,GCFunction,&gc_values);
  XSetFunction(display,my_gc,GXxor);
  paint_arc(x1,y1,x2,y2,angle1,angle1,p);
  XSetFunction(display,my_gc,gc_values.function);

  return p;
}

/***************************************/
/* Graphic operations with polygons.   */
/***************************************/

XPoint* alloc_polygon(int n)
{ XPoint *p;
  p = (XPoint *)XtMalloc(sizeof(XPoint)*n);
  return p;
}

Picture free_polygon(XPoint *p, Picture pic)
{ XtFree((XtPointer)p); /* Halbe: was *p */

  return pic;
}

XPoint* set_polygon_point(XPoint *p,int n,int x,int y)
{ 
  p[n].x = (short)x;
  p[n].y = (short)y;

  return p;
}

Picture frame_polygon(XPoint *poly,int n,int x, int y, Picture p)
{ poly[0].x = (short)(x-base_x);
  poly[0].y = (short)(y-base_y);

  XDrawLines(display,current_picture,my_gc,poly,n,CoordModePrevious);

  return p;
}

Picture paint_polygon(XPoint *poly,int n,int x,int y,Picture p)
{ poly[0].x = (short)(x-base_x);
  poly[0].y = (short)(y-base_y);
 
  XFillPolygon(display,current_picture,my_gc,poly,n,Complex,CoordModePrevious);

  return p;
}

Picture erase_polygon(XPoint *poly,int n,int x,int y,Picture p)
{ XGCValues gc_values;
 
  XGetGCValues(display,my_gc,GCBackground|GCFunction|GCForeground,
               &gc_values);
  
  XSetForeground(display,my_gc,gc_values.background);
  XSetFunction(display,my_gc,GXcopy);
  paint_polygon(poly,n,x,y,p);
  XSetFunction(display,my_gc,gc_values.function);
  XSetForeground(display,my_gc,gc_values.foreground);
 
  return p;
}

Picture invert_polygon(XPoint *poly,int n,int x,int y,Picture p)
{ XGCValues gc_values;
 
  XGetGCValues(display,my_gc,GCFunction,&gc_values);
  XSetFunction(display,my_gc,GXxor);
  paint_polygon(poly,n,x,y,p);
  XSetFunction(display,my_gc,gc_values.function);
 
  return p;
}


/****************************************/
/* Font functions.                      */
/****************************************/
char **all_fonts;
int NrOfAllFonts;

void add_font(char *font)
{ int i;
  int len;
  char *s;
  char *ss;

  s=strchr(font,'-');
  if(s==NULL) return;
  s++;
  s=strchr(s,'-');
  if(s==NULL) return;
  s++;
  ss=strchr(s,'-');
  if(ss==NULL) return;
  len=ss-s;
  i=0;
  while( (i<NrOfAllFonts) && (strncmp(s,all_fonts[i],len)!=0)) i++;
  if(i==NrOfAllFonts)
  { all_fonts[NrOfAllFonts]=ss=(char *)XtMalloc(len+1);
    strncpy(ss,s,len);
    ss[len]=(char)0;
    NrOfAllFonts++;
  };
}

void retrieve_all_fonts(char **fonts,int count)
{ int i;
  int current_max_fonts=50;
  NrOfAllFonts=0;
  
  all_fonts=(char **)XtMalloc(current_max_fonts * sizeof(char *));
  for(i=0;i<count;i++)
  { if(NrOfAllFonts==current_max_fonts)
    { current_max_fonts+=50;
      all_fonts=(char **)XtRealloc((XtPointer)all_fonts,
                                   current_max_fonts * sizeof(char*));
    };
    add_font(fonts[i]);
  };
}

void read_all_fonts(void)
{ char **fonts;
  int count;

  fonts=XListFonts(display,"*",2000,&count);
  if(count==0)
  { fprintf(stderr,"Fatal error: no fonts available.\n");
    exit(-1);
  };

  retrieve_all_fonts(fonts,count);
  XFreeFontNames(fonts);
  AllFontsRead=True;
}

int get_number_fonts(int dummy)
{ if(!AllFontsRead) read_all_fonts();
  return NrOfAllFonts;
}

extern CLEAN_STRING result_clean_string;

CLEAN_STRING get_font_name(int index)
{ char *s;
  int len;

  s=all_fonts[index];
  len=strlen(s);
  XtFree((XtPointer)result_clean_string);
  result_clean_string=(CLEAN_STRING)XtMalloc(sizeof(int)+len+1);
  result_clean_string->length=len;
  memcpy(result_clean_string->characters,s,len+1);

  return result_clean_string;
}

void get_font_info(Widget pic, int *ascent, int *descent,
                   int *widmax, int *leading,Widget *rpic)
{ XFontStruct *font_info;
  WindowData *wdata;

  XtVaGetValues(pic, XtNuserData, &wdata, NULL);
  font_info=wdata->font_info;
  *ascent =(font_info->max_bounds).ascent;
  *descent=(font_info->max_bounds).descent;
  *widmax =(int)((font_info->max_bounds).width);
  *leading=(font_info->descent)-*descent+(font_info->ascent)-*ascent;
  *rpic   =pic;
}

void get_font_font_info(int font,int *ascent,int *descent,int *widmax,
                        int *leading)
{ XFontStruct *font_info;

  font_info=(XFontStruct *)font;
  *ascent =(font_info->max_bounds).ascent;
  *descent=(font_info->max_bounds).descent;
  *widmax =(int)((font_info->max_bounds).width);
/* RWS do the same thing as in get_font_info
  *leading=(font_info->descent)-(*descent);
*/
  *leading=(font_info->descent)-*descent+(font_info->ascent)-*ascent;
}

void get_string_width(Widget pic, CLEAN_STRING cs, int *width, Widget *rpic)
{ WindowData *wdata;
  char *s;

  s=cstring(cs);
  XtVaGetValues(pic, XtNuserData, &wdata, NULL);
  *width=XTextWidth(wdata->font_info, s, cs->length);
  *rpic =pic;
  free(s);
}

int get_font_string_width(int font, CLEAN_STRING cs)
{ int width;
  char *s;

  s=cstring(cs);
  width=XTextWidth((XFontStruct *)font,s,cs->length); 
  XtFree(s);


  return width;
}

void set_new_font(WindowData *wdata)
{ char *new_font;
  int number_of_fonts;
  char **font_names;

  new_font=XtMalloc(strlen(wdata->font_name)+
                    strlen(wdata->font_style)+
                    strlen(wdata->font_size)+1);
  strcpy(new_font,wdata->font_name);
  strcat(new_font,wdata->font_style);
  strcat(new_font,wdata->font_size);

#ifdef DEBUG
  fprintf(stderr, "new font:%s\n", new_font);
#endif

  
  font_names=XListFonts(display, new_font, 1, &number_of_fonts);
#ifdef DEBUG
  fprintf(stderr, "matching fonts: %d\n", number_of_fonts);
#endif

  if(number_of_fonts>0)
  { wdata->font_info = XLoadQueryFont(display, new_font);
    XSetFont(display, wdata->window_gc, wdata->font_info->fid);
    XFreeFontNames(font_names);
    #ifdef DEBUG 
       fprintf(stderr, "font ready\n");
    #endif
  };

  XtFree(new_font);
}
  

void set_default_font(WindowData *wdata)
{  
  wdata->font_name =XtMalloc(strlen("*courier")+1);
  wdata->font_style=XtMalloc(strlen("-medium-r-normal-*-*-")+1);
  wdata->font_size =XtMalloc(strlen("120-*-*-*-*-*-*")+1);
  strcpy(wdata->font_name,"*courier");
  strcpy(wdata->font_style,"-medium-r-normal-*-*-");
  strcpy(wdata->font_size,"120-*-*-*-*-*-*");
  wdata->font_info=default_font;
  XSetFont(display,wdata->window_gc,default_font->fid);
}

XFontStruct *select_default_font(int dummy)
{
  return default_font;
}

Widget set_font(Widget pic, XFontStruct *info, CLEAN_STRING font_name,
                CLEAN_STRING font_style, CLEAN_STRING font_size)
{ WindowData *wdata;

  XtVaGetValues(pic, XtNuserData, &wdata, NULL);
  XtFree(wdata->font_name);
  wdata->font_name=cstring(font_name);
  XtFree(wdata->font_style);
  wdata->font_style=cstring(font_style);
  XtFree(wdata->font_size);
  wdata->font_size=cstring(font_size);
  wdata->font_info=info;
  XSetFont(display, wdata->window_gc, info->fid);

  return pic;
}

Widget set_font_name(Widget pic, CLEAN_STRING font_name)
{ WindowData *wdata;

  XtVaGetValues(pic, XtNuserData, &wdata, NULL);
  XtFree(wdata->font_name);
  wdata->font_name=cstring(font_name);
  set_new_font(wdata);

  return pic;
} 

Widget set_font_style(Widget pic, CLEAN_STRING font_style)
{ WindowData *wdata;

  XtVaGetValues(pic, XtNuserData, &wdata, NULL);
  XtFree(wdata->font_style);
  wdata->font_style=cstring(font_style);
  set_new_font(wdata);

  return pic;
}

Widget set_font_size(Widget pic, CLEAN_STRING font_size)
{ WindowData *wdata;

  XtVaGetValues(pic, XtNuserData, &wdata, NULL);
  XtFree(wdata->font_size);
  wdata->font_size=cstring(font_size);
  set_new_font(wdata);

  return pic;
}

XFontStruct *select_font(CLEAN_STRING font)
{ char *s;
/*  char **fonts;            Halbe: unused */
  XFontStruct *font_info;
/*  int n;                   Halbe: unused */

  check_init_toplevelx();  /* Halbe: Initialize the toolkit, if necessary */

  s=cstring(font);
  font_info=XLoadQueryFont(display,s);

  if(font_info==NULL)
  { 
    return (XFontStruct *)0;
  }
  else
  {
    return font_info;
  };
}

/*****************************************************/
/* Return the styles and sizes for a given font name */
/*****************************************************/

char test_font[80];

void get_font_styles(CLEAN_STRING font_name, int *normal, int *bold,
                     int *demibold, int *italic, int *condensed)
{ char *s; 
/*  char *t;          Halbe: unused */
  char **fonts;
  int n;

  s=cstring(font_name);

  /* check for normal style */
  strcpy(test_font,s);
  strcat(test_font,"-medium-r-normal*");
  fonts=XListFonts(display, test_font, 10, &n);
  if(n>0) { *normal=1;
            XFreeFontNames(fonts);
          };

  /* check for bold style */
  strcpy(test_font,s);
  strcat(test_font,"-bold-r-normal");
  fonts=XListFonts(display, test_font, 10, &n);
  if(n>0) { *bold=1;
            XFreeFontNames(fonts);
          };

  /* checking for demibold style */
  strcpy(test_font,s);
  strcat(test_font,"-demibold-r-normal");
  fonts=XListFonts(display, test_font, 10, &n);
  if(n>0) { *demibold=1;
            XFreeFontNames(fonts);
          };

  /* check for italic style */
  strcpy(test_font,s);
  strcat(test_font,"-medium-i-normal");
  fonts=XListFonts(display, test_font, 10, &n);
  if(n>0) { *italic=1;
            XFreeFontNames(fonts);
          };

  /* check for condensed style */
  strcpy(test_font,s);
  strcat(test_font,"-medium-r-condensed");
  fonts=XListFonts(display, test_font, 10, &n);
  if(n>0) { *condensed=1;
            XFreeFontNames(fonts);
          };

  XtFree(s);
}

int font_sizes[100];
int number_font_sizes;

int font_size_cmp(int *x,int *y)
{ return (*y)<(*x);
}

typedef int (*QSortCompareProc)(const void *, const void *);
void retrieve_sizes(int len,char **fonts, int n)
{ int j,i;
  int size;
  char *s;

  number_font_sizes=0;
  for(i=0;i<n;i++)
  { 
    s=fonts[i];
    for(j=0;j<8;j++)
    { s=strchr(s,'-');
      s++;
    };
    size=atoi(s);
    j=0;
    while((j<number_font_sizes) && (font_sizes[j]!=size)) j++;
    if(j==number_font_sizes)
    { font_sizes[j]=size;
      number_font_sizes++;
    };
  }

  qsort(font_sizes,number_font_sizes,sizeof(int),
									(QSortCompareProc) font_size_cmp);

}
 
int get_font_sizes(CLEAN_STRING font_name)
{ /* int i;         Halbe: unused */
  int n;
  char *s;
  char **fonts;

  s=cstring(font_name);
  strcpy(test_font, s);
  strcat(test_font,"-medium-r-normal-*-*-*");
  fonts=XListFonts(display, test_font, 100, &n);

  retrieve_sizes(strlen(test_font),fonts,n);

  XtFree(s);
  XFreeFontNames(fonts);

  return number_font_sizes;
}

int get_one_font_size(int index)
{ 
  if(index==number_font_sizes) return 0;
  else return font_sizes[index];
}
