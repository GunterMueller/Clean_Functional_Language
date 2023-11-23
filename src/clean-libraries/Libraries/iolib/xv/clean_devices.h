/* device numbers corresponding with the devices in the Clean gui
   c: Leon Pillich 1992

   1993 (Sven Panne) : added ifndef
*/

#ifndef clean_devices_DEFINED
#define clean_devices_DEFINED

#define CLEAN_DEVICE int

#define CLEAN_MENU_DEVICE       1
#define CLEAN_NULL_DEVICE       4
#define CLEAN_TIMER_DEVICE      5
#define CLEAN_WINDOW_DEVICE     6
#define CLEAN_DIALOG_DEVICE     7

/* special window events */
#define CLEAN_WINDOW_KEYBOARD   2
#define CLEAN_WINDOW_MOUSE      3
#define CLEAN_WINDOW_ACTIVATE   20
#define CLEAN_WINDOW_DEACTIVATE 21
#define CLEAN_WINDOW_UPDATE     22
#define CLEAN_WINDOW_CLOSED     23

/* special dialog events */
#define CLEAN_DIALOG_BUTTON     30
#define CLEAN_DIALOG_CLOSED     31
#define CLEAN_DIALOG_RADIOB     32
#define CLEAN_DIALOG_CHECKB     33
#define CLEAN_DIALOG_REDRAW     34
#define CLEAN_DIALOG_MOUSE      35
#define CLEAN_DIALOG_APPLY      36
#define CLEAN_DIALOG_RESET      37
#define CLEAN_DIALOG_IMOUSE     38
#define CLEAN_DIALOG_IREDRAW    39
#define CLEAN_DIALOG_ACTIVATE   40
#define CLEAN_ABOUT_REDRAW      41
#define CLEAN_ABOUT_HELP        42

/* mouse/keyboard events */
#define NOTHING         0
#define BUTTONUP        1
#define BUTTONDOWN      2
#define BUTTONSTILLDOWN 3
#define DOUBLECLICK     4
#define TRIPLECLICK     5
#define KEYUP           1
#define KEYDOWN         2
#define KEYSTILLDOWN    3

/* cursor shapes */
#define STANDARDCURSOR          0
#define BUSYCURSOR              1
#define IBEAMCURSOR             2
#define CROSSCURSOR             3
#define FATCROSSCURSOR          4
#define ARROWCURSOR             5

#endif
