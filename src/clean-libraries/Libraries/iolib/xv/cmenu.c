/*
   This module implements support for creating and handling XView menus in Concurrent
   Clean Event I/O. This menu (the menu bar) is placed in the applications root window
   and a copy is made that is used (transparently) as a popup menu for every document
   window that is created.

   The interfacing to Clean for this module can be found in xmenu.fcl. These functions
   are used by the Clean modules menuDevice and deltaMenu.

   1991/1992: Leon Pillich.
   1994: Sven Panne.
*/

typedef int MyBoolean;

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include <xview/xview.h>
#include <xview/panel.h>

#include <ctype.h>
#include <string.h>

#include "interface.h"
#include "clean_devices.h"
#include "windowdata.h"
#include "cmenu.h"
#include "ckernel.h"
#include "cfileselect.h"

#define MY_CHECKED_CHAR   '\256'
#define MY_UNCHECKED_CHAR ' '

/* global to hold menu bar widget */
Panel global_menu_bar;
Menu global_popup;
MyBoolean MenuPresent;

#define MIN_SHORTCUT_CHAR ' '
#define MAX_SHORTCUT_CHAR '~'
#define NO_SHORTCUT_CHAR  '\0'

#define NO_SHORTCUT ((int)XV_NULL)
static int shortcuts[MAX_SHORTCUT_CHAR - MIN_SHORTCUT_CHAR + 1];

#define SHORTCUT_PREFIX "  ^"

static int MenuParentKey;
static int MenuBrotherKey;
static int ItemMarkedKey;
static int ItemShortcutKey;

void
init_menu(void)
{
  int i;

  MenuPresent  = FALSE;
  for (i = MIN_SHORTCUT_CHAR;  i <= MAX_SHORTCUT_CHAR;  i++)
    shortcuts[i - MIN_SHORTCUT_CHAR] = NO_SHORTCUT;

  MenuParentKey   = xv_unique_key();
  MenuBrotherKey  = xv_unique_key();
  ItemMarkedKey   = xv_unique_key();
  ItemShortcutKey = xv_unique_key();
}

int last_shortcut_key_state;

int
handle_shortcut(XKeyEvent *event)
{
  char ch, buffer[16];
  int handled;
  int item;
  KeySym keysym;
  XComposeStatus compose;

  handled = 0;

  if ((event->state) & ControlMask) {
    event->state &= ~ControlMask;
    XLookupString(event, buffer, sizeof(buffer), &keysym, &compose);
    event->state |= ControlMask;
    ch = (char)tolower(buffer[0]);

    if ((ch >= MIN_SHORTCUT_CHAR) && (ch <= MAX_SHORTCUT_CHAR)) {
      item = shortcuts[ch - MIN_SHORTCUT_CHAR];
      if (item != NO_SHORTCUT) {
        set_global_event(CLEAN_MENU_DEVICE, item, 0, 0, 0, 0, 0, 0);
        last_shortcut_key_state = event->state;
        handled = 1;
#ifdef DEBUG
        fprintf(stderr, "handle_shortcut <%c>\n", ch);
#endif
      }
    }
  }
  return handled;
}

int get_last_shortcut_shift_state (int dummy)
{
	return (last_shortcut_key_state & ShiftMask)!=0;
}

int
destroy_item_widget (int item)
{
#ifdef DEBUG
  fprintf(stderr, "destroy_item_widget 0x%X\n", item);
#endif

  /* A button and a corresponding popup submenu share the same menu, so we have to
     remove and destroy only once. */
  xv_set((Menu)xv_get((Menu_item)item, XV_KEY_DATA, MenuParentKey),
         MENU_REMOVE_ITEM, (Menu_item)item,
         NULL);
  xv_destroy_safe((Menu_item)item);
  return 0;
}

int
destroy_menu (int menu)
{
#ifdef DEBUG
  fprintf(stderr, "Destroying menu 0x%X\n", global_popup /*menu*/);
#endif

  /* The toplevel menu gets destroyed when the toplevel itself gets destroyed.
     So we have to destroy the popup menu only. */

  xv_destroy_safe (global_popup);
  
  return 0;
}

static void
menu_item_notify_proc (Menu menu, Menu_item menu_item)
{
#ifdef DEBUG
  fprintf(stderr, "Menu event: item 0x%X from menu 0x%X\n", (int)menu_item, (int)menu);
#endif

  set_global_event(CLEAN_MENU_DEVICE, (int)menu_item, 0, 0, 0, 0, 0, 0);
}

