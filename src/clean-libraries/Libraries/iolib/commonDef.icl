implementation module commonDef;

//
// Common type for the event I/O system.
//

from StdString import class +++(+++), instance +++ ({#Char});
from StdMisc import abort;
from StdInt import instance < (Int);
from StdClass import class <(<), class Ord, >;
from deltaPicture import :: Rectangle, :: Point;

::	ItemTitle	:== String;

:: SelectState = Able | Unable;
:: MarkState   = Mark | NoMark;

:: KeyboardState :== (!KeyCode, !KeyState, !Modifiers);
:: KeyCode       :== Char;
:: KeyState     	= KeyUp | KeyDown | KeyStillDown;

:: MouseState    :== (!MousePosition, !ButtonState, !Modifiers);
:: MousePosition :== (!Int, !Int);
:: ButtonState   = ButtonUp | ButtonDown | ButtonDoubleDown |
                    ButtonTripleDown | ButtonStillDown;

/* Modifiers indicates the meta keys that have been pressed (TRUE)
   or not (FALSE): (Shift, Alternate/Meta, Control, Control)
*/
:: Modifiers     :== (!Bool,!Bool,!Bool,!Bool);

:: PictureDomain :== Rectangle;

SelectStateEqual :: !SelectState !SelectState -> Bool;
SelectStateEqual Able   Able   =  True;
SelectStateEqual Unable Unable =  True;
SelectStateEqual s t =  False;

MarkEqual :: !MarkState !MarkState -> Bool;
MarkEqual Mark   Mark   =  True;
MarkEqual NoMark NoMark =  True;
MarkEqual m n =  False;

Enabled :: !SelectState -> Bool;
Enabled Able   =  True ;
Enabled Unable =  False;

SetBetween :: !Int !Int !Int -> Int;
SetBetween x low up 
  | x < low   = low;
  | x > up    = up;
              = x;

Error :: !String !String !String -> .x;
Error rule modulename error = abort ( "Error in rule " +++ rule +++ " [" +++ modulename +++ "]: " +++ error +++ ".\n");
