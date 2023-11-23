definition module osutil

import StdFunc
import StdIOCommon
import windowhandle
import ostypes, ostoolbox

from mac_types import :: Ptr, :: Rect

//loadRgnBBox	:: ! OSRgnHandle  !*OSToolbox -> (!OSRect,!*OSToolbox)
loadUpdateBBox :: !OSWindowPtr !*OSToolbox -> (!OSRect,!*OSToolbox)
loadUpdateRegion :: !OSWindowPtr !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
GlobalToLocal :: !Point2 !*OSToolbox -> (!Point2,!*OSToolbox)
LocalToGlobal :: !Point2 !*OSToolbox -> (!Point2,!*OSToolbox)
GetMousePosition :: !*OSToolbox -> (!Point2, !*OSToolbox)
WaitForMouseUp :: !*OSToolbox -> *OSToolbox
toModifiers :: !Int -> Modifiers
KeyMapToModifiers :: !(!Int,!Int,!Int,!Int) -> Modifiers
KeyEventInfo :: !Int !Int !Int -> (Bool,Bool,Bool)
getASCII :: !Int -> Char
getMacCode :: !Int -> Int
keyEventToKeyState :: !Int -> KeyState
assertPort` :: !OSWindowPtr !*OSToolbox -> *OSToolbox
appClipped :: !OSWindowPtr !(IdFun *OSToolbox) !*OSToolbox -> *OSToolbox
doWindowScrollers :: !OSWindowPtr !WindowData !Size !*OSToolbox -> (!WindowInfo,!*OSToolbox)
zoomWindow :: !OSWindowPtr !Int !Bool !*Toolbox -> *Toolbox;
invalRect :: !OSWindowPtr !Rect !*Toolbox -> *Toolbox;
