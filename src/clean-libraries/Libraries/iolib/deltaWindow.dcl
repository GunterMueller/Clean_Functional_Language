definition module deltaWindow;

//  Version 0.8

//
//  Operations on windows.
//

import deltaIOSystem, deltaEventIO, deltaPicture;


/*  Functions that operate on the active window are identical to the
    functions that operate on a WindowId or [WindowId], but are
    slightly faster. If there are no windows nothing happens. */

OpenWindows  :: ![WindowDef s (IOState s)] !(IOState s) -> IOState s;

/*  The windows are opened in the same order as they are specified
    in the list of WindowDefs. If one of these windows has the
    WindowId of an already open window the window is not opened.
    Each new window becomes the frontmost, active window. */
    
CloseWindows  :: ![WindowId] !(IOState s) -> IOState s;
CloseActiveWindow  ::        !(IOState s) -> IOState s;

/*  The windows are closed in the same order as in the list (CloseWindows)
    or the active window (CloseActiveWindow). */

GetActiveWindow  :: !(IOState s) -> (!Bool, !WindowId, !IOState s);

/*  Returns TRUE and the id of the active window if there is an
    active window. If not, it returns FALSE and WindowId 0. */

ActivateWindow  :: !WindowId !(IOState s) -> IOState s;

/*  Activate the window with the indicated Id. If the window was
    already the active window nothing happens. */

ChangeUpdateFunction  :: !WindowId !(UpdateFunction s)
    !(IOState s) -> IOState s;
ChangeActiveUpdateFunction  :: !(UpdateFunction s) !(IOState s)
    -> IOState s;

/*  Changes the update functions of the indicated windows
    (ChangeUpdateFunctions) or of the active window
    (ChangeActiveUpdateFunction). */

ChangeWindowTitle  :: !WindowId !WindowTitle !(IOState s) -> IOState s;
ChangeActiveWindowTitle  ::     !WindowTitle !(IOState s) -> IOState s;

/*  Changes the cursor of the indicated window or the active window.
*/
ChangeWindowCursor  :: !WindowId !CursorShape !(IOState s) -> IOState s;
ChangeActiveWindowCursor  :: !CursorShape !(IOState s) -> IOState s;

/*  Changes the title of the indicated window (ChangeWindowTitle) or of
    the active window (ChangeActiveWindowTitle). */

::  ScrollBarChange
    =  ChangeThumbs  Int Int   // set new horizontal and vertical thumb values
    |   ChangeScrolls Int Int   // set new horizontal and vertical scroll values
    |   ChangeHThumb  Int       // set new horizontal thumb value
    |   ChangeVThumb  Int       // set new vertical thumb value
    |   ChangeHScroll Int       // set new horizontal scroll value
    |   ChangeVScroll Int       // set new vertical scroll value
    |   ChangeHBar    Int Int   // set new horizontal thumb and scroll values
    |   ChangeVBar    Int Int;  // set new vertical thumb and scroll values

ChangeScrollBar :: !WindowId !ScrollBarChange !*s !(IOState *s) -> (!*s, !IOState *s);
ChangeActiveScrollBar :: !ScrollBarChange !*s !(IOState *s) -> (!*s, !IOState *s);

/*  Change the values of the Thumbs and the Scrolls of the indicated
    window (ChangeScrollBar) or the active window (ChangeActiveScrollBar).
    Illegal Thumb and Scroll values are adjusted to an acceptable value. */

ChangePictureDomain :: !WindowId !PictureDomain !*s !(IOState *s) -> (!*s, !IOState *s);
ChangeActivePictureDomain :: !PictureDomain !*s !(IOState *s) -> (!*s, !IOState *s);
/*  Changes the PictureDomains of the indicated windows (ChangePictureDomains)
    or of the active window (ChangeActivePictureDomain).
    The settings of the scrollbars are automatically adjusted. The window will
    be resized when the new domain is smaller than the current size. */

DrawInWindow  :: !WindowId ![DrawFunction] !(IOState s) -> IOState s;
DrawInActiveWindow  ::     ![DrawFunction] !(IOState s) -> IOState s;

/*  Applies the list of DrawFunctions (see deltaPicture.dcl) in the given order
    to the Picture of the indicated window (DrawInWindow) or the active window
    (DrawInActiveWindow). */

DrawInWindowFrame :: !WindowId !(UpdateFunction *s) !*s !(IOState *s) -> (!*s, !IOState *s);
DrawInActiveWindowFrame :: !(UpdateFunction *s) !*s !(IOState *s) -> (!*s, !IOState *s);

/*  Applies the list of DrawFunctions yielded by the UpdateFunction to the
    Picture of the indicated window (DrawInWindowFrame) or the active window
    (DrawInActiveWindowFrame).
    The UpdateFunction has a list of visible rectangles as parameter, which
    makes it possible to return a list of drawing functions that only draw in
    the visible part of the window. */

WindowGetFrame  :: !WindowId !(IOState s) -> (!PictureDomain, !IOState s);
WindowGetPos :: !WindowId !(IOState s) -> (!Point,!IOState s);
ActiveWindowGetFrame  ::     !(IOState s) -> (!PictureDomain, !IOState s);

/*  WindowGetFrame yields the visible part of the Picture of the indicated
    window (WindowGetFrame) or the active window (ActiveWindowGetFrame) in
    terms of a PictureDomain. In case the WindowId is unknown, ((0,0),(0,0))
    is returned. */

EnableKeyboard  ::  !WindowId !(IOState s) -> IOState s;
DisableKeyboard  :: !WindowId !(IOState s) -> IOState s;
EnableActiveKeyboard  :: !(IOState s) -> IOState s;
DisableActiveKeyboard  :: !(IOState s) -> IOState s;
ChangeKeyboardFunction  :: !WindowId !(KeyboardFunction s (IOState s))
    !(IOState s) -> IOState s;
ChangeActiveKeyboardFunction  :: !(KeyboardFunction s (IOState s))
    !(IOState s) -> IOState s;

/*  Enabling, disabling and changing the KeyboardFunction of the
    indicated window(s) (EnableKeyboards, DisableKeyboards and 
    ChangeKeyboardFunction) or of the active window (EnableActiveKeyboard,
    DisableActiveKeyboard, ChangeActiveKeyboardFunction). */

EnableMouse  :: !WindowId !(IOState s) -> IOState s;
DisableMouse  :: !WindowId !(IOState s) -> IOState s;
EnableActiveMouse  :: !(IOState s) -> IOState s;
DisableActiveMouse  :: !(IOState s) -> IOState s;
ChangeMouseFunction  :: !WindowId !(MouseFunction s (IOState s))
    !(IOState s) -> IOState s;
ChangeActiveMouseFunction  :: !(MouseFunction s (IOState s))
    !(IOState s) -> IOState s;

/*  Enabling, disabling and changing the MouseFunction of the
    indicated window(s) (EnableMice, DisableMice, ChangeMouseFunction)
    or of the active window (EnableActiveMouse, DisableActiveMouse,
    ChangeActiveMouseFunction). */
