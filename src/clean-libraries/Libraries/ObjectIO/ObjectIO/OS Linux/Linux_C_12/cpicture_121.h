#include "util_121.h"
#include "intrface_121.h"
#include <math.h>

#define RGN_AND 1  /* Creates the intersection of the two regions */
#define RGN_OR 2 /* creates the union of the two regions */
#define RGN_DIFF 3 /* Returns the parts of region1 not in region2 */
#define RGN_XOR 4 /* creates the union (not including overlap) */
#define RGN_COPY 5 /* Creates a copy of the region */

extern void WinGetDC (OSWindowPtr, OS, OSPictContext*, OS*);
extern OS   WinReleaseDC (OSWindowPtr,OSPictContext,OS);
extern int  OsMMtoVPixels(double);
extern int  OsMMtoHPixels(double);

void WinInitPicture (int size, int mode, int pr, int pg, int pb,
					 int br, int bg, int bb, int x, int y,
                     CLEAN_STRING fname, int fstyle, int fsize,
                     int ox, int oy, OSPictContext inDraw, OS os,
					 OSPictContext *outDraw, OS *oos);
extern void WinDonePicture (OSPictContext,OS,int*,int*,int*,int*,int*,
                int*,int*,int*,int*,int*,CLEAN_STRING*,int*,int*,
                OSPictContext*,OS*);

extern void WinClipRgnPicture(OSRgnHandle,OSPictContext,OS,
                OSPictContext*,OS*);
extern void WinClipPicture (int,int,int,int,OSPictContext,OS,
                OSPictContext*,OS*);
extern void WinSetClipRgnPicture (OSRgnHandle,OSPictContext,OS,
                OSPictContext*,OS*);
extern void WinGetClipRgnPicture (OSPictContext,OS,OSRgnHandle*,OSPictContext*,OS*);

/*	Operations to create, modify, and destroy polygon shapes.
*/
extern void WinAllocPolyShape (int,OS,PointsArray*,OS*);
extern OS     WinSetPolyPoint (int,int,int,PointsArray, OS);
extern OS     WinFreePolyShape (PointsArray,OS);

/*	Operations to create, modify and destroy regions.
*/
extern OSRgnHandle WinCreateEmptyRgn();
extern void WinCreateRectRgn(int,int,int,int,OS,OSRgnHandle*,OS*);
extern void WinCreatePolygonRgn(PointsArray,int,int,OS,OSRgnHandle*,OS*);
extern void WinSetRgnToRect(int,int,int,int,OSRgnHandle,OS,OSRgnHandle*,OS*);
/* extern OSRgnHandle WinCombineRgn (HRGN,HRGN,HRGN,int,OS,HRGN*,OS*); */
extern void WinCombineRgn (OSRgnHandle,OSRgnHandle,OSRgnHandle,int,OS,
                OSRgnHandle*,OS*);
extern OSRgnHandle WinUnionRgn(OSRgnHandle rgn1, OSRgnHandle rgn2);
extern OSRgnHandle WinSectRgn(OSRgnHandle rgn1, OSRgnHandle rgn2);
extern OSRgnHandle WinDiffRgn(OSRgnHandle rgn1, OSRgnHandle rgn2);
extern OSRgnHandle WinXorRgn (OSRgnHandle rgn1, OSRgnHandle rgn2);
extern void WinGetRgnBox(OSRgnHandle,OS,int*,int*,int*,int*,BOOL*,BOOL*,OS*);
extern BOOL WinIsEmptyRgn(OSRgnHandle rgn);
extern void WinDisposeRgn(OSRgnHandle rgn);