int
show_menu(int menu_bar)
{
#ifdef DEBUG
  fprintf(stderr, "show_menu 0x%X\n", menu_bar);
#endif

  MenuPresent = True;
  xv_set((Panel)menu_bar, XV_SHOW, TRUE, NULL);
  return menu_bar;
}

int
hide_menu(int menu_bar)
{
#ifdef DEBUG
  fprintf(stderr, "hide_menu 0x%X\n", menu_bar);
#endif

  MenuPresent = False;
  xv_set((Panel)menu_bar, XV_SHOW, FALSE, NULL);
  return menu_bar;
}

/* menus will be added in a menu bar */
int
add_menu_bar(int dummy)
{
  global_menu_bar = (Panel)xv_get(toplevel, XV_KEY_DATA, ToplevelPanelKey);
  global_popup = (Menu)xv_create((Xv_window)NULL, MENU, NULL);
  MenuPresent = True;

#ifdef DEBUG
  fprintf(stderr,"Menu Bar Created: menu 0x%X,  popup 0x%X\n",
          (int)global_menu_bar, (int)global_popup);
#endif

  return (int)global_menu_bar;
}

int
add_menu(int bar, CLEAN_STRING title)
{
  Panel panel;
  Panel_button_item button;
  Menu menu;
  Menu_item item;
  char *s;

  s = cstring(title);

  menu   = (Menu)xv_create(XV_NULL, MENU, NULL);

  panel  = (Panel)xv_get(toplevel, XV_KEY_DATA, ToplevelPanelKey);

  item   = (Menu_item)xv_create(XV_NULL, MENUITEM,
                                MENU_STRING,        s,
                                MENU_RELEASE_IMAGE,
                                MENU_PULLRIGHT,     menu,
                                NULL);
  xv_set(global_popup, MENU_APPEND_ITEM, item, NULL);

  button = (Panel_button_item)xv_create(panel, PANEL_BUTTON,
                                        PANEL_LABEL_STRING, s,
                                        PANEL_ITEM_MENU,    menu,
                                        XV_KEY_DATA,        MenuBrotherKey, item,
                                        NULL);

  xv_set(menu, XV_KEY_DATA, MenuParentKey, button, NULL);

#ifdef DEBUG
  fprintf(stderr,"adding menu 0x%X with title <%s> to bar 0x%X\n", (int)menu, s, bar);
#endif

  return (int)menu;
}

int
add_sub_menu(int menu, CLEAN_STRING title)
{
  char *s;
  Menu sub_menu;
  Menu_item item;

  s        = cstring_shift(title, 1);
  s[0]     = MY_UNCHECKED_CHAR;
  sub_menu = (Menu)xv_create(XV_NULL, MENU, NULL);
  item     = (Menu_item)xv_create(XV_NULL, MENUITEM,
                                  MENU_STRING,        s,
                                  MENU_RELEASE_IMAGE,
                                  MENU_PULLRIGHT,     sub_menu,
                                  XV_KEY_DATA,        ItemMarkedKey,  0,
                                  XV_KEY_DATA,        MenuBrotherKey, XV_NULL,
                                  NULL);
  xv_set((Menu)menu, MENU_APPEND_ITEM, item, NULL);
  xv_set(sub_menu, XV_KEY_DATA, MenuParentKey, item, NULL);

#ifdef DEBUG
  fprintf(stderr,"Adding submenu 0x%X with title <%s> to menu 0x%X\n", (int)sub_menu, s, menu);
#endif

  return (int)sub_menu;
}

int
add_check_item(int menu, CLEAN_STRING title, int check)
{
  char *s;
  Menu_item item;

  s = cstring_shift(title, 1);
  s[0] = (check == 1) ? MY_CHECKED_CHAR : MY_UNCHECKED_CHAR;

  item = (Menu)xv_create(XV_NULL, MENUITEM,
                         MENU_STRING,        s,
                         MENU_RELEASE_IMAGE,
                         MENU_NOTIFY_PROC,   menu_item_notify_proc,
                         XV_KEY_DATA,        ItemMarkedKey,   check,
                         XV_KEY_DATA,        ItemShortcutKey, NO_SHORTCUT_CHAR,
                         XV_KEY_DATA,        MenuParentKey,   (Menu)menu,
                         NULL);
  xv_set((Menu)menu, MENU_APPEND_ITEM, item, NULL);

#ifdef DEBUG
  fprintf(stderr,"Adding check item 0x%X with title <%s> to menu 0x%X, check: %d\n",
          (int)item, s, menu, check);
#endif

  return (int)item;
}

