/********************************************************************************************
	Clean OS Windows library module version 1.2.1.
	This module is part of the Clean Object I/O library, version 1.2.1,
	for the Windows platform.
********************************************************************************************/

/********************************************************************************************
	About this module:
	Routines related to window/dialog handling.
********************************************************************************************/
#include "cCCallWindows_121.h"
#include "cCrossCallWindows_121.h"

OS WinInvalidateWindow (GtkWidget *widget, OS ios)
{
    rprintf("WinInvalidateWindow\n");
	gtk_widget_queue_draw(widget);
    return ios;
}

OS WinInvalidateRect (GtkWidget *widget, int left, int top, int right,
                int bottom, OS ios)
{
    /* rprintf("WinInvalidateRect\n"); */
	gint temp;
	GdkRectangle* rect = g_new(GdkRectangle,1);
	if (top > bottom) {
		temp = top;
		top = bottom;
		bottom = top;
	}
	rect->x = (gint)left;
	rect->y = (gint)top;
	rect->width = (gint)(right - left);
	rect->height = (gint)(bottom - top);
	gdk_window_invalidate_rect(GDK_WINDOW(widget),rect, 1);
	/* FIXME: destroy the Rectangle here? */
    return ios;
}

OS WinValidateRect (GtkWidget *widget, int left, int top, int right, int bottom,
                OS ios)
{
    /* GTK Automatically calculates valid regions. */
    return ios;
}

OS WinValidateRgn (GtkWidget *widget, GdkRegion *region, OS ios)
{
    /* GTK Automatically calculates valid regions. */
    return ios;
}

/*	Win(M/S)DIClientToOuterSizeDims returns the width and height needed to add/subtract
	from the client/outer size to obtain the outer/client size.
	These values must be the same as used by W95AdjustClean(M/S)DIWindowDimensions!
*/
void WinMDIClientToOuterSizeDims (int styleFlags, OS ios, int *dw, int *dh, OS* oos)
{
/*	if ((styleFlags&WS_THICKFRAME) != 0)
	{	// resizable window
		*dw = 2 * GetSystemMetrics (SM_CXSIZEFRAME);
		*dh = 2 * GetSystemMetrics (SM_CYSIZEFRAME) + GetSystemMetrics (SM_CYCAPTION);
	} else
	{	// fixed size window
		*dw = 2 * GetSystemMetrics (SM_CXFIXEDFRAME);
		*dh = 2 * GetSystemMetrics (SM_CYFIXEDFRAME) + GetSystemMetrics (SM_CYCAPTION);
	}
*/
	*dw = 0;
    *dh = 0;
	printf("WinMDIClientOuterSizeDims -> not implemented\n");
    *oos = ios;
}

void WinSDIClientToOuterSizeDims (int styleFlags, OS ios, int *dw, int *dh, OS *oos)
{
	*dw = 0; //2 * GetSystemMetrics (SM_CXSIZEFRAME);
	*dh = 0; //2 * GetSystemMetrics (SM_CYSIZEFRAME) + GetSystemMetrics (SM_CYCAPTION);
	printf("WinSDIClientOuterSizeDims -> not implemented\n");
    *oos = ios;
}


/*	UpdateWindowScrollbars updates any window scrollbars and non-client area if present.
	Uses the following access procedures to the GWL_STYLE of a windowhandle:
		GetGWL_STYLE (hwnd) returns the GWL_STYLE value of hwnd;
		WindowHasHScroll (hwnd) returns TRUE iff hwnd has a horizontal scrollbar;
		WindowHasVScroll (hwnd) returns TRUE iff hwnd has a vertical scrollbar;
*/

void UpdateWindowScrollbars (GtkWidget *widget)
{
/*	int w,h;
	RECT rect;

	GetWindowRect (hwnd, &rect);
	w = rect.right -rect.left;
	h = rect.bottom-rect.top;

	if (WindowHasHScroll (hwnd))
	{
		rect.left   = 0;
		rect.top    = h-GetSystemMetrics (SM_CYHSCROLL);
		rect.right  = w;
		rect.bottom = h;
		InvalidateRect (hwnd,&rect,FALSE);
		RedrawWindow (hwnd,&rect,NULL,RDW_FRAME | RDW_VALIDATE | RDW_UPDATENOW | RDW_NOCHILDREN);
		ValidateRect (hwnd,&rect);
	}
	if (WindowHasVScroll (hwnd))
	{
		rect.left   = w-GetSystemMetrics (SM_CXVSCROLL);
		rect.top    = 0;
		rect.right  = w;
		rect.bottom = h;
		InvalidateRect (hwnd,&rect,FALSE);
		RedrawWindow (hwnd,&rect,NULL,RDW_FRAME | RDW_VALIDATE | RDW_UPDATENOW | RDW_NOCHILDREN);
		ValidateRect (hwnd,&rect);
	}
*/
	printf("UpdateWindowScrollbars -> not implemented\n");
}


void WinScreenYSize (OS ios, int *py, OS *oos)
{
    rprintf("WinScreenYSize\n");
	*py = gdk_screen_height();
    *oos = ios;
}

void WinScreenXSize (OS ios, int *px, OS *oos)
{
    rprintf("WinScreenXSize\n");
	*px = gdk_screen_width();
    *oos = ios;
}

void WinMinimumWinSize (int *mx, int *my)
{
    rprintf("WinMinimumWinSize\n");
	*mx = 48;
	*my = 0;
}

/*	WinScrollbarSize determines system metrics of width and height of scrollbars.
*/
void WinScrollbarSize (OS ios, int *width, int *height, OS *oos)
{
    GtkRequisition req;
    GtkWidget *vbar, *hbar;
    printf ("WinScrollbarSize\n");

    vbar = gtk_vscrollbar_new(NULL);
    hbar = gtk_hscrollbar_new(NULL);
    

    gtk_widget_size_request(vbar, &req);
	*width  = req.width; /* Width of the vertical arrow */
    gtk_widget_size_request(hbar, &req);
	*height = req.height; /* Height of the horizontal bar */

    gtk_widget_destroy(vbar);
    gtk_widget_destroy(hbar);

    *oos = ios;
}

void WinMaxFixedWindowSize (int *mx, int *my)
{
    rprintf("WinMaxFixedWindowSize\n");
    *mx = gdk_screen_width();
    *my = gdk_screen_height();
}

void WinMaxScrollWindowSize (int *mx, int *my)
{
    rprintf("WinMaxScrollWindowSize\n");
    *mx = gdk_screen_width();
    *my = gdk_screen_height();
}
