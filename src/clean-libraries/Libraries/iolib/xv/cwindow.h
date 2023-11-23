#include <xview/xview.h>
#include "windowdata.h"

extern int my_local_mouse_x;
extern int my_local_mouse_y;
extern int double_down_distance;
extern ButtonDownState button_down;
extern Xv_Window my_last_window;
extern int UserDataKey;

extern void init_window(void);
extern MyBoolean ButtonStillDown(void);
extern void ButtonStillDownEvent(void);
