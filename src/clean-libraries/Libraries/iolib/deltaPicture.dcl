definition module deltaPicture;

//  Version 0.8.3

//
//  Drawing functions and other operations on Pictures. 
//


import deltaFont;


/*
ABSTYPE

::  UNQ Picture;


TYPE

::  DrawFunction    -> => Picture Picture;


==  The predefined figures that can be drawn:

::  Point               -> (!INT, !INT);
::  Line                -> (!Point, !Point);
::  Curve               -> (!Oval, !INT, !INT);
::  Rectangle       -> (!Point, !Point);
::  RoundRectangle  -> (!Rectangle, !INT, !INT);
::  Oval                -> Rectangle;
::  Circle          -> (!Point, !INT);
::  Wedge               -> (!Oval, !INT, !INT);
::  Polygon         -> (!Point, !PolygonShape);

::  PolygonShape    -> [Vector];
::  Vector          -> (!INT, !INT);


==  The pen attributes which influence the way figures are drawn:

::  PenSize     -> (!INT, !INT);
::  PenMode     -> CopyMode     | OrMode        | XorMode       | ClearMode   | HiliteMode
                    |   NotCopyMode | NotOrMode | NotXorMode    | NotClearMode;
::  PenPattern  -> BlackPattern
                    |   DkGreyPattern
                    |   GreyPattern
                    |   LtGreyPattern
                    |   WhitePattern;


==  The predefined colours:

::  Colour  -> RGB REAL REAL REAL
                |   BlackColour | RedColour
                |   WhiteColour | GreenColour
                |   BlueColour  | YellowColour
                |   CyanColour  | MagentaColour;


MACRO

    MinRGB -> 0.0;
    MaxRGB -> 1.0;


RULE
    
<<  Rules setting the attributes of a Picture:
>>

<<  SetPenSize (w, h) sets the PenSize to w pixels wide and h pixels high.
    SetPenMode sets the interference how new figures 'react' to drawn ones.
    SetPenPattern sets the way new figures are drawn.
    SetPenNormal sets the SetPenSize to (1,1), the PenMode to CopyMode and
        the PenPattern to BlackPattern. >>

::  SetPenSize      !PenSize        !Picture -> Picture;
::  SetPenMode      !PenMode        !Picture -> Picture;
::  SetPenPattern   !PenPattern !Picture -> Picture;
::  SetPenNormal                    !Picture -> Picture;


<<  Using colours:
    There are basically two types of Colours: RGB and basic colours.
        An RGB colour defines the amount of red (r), green (g) and blue (b)
        in a certain colour by the tuple (r,g,b). These are REAL values and
        each of them must be between MinRGB and MaxRGB (0.0 and 1.0).
        The colour black is defined by (MinRGB, MinRGB, MinRGB) and white
        by (MaxRGB, MaxRGB, MaxRGB).
        Given a RGB colour, all amounts are adjusted between MinRGB and
        MaxRGB.
    Only FullColour windows can apply RGB colours. Applications that use
    these windows may not run on all computers (e.g. Macintosh Plus).
    A small set of basic colours is defined that can be used on all systems.
    
    SetPenColour    sets the colour of the pen.
    SetBackColour   sets the background colour. >>

::  SetPenColour    !Colour !Picture -> Picture;
::  SetBackColour   !Colour !Picture -> Picture;


<<  Using fonts:
    The initial font of a Picture is 12 point Chicago in PlainStyle.
    SetFont      sets a new complete Font in the Picture.
    SetFontName  sets a new font without changing the style or size.
                     In case of [], the font is set without stylistic
                     variations.
    SetFontStyle sets a new style without changing font or size.
    SetFontSize  sets a new size without changing font or style.
                     The size is always adjusted between MinFontSize and
                     MaxFontSize (see deltaFont.dcl). 
    
    PictureCharWidth (PictureStringWidth) yield the width of the
    given CHAR (STRING) given the current font of the Picture.
    PictureFontMetrics yields the FontInfo of the current font. >>

::  SetFont         !Font               !Picture -> Picture;
::  SetFontName     !FontName       !Picture -> Picture;
::  SetFontStyle    ![FontStyle]    !Picture -> Picture;
::  SetFontSize     !FontSize       !Picture -> Picture;

::  PictureCharWidth     !CHAR  !Picture -> (!INT,      !Picture);
::  PictureStringWidth !STRING !Picture -> (!INT,       !Picture);
::  PictureFontMetrics          !Picture -> (!FontInfo, !Picture);


<<  Rules changing the position of the pen:
>>

<<  Absolute and relative pen move operations (without drawing).
>>

::  MovePenTo   !Point  !Picture -> Picture;
::  MovePen     !Vector !Picture -> Picture;


<<  Absolute and relative pen move operations (with drawing).
>>

::  LinePenTo   !Point  !Picture -> Picture;
::  LinePen     !Vector !Picture -> Picture;

    
<<  DrawChar (DrawString) draws the character (string) in the current font.
    The baseline of the characters is the y coordinate of the pen.
    The new position of the pen is directly after the character (string)
    including spacing.
>>

::  DrawChar        !CHAR       !Picture -> Picture;
::  DrawString  !STRING !Picture -> Picture;


<<  Rules not changing the position of the pen after drawing:
>>

<<  Non plane figures:
        Draw(C)Point    draws the pixel (in the given colour) in the Picture.
        Draw(C)Line     draws the line  (in the given colour) in the Picture.
        Draw(C)Curve    draws the curve (in the given colour) in the Picture.
                        A Curve is part of an Oval o starting from angle a
                        upto angle b (both of type INT in degrees modulo 360):
                            (o, a, b).
                        See Wedges for further information on the angles. >>

::  DrawPoint   !Point  !Picture -> Picture;
::  DrawLine        !Line       !Picture -> Picture;
::  DrawCurve   !Curve  !Picture -> Picture;

::  DrawCPoint  !Point !Colour !Picture -> Picture;
::  DrawCLine   !Line    !Colour !Picture -> Picture;
::  DrawCCurve  !Curve !Colour !Picture -> Picture;


<<  A Rectangle is defined by two of its diagonal corner Points (a, b)
    with: a: (a_x, a_y),
            b: (b_x, b_y)
    such that a_x <> b_x and a_y <> b_y.
    In case either a_x = b_x or a_y = b_y, the Rectangle is empty.

    DrawRectangle       draws the edges of the rectangle.
    FillRectangle       draws the edges and interior of the rectangle.
    EraseRectangle      erases the edges and interior of the rectangle.
    InvertRectangle inverts the edges and interior of the rectangle.
    
    MoveRectangleTo   scrolls the contents of the rectangle to a new top corner.
    MoveRectangle scrolls the contents of the rectangle over the given vector. >>

::  DrawRectangle       !Rectangle !Picture -> Picture;
::  FillRectangle       !Rectangle !Picture -> Picture;
::  EraseRectangle      !Rectangle !Picture -> Picture;
::  InvertRectangle !Rectangle !Picture -> Picture;

::  MoveRectangleTo   !Rectangle !Point       !Picture -> Picture;
::  MoveRectangle !Rectangle !Vector  !Picture -> Picture;
::  CopyRectangleTo   !Rectangle !Point       !Picture -> Picture;
::  CopyRectangle !Rectangle !Vector  !Picture -> Picture;


<<  Rounded corner rectangles: a RoundRectangle with enclosing Rectangle
    r and corner curvatures x and y is defined by the tuple (r, x, y).
    x (y) defines the horizontal (vertical) diameter of the corner curves.
    x (y) is always adjusted between 0 and the width (height) of r.
    Note:   RoundRectangle (r, 0, 0) is the Rectangle r, 
            RoundRectangle (r, w, h) is the Oval r if w and h are the width
            and height of r.
>>

::  DrawRoundRectangle  !RoundRectangle !Picture -> Picture;
::  FillRoundRectangle  !RoundRectangle !Picture -> Picture;
::  EraseRoundRectangle !RoundRectangle !Picture -> Picture;
::  InvertRoundRectangle    !RoundRectangle !Picture -> Picture;


<<  Ovals: an Oval is defined by its enclosing Rectangle.
    Note : the Oval of a square Rectangle is a Circle.
>>

::  DrawOval        !Oval !Picture -> Picture;
::  FillOval        !Oval !Picture -> Picture;
::  EraseOval   !Oval !Picture -> Picture;
::  InvertOval  !Oval !Picture -> Picture;


<<  Circles:    a Circle with center c (Point) and radius r (INT) is
                defined by the tuple (c, r). >>

::  DrawCircle      !Circle !Picture -> Picture;
::  FillCircle      !Circle !Picture -> Picture;
::  EraseCircle     !Circle !Picture -> Picture;
::  InvertCircle    !Circle !Picture -> Picture;


<<  Wedges: a Wedge is a pie part of an Oval o starting from angle a
    upto angle b (both of type INT in degrees modulo 360):
        (o, a, b).
    Angles are always taken counterclockwise, starting from 3 o'clock.
    So angle 0 is at 3 o'clock, angle 90 (-270) at 12 o'clock,
    angle 180 (-180) at 9 o'clock and angle 270 (-90) at 6 o'clock. >>

::  DrawWedge   !Wedge !Picture -> Picture;
::  FillWedge   !Wedge !Picture -> Picture;
::  EraseWedge  !Wedge !Picture -> Picture;
::  InvertWedge !Wedge !Picture -> Picture;


<<  Polygons: a Polygon is a figure drawn by a number of lines without
    taking the pen of the Picture, starting from some Point p.
    The PolygonShape s (a list [v1,...,vN] of Vectors) defines how the
    Polygon is drawn:
        MoveTo p, DrawLine from v1 upto vN, DrawLineTo p to close it.
    So a Polygon with s [] is actually the Point p.
    
    ScalePolygon    by scale k sets shape [v1,...,vN] into [k*v1,...,k*vN].
                        Negative, as well as 0 are valid scales.
    MovePolygonTo   changes the starting point into the given Point and
    MovePolygon     moves the starting point by the given Vector. >>

::  ScalePolygon    !INT        !Polygon -> Polygon;
::  MovePolygonTo   !Point  !Polygon -> Polygon;
::  MovePolygon     !Vector !Polygon -> Polygon;

::  DrawPolygon     !Polygon !Picture   -> Picture;
::  FillPolygon     !Polygon !Picture   -> Picture;
::  ErasePolygon    !Polygon !Picture   -> Picture;
::  InvertPolygon   !Polygon !Picture   -> Picture;
*/

