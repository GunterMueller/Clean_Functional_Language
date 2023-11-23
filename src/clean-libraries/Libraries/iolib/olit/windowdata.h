/* This c header file contains the typedefinition for the WindowData type,
   an data structure containing all necessary window information needed
   in a Clean program.
   Furthermore some auxiliary types are declared.
   Leon Pillich, October 1992
*/

typedef struct _WindowData
{
        /* Data primarily associated with the window */
        Widget hscrollbar;
        Widget vscrollbar;
/* RWS */
        Widget shell;
/* */

        /* Data associated with the picture domain */
        Widget picture;
        int width,height;
        int x0,y0;

        /* Data associated with the actual picture */
        GC window_gc;
        int curx,cury;
        int pen;

        /* Font information for the pictures gc */
        XFontStruct *font_info;
        char *font_name;
        char *font_style;
        char *font_size;

        /* Is this window active? */
        Boolean active;
} WindowData;

/* Keeping track of multiclicks */
typedef enum {NoClick, OneClick, TwoClicks} ClickCount;

/* Keeping track of button still down events. */
typedef enum {ButtonUp, ButtonStillDownWindow,
              ButtonStillDownDialog} ButtonDownState;

/* modifiers */
typedef struct modifiers
{ int shift;
  int option;
  int command;
  int control;
} CleanModifiers;

/* from clean types */
typedef struct clean_string
{
        int     length;
        char    characters[0];
} *CLEAN_STRING;

