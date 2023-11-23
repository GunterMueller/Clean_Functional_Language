#include <X11/Xlib.h>
#include <xview/frame.h>
#include <xview/notify.h>
#include "clean_devices.h"

extern int ToplevelPanelKey;
extern int ToplevelHelpPanelKey;
extern int ToplevelAboutCanvasKey;
extern Time multi_click_time;

#define NOWIDGET -42
#define NODEVICE -42

extern void set_global_event(int, int, int, int, int, int, int, int);

extern int last_event;
extern int last_sub_widget;
extern int last_mouse_event;
extern int last_mouse_x;
extern int last_mouse_y;
extern int last_key_state;

extern Display *display;
extern Screen *screen;
extern Window default_window;
extern Frame toplevel;

extern void *my_malloc(size_t);
extern void *my_realloc(void *, size_t);
extern void my_free(void *);
extern char *cstring(const CLEAN_STRING);
extern char *cstring_shift(const CLEAN_STRING, const shift);
extern CLEAN_STRING cleanstring(const char *);
extern void check_init_toplevelx (void);

extern int get_argc (void);
extern CLEAN_STRING get_argv_n (int n);