from picture import
    :: Picture, :: DrawFunction,
    :: Point, :: Line, :: Curve, :: Rectangle, :: RoundRectangle,
    :: Oval, :: Circle, :: Wedge, :: Polygon, :: PolygonShape, :: Vector,
    :: PenSize,
    :: PenMode (CopyMode, OrMode, XorMode, ClearMode, HiliteMode,
		        NotCopyMode, NotOrMode, NotXorMode, NotClearMode),
    :: PenPattern (BlackPattern, DkGreyPattern, GreyPattern, LtGreyPattern, WhitePattern),
    :: Colour (RGB,
        BlackColour, RedColour, WhiteColour, GreenColour,
        BlueColour, YellowColour, CyanColour, MagentaColour),
	MinRGB, MaxRGB,
    SetPenSize, SetPenMode, SetPenPattern, SetPenNormal, SetPenColour, SetBackColour,
    SetFont,SetFontName, SetFontStyle, SetFontSize,
        PictureCharWidth, PictureStringWidth, PictureFontMetrics,
    MovePenTo, MovePen, LinePenTo, LinePen,
    DrawChar, DrawString,
    DrawPoint, DrawLine, DrawCurve, DrawCPoint, DrawCLine, DrawCCurve,
    MoveRectangleTo, MoveRectangle,CopyRectangleTo,CopyRectangle,
    DrawRectangle,          FillRectangle,          EraseRectangle,     InvertRectangle,
    DrawRoundRectangle, FillRoundRectangle, EraseRoundRectangle,    InvertRoundRectangle,
    DrawOval,               FillOval,               EraseOval,              InvertOval,
    DrawCircle,             FillCircle,             EraseCircle,            InvertCircle,
    DrawWedge,              FillWedge,              EraseWedge,             InvertWedge,
    DrawPolygon,            FillPolygon,            ErasePolygon,           InvertPolygon,
    ScalePolygon, MovePolygonTo, MovePolygon;