extern void WinSetPenSize (int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinSetPenColor (int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinSetBackColor (int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinSetMode (int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinSetPattern (int,OSPictContext,OS,OSPictContext*,OS*);

extern void WinDrawPoint (int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinDrawLine (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinUndrawLine(int,int,int,int,OSPictContext);
extern void WinDrawCurve (int,int,int,int,int,int,int,int,OSPictContext,OS,
                OSPictContext*,OS*);
extern void WinUndrawCurve (int,int,int,int,float,float,BOOL,OSPictContext);

extern void WinDrawChar (char,OSPictContext,OS,OSPictContext*,OS*);
extern void WinUndrawChar (int,int,char,OSPictContext);
extern void WinDrawString (CLEAN_STRING,OSPictContext,OS,OSPictContext*,OS*);
extern void WinUndrawString (int,int,char*,OSPictContext);

extern void WinDrawRectangle (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinUndrawRectangle (int,int,int,int,OSPictContext);
extern void WinFillRectangle (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinEraseRectangle (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinInvertRectangle (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinMoveRectangleTo (int,int,int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinMoveRectangle (int,int,int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinCopyRectangleTo (int,int,int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinCopyRectangle (int,int,int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinScrollRectangle (int,int,int,int,int,int,OSPictContext,OS,int*,int*,int*,int*,OSPictContext*,OS*);

extern void WinDrawOval (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinUndrawOval (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinFillOval (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinEraseOval (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinInvertOval (int,int,int,int,OSPictContext,OS,OSPictContext*,OS*);

extern void WinFillWedge (int,int,int,int,int,int,int,int,OSPictContext,
                OS,OSPictContext*,OS*);
extern void WinEraseWedge (int,int,int,int,int,int,int,int,OSPictContext,
                OS,OSPictContext*,OS*);
extern void WinInvertWedge (int,int,int,int,int,int,int,int,OSPictContext,
                OS,OSPictContext*,OS*);

extern OS   WinStartPolygon (int,OS);
extern OS   WinEndPolygon (OS);
extern OS   WinAddPolygonPoint (int,int,OS);
extern void WinDrawPolygon (OSPictContext,OS,OSPictContext*,OS*);
extern void WinUndrawPolygon (OSPictContext);
extern void WinFillPolygon (OSPictContext,OS,OSPictContext*,OS*);
extern void WinErasePolygon (OSPictContext,OS,OSPictContext*,OS*);
extern void WinInvertPolygon (OSPictContext,OS,OSPictContext*,OS*);

/*
 * Routines that temporarily create and destroy a DISPLAY OSPictContext. Use
 * this OSPictContext only locally.
 */
extern void WinCreateScreenHDC (OS,OSPictContext*,OS*);
extern OS   WinDestroyScreenHDC (OSPictContext,OS);

extern void WinDrawResizedBitmap (int,int,int,int,int,int,OSBmpHandle,
                OSPictContext,OS,OSPictContext*,OS*);
extern void WinDrawBitmap (int,int,int,int,OSBmpHandle,OSPictContext,OS,
                OSPictContext*,OS*);
extern void WinCreateBitmap (int, char*,OSPictContext,OS,OSBmpHandle*,OS*);
extern void WinDisposeBitmap(OSBmpHandle);

extern void WinSetFont (CLEAN_STRING,int,int,OSPictContext,OS,OSPictContext*,OS*);
extern void WinGetFontInfo (CLEAN_STRING,int,int,int,OSPictContext,OS,
                int*,int*,int*,int*,OS*);
extern void WinGetPicFontInfo (OSPictContext,OS,int*,int*,int*,int*,
                OSPictContext*,OS*);

extern void WinGetPicStringWidth (CLEAN_STRING,OSPictContext,OS,int*,OSPictContext*,OS*);
extern void WinGetPicCharWidth (char,OSPictContext,OS,int*,OSPictContext*,OS*);
extern void WinGetStringWidth (CLEAN_STRING,CLEAN_STRING,int,int,int,
                OSPictContext,OS,int*,OS*);
extern void WinGetCharWidth (char,CLEAN_STRING,int,int,int,OSPictContext,
                OS,int*,OS*);

/*	Get the resolution of a picture */
extern void getResolutionC(OSPictContext,int*,int*);

/*
 * Get scaling factors, which have to be applied to coordinates for clipping
 * regions in case of emulating the screen resolution for printing
 * (MM_ISOTROPIC)
 */
extern void WinGetPictureScaleFactor(OSPictContext,OS,int*,int*,int*,int*,
                OSPictContext*,OS*);

void WinDialogFontDef(char **fname, int *fstyle, int *fsize);
void WinDefaultFontDef(char **fname, int *fstyle, int *fsize);
void WinSerifFontDef(char **fname, int *fstyle, int *fsize);
void WinSansSerifFontDef(char **fname, int *fstyle, int *fsize);
void WinSmallFontDef(char **fname, int *fstyle, int *fsize);
void WinNonProportionalFontDef(char **fname, int *fstyle, int *fsize);
void WinSymbolFontDef(char **fname, int *fstyle, int *fsize);

extern void WinLinePen (int x, int y, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos);
extern void WinLinePenTo (int x, int y, GdkDrawable *inDraw, OS ios,
                GdkDrawable **outDraw, OS *oos);

extern int WinGetVertResolution (void);
extern int WinGetHorzResolution (void);

extern void WinCreateEllipseRgn (int,int,int,int,OS,GdkRegion*,OS*);
extern OS WinDeleteObject (GdkRegion*,OS);
extern void WinGetPenPos(GdkDrawable*, OS, int*, int*, GdkDrawable**, OS* );
extern void WinMovePenTo (int,int,GdkDrawable*,OS,GdkDrawable**,OS*);
extern void WinMovePen (int,int,GdkDrawable*,OS,GdkDrawable**,OS*);
extern void WinDrawCPoint (int,int,int,int,int,GdkDrawable*,
                OS,GdkDrawable**,OS*);
extern void WinDrawCLine (int,int,int,int,int,int,int,GdkDrawable*,OS,
                GdkDrawable**,OS*);
extern void WinDrawCCurve (int,int,int,int,int,int,int,int,int,int,int,
                GdkDrawable*,OS,GdkDrawable**,OS*);
extern void WinDrawRoundRectangle (int,int,int,int,int,int,GdkDrawable*,
                OS,GdkDrawable**,OS*);
extern void WinFillRoundRectangle (int,int,int,int,int,int,GdkDrawable*,
                OS,GdkDrawable**,OS*);
extern void WinEraseRoundRectangle (int,int,int,int,int,int,GdkDrawable*,
                OS,GdkDrawable**,OS*);
extern void WinInvertRoundRectangle (int,int,int,int,int,int,GdkDrawable*,
                OS,GdkDrawable**,OS*);
extern void WinDrawCircle (int,int,int,GdkDrawable*,OS,GdkDrawable**,OS*);
extern void WinFillCircle (int,int,int,GdkDrawable*,OS,GdkDrawable**,OS*);
extern void WinEraseCircle (int,int,int,GdkDrawable*,OS,GdkDrawable**,OS*);
extern void WinInvertCircle (int,int,int,GdkDrawable*,OS,GdkDrawable**,OS*);

extern void WinDrawWedge (int,int,int,int,int,int,int,int,GdkDrawable*,
                OS,GdkDrawable**,OS*);
extern void WinPrintResizedBitmap (int,int,int,int,int,int,char*,GdkDrawable*,
                int,GdkDrawable**,int*);

static void InternalGetPenPos( GdkDrawable*, int*, int*);
static void InternalSetPenPos( GdkDrawable*, int, int);
