definition module commonDef;

//
// Common type for the event I/O system.
//

from deltaPicture import :: Rectangle, :: Point;

::	ItemTitle	:== String;

:: SelectState = Able | Unable;
:: MarkState   = Mark | NoMark;

:: KeyboardState :== (!KeyCode, !KeyState, !Modifiers);
:: KeyCode       :== Char;
:: KeyState     = KeyUp | KeyDown | KeyStillDown;

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
MarkEqual :: !MarkState !MarkState -> Bool;
Enabled ::   !SelectState -> Bool;
SetBetween :: !Int !Int !Int -> Int;
Error :: !String !String !String -> .x;
