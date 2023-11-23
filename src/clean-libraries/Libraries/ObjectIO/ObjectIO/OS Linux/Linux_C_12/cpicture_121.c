/********************************************************************************************
	Clean OS Windows library module version 1.2.1.
	This module is part of the Clean Object I/O library, version 1.2.1,
	for the Windows platform.
********************************************************************************************/

/********************************************************************************************
	About this module:
	Routines related to drawing.
********************************************************************************************/
#include "util_121.h"
#include <pango/pango.h>
#include <pango/pangoft2.h>
#include "cpicture_121.h"
#include "cCrossCall_121.h"
#include "cCrossCallWindows_121.h"

extern void InitGTK();

const gchar* PEN_POS_KEY = "current-pen-position";

void WinGetDC (GtkWidget *widget, OS ios, GdkDrawable **outDraw, OS *oos)
{
	GdkWindow *window;
    printf("WinGetDC\n");
	window = GTK_BIN(GTK_BIN(widget)->child)->child->window;

	gdk_window_ref(window);
	*outDraw = GDK_DRAWABLE(window);
    *oos = ios;
}	/* WinGetDC */

OS WinReleaseDC(GtkWidget *widget, GdkDrawable *drawable, OS ios)
{
    printf("WinReleaseDC\n");
	gdk_window_unref(GDK_WINDOW(drawable));
	return ios;
}	/* WinReleaseDC */

gint OsMMtoVPixels(double mm)

{
    printf("OsMMtoVPixels\n");
  	InitGTK();
	return (int) ((mm*gdk_screen_height())/gdk_screen_height_mm());
}

gint OsMMtoHPixels(double mm)
{
    printf("OsMMtoHPixels\n");
  	InitGTK();
	return (int) ((mm*gdk_screen_width())/gdk_screen_width_mm());
}

/*------------------------------------*\
|									   |
|	   Helper functions 			   |
|									   |
\*------------------------------------*/

static GdkGC *theDrawGC, *theEraseGC, *theInvertGC;
static GdkFont *theFont;
static PangoFontDescription *theFontDesc;
static gint penSize;
static gint penPat;
static gint penMode;
static GdkColor penColor;
static GdkColor backColor;
static GdkPoint *thePolygon;
static gint thePolygonIndex;
static GdkRegion *theClipRgn = NULL;


void WinInitPicture (gint size, gint mode, gint pr, gint pg, gint pb,
					 gint br, gint bg, gint bb, gint x, gint y,
                     CLEAN_STRING fname, gint fstyle, gint fsize,
                     gint ox, gint oy, GdkDrawable *inDraw, OS os,
					 GdkDrawable **outDraw, OS *oos)
{
    printf("WinInitPicture\n");
	penColor.pixel = 0;
	penColor.red   = pr*257;
	penColor.green = pg*257;
	penColor.blue  = pb*257;

	backColor.pixel = 0;
	backColor.red   = br*257;
	backColor.green = bg*257;
	backColor.blue  = bb*257;

	penSize = size;
	penMode = mode;

	if (inDraw)
	{
        printf("inDraw non-null\n");
		gdk_colormap_alloc_color(gdk_drawable_get_colormap(inDraw), &penColor, FALSE, FALSE);
		gdk_colormap_alloc_color(gdk_drawable_get_colormap(inDraw), &backColor, FALSE, FALSE);

		theDrawGC = gdk_gc_new(inDraw);
		gdk_gc_set_foreground(theDrawGC, &penColor);
		gdk_gc_set_background(theDrawGC, &backColor);
		gdk_gc_set_clip_origin(theDrawGC, 0, 0);
		gdk_gc_set_line_attributes(theDrawGC, size, GDK_LINE_SOLID, GDK_CAP_ROUND, GDK_JOIN_ROUND);

		theEraseGC = gdk_gc_new(inDraw);
		gdk_gc_set_foreground(theEraseGC, &backColor);
		gdk_gc_set_background(theEraseGC, &penColor);
		gdk_gc_set_clip_origin(theEraseGC, 0, 0);
		gdk_gc_set_line_attributes(theEraseGC, size, GDK_LINE_SOLID, GDK_CAP_ROUND, GDK_JOIN_ROUND);

		theInvertGC = gdk_gc_new(inDraw);
		gdk_gc_set_foreground(theInvertGC, &penColor);
		gdk_gc_set_background(theInvertGC, &backColor);
		gdk_gc_set_function(theInvertGC, GDK_INVERT);
		gdk_gc_set_clip_origin(theInvertGC, 0, 0);
	}
	else
	{
		theDrawGC = NULL;
		theEraseGC = NULL;
		theInvertGC = NULL;
	}

	theFontDesc = pango_font_description_new();
	pango_font_description_set_family(theFontDesc,cstring(fname));
	pango_font_description_set_weight(theFontDesc,(fstyle & iBold) ? PANGO_WEIGHT_BOLD : PANGO_WEIGHT_NORMAL);
	pango_font_description_set_style(theFontDesc,(fstyle & iItalic) ? PANGO_STYLE_ITALIC : PANGO_STYLE_NORMAL);
	/*	plf->lfUnderline = (style & iUnderline) ? TRUE : FALSE; */
	/*	plf->lfStrikeOut = (style & iStrikeOut) ? TRUE : FALSE; */
	pango_font_description_set_size(theFontDesc, fsize*PANGO_SCALE);
	theFont = gdk_font_from_description(theFontDesc);

    /*
  	theClipRgn = NULL;
  	if (clipRgn)
  	{
		theClipRgn = gdk_region_copy(clipRgn);
  		if (theDrawGC)   gdk_gc_set_clip_region(theDrawGC,   theClipRgn);
		if (theEraseGC)  gdk_gc_set_clip_region(theEraseGC,  theClipRgn);
		if (theInvertGC) gdk_gc_set_clip_region(theInvertGC, theClipRgn);
	}
    */

    /* Remember the pen position */
    InternalSetPenPos(inDraw, x, y);

    *outDraw = inDraw;
    *oos = os;
    printf("WinInitPicture -- returning\n");
}	/* WinInitPicture */

void WinDonePicture (GdkDrawable *inDraw, OS ios,
                gint *size, gint *mode, gint *pr, gint *pg, gint *pb, gint *br,
                gint *bg, gint *bb, gint *x, gint *y, CLEAN_STRING *fname,
                gint *fstyle, gint *fsize, GdkDrawable **outDraw, OS* oos)
{
    GdkPoint *p;
    PangoContext *pc;
    PangoFontDescription *fontDesc;
    gchar *fontDescString;
    GtkWidget *widget;
    gboolean inDrawIsWidget;

    printf("WinDonePicture\n");
    inDrawIsWidget = GTK_IS_WIDGET(inDraw);

	if (inDraw)
	{
        printf("inDraw non-null\n");
		gdk_colormap_free_colors(gdk_drawable_get_colormap(inDraw), &penColor, 1);
		gdk_colormap_free_colors(gdk_drawable_get_colormap(inDraw), &backColor, 1);
	}

	if (theFont)
	{
		gdk_font_unref(theFont);
		theFont = NULL;
	}
	if (theFontDesc)
	{
		pango_font_description_free(theFontDesc);
		theFontDesc = NULL;
	}

	if (theDrawGC)   gdk_gc_unref(theDrawGC);
	if (theEraseGC)  gdk_gc_unref(theEraseGC);
	if (theInvertGC) gdk_gc_unref(theInvertGC);

	if (theClipRgn)
	{
	   	gdk_region_destroy(theClipRgn);
	   	theClipRgn = NULL;
	}

	*size = penSize;
	*mode = penMode;

	*pr = penColor.red/257;
	*pg = penColor.green/257;
	*pb = penColor.blue/257;

	*br = backColor.red/257;
	*bg = backColor.green/257;
	*bb = backColor.blue/257;

    /* inDraw may not have font context */
	*outDraw  = inDraw;
    if (! inDrawIsWidget)
    {
        widget = gtk_label_new(NULL);
    }
    else
    {
        widget = GTK_WIDGET(inDraw);
    }

    pc = gtk_widget_get_pango_context(widget);

    fontDesc = pango_context_get_font_description(pc);

    InternalGetPenPos(inDraw, x, y);
    
    *fname = cleanstring(pango_font_description_get_family(fontDesc));
	*fstyle= pango_font_description_get_style(fontDesc);
	*fsize = pango_font_description_get_size(fontDesc);

    g_object_unref(G_OBJECT(pc));
    if (! inDrawIsWidget)
    {
        gtk_widget_destroy(widget);
    }

    *oos = ios;    
    printf("WinDonePicture -- returning\n");
}	/* WinDonePicture */

