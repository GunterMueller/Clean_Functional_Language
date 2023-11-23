definition module windowDef;

/* The type definitions for the window device.
*/

import commonDef;
from deltaPicture import :: Picture, :: DrawFunction;


    

:: WindowDef * s * io
   = ScrollWindow WindowId WindowPos WindowTitle
                   ScrollBarDef ScrollBarDef
                   PictureDomain MinimumWindowSize InitialWindowSize
                   (UpdateFunction s) [WindowAttribute s io]
   |  FixedWindow  WindowId WindowPos WindowTitle
                   PictureDomain
                   (UpdateFunction s) [WindowAttribute s io];
 
:: WindowId          :== Int;
:: WindowPos         :== (!Int, !Int);
:: WindowTitle       :== String;

:: ScrollBarDef      = ScrollBar ThumbValue ScrollValue;
:: ThumbValue        = Thumb  Int;
:: ScrollValue       = Scroll Int;
:: MinimumWindowSize :== (!Int, !Int);
:: InitialWindowSize :== (!Int, !Int);
:: UpdateArea        :== [Rectangle];

:: UpdateFunction * s        :== UpdateArea ->  s -> *(s,[DrawFunction]) ;
:: GoAwayFunction * s * io :== s ->  * (io -> *(s, io)) ;
 
:: WindowAttribute * s * io
   = Activate   (WindowFunction s io)
   |  Deactivate (WindowFunction s io)
   |  GoAway     (WindowFunction s io)
   |  Mouse      SelectState (MouseFunction    s io)
   |  Keyboard   SelectState (KeyboardFunction s io)
   |  Cursor     CursorShape
   |  StandByWindow;

:: WindowFunction   * s * io :== s ->  * (io -> *(s, io)) ;
:: KeyboardFunction * s * io :== KeyboardState ->  s -> *( io -> *(s, io) ) ;
:: MouseFunction    * s * io :== MouseState ->     s -> *( io -> *(s, io) ) ;
 
:: CursorShape = StandardCursor | BusyCursor     | IBeamCursor |
                  CrossCursor    | FatCrossCursor | ArrowCursor |
                  HiddenCursor;

