definition module deltaFont;

//  Version 0.8

//
//  Operations on Fonts.
//

/*
ABSTYPE
::  Font;

TYPE
::  FontName        -> STRING;
::  FontStyle   -> STRING;
::  FontSize        -> INT;
::  FontInfo        -> (!INT, !INT, !INT, !INT);

MACRO
    MinFontSize     -> 6;
    MaxFontSize     -> 128;
    
RULE

::  SelectFont !FontName ![FontStyle] !FontSize -> (!BOOL, !Font);

<<  SelectFont creates the font as specified by the name, the stylistic
    variations and size. In case there are no FontStyles ([]), the font
    is selected without stylistic variations (i.e. in plain style).
    The size is always adjusted between MinFontSize and MaxFontSize.
    The boolean result is TRUE in case this font is available and needn't
    be scaled. In case the font is not available, the default font is
    chosen in the indicated style and size. >>

::  DefaultFont -> (!FontName, ![FontStyle], !FontSize);

<<  DefaultFont returns name, style and size of the default font. >>

::  FontNames               -> [FontName];
::  FontStyles !FontName    -> [FontStyle];
::  FontSizes  !FontName    -> [FontSize];

<<  FontNames   returns the FontNames of all available fonts.
    FontStyles  returns the FontStyles of all available styles.
    FontSizes   returns all FontSizes of a font that are available without scaling.
    In case the font is unavailable, the styles or sizes of the default font
    are returned. >>


::  FontCharWidth       !CHAR           !Font -> INT;
::  FontCharWidths      ![CHAR]     !Font -> [INT];
::  FontStringWidth !STRING     !Font -> INT;
::  FontStringWidths    ![STRING]   !Font -> [INT];

<<  FontCharWidth(s) (FontStringWidth(s)) return the width(s) in terms of pixels
    of given character(s) (string(s)) for a particular Font. >>

::  FontMetrics !Font -> FontInfo;

<<  FontMetrics yields the FontInfo in terms of pixels of a given Font. The FontInfo
    is a four-tuple (ascent, descent, max width, leading) which defines the metrics
    of a font:
        - ascent        is the height of the top most character measured from the base
        - descent   is the height of the bottom most character measured from the base
        - max width is the width of the widest character including spacing
        - leading   is the vertical distance between two lines of the same font.
    The full height of a line is the sum of the ascent, descent and leading. >>
*/

from picture import
    :: Font, :: FontName, :: FontStyle, :: FontSize, :: FontInfo,
    MinFontSize, MaxFontSize,
    SelectFont, DefaultFont,
    FontNames, FontStyles, FontSizes,
    FontCharWidth, FontStringWidth, FontCharWidths, FontStringWidths, FontMetrics;