/*	PA: Set and get the clipping region of a picture:
		WinClipRgnPicture    takes the intersection of the argument clipRgn with the current clipping region.
		WinSetClipRgnPicture sets the argument clipRgn as the new clipping region.
		WinGetClipRgnPicture gets the current clipping region.
*/
void WinClipRgnPicture (GdkRegion *region, GdkDrawable *drawable, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
	GdkRectangle *rectangles;
	gint n_rectangles, i;

    printf("WinClipRgnPicture\n");
	if (theClipRgn != NULL)
    {
		gdk_region_intersect(theClipRgn, region);
    }
	else
	{
		if (region)
			theClipRgn = gdk_region_copy(region);
	}

	if (theDrawGC)   gdk_gc_set_clip_region(theDrawGC,   theClipRgn);
	if (theEraseGC)  gdk_gc_set_clip_region(theEraseGC,  theClipRgn);
	if (theInvertGC) gdk_gc_set_clip_region(theInvertGC, theClipRgn);

    *outDraw = drawable;
    *oos = ios;
}	/* WinClipRgnPicture */

void WinSetClipRgnPicture (GdkRegion *region, GdkDrawable *drawable, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
	GdkRectangle *rectangles;
	gint n_rectangles, i;

    printf("WinSetClipRgnPicture\n");
	if (theClipRgn != NULL)
    {
		gdk_region_destroy(theClipRgn);
    }

	theClipRgn = region ? gdk_region_copy(region) : NULL;

	if (theDrawGC)   gdk_gc_set_clip_region(theDrawGC,   theClipRgn);
	if (theEraseGC)  gdk_gc_set_clip_region(theEraseGC,  theClipRgn);
	if (theInvertGC) gdk_gc_set_clip_region(theInvertGC, theClipRgn);
    *outDraw = drawable;
    *oos = ios;
}	/* WinSetClipRgnPicture */

void WinGetClipRgnPicture (GdkDrawable *drawable,OS ios,
                GdkRegion **outRegion, GdkDrawable **outDraw, OS* oos)
{
	GdkRegion *r = NULL;

    printf("WinGetClipRgnPicture\n");
	if (theClipRgn)
	{
		r = gdk_region_copy(theClipRgn);
	}

	*outRegion = r;
    *outDraw = drawable;
    *oos = ios;
}	/* WinGetClipRgnPicture */


/*	Operations to create, modify, and destroy polygon shapes.
*/

void WinAllocPolyShape (gint size, OS ios, GdkPoint **outPoint, OS *oos)
{
    printf("WinAllocPolyShape\n");
    *outPoint = g_new(GdkPoint,1);
    *oos = ios;
}	/* WinAllocPolyShape */

OS WinSetPolyPoint (gint i, gint x, gint y, GdkPoint *shape, OS os)
{
    printf("WinSetPolyPoint\n");
	shape[i].x = x;
	shape[i].y = y;

    return (os);
}	/* WinSetPolyPoint */

OS WinFreePolyShape (GdkPoint *shape, OS os)
{
    printf("WinFreePolyShape\n");
    gdk_drawable_unref(GDK_DRAWABLE(shape));
    return (os);
}	/* WinFreePolyShape */


/*
 * Operations to create, modify and destroy regions.
 */
GdkRegion *WinCreateEmptyRgn()
{
    printf("WinCreateEmptyRgn\n");
	return gdk_region_new();
}	/* WinCreateEmptyRgn */

void WinCreateRectRgn (gint nLeftRect, gint nTopRect, gint nRightRect,
                gint nBottomRect, OS ios, GdkRegion **rgn, OS *oos)
{
	GdkRectangle rectangle;
    printf("WinCreateRectRgn\n");
	rectangle.x = nLeftRect;
	rectangle.y = nTopRect;
	rectangle.width  = nRightRect-nLeftRect;
	rectangle.height = nBottomRect-nTopRect;
	*rgn = gdk_region_rectangle(&rectangle);
    *oos = ios;
}	/* WinCreateRectRgn */

void WinCreatePolygonRgn (GdkPoint *points, gint nPoints,
                gint fnPolyFillMode, OS ios, GdkRegion **rgn, OS *oos)
{
    printf("WinCreatePolygonRgn\n");
	*rgn = gdk_region_polygon(points,nPoints, fnPolyFillMode == 1 ? GDK_EVEN_ODD_RULE : GDK_WINDING_RULE);
    *oos = ios;
}	/* WinCreatePolygonRgn */

GdkRegion *WinUnionRgn (GdkRegion *src1, GdkRegion *src2)
{
	GdkRegion *dst = NULL;
    printf("WinUnionRgn\n");

	if (src1)
	{
		dst = gdk_region_copy(src1);
		gdk_region_union(dst, src2);
	}

	return dst;
}	/* WinUnionRgn */

GdkRegion *WinSectRgn (GdkRegion *src1, GdkRegion *src2)
{
	GdkRegion *dst = src2;
    printf("WinSectRgn\n");

	if (src1)
	{
		dst = gdk_region_copy(src1);
		gdk_region_intersect(dst, src2);
	}

	return dst;
}	/* WinSectRgn */

GdkRegion *WinDiffRgn (GdkRegion *src1, GdkRegion *src2)
{
	GdkRegion *dst = NULL;
    printf("WinDiffRgn\n");

	if (src1)
	{
		dst = gdk_region_copy(src1);
		gdk_region_subtract(dst, src2);
	};

	return dst;
}	/* WinDiffRgn */

GdkRegion *WinXorRgn (GdkRegion *src1, GdkRegion *src2)
{
	GdkRegion *dst = NULL;
    printf("WinXorRgn\n");

	if (src1)
	{
		dst = gdk_region_copy(src1);
		gdk_region_xor(dst, src2);
	}

	return dst;
}	/* WinXorRgn */

void WinGetRgnBox (GdkRegion *region, OS ios, gint *left, gint *top, gint *right,
                gint *bottom, gboolean *isrect, gboolean *isempty, OS *oos)
{
	GdkRegion *tempRegion;
	GdkRectangle rectangle;
    printf("WinGetRgnBox\n");

	gdk_region_get_clipbox(region,&rectangle);
	tempRegion = gdk_region_rectangle(&rectangle);

	*left   = rectangle.x;
	*top    = rectangle.y;
	*right  = rectangle.x+rectangle.width;
	*bottom = rectangle.y+rectangle.height;
	*isrect  = gdk_region_equal(region, tempRegion);

	gdk_region_destroy(tempRegion);

    *oos = ios;
}	/* WinGetRgnBox */