int
add_menu_separator(int menu)
{
  Menu_item item;

  /* Sven: The gap is too large, but XView wants every menu item to be of the same height... */
  item = (Menu_item)xv_create(XV_NULL,
                              MENUITEM_SPACE,
                              XV_KEY_DATA,    ItemMarkedKey,   0,
                              XV_KEY_DATA,    ItemShortcutKey, NO_SHORTCUT_CHAR,
                              XV_KEY_DATA,    MenuParentKey,   (Menu)menu,
                              NULL);
  xv_set((Menu)menu, MENU_APPEND_ITEM, item, NULL);

#ifdef DEBUG
  fprintf(stderr,"Adding menu separator 0x%X to menu 0x%X\n", (int)item, menu);
#endif

  return (int)item;
}

int
add_menu_item(int menu, CLEAN_STRING title)
{
  char *s;
  Menu_item item;

  s = cstring_shift(title, 1);
  s[0] = MY_UNCHECKED_CHAR;
  item = (Menu_item)xv_create(XV_NULL, MENUITEM,
                              MENU_STRING,        s,
                              MENU_RELEASE_IMAGE,
                              MENU_NOTIFY_PROC,   menu_item_notify_proc,
                              XV_KEY_DATA,        ItemMarkedKey,   0,
                              XV_KEY_DATA,        ItemShortcutKey, NO_SHORTCUT_CHAR,
                              XV_KEY_DATA,        MenuParentKey,   (Menu)menu,
                              NULL);
  xv_set((Menu)menu, MENU_APPEND_ITEM, item, NULL);

#ifdef DEBUG
  fprintf(stderr,"Adding menu item 0x%X with title <%s> to menu 0x%X\n", (int)item, s, menu);
#endif

  return (int)item;
}

int
enable_menu_widget(int w)
{
  Xv_pkg *type;
  Xv_opaque brother;

#ifdef DEBUG
  fprintf(stderr, "Enabling 0x%X...", w);
#endif
  type = (Xv_pkg *)xv_get((Xv_object)w, XV_TYPE);
  if (type == MENU) {
    enable_menu_widget((int)xv_get(w, XV_KEY_DATA, MenuParentKey));
    brother = xv_get(w, XV_KEY_DATA, MenuBrotherKey);
    if (brother != XV_NULL)
      enable_menu_widget(brother);
  } else if (type == MENUITEM) {
#ifdef DEBUG
    fprintf(stderr, "Menu item 0x%X enabled\n", w);
#endif
    xv_set((Menu_item)w, MENU_INACTIVE, FALSE, NULL);
  } else if (type == PANEL_BUTTON) {
#ifdef DEBUG
    fprintf(stderr, "Panel Button 0x%X enabled\n", w);
#endif
    xv_set((Panel_item)w, PANEL_INACTIVE, FALSE, NULL);
  }
  return w;
}

int
disable_menu_widget(int w)
{
  Xv_pkg *type;
  Xv_opaque brother;

#ifdef DEBUG
  fprintf(stderr, "Disabling 0x%X...", w);
#endif
  type = (Xv_pkg *)xv_get((Xv_object)w, XV_TYPE);
  if (type == MENU) {
    disable_menu_widget((int)xv_get(w, XV_KEY_DATA, MenuParentKey));
    brother = xv_get(w, XV_KEY_DATA, MenuBrotherKey);
    if (brother != XV_NULL)
      disable_menu_widget(brother);
  } else if (type == MENUITEM) {
#ifdef DEBUG
    fprintf(stderr, "Menu item 0x%X disabled\n", w);
#endif
    xv_set((Menu_item)w, MENU_INACTIVE, TRUE, NULL);
  } else if (type == PANEL_BUTTON) {
#ifdef DEBUG
    fprintf(stderr, "Panel Button 0x%X disabled\n", w);
#endif
    xv_set((Panel_item)w, PANEL_INACTIVE, TRUE, NULL);
  }
  return w;
}

