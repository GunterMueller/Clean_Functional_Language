#include <X11/Xlib.h>
#include <xview/xview.h>
#include <xview/panel.h>
#include "windowdata.h"

extern Panel global_menu_bar;
extern Menu global_popup;
extern MyBoolean MenuPresent;

extern void init_menu(void);
extern int handle_shortcut(XKeyEvent *);