gboolean WinIsEmptyRgn(GdkRegion *region)
{
    printf("WinIsEmptyRgn\n");
	return gdk_region_empty(region);
}

void WinDisposeRgn (GdkRegion *region)
{
    printf("WinDisposeRgn\n");
	gdk_region_destroy(region);
}

/*------------------------------------*\
|	   Interface functions			   |
\*------------------------------------*/

void WinSetPenSize (gint size, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinSetPenSize\n");
	if (theDrawGC)  gdk_gc_set_line_attributes(theDrawGC,  size, GDK_LINE_SOLID, GDK_CAP_ROUND, GDK_JOIN_ROUND);
	if (theEraseGC) gdk_gc_set_line_attributes(theEraseGC, size, GDK_LINE_SOLID, GDK_CAP_ROUND, GDK_JOIN_ROUND);
	penSize = size;
    *outDraw = inDraw;
    *oos = ios;
}	/* WinSetPenSize */

void WinSetPenColor (gint red, gint green, gint blue, GdkDrawable *inDraw,
                OS ios, GdkDrawable **outDraw, OS* oos)
{
    printf("WinSetPenColor\n");
	if (inDraw)
	{
		gdk_colormap_free_colors(gdk_drawable_get_colormap(inDraw), &backColor, 1);
		penColor.pixel = 0;
		penColor.red   = red*257;
		penColor.green = green*257;
		penColor.blue  = blue*257;
		gdk_colormap_alloc_color(gdk_drawable_get_colormap(inDraw), &penColor, FALSE, FALSE);

		gdk_gc_set_foreground(theDrawGC, &penColor);
		gdk_gc_set_background(theEraseGC, &penColor);
		gdk_gc_set_foreground(theInvertGC, &penColor);
	}
    *outDraw = inDraw;
    *oos = ios;
}	/* WinSetPenColor */

void WinSetBackColor (gint red, gint green, gint blue, GdkDrawable *inDraw,
                OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinSetBackColor\n");
	if (inDraw)
	{
		gdk_colormap_free_colors(gdk_drawable_get_colormap(inDraw), &backColor, 1);
		backColor.pixel = 0;
		backColor.red   = red*257;
		backColor.green = green*257;
		backColor.blue  = blue*257;
		gdk_colormap_alloc_color(gdk_drawable_get_colormap(inDraw), &backColor, FALSE, FALSE);

		gdk_gc_set_background(theDrawGC, &backColor);
		gdk_gc_set_foreground(theEraseGC, &backColor);
		gdk_gc_set_background(theInvertGC, &backColor);
	}
    *outDraw = inDraw;
    *oos = ios;
}	/* WinSetBackColor */

void WinSetMode (gint mode, GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw,
                OS *oos)
{
    printf("WinSetMode\n");
	switch (mode)
	{
		case iModeCopy:
			penMode = iModeCopy;
			if (theDrawGC)   gdk_gc_set_function(theDrawGC,   GDK_COPY);
			if (theEraseGC)  gdk_gc_set_function(theEraseGC,  GDK_COPY);
			if (theInvertGC) gdk_gc_set_function(theInvertGC, GDK_COPY);
			break;
		case iModeXor:
			penMode = iModeXor;
			if (theDrawGC)   gdk_gc_set_function(theDrawGC,   GDK_XOR);
			if (theEraseGC)  gdk_gc_set_function(theEraseGC,  GDK_XOR);
			if (theInvertGC) gdk_gc_set_function(theInvertGC, GDK_XOR);
			break;
		case iModeOr:
		default:
			if (theDrawGC)   gdk_gc_set_function(theDrawGC,   GDK_OR);
			if (theEraseGC)  gdk_gc_set_function(theEraseGC,  GDK_OR);
			if (theInvertGC) gdk_gc_set_function(theInvertGC, GDK_OR);
			break;
	}
    *outDraw = inDraw;
    *oos = ios;
}	/* WinSetMode */

void WinSetPattern (gint pattern, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinSetPattern --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}	/* WinSetPattern */