int
check_widget(int menu_item, int check)
{
  char *s;

  /* The old MENU_STRING is released by XView on set! */
  s    = duplicate_string((char *)xv_get((Menu_item)menu_item, MENU_STRING));
  s[0] = (check == 1) ? MY_CHECKED_CHAR : MY_UNCHECKED_CHAR;
  xv_set((Menu_item)menu_item,
         MENU_STRING,        s,
         MENU_RELEASE_IMAGE,
         XV_KEY_DATA,        ItemMarkedKey, check,
         NULL);

#ifdef DEBUG
  fprintf(stderr,"Widget 0x%X checked: %d\n", menu_item, check);
#endif

  return menu_item;
}

int
set_widget_title(int item, CLEAN_STRING title)
{
  char *new, *tmp, buf[2], ch;
  int check;

  check  = (int)xv_get((Menu_item)item, XV_KEY_DATA, ItemMarkedKey);
  ch     = (int)xv_get((Menu_item)item, XV_KEY_DATA, ItemShortcutKey);
  new    = cstring_shift(title, 1);
  new[0] =  (check == 1) ? MY_CHECKED_CHAR : MY_UNCHECKED_CHAR;
  if (ch != NO_SHORTCUT_CHAR) {
    buf[0] = (char)ch;
    buf[1] = '\0';
    tmp = append_strings3(new, SHORTCUT_PREFIX, buf);
    my_free(new);
    new = tmp;
  }
  xv_set((Menu_item)item,
         MENU_STRING,        new,
         MENU_RELEASE_IMAGE,
         NULL);

#ifdef DEBUG
  fprintf(stderr,"Title of menu item 0x%X changed to <%s>\n", item, new);
#endif

  return item;
}

/* installing a key shortcut */
int
install_shortcut(int item, CLEAN_STRING c)
{
  char ch[2];

  /* We don't make a difference between upper case and lower case within shortcuts */
  ch[0] = (char)tolower((c->characters)[0]);
  ch[1] = '\0';

  if ((ch[0] >= MIN_SHORTCUT_CHAR) && (ch[0] <= MAX_SHORTCUT_CHAR)) {

    shortcuts[ch[0] - MIN_SHORTCUT_CHAR] = item;
    xv_set((Menu_item)item,
           MENU_STRING,        append_strings3((char *)xv_get((Menu_item)item, MENU_STRING),
                                               SHORTCUT_PREFIX,
                                               ch),
           MENU_RELEASE_IMAGE,
           XV_KEY_DATA,        ItemShortcutKey, ch[0],
           NULL);

#ifdef DEBUG
      fprintf(stderr,"Shortcut: '%c' installed on item 0x%X\n", ch[0], item);
#endif
  }

  return item;
}

struct clean_string_4 {
	int length;
	char chars[4];
};

static struct clean_string_4 key_string;

/* we need to get information about menu items to reconstuct the MenuElement */
void
get_item_info(int item, int *ability, int *state, CLEAN_STRING *title, CLEAN_STRING *shortcut)
{
  int inactive, key;
  char *s;

  inactive  = (int)xv_get((Menu_item)item, MENU_INACTIVE);
  *ability  = (inactive == TRUE) ? 0 : 1;

  *state    = (int)xv_get((Menu_item)item, XV_KEY_DATA, ItemMarkedKey);

  key       = (int)xv_get((Menu_item)item, XV_KEY_DATA, ItemShortcutKey);
  if (key == NO_SHORTCUT_CHAR)
  	key_string.length=0;
  else {
  	key_string.length=1;
	key_string.chars[0]=(char)key;
  }
  *shortcut = (CLEAN_STRING) &key_string;

  s         = duplicate_string((char *)xv_get((Menu_item)item, MENU_STRING) + 1);
  if (key != NO_SHORTCUT_CHAR) {
    s[strlen(s) - (strlen(SHORTCUT_PREFIX) + 1)] = '\0';
  }
  *title    = cleanstring(s);

#ifdef DEBUG
  fprintf(stderr,"info of menu item 0x%X: ability %d, state %d, title <%s>, shortcut <%s>\n",
          item, *ability, *state, s);
#endif

  my_free(s);
}

void
get_submenu_info(int submenu, CLEAN_STRING *title, int *ability)
{
  int inactive;
  char *s;

  inactive = (int)xv_get((Menu)submenu, MENU_INACTIVE);
  *ability = (inactive == TRUE) ? 0 : 1;

  s        = (char *)xv_get((Menu)submenu, MENU_STRING);
  *title   = cleanstring(s + 1);

#ifdef DEBUG
  fprintf(stderr,"info of menu submenu 0x%X:  title <%s>, ability %d\n",
          submenu, s + 1, *ability);
#endif
}