/* changed by MW */
void WinDrawPoint (gint x, gint y, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawPoint\n");
	if (inDraw) gdk_draw_point(inDraw, theDrawGC, x, y);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawPoint */

void WinDrawLine (gint startx, gint starty, gint endx, gint endy,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawLine\n");
	if (inDraw) gdk_draw_line(inDraw, theDrawGC, startx, starty, endx, endy);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawLine */

void WinUndrawLine (gint startx, gint starty, gint endx, gint endy,
                GdkDrawable *inDraw)
{
    printf("WinUndrawLine\n");
	if (inDraw) gdk_draw_line(inDraw, theEraseGC, startx, starty, endx, endy);
}	/* WinDrawLine */

static gfloat PI = 3.1415926535897932384626433832795;

void WinDrawCurve (gint left, gint top, gint right, gint bottom, gint startradx,
                gint startrady, gint endradx, gint endrady, GdkDrawable *inDraw,
                OS ios, GdkDrawable **outDraw, OS *oos)
{
    gint x = left;
    gint y = top;
    gint rx = right;
    gint ry = bottom;
    gfloat from = startradx;
    gfloat to = endradx;
    gboolean clockwise = TRUE;
	gint cx, cy;

    printf("WinDrawCurve\n");
	if (inDraw)
	{
		cx	= x  - floor(cos(from)* abs(rx));
		cy	= y  + floor(sin(from)* abs(ry));

		from = (32*360*from)/PI;
		to   = (32*360*to)/PI;

		if (clockwise)
			gdk_draw_arc(inDraw, theDrawGC, FALSE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(from-PI/2),floor(from-to));
		else
			gdk_draw_arc(inDraw, theDrawGC, FALSE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(to-PI/2),floor(to-from));
	}
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawCurve */

void WinUndrawCurve(gint x, gint y, gint rx, gint ry, gfloat from, gfloat to,
                gboolean clockwise,GdkDrawable *drawable)
{
	gint cx, cy;

    printf("WinUndrawCurve\n");
	if (drawable)
	{
		cx	= x  - floor(cos(from)* abs(rx));
		cy	= y  + floor(sin(from)* abs(ry));

		from = (32*360*from)/PI;
		to   = (32*360*to)/PI;

		if (clockwise)
			gdk_draw_arc(drawable, theEraseGC, FALSE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(from-PI/2),floor(from-to));
		else
			gdk_draw_arc(drawable, theEraseGC, FALSE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(to-PI/2),floor(to-from));
	}
}	/* WinDrawCurve */

void WinDrawChar (gchar c, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    gint x, y;
    printf("WinDrawChar\n");

    InternalGetPenPos(inDraw, &x, &y);
	if (inDraw) gdk_draw_text(inDraw, theFont, theDrawGC, x, y, &c, 1);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawChar */

void WinUndrawChar(gint x, gint y, gchar c, GdkDrawable *drawable)
{
    printf("WinUndrawChar\n");
	if (drawable) gdk_draw_text(drawable,theFont,theEraseGC,x,y,&c,1);
}	/* WinDrawChar */

/*void WinDrawString (int x, int y, CLEAN_STRING string, GdkDrawable *inDraw, */
void WinDrawString (CLEAN_STRING string, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    gint x, y;
    printf("WinDrawString\n");

    InternalGetPenPos(inDraw, &x, &y);
    if (inDraw)
    {
            printf("Drawing %s\n", cstring(string));
            gdk_draw_string(inDraw, theFont, theDrawGC, x, y, cstring(string));
    }

    *outDraw = inDraw;
    *oos = ios;
    printf("Leaving drawstring.\n");
}	/* WinDrawString */

void WinUndrawString (gint x, gint y, gchar *string, GdkDrawable *drawable)
{
    printf("WinUndrawString\n");
	if (drawable) gdk_draw_string(drawable,theFont,theEraseGC,x,y,string);
}	/* WinUndrawString */

void WinDrawRectangle (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawRectangle\n");
	if (inDraw)
		gdk_draw_rectangle(inDraw, theDrawGC, FALSE,
	                   left, top,
	                   right-left-1,
	                   bot-top-1);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawRectangle */

void WinUndrawRectangle (gint left, gint top, gint right, gint bot,
                GdkDrawable *drawable)
{
    printf("WinUndrawRectangle\n");
	if (drawable)
    {
		gdk_draw_rectangle(drawable, theEraseGC, FALSE,
	                   left, top,
	                   right-left-1,
	                   bot-top-1);
    }
}	/* WinDrawRectangle */

void WinFillRectangle (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinFillRectangle\n");
	if (inDraw)
    {
		gdk_draw_rectangle(inDraw, theDrawGC, TRUE,
	                   left, top,
	                   right-left,
	                   bot-top);
    }
    *outDraw = inDraw;
    *oos = ios;
}	/* WinFillRectangle */

void WinEraseRectangle (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinEraseRectangle\n");
	if (inDraw)
    {
		gdk_draw_rectangle(inDraw, theEraseGC, TRUE,
					   left, top,
					   right-left,
	                   bot-top);
    }
    *outDraw = inDraw;
    *oos = ios;
}	/* WinEraseRectangle */

void WinInvertRectangle (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinInvertRectangle\n");
	if (inDraw)
    {
		gdk_draw_rectangle(inDraw, theInvertGC, TRUE,
					   left, top,
					   right-left,
	                   bot-top);
    }
    *outDraw = inDraw;
    *oos = ios;
}	/* WinInvertRectangle */

void WinMoveRectangleTo (gint left, gint top, gint right, gint bot, gint x,
                gint y, GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw,
                OS *oos)
{
	printf("WinMoveRectangleTo is not implemented\n");
	WinMoveRectangle (left,top, right,bot, x-left, y-top, inDraw,ios,
                    outDraw,oos);
}	/* WinMoveRectangleTo */

void WinMoveRectangle (gint left, gint top, gint right, gint bot, gint dx,
                gint dy, GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw,
                OS *oos)
{
	printf("WinMoveRectangle is not implemented\n");
/*	int w, h;
	HWND hwnd;

	hwnd = WindowFromDC (ihdc);
	if (hwnd != NULL)
	{
		RECT r;
		POINT p;

		GetClientRect (hwnd, &r);
		GetWindowOrgEx (ihdc, &p);
		left = max (left, r.left + p.x);
		top = max (top, r.top + p.y);
		right = min (right, r.right + p.x);
		bot = min (bot, r.bottom + p.y);
	}

	w = right - left;
	h = bot - top;

	WinCopyRectangle (left, top, right, bot, dx, dy, ihdc);

//	StartErasing (ihdc);

	if (dx > w || dy > h)
	{
		Rectangle (ihdc, left, top, right + 1, bot + 1);
		return;
	}

	if (dx < 0)
		Rectangle (ihdc, right - dx, top, right + 1, bot + 1);
	else
		Rectangle (ihdc, left, top, left + dx + 1, bot + 1);

	if (dy < 0)
		Rectangle (ihdc, left, bot - dy, right + 1, bot + 1);
	else
		Rectangle (ihdc, left, top, right + 1, top + dy + 1);*/
    *outDraw = inDraw;
    *oos = ios;
}	/* WinMoveRectangle */

void WinCopyRectangleTo (gint left, gint top, gint right, gint bot, gint x,
                gint y, GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw,
                OS *oos)
{
/*	WinCopyRectangle (left,top, right,bot, x-left,y-top, ihdc); */
	printf("WinCopyRectangleTo is not implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}	/* WinCopyRectangleTo */

void WinCopyRectangle (gint left, gint top, gint right, gint bottom, gint dx,
                gint dy, GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw,
                OS *oos)
{
/*	RECT scrollRect;

	scrollRect.left   = left;
	scrollRect.top    = top;
	scrollRect.right  = right;
	scrollRect.bottom = bottom;

	if (!ScrollDC (ihdc, dx,dy, &scrollRect, &scrollRect, NULL, NULL))
	{
		rMessageBox (NULL,MB_APPLMODAL,"WinCopyRectangle","ScrollDC failed");
	}*/
	printf("WinCopyRectangle is not implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}	/* WinCopyRectangle */

/*	PA: new routine to scroll part of the content of a window.
		It is assumed that scrolling happens in one direction only (dx<>0 && dy==0 || dx==0 && dy<>0).
		The result rect (oleft,otop,oright,obottom) is the bounding box of the update area that
		remains to be updated. If all are zero, then nothing needs to be updated.
*/
void WinScrollRectangle (gint left, gint top, gint right, gint bottom, gint dx,
                gint dy, GdkDrawable *inDraw, OS ios, gint *oleft, gint *otop,
                gint *oright, gint *obottom, GdkDrawable **outDraw, OS *oos)
{
/*	RECT scrollRect;
	HRGN hrgnUpdate, hrgnRect;

	scrollRect.left   = left;
	scrollRect.top    = top;
	scrollRect.right  = right;
	scrollRect.bottom = bottom;

	if (dx<0)
	{
		hrgnRect   = CreateRectRgn (right+dx-1,top-1,right+1,bottom+1);
	}
	else if (dx>0)
	{
		hrgnRect   = CreateRectRgn (left-1,top-1,left+dx+1,bottom+1);
	}
	else if (dy<0)
	{
		hrgnRect   = CreateRectRgn (left-1,bottom+dy-1,right+1,bottom+1);
	}
	else if (dy>0)
	{
		hrgnRect   = CreateRectRgn (left-1,top-1,right+1,top+dy+1);
	}
	else
	{
		hrgnRect   = CreateRectRgn (0,0,0,0);
	}
	hrgnUpdate = CreateRectRgn (0,0,1,1);

	if (!ScrollDC (ihdc, dx,dy, &scrollRect, &scrollRect, hrgnUpdate, NULL))
	{
		rMessageBox (NULL,MB_APPLMODAL,"WinScrollRectangle","ScrollDC failed");
	}
	else
	{
		if (CombineRgn (hrgnUpdate, hrgnUpdate, hrgnRect, RGN_DIFF) == NULLREGION)
		{
			*oleft   = 0;
			*otop    = 0;
			*oright  = 0;
			*obottom = 0;
		}
		else
		{
			RECT box;
			GetRgnBox (hrgnUpdate,&box);
			*oleft   = box.left;
			*otop    = box.top;
			*oright  = box.right;
			*obottom = box.bottom;
		}
	}
	DeleteObject (hrgnUpdate);
	DeleteObject (hrgnRect);
*/
	printf("WinScrollRectangle is not implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}	/* WinScrollRectangle */


void WinUndrawOval (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinUndrawOval\n");
	if (inDraw) gdk_draw_arc(inDraw,theEraseGC,FALSE,left,top,right-left,bot-top,0,64*360);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawOval */

void WinDrawOval (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawOval\n");
	if (inDraw) gdk_draw_arc(inDraw,theDrawGC,FALSE,left,top,right-left,bot-top,0,64*360);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawOval */

void WinFillOval (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinFillOval\n");
	if (inDraw) gdk_draw_arc(inDraw,theDrawGC,TRUE,left,top,right-left,bot-top,0,64*360);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinFillOval */

void WinEraseOval (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinEraseOval\n");
	if (inDraw) gdk_draw_arc(inDraw,theEraseGC,TRUE,left,top,right-left,bot-top,0,64*360);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinEraseOval */

void WinInvertOval (gint left, gint top, gint right, gint bot,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinInvertOval\n");
	if (inDraw) gdk_draw_arc(inDraw,theInvertGC,TRUE,left,top,right-left,bot-top,0,64*360);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinInvertOval */


void WinFillWedge (gint left, gint top, gint right, gint bottom, gint startradx,
                gint startrady, gint endradx, gint endrady, GdkDrawable *inDraw,
                OS ios, GdkDrawable **outDraw, OS *oos)
{
	gint cx, cy;
    gint x = left;
    gint y = top;
    gint rx = right;
    gint ry = bottom;
    gfloat from = startradx;
    gfloat to = startrady;
    gboolean clockwise = TRUE;

    printf("WinFillWedge\n");
	if (inDraw)
	{
		cx	= x  - floor(cos(from)* abs(rx));
		cy	= y  + floor(sin(from)* abs(ry));

		from = (32*360*from)/PI;
		to   = (32*360*to)/PI;

		if (clockwise)
			gdk_draw_arc(inDraw, theDrawGC, TRUE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(from-PI/2),floor(from-to));
		else
			gdk_draw_arc(inDraw, theDrawGC, TRUE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(to-PI/2),floor(to-from));
	}
    *outDraw = inDraw;
    *oos = ios;
}	/* WinFillWedge */

void WinEraseWedge (gint left, gint top, gint right, gint bottom,
                gint startradx, gint startrady, gint endradx, gint endrady,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
	gint cx, cy;
    gint x = left;
    gint y = top;
    gint rx = right;
    gint ry = bottom;
    gfloat from = startradx;
    gfloat to = startrady;
    gboolean clockwise = TRUE;

    printf("WinEraseWedge\n");
	if (inDraw)
	{
		cx	= x  - floor(cos(from)* abs(rx));
		cy	= y  + floor(sin(from)* abs(ry));

		from = (32*360*from)/PI;
		to   = (32*360*to)/PI;

		if (clockwise)
			gdk_draw_arc(inDraw, theEraseGC, TRUE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(from-PI/2),floor(from-to));
		else
			gdk_draw_arc(inDraw, theEraseGC, TRUE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
					 	floor(to-PI/2),floor(to-from));
	}
    *outDraw = inDraw;
    *oos = ios;
}	/* WinEraseWedge */

void WinInvertWedge (gint left, gint top, gint right, gint bottom,
                gint startradx, gint startrady, gint endradx, gint endrady,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
	gint cx, cy;
    gint x = left;
    gint y = top;
    gint rx = right;
    gint ry = bottom;
    gfloat from = startradx;
    gfloat to = startrady;
    gboolean clockwise = TRUE;

    printf("WinInvertWedge\n");
	if (inDraw)
	{
		cx	= x  - floor(cos(from)* abs(rx));
		cy	= y  + floor(sin(from)* abs(ry));

		from = (32*360*from)/PI;
		to   = (32*360*to)/PI;

		if (clockwise)
			gdk_draw_arc(inDraw, theInvertGC, TRUE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(from-PI/2),floor(from-to));
		else
			gdk_draw_arc(inDraw, theInvertGC, TRUE,
						 cx-rx, cy-ry, 2*rx, 2*ry,
						 floor(to-PI/2),floor(to-from));
	}
    *outDraw = inDraw;
    *oos = ios;
}	/* WinInvertWedge */


OS WinStartPolygon (gint size, OS ios)
{
    printf("WinStartPolygon\n");
	thePolygon = g_new(GdkPoint, size);
	thePolygonIndex = 0;

    return ios;
}	/* WinStartPolygon */

OS WinEndPolygon (OS ios)
{
    printf("WinEndPolygon\n");
	rfree (thePolygon);
	thePolygon = NULL;

    return ios;
}	/* WinEndPolygon */

OS WinAddPolygonPoint (gint x, gint y, OS ios)
{
    printf("WinAddPolygonPoint\n");
	thePolygon[thePolygonIndex].x = x;
	thePolygon[thePolygonIndex].y = y;
	thePolygonIndex++;

    return ios;
}	/* WinAddPolygonPoint */

void WinDrawPolygon(GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawPolygon\n");
	if (inDraw) gdk_draw_polygon(inDraw,theDrawGC,FALSE,thePolygon,thePolygonIndex);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawPolygon */

void WinUndrawPolygon (GdkDrawable *drawable)
{
    printf("WinUndrawPolygon\n");
	if (drawable) gdk_draw_polygon(drawable,theEraseGC,FALSE,thePolygon,thePolygonIndex);
}	/* WinUndrawPolygon */

void WinFillPolygon (GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinFillPolygon\n");
	if (inDraw) gdk_draw_polygon(inDraw,theDrawGC,TRUE,thePolygon,thePolygonIndex);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinFillPolygon */

void WinErasePolygon (GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinErasePolygon\n");
	if (inDraw) gdk_draw_polygon(inDraw,theEraseGC,TRUE,thePolygon,thePolygonIndex);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinErasePolygon */

void WinInvertPolygon (GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinInvertPolygon\n");
	if (inDraw) gdk_draw_polygon(inDraw,theInvertGC,TRUE,thePolygon,thePolygonIndex);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinInvertPolygon */

void WinCreateScreenHDC(OS ios, GdkDrawable **outDraw, OS *oos)
{
    GdkWindow* theWindow;
    GdkScreen* theScreen;
    
    printf("WinCreateScreenHDC\n");
	InitGTK();
    theScreen = gdk_screen_get_default();
    theWindow = gdk_screen_get_root_window(theScreen);

    *oos = ios;
    *outDraw = GDK_DRAWABLE(theWindow);
    printf("WinCreateScreenHDC - %d\n",theWindow);
}	/* WinCreateScreenHDC */

OS WinDestroyScreenHDC (GdkDrawable *drawable, OS os)
{
    printf("WinDestroyScreenHDC - %d\n",drawable);
/*    g_object_unref(drawable); */
    return os;
}	/* WinDestroyScreenHDC */


/*	WinDrawResizedBitmap draws a bitmap on screen. For reasons of efficiency it uses an
	already created bitmap handle.
*/
void WinDrawResizedBitmap (gint sourcew, gint sourceh, gint destx, gint desty,
                gint destw, gint desth, GdkPixbuf *pixbuf, GdkDrawable *inDraw,
                OS ios, GdkDrawable **outDraw, OS *oos)
{
/*	HDC compatibleDC;
	POINT sourcesize, destsize, dest, origin;
	HGDIOBJ prevObj;

	sourcesize.x = sourcew;
	sourcesize.y = sourceh;
	origin.x     = 0;
	origin.y     = 0;
	destsize.x   = destw;
	destsize.y   = desth;
	dest.x       = destx;
	dest.y       = desty;

	//	Create a compatible device context
	compatibleDC = CreateCompatibleDC (hdc);
	if (compatibleDC == NULL)
		rMessageBox (NULL,MB_APPLMODAL,"WinDrawResizedBitmap","CreateCompatibleDC failed");

	//	Select bitmap into compatible device context
	prevObj = SelectObject (compatibleDC, hbmp);
	SetMapMode (compatibleDC, GetMapMode (hdc));
	DPtoLP (hdc, &destsize, 1);
	DPtoLP (hdc, &dest, 1);
	DPtoLP (compatibleDC, &sourcesize, 1);
	DPtoLP (compatibleDC, &origin, 1);

	if (!StretchBlt (hdc, dest.x, dest.y, destsize.x, destsize.y, compatibleDC, origin.x, origin.y, sourcesize.x, sourcesize.y, SRCCOPY))
		rMessageBox (NULL,MB_APPLMODAL,"WinDrawResizedBitmap","StretchBlt failed");

	SelectObject (compatibleDC, prevObj);
	DeleteDC (compatibleDC);*/
	printf("WinDrawResizedBitmap is not implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}	/* WinDrawResizedBitmap */

/* ... MW */
void WinDrawBitmap (gint w, gint h, gint destx, gint desty, GdkPixbuf *pixbuf,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawBitmap\n");
  /*	if (drawable) gdk_draw_drawable(drawable,theDrawGC,GDK_DRAWABLE(pixbuf),0,0,destx,desty,w,h); */
  if (inDraw)
    {
      gdk_pixbuf_render_to_drawable   (pixbuf, inDraw, theDrawGC, 0, 0, destx,
                      desty, w, h, GDK_RGB_DITHER_NONE, 0, 0);
    }
  *outDraw = inDraw;
  *oos = ios;
}	/* WinDrawBitmap */

void WinCreateBitmap (gint width, gchar *filename, GdkDrawable *inDraw,OS ios,
                GdkPixbuf **bitmap, OS* oos)
{
	GError *err = NULL;

    printf("WinCreateBitmap\n");
	InitGTK();
	*bitmap = gdk_pixbuf_new_from_file(filename, &err);

	/*
    *pWidth  = gdk_pixbuf_get_width(pixbuf);
	*pHeight  = gdk_pixbuf_get_height(pixbuf);
    */

    *oos = ios;
}	/* WinCreateBitmap */

void WinDisposeBitmap (GdkPixbuf *pixbuf)
{
    printf("WinDisposeBitmap\n");
	gdk_pixbuf_unref(pixbuf);
}


/*-----------------------------
	   Font stuff
  -----------------------------*/

void WinSetFont (CLEAN_STRING fontName, gint style, gint size,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinSetFont\n");
	if (theFont) gdk_font_unref(theFont);

	pango_font_description_set_family(theFontDesc,cstring(fontName));
	pango_font_description_set_weight(theFontDesc,(style & iBold) ? PANGO_WEIGHT_BOLD : PANGO_WEIGHT_NORMAL);
	pango_font_description_set_style(theFontDesc,(style & iItalic) ? PANGO_STYLE_ITALIC : PANGO_STYLE_NORMAL);
	/*	plf->lfUnderline = (style & iUnderline) ? TRUE : FALSE; */
	/*	plf->lfStrikeOut = (style & iStrikeOut) ? TRUE : FALSE; */
	pango_font_description_set_size(theFontDesc, size*PANGO_SCALE);
	theFont = gdk_font_from_description(theFontDesc);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinSetFont */

void WinGetFontInfo (CLEAN_STRING fontName, gint style, gint size,
                gint drawablePassed, GdkDrawable *drawable, OS ios,
                gint *ascent, gint *descent, gint *maxwidth,
                gint *leading, OS* oos )
{
    PangoContext *pc;
	PangoFontset *fontset;
	PangoFontMetrics *metrics;
	PangoFontDescription *fontDesc;
    GtkWidget *widget;
    gchar *fName;
    gboolean inDrawIsWidget;
    printf("WinGetFontInfo\n");
    
    fName = cstring(fontName);
    inDrawIsWidget = GTK_IS_WIDGET(drawable);

    printf("WinGetFontInfo - %d\n",drawable);
    if (! inDrawIsWidget)
    {
        widget = gtk_label_new(NULL);
        drawablePassed = 0;
    } else {widget=GTK_WIDGET(drawable);}
    pc = gtk_widget_get_pango_context(widget);
    fontDesc = pango_font_description_new();
    
    printf("Font Name: %s\n", fName);
    pango_font_description_set_family(fontDesc,fName);
    pango_font_description_set_weight(fontDesc,(style & iBold) ? PANGO_WEIGHT_BOLD : PANGO_WEIGHT_NORMAL);
	pango_font_description_set_style(fontDesc,(style & iItalic) ? PANGO_STYLE_ITALIC : PANGO_STYLE_NORMAL);
	/*	plf->lfUnderline = (style & iUnderline) ? TRUE : FALSE; */
	/*	plf->lfStrikeOut = (style & iStrikeOut) ? TRUE : FALSE; */
	pango_font_description_set_size(fontDesc, size*PANGO_SCALE);

    pango_context_set_font_description(pc, fontDesc);
    metrics = pango_context_get_metrics (pc, fontDesc,
                    pango_context_get_language(pc));
    

	*ascent = PANGO_PIXELS(pango_font_metrics_get_ascent(metrics));
	*descent = PANGO_PIXELS(pango_font_metrics_get_descent(metrics));
	*maxwidth = PANGO_PIXELS(pango_font_metrics_get_approximate_char_width(metrics));
	*leading = 2; /* FIXME */

    /* Pango gets the heights a bit wrong, so fudge it. */
    *ascent = (*ascent) + 1;
    *descent = (*descent) + 1;

    printf("About to free font description\n");
    g_object_unref(G_OBJECT(pc));
    if (! inDrawIsWidget)
    {
        gtk_widget_destroy(widget);
    }
	pango_font_metrics_unref(metrics);
  	pango_font_description_free(fontDesc);
    printf("Freed it.\n");
    /* Connect the input and output */
    *oos = ios;
}	/* WinGetFontInfo */

void WinGetPicFontInfo (GdkDrawable *inDraw, OS ios, gint *ascent,
                gint *descent, gint *maxwidth, gint *leading,
                GdkDrawable **outDraw, OS *oos)
{
	PangoFontset *fontset;
	PangoFontMetrics *metrics;

    printf("WinGetPicFontInfo\n");
	fontset = pango_font_map_load_fontset
				(pango_ft2_font_map_for_display(),
				 gdk_pango_context_get(),
				 theFontDesc,
				 pango_language_from_string("EN"));
	metrics = pango_fontset_get_metrics(fontset);
	*ascent = pango_font_metrics_get_ascent(metrics);
	*descent = pango_font_metrics_get_descent(metrics);
	*maxwidth = pango_font_metrics_get_approximate_char_width(metrics);
	*leading = 2; /* FIXME */
	pango_font_metrics_unref(metrics);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinGetPicFontInfo */

void WinGetPicStringWidth (CLEAN_STRING string, GdkDrawable *inDraw, OS ios,
                gint *width, GdkDrawable **outDraw, OS *oos)
{
    printf("WinGetPicStringWidth\n");
    *width = gdk_string_width(theFont, cstring(string));
    printf("Width: %d, String: %s\n", *width, cstring(string));
    *outDraw = inDraw;
    *oos = ios;
}	/* WinGetPicStringWidth */

void WinGetPicCharWidth (gchar ch, GdkDrawable *inDraw, OS ios, gint *width,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinGetPicCharWidth\n");
    *width = gdk_char_width(theFont, ch);
    *outDraw = inDraw;
    *oos = ios;
}	/* WinGetPicCharWidth */

void WinGetStringWidth (CLEAN_STRING string, CLEAN_STRING fontName, gint style,
                gint size, gint drawablePassed, GdkDrawable *drawable, OS ios,
                gint *width, OS *oos)
{
	GdkFont *font;
	PangoFontDescription *fontDesc;
    PangoContext *pc;
    PangoLayout *pl;
    GtkWidget *widget;
    gchar* fName;
    gboolean inDrawIsWidget;
    printf("WinGetStringWidth\n");

    fName = cstring(fontName);
    inDrawIsWidget = GTK_IS_WIDGET(drawable);
    
    if (! inDrawIsWidget)
    {
        widget = gtk_label_new(NULL);
    }
    else
    {
        widget = GTK_WIDGET(drawable);
    }

    pc = gtk_widget_get_pango_context(widget);
    fontDesc = pango_font_description_new();
    
    printf("Font Name: %s\n", fName);
    pango_font_description_set_family(fontDesc,fName);
    pango_font_description_set_weight(fontDesc,(style & iBold) ? PANGO_WEIGHT_BOLD : PANGO_WEIGHT_NORMAL);
	pango_font_description_set_style(fontDesc,(style & iItalic) ? PANGO_STYLE_ITALIC : PANGO_STYLE_NORMAL);
	/*	plf->lfUnderline = (style & iUnderline) ? TRUE : FALSE; */
	/*	plf->lfStrikeOut = (style & iStrikeOut) ? TRUE : FALSE; */
	pango_font_description_set_size(fontDesc, size*PANGO_SCALE);

    pango_context_set_font_description(pc, fontDesc);
    pl = pango_layout_new(pc);
    pango_layout_set_text(pl, string->characters, string->length);
    pango_layout_get_pixel_size(pl, width, NULL);
    
    g_object_unref(G_OBJECT(pl));
    g_object_unref(G_OBJECT(pc));
    if (! inDrawIsWidget)
    {
        gtk_widget_destroy(GTK_WIDGET(widget));
    }
  	pango_font_description_free(fontDesc);

    /* HACK:  Pango seems to generate overly narrow widths based on
     * the font settings.
     * a bit too small.  So fudge it.
     */
    *width = *width * 1.25;
    printf("Width: %d, String: %s\n", *width, cstring(string));

    *oos = ios;
}	/* WinGetStringWidth */

void WinGetCharWidth (gchar ch, CLEAN_STRING fontName, gint style, gint size,
                gint drawablePassed, GdkDrawable *drawable, OS ios, gint* width,
                OS *oos)
{
	GdkFont *font;
	PangoFontDescription *fontDesc;
    PangoContext *pc;
    PangoLanguage *lang;
    PangoFontMetrics *metrics;
    GtkWidget *widget;
    gchar *fName;
    gboolean inDrawIsWidget;
    printf("WinGetCharWidth\n");

    fName = cstring(fontName);
    inDrawIsWidget = GTK_IS_WIDGET(drawable);

    if (! inDrawIsWidget)
    {
        widget = gtk_label_new(NULL);
    }
    else
    {
        widget = GTK_WIDGET(drawable);
    }

    pc = gtk_widget_get_pango_context(widget);
	fontDesc = pango_font_description_new();
    printf("Font Name: %s\n", fName);

	pango_font_description_set_family(fontDesc,cstring(fontName));
	pango_font_description_set_weight(fontDesc,(style & iBold) ? PANGO_WEIGHT_BOLD : PANGO_WEIGHT_NORMAL);
	pango_font_description_set_style(fontDesc,(style & iItalic) ? PANGO_STYLE_ITALIC : PANGO_STYLE_NORMAL);
	/*	plf->lfUnderline = (style & iUnderline) ? TRUE : FALSE; */
	/*	plf->lfStrikeOut = (style & iStrikeOut) ? TRUE : FALSE; */
	pango_font_description_set_size(fontDesc, size*PANGO_SCALE);
    lang = pango_context_get_language(pc);
    metrics = pango_context_get_metrics(pc, fontDesc, lang);

    *width = pango_font_metrics_get_approximate_char_width(metrics);

  	pango_font_description_free(fontDesc);
    pango_font_metrics_unref(metrics);
    g_object_unref(G_OBJECT(pc));
    if (! inDrawIsWidget)
    {
        gtk_widget_destroy(widget);
    }

    *oos = ios;
}	/* WinGetCharWidth */


void getResolutionC(GdkDrawable *drawable, int *xResP, int *yResP)
{
    printf("getResolutionC\n");
	*xResP = gdk_screen_width();
	*yResP = gdk_screen_height();
}	/* getResolutionC */

void WinGetPictureScaleFactor(GdkDrawable* inDraw, OS ios, gint *nh, gint *dh,
                gint *nv, gint *dv, GdkDrawable **outDraw, OS *oos)
{
    printf("WinGetPictureScaleFactor\n");
	*nh = 1;
	*dh = 1;
	*nv = 1;
	*dv = 1;
    *outDraw = inDraw;
    *oos = ios;
}	/* WinGetPictureScaleFactor */

void WinDefaultFontDef(gchar **fname, gint *fstyle, gint *fsize)
{
    printf("WinDefaultFontDef\n");
  *fname  = "helvetica";
  *fstyle = 0;
  *fsize  = 12;
}

void WinDialogFontDef(gchar **fname, gint *fstyle, gint *fsize)
{
    printf("WinDialogFontDef\n");
  *fname  = "helvetica";
  *fstyle = 0;
  *fsize  = 12;
}

void WinSerifFontDef(gchar **fname, gint *fstyle, gint *fsize)

{
    printf("WinSerifFontDef\n");
	*fname  = "times";
	*fstyle = 0;
	*fsize  = 10;
}

void WinSansSerifFontDef(gchar **fname, gint *fstyle, gint *fsize)

{
    printf("WinSansSerifFontDef\n");
	*fname  = "helvetica";
	*fstyle = 0;
	*fsize  = 10;
}

void WinSmallFontDef(gchar **fname, gint *fstyle, gint *fsize)
{
    printf("WinSmallFontDef\n");
	*fname  = "helvetica";
	*fstyle = 0;
	*fsize  = 7;
}

void WinNonProportionalFontDef(gchar **fname, gint *fstyle, gint *fsize)
{
    printf("WinNonProportionalFontDef\n");
	*fname  = "fixed";
	*fstyle = 0;
	*fsize  = 10;
}

void WinSymbolFontDef(gchar **fname, gint *fstyle, gint *fsize)
{
    printf("WinSymbolFontDef\n");
	*fname  = "adobe-symbol";
	*fstyle = 0;
	*fsize  = 10;
}

void WinCombineRgn (GdkRegion *dest, GdkRegion *src1, GdkRegion *src2,
                gint fnCombineMode, OS ios, GdkRegion **outDest, OS *oos)
{
    printf("WinCombineRgn\n");
    dest = gdk_region_copy(src1);

    switch(fnCombineMode)
    {
        case RGN_AND:
    printf("RGN_AND\n");
            gdk_region_intersect(dest, src2);
            break;
        case (RGN_OR):
    printf("RGN_OR\n");
            gdk_region_union(dest, src2);
            break;
        case (RGN_DIFF):
    printf("RGN_DIFF\n");
            gdk_region_subtract(dest, src2);
            break;
        case (RGN_XOR):
    printf("RGN_XOR\n");
            gdk_region_xor(dest, src2);
            break;
        case (RGN_COPY):
        default:
            /* We already copied the region, so just return it */
    printf("RGN_COPY\n");
            break;
    }

    *outDest = dest;
    *oos = ios;
}

void WinSetRgnToRect (gint left, gint top, gint right, gint bottom,
                GdkRegion *rgn, OS ios, GdkRegion **orgn, OS *oos)
{
    GdkRegion* r = NULL;
    printf("WinSetRgnToRect --> Not Implemented\n");
    *orgn = rgn;
    *oos = ios;
}

/*
 * Review of source indicates this is always called on a GdkRegion*
 */
OS WinDeleteObject (GdkRegion* region, OS ios)
{
    printf("WinDeleteObject\n");
    if (region)
    {
        gdk_region_destroy(region);
    }
    return ios;
}

void WinClipPicture (gint left, gint top, gint right, gint bot,
                GdkDrawable *drawable, OS ios, GdkDrawable **outDraw,
                OS *oos)
{
    printf("WinClipPicture\n");

    /* Do something here */

    *outDraw = drawable;
    *oos = ios;
}

void InternalGetPenPos (GdkDrawable *context, gint *x, gint *y)
{
    GdkPoint *p;
    printf("InternalGetPenPos: ");
    p = (GdkPoint*)(g_object_get_data(G_OBJECT(context), PEN_POS_KEY));
    if (p)
    {
	    *x = p->x;
	    *y = p->y;
        rprintf("Pen Pos: (%d, %d)\n", *x, *y);
    } else {
        rprintf("No data for current-pen-position.\n");
    }
}

void InternalSetPenPos (GdkDrawable *context, gint x, gint y)
{
    GdkPoint *p;
    printf("InternalSetPenPos\n");
    
    p = g_new(GdkPoint,1);
    printf("InternalSetPenPos: (%d, %d)\n", x, y);

    p->x = x;
    p->y = y;
    g_object_set_data(G_OBJECT(context), PEN_POS_KEY, (gpointer)p);
}

void WinGetPenPos (GdkDrawable *inDraw, OS ios, gint *x, gint *y,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinGetPenPos\n");

    InternalGetPenPos(inDraw, x, y);

    *outDraw = inDraw;
    *oos = ios;
}

void WinMovePenTo (gint x, gint y, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinMovePenTo\n");

    InternalSetPenPos(inDraw, x, y);

    *outDraw = inDraw;
    *oos = ios;
}

void WinMovePen (gint dx, gint dy, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    gint x, y;
    
    printf("WinMovePen\n");
    InternalGetPenPos(inDraw, &x, &y);
    x += dx;
    y += dy;
    
    InternalSetPenPos(inDraw, x, y);

    *outDraw = inDraw;
    *oos = ios;
}

void WinDrawCPoint (gint x, gint y, gint red, gint green, gint blue,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawCPoint --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinDrawCLine (gint startX, gint startY, gint endX, gint endY, gint red,
                gint green, gint blue, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawCLine --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinDrawCCurve (gint left, gint top, gint right, gint bot, gint startradx,
                gint startrady, gint endradx, gint endrady, gint red,
                gint green, gint blue, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS * oos)
{
    printf("WinDrawCCurve --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinScrollRectangle2 (gint left, gint top, gint right, gint bot, gint width,
                gint height, GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw,
                OS *oos)
{
    printf("WinScrollRectangle2 --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinDrawRoundRectangle (gint left, gint top, gint right, gint bottom, 
                gint width, gint height, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawRoundRectangle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinFillRoundRectangle (gint left, gint top, gint right, gint bot,
                gint width, gint height, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinFillRoundRectangle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinEraseRoundRectangle (gint left, gint top, gint right, gint bot,
                gint width, gint height, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinEraseRoundRectangle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinInvertRoundRectangle (gint left, gint top, gint right, gint bot,
                gint width, gint height, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinInvertRoundRectangle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinDrawCircle (gint centerx, gint centery, gint radius,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinDrawCircle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinFillCircle (gint centerx, gint centery, gint radius,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinFillCircle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinEraseCircle (gint centerx, gint centery, gint radius,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinEraseCircle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinInvertCircle (gint centerx, gint centery, gint radius,
                GdkDrawable *inDraw, OS ios, GdkDrawable **outDraw, OS *oos)
{
    printf("WinInvertCircle --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinDrawWedge (gint left, gint top, gint right, gint bottom, gint startradx,
                gint startrady, gint endradx, gint endrady, GdkDrawable *inDraw,
                OS ios, GdkDrawable **outDraw, OS *oos)
{
	gint cx, cy;
    gint x = left;
    gint y = top;
    gint rx = right;
    gint ry = bottom;
    gfloat from = startradx;
    gfloat to = startrady;
    gboolean clockwise = TRUE;

    printf("WinDrawWedge --> Not Implemented\n");

    *outDraw = inDraw;
    *oos = ios;
}

void WinPrintResizedBitmap (gint sz2, gint sy2, gint dx1, gint dy1, gint dw,
                gint dh, gchar* ptr, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinPrintResizedBitmap --> Not implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinSetFontName (CLEAN_STRING fontName, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinSetFontName --> Not Implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinSetFontSize (gint size, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinSetFontSize: %d\n", size);
	pango_font_description_set_size(theFontDesc, size*PANGO_SCALE);
	theFont = gdk_font_from_description(theFontDesc);
    *outDraw = inDraw;
    *oos = ios;
}

void WinSetFontStyle (gint style, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinSetFontStyle: %d\n", style);
	pango_font_description_set_style(theFontDesc,(style & iItalic) ? PANGO_STYLE_ITALIC : PANGO_STYLE_NORMAL);
	/*	plf->lfUnderline = (style & iUnderline) ? TRUE : FALSE; */
	/*	plf->lfStrikeOut = (style & iStrikeOut) ? TRUE : FALSE; */
	theFont = gdk_font_from_description(theFontDesc);
    *outDraw = inDraw;
    *oos = ios;
}

gint WinGetVertResolution (void)
{
    static gint res = 0;
    printf("WinGetVertResolution\n");

    InitGTK();

    if (res == 0)
    {
        GdkScreen* screen;
        GdkWindow* window;
        GdkRectangle rect;
        
        InitGTK();
        screen = gdk_screen_get_default();
        window = gdk_screen_get_root_window(screen);
        gdk_window_get_frame_extents(window, &rect);
        
        res = rect.height;
        g_object_unref(window);
    }

    return res;
}

gint WinGetHorzResolution (void)
{
    static gint res = 0;
    printf("WinGetHorzResolution\n");

    InitGTK();

    if (res == 0)
    {
        GdkScreen* screen;
        GdkWindow* window;
        GdkRectangle rect;

        screen = gdk_screen_get_default();
        window = gdk_screen_get_root_window(screen);
        gdk_window_get_frame_extents(window, &rect);
        
        res = rect.width;
        g_object_unref(window);
    }

    return res;
}

void WinLinePen (gint x, gint y, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinLinePen --> Not implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinLinePenTo (gint x, gint y, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos)
{
    printf("WinLinePenTo --> Not implemented\n");
    *outDraw = inDraw;
    *oos = ios;
}

void WinCreateEllipseRgn(gint nLeftRect, gint nTopRect, gint nRightRect,
                gint nBottomRect, OS ios, GdkRegion* rgn, OS* oos)
{
    printf("WinCreateEllipseRgn --> Not Implemented\n");
    *oos = ios;
}
