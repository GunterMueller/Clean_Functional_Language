/*
   This module implements support functions for creating and handling
   Open Look Notice, Property and (Modal and Modeless) Command
   dialogs. Furthermore a rudimentairy about dialog is implemented 
   as a simple dialog in the applications root window.

   The interfacing functions for Clean for this module can be found
   in xdialog.fcl. These functions are used in the Clean modules
   dialogDevice and deltaDialog.

   1992: Leon Pillich
   1994: Sven Panne
*/

typedef int MyBoolean;

#include <X11/Xlib.h>
#include <xview/xview.h>
#include <xview/canvas.h>
#include <xview/notice.h>
#include <xview/panel.h>
#include <xview/xv_xrect.h>
#include <xview/notify.h>
#include <xview/cms.h>
#include "interface.h"
#include "windowdata.h"
#include "ckernel.h"
#include "cwindow.h"
#include "cpicture.h"


#define ModalCommandDialog      0
#define ModelessCommandDialog   1
#define PropertyDialog          2

#define GroupRows               0
#define GroupColumns            1

#define MarkOn                  0
#define MarkOff                 1

#define Able                    0
#define Unable                  1

#define ControlTypeCustom       0
#define ControlTypeIcon         1


/* A dialog item can't be represented directly by an XView object, because check boxes and
   radio buttons are no seperate XView objects (they are only part of a PANEL_CHOICE).
   The XView toolbox really could do a better job here! =:-( */
struct dialog_item_struct {
  Xv_object di_item;             /* XView item to which the dialog item belongs */
  unsigned int di_sub_item_no;   /* button number */
  int di_select_state;           /* Able or Unable */
};
typedef struct dialog_item_struct *dialog_item_t;


/* To return the corresponding dialog item, we need a list of dialog items for
   every PANEL_CHOICE. */
struct choice_button_struct {
  int cb_item;                           /* dialog item */
  int cb_choice_number;                  /* button number */
  int cb_toggle_value;                   /* MarkOn or MarkOff */
  struct choice_button_struct *cb_next;  /* next element in list */
};
typedef struct choice_button_struct *choice_button_t;


/* A dialog is not an XView object, either! :-[ */
struct dialog_info_struct {
  Frame di_frame;
  Panel di_panel;
  Panel_button_item di_apply_button;
  Panel_button_item di_reset_button;
  int di_active;
  int di_mode;
};
typedef struct dialog_info_struct *dialog_info_t;


enum ChoiceMode {DialogPopUp, RadioButtons, CheckBoxes};


static int DialogItemKey;
static int ButtonListKey;
static int ChoiceNumberKey;
static int DialogInfoKey;
static int ControlActiveKey;

static Xv_Window about_dialog_item;

void
init_dialog(void)
{
#ifdef DEBUG
  fprintf(stderr, "init_dialog\n");
#endif

  DialogItemKey    = xv_unique_key();
  ButtonListKey    = xv_unique_key();
  ChoiceNumberKey  = xv_unique_key();
  DialogInfoKey    = xv_unique_key();
  ControlActiveKey = xv_unique_key();
}


static void
free_dialog_info(Xv_object object, int key, caddr_t data)
{
#ifdef DEBUG
    fprintf(stderr, "freeing dialog info 0x%X\n", (int)data);
#endif

    my_free((dialog_info_t)data);
}


static void
free_dialog_item(Xv_object object, int key, caddr_t data)
{
#ifdef DEBUG
    fprintf(stderr, "freeing dialog item 0x%X\n", (int)data);
#endif

    my_free((dialog_item_t)data);
}


static int
make_dialog_item(int set_key, Xv_object item, unsigned int sub_item_no, int select_state)
{
  dialog_item_t dialog_item;

  dialog_item = (dialog_item_t)my_malloc(sizeof(struct dialog_item_struct));
  dialog_item->di_item         = item;
  dialog_item->di_sub_item_no  = sub_item_no;
  dialog_item->di_select_state = select_state;
  if (set_key == TRUE) {

    xv_set(item,
           XV_KEY_DATA,             DialogItemKey, (int)dialog_item,
           XV_KEY_DATA_REMOVE_PROC, DialogItemKey, free_dialog_item,
           NULL);
  }
  return (int)dialog_item;
}


static dialog_info_t
panel_item_to_dialog_info(Panel_item item)
{
  return (dialog_info_t)xv_get((Panel)xv_get(item, PANEL_PARENT_PANEL),
                               XV_KEY_DATA, DialogInfoKey);
}


/* Return the actual button pressed in the dialog.
*/
void
get_dialog_event(int dummy, int *dial_event, int *sub_widget)
{
#ifdef DEBUG
    fprintf(stderr, "get_dialog_event: event %d, sub_widget 0x%X\n",
            last_event, last_sub_widget);
#endif

    *dial_event = last_event;
    *sub_widget = last_sub_widget;
}


static void
set_size(Xv_object object, int width, int height)
{
  if (width != 0) {
    xv_set(object, XV_WIDTH, width, NULL);
  }
  if (height != 0) {
    xv_set(object, XV_HEIGHT, height, NULL);
  }
}


/* Activation for bringing a dialog to front and changing input focus.
   A mark is set to indicate that this is the active (last active) dialog.
*/
int
activate_dialog(int dialog)
{
#ifdef DEBUG
    fprintf(stderr, "activating dialog 0x%X%s\n", dialog,
            (((dialog_info_t)dialog)->di_active == TRUE) ? " (was already active)" : "" );
#endif

  if (((dialog_info_t)dialog)->di_active == FALSE) {
    xv_set(((dialog_info_t)dialog)->di_frame,
           XV_SHOW,             TRUE,
           WIN_SET_FOCUS,
           NULL);
    ((dialog_info_t)dialog)->di_active = TRUE;
  }
  return dialog;
}


int
destroy_dialog(int dialog)
{
  /* NOTE: The about dialog is considered as a dialog on the clean side, but as a
     dialog item on the C side, so we don't destroy it here. This is done automatically
     when the toplevel frame gets destroyed. */
  if (dialog != (int)about_dialog_item) {
#ifdef DEBUG
    fprintf(stderr,"Destroying dialog 0x%X: frame 0x%X\n",
            dialog, (int)(((dialog_info_t)dialog)->di_frame));
#endif
    xv_destroy_safe(((dialog_info_t)dialog)->di_frame);
  }
  return 0;
}


/* Called from dialog_window_event_proc when a focus change event occured,
   which in terms of Clean Event IO events means activation/decativation events.
   We are only interested in Nonlinear notify events, don't ask me why.
*/
static void
handle_dialog_focus_events(dialog_info_t dialog_info, XEvent *event)
{
  switch (event->type) {
  case FocusIn:
    if (((event->xfocus).detail) == NotifyNonlinear) {
      /* this dialog has been activated */
      if (dialog_info->di_active == FALSE) {
        set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_info, CLEAN_DIALOG_ACTIVATE, 0,
                         0, 0, 0, 0);
        dialog_info->di_active = TRUE;
      }
    }
    break;

  case FocusOut:
    if (((event->xfocus).detail) == NotifyNonlinear) {
      /* this dialog has been deactivated. No event generated. */
      dialog_info->di_active = FALSE;
    }
    break;
  }

#ifdef DEBUG
  fprintf(stderr, "Focus i/o event on dialog 0x%X, type %d, detail %d\n",
          (int)dialog_info, event->type, (event->xfocus).detail);
#endif
}


/* the main event dispatcher for a dialog window
*/
static Notify_value
dialog_interposer(Xv_Window window, Event *event, Notify_arg arg, Notify_event_type type)
{
  dialog_info_t dialog_info;

  dialog_info = (dialog_info_t)xv_get(window, XV_KEY_DATA, DialogInfoKey);

#ifdef DEBUG
  fprintf(stderr, "dialog 0x%X: window 0x%X, event %d, action %d, arg 0x%x, type 0x%X\n",
          (int)dialog_info, (int)window, event_id(event), event_action(event), arg, type);
#endif

  switch (event_action(event)) {
  case KBD_USE:
  case KBD_DONE:
    handle_dialog_focus_events(dialog_info, event_xevent(event));
    break;

  case ACTION_DISMISS:
    if (dialog_info->di_mode == ModalCommandDialog) {
#ifdef DEBUG
      fprintf(stderr,"dismissal of modal dialog 0x%X refused.\n", (int)dialog_info);
#endif
      return NOTIFY_DONE;
    } else {
      set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_info, CLEAN_DIALOG_CLOSED, 0,
                       0, 0, 0, 0);
#ifdef DEBUG
      fprintf(stderr,"dismissal of modeless dialog 0x%X allowed.\n", (int)dialog_info);
#endif
    }
    break;

  default:
    break;
  }
  return notify_next_event_func(window, (Notify_event)event, arg, type);
}


/* Create a command dialog. This a version of a PopupWindow, without Apply, Set... buttons.
   Width = 0 or Height = 0      means that dimension should be dynamically calculated,
                                otherwise it is fixed to the provided value.
   Mode = ModalCommandDialog    means that there will be no pushpin and that destroying the
                                dialog with the window menu should be impossible.
   Mode = ModelessCommandDialog means that the pushpin will be in and that removing the
                                pushpin or destroying the window will generate a close
                                dialog event.
*/
int
create_commanddial(CLEAN_STRING title, int width, int height, int mode)
{
  char *ctitle;
  Frame frame;
  Panel panel;
  dialog_info_t dialog_info;

  ctitle = cstring(title);

#ifdef DEBUG
  fprintf(stderr,"Creating command dialog: title=<%s>, width=%d, height=%d, mode=%d\n",
          ctitle, width, height, mode);
#endif

  if (mode == ModalCommandDialog) {
    frame = (Frame)xv_create(toplevel, FRAME, 
							NULL);
    panel = (Panel)xv_create(frame, PANEL, NULL);
  } else {
    frame = (Frame)xv_create(toplevel, FRAME_CMD,
                             FRAME_CMD_DEFAULT_PIN_STATE, FRAME_CMD_PIN_IN,
                             NULL);
    panel = (Panel)xv_get(frame, FRAME_CMD_PANEL, NULL);
  }

  xv_set(frame, FRAME_LABEL, ctitle, NULL); /* copied by XView */
  my_free(ctitle);
  set_size(frame, width, height);
  
  dialog_info = (dialog_info_t)my_malloc(sizeof(struct dialog_info_struct));
  dialog_info->di_frame        = frame;
  dialog_info->di_panel        = panel;
  dialog_info->di_apply_button = (Panel_button_item)0;
  dialog_info->di_reset_button = (Panel_button_item)0;
  dialog_info->di_active       = FALSE;
  dialog_info->di_mode         = mode;
  xv_set(frame, XV_KEY_DATA, DialogInfoKey, dialog_info, NULL);

  xv_set(panel,
         XV_KEY_DATA,             DialogInfoKey, dialog_info,
         XV_KEY_DATA_REMOVE_PROC, DialogInfoKey, free_dialog_info,
         NULL);

  /* We have to use interposition, because XView's panels eat away the KBD_* events! */
  notify_interpose_event_func(frame, dialog_interposer, NOTIFY_SAFE);
  notify_interpose_event_func(panel, dialog_interposer, NOTIFY_SAFE);

#ifdef DEBUG
  fprintf(stderr,"Command dialog 0x%X created.\n", (int)dialog_info);
#endif
  return (int)dialog_info;
}


/* We need to be able to set a default button in a command dialog.
*/
int
set_command_default(int dialog, int button)
{
#ifdef DEBUG
  fprintf(stderr, "set_command_default: dialog 0x%X, button 0x%X\n", dialog, button);
#endif

  /* NOTE: XView doesn't allow us to make a radio button of a choice item the
     default item, so we make the whole choice item the default item. */
	
  xv_set(((dialog_info_t)dialog)->di_panel,
         PANEL_DEFAULT_ITEM, ((dialog_item_t)button)->di_item,
         NULL);
  return dialog;
}


/* Create a property dialog. This popup window is provided with apply and reset buttons.
   Width = 0 or height = 0 means dimensions are dynamically calculated.
   These dialogs are always modeless and therefore have the pushpin in.
*/
int
create_propertydial(CLEAN_STRING title, int width, int height)
{
#ifdef DEBUG
  fprintf(stderr,"Creating property dialog.\n");
#endif

  return create_commanddial(title, width, height, PropertyDialog);
}


/* Callback used by dialog buttons.
*/
static void
dialog_button_pressed(Panel_button_item button, Event *event)
{
  dialog_info_t dialog_info;
  dialog_item_t dialog_item;

  dialog_info = panel_item_to_dialog_info(button);
  dialog_item = (dialog_item_t)xv_get(button, XV_KEY_DATA, DialogItemKey);

#ifdef DEBUG
  fprintf(stderr,"dialog button 0x%X in dialog 0x%X pressed\n",
          (int)dialog_item, (int)dialog_info);
#endif

  set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_info,
                   CLEAN_DIALOG_BUTTON, (int)dialog_item,
                   0, 0, 0, 0);
  activate_dialog((int)dialog_info);
}


/* Add a simple dialog button to a command (or property) dialog.
   Dimension 0 means  dynamically setting that dimension, otherwise it will be fixed.
*/
int
add_dialog_button(int dialog, int x, int y, int width, int height, CLEAN_STRING label)
{
  char *clabel;
  Panel_button_item button;
  int return_value;

  clabel = cstring(label);

  button =
    (Panel_button_item) xv_create(((dialog_info_t)dialog)->di_panel, PANEL_BUTTON,
                                  XV_X,               x,
                                  XV_Y,               y,
                                  PANEL_LABEL_STRING, clabel, /* copied by XView */
                                  PANEL_NOTIFY_PROC,  dialog_button_pressed,
                                  NULL);
  set_size(button, width, height);
  return_value = make_dialog_item(TRUE, button, 0, Able);

#ifdef DEBUG
  fprintf(stderr,
          "adding dialog button: dialog 0x%X, dim (%d,%d) (%d,%d), label <%s> => 0x%X\n",
          dialog, x, y, width, height, clabel, return_value);
#endif

  my_free(clabel);
  return return_value;
}


/* Add static text to a command or property dialog.
   Dimension 0 means  dynamically setting that dimension, otherwise it will be fixed.
*/
int
add_static_text(int dialog, int x, int y, int width, int height, CLEAN_STRING text)
{
  char *ctext;
  Panel_item static_text;
  int return_value;

  ctext = cstring(text);

  static_text =
    (Panel_item)xv_create(((dialog_info_t)dialog)->di_panel, PANEL_MESSAGE,
                          XV_X,               x,
                          XV_Y,               y,
                          PANEL_LABEL_STRING, ctext, /* copied by XView */
                          NULL);
  set_size(static_text, width, height);
  return_value = make_dialog_item(TRUE, static_text, 0, Able);

#ifdef DEBUG
  fprintf(stderr,"adding static text: dialog 0x%X, dim (%d,%d) (%d,%d), text <%s> => 0x%X\n",
          dialog, x, y, width, height, ctext, return_value);
#endif

  my_free(ctext);
  return return_value;
}


/* Set static text.
*/
int
set_static_text(int statictext, CLEAN_STRING text)
{
  char *ctext;

  ctext = cstring(text);

#ifdef DEBUG
  fprintf(stderr, "set static text of 0x%X to <%s>\n", statictext, ctext);
#endif
  
  xv_set(((dialog_item_t)statictext)->di_item, PANEL_LABEL_STRING, ctext, NULL);
  my_free(ctext);
  return statictext;
}


/* Add edit text to a command or property dialog.
   Dimension 0 means  dynamically setting that dimension, otherwise it will be fixed.
*/
int
add_edit_text(int dialog, int x, int y, int width, int height, int lines, CLEAN_STRING text)
{
  char *ctext;
  Panel_item edit_text;
  int return_value;

  ctext = cstring(text);

  edit_text = (Panel_item)xv_create(((dialog_info_t)dialog)->di_panel,
                                    (lines == 1) ? PANEL_TEXT : PANEL_MULTILINE_TEXT,
                                    XV_X,            x,
                                    XV_Y,            y,
                                    PANEL_VALUE,     ctext, /* copied by XView */
                                    PANEL_READ_ONLY, FALSE,
                                    NULL);
  if (width != 0) {
    xv_set(edit_text, PANEL_VALUE_DISPLAY_WIDTH, width, NULL);
  }
  if (height != 0) {
    xv_set(edit_text, XV_HEIGHT, height, NULL);
  }
  return_value = make_dialog_item(TRUE, edit_text, 0, Able);

#ifdef DEBUG
  fprintf(stderr,
          "adding edit text: dialog 0x%X, dim (%d,%d) (%d,%d), lines %d, text <%s> => 0x%X\n",
          dialog, x, y, width, height, lines, ctext, return_value);
#endif

  my_free(ctext);
  return return_value;
}


/* Access the text in a text edit field.
*/
CLEAN_STRING
get_edit_text(int textfield)
{
  char *text;

  text = (char *)xv_get(((dialog_item_t)textfield)->di_item, PANEL_VALUE);

#ifdef DEBUG
  fprintf(stderr,"get_edit_text from text field 0x%X = <%s>\n", textfield, text);
#endif

  return cleanstring(text);
}


/* Change the text in a text edit field.
*/
int
set_edit_text(int textfield, CLEAN_STRING text)
{
  char *ctext;

  ctext = cstring(text);

#ifdef DEBUG
  fprintf(stderr, "set edit text of text field 0x%X to <%s>\n", textfield, ctext);
#endif

  xv_set(((dialog_item_t)textfield)->di_item, PANEL_VALUE, ctext, NULL);
  my_free(ctext);
  return textfield;
}


static void
choice_button_pressed(Panel_item choice_item, int value, Event *event)
{
  choice_button_t tmp_button;
  choice_button_t choice_button;
  int choose_one;
  int new_toggle_value;
  dialog_info_t dialog_info;

  choice_button = (choice_button_t)0; /* to avoid warning about uninitialized variable */
  choose_one = ((int)xv_get(choice_item, PANEL_CHOOSE_ONE) == TRUE);
  for (tmp_button =
       ((choice_button_t)xv_get(choice_item, XV_KEY_DATA, ButtonListKey))->cb_next;
       tmp_button != (choice_button_t)0;
       tmp_button = tmp_button->cb_next) {
    new_toggle_value =
      (int)xv_get(choice_item, PANEL_TOGGLE_VALUE, tmp_button->cb_choice_number);
    if (( choose_one && (tmp_button->cb_choice_number == value)) ||
        (!choose_one && (tmp_button->cb_toggle_value  != new_toggle_value))) {
      choice_button = tmp_button;
    }
    tmp_button->cb_toggle_value = new_toggle_value;
  }

  if (choice_button == (choice_button_t)0) {
    fprintf(stderr, "LIBRARY BUG: This should not happen! (choice_button_pressed)\n");
    abort();
  }

  dialog_info = panel_item_to_dialog_info(choice_item);
  activate_dialog((int)dialog_info);
  set_global_event(CLEAN_DIALOG_DEVICE,
                   (int)dialog_info,
                   choose_one ? CLEAN_DIALOG_RADIOB : CLEAN_DIALOG_CHECKB,
                   choice_button->cb_item, 0, 0, 0, 0);

#ifdef DEBUG
  fprintf(stderr, "%s button 0x%X pressed.\n",
          choose_one ? "radio" : "check", choice_button->cb_item);
#endif
}


static void
free_choice_button_list(Xv_object object, int key, caddr_t data)
{
  choice_button_t choice_button;
  choice_button_t previous;

#ifdef DEBUG
  fprintf(stderr, "freeing choice button list 0x%X\n", (int)data);
#endif

  previous = (choice_button_t)data;
  do {
    choice_button = previous->cb_next;
    my_free(previous);
    if (choice_button != (choice_button_t)0) {
      free_dialog_item(XV_NULL, DialogItemKey, (caddr_t)(choice_button->cb_item));
      previous = choice_button;
    }
  } while (choice_button != (choice_button_t)0);
}


/* Add a choice item to a dialog that is to hold some radiobuttons or check boxes.
*/
static int
add_choice_item(int choice_mode, dialog_info_t dialog_info, int x, int y,
                int width, int height, int rows_or_columns, int number_r_c)
{
  Panel_item choice_item;
  struct choice_button_struct *empty;
  int return_value;

  choice_item = (Panel_item)0; /* to avoid warning about uninitialized variable */

  empty = (struct choice_button_struct *)my_malloc(sizeof(struct choice_button_struct));
  empty->cb_next = (struct choice_button_struct *)0;

  switch (choice_mode) {
  case DialogPopUp:
    choice_item = (Panel_item)xv_create(dialog_info->di_panel, PANEL_CHOICE_STACK, NULL);
    break;
  case RadioButtons:
    choice_item = (Panel_item)xv_create(dialog_info->di_panel, PANEL_CHOICE, NULL);
    break;
  case CheckBoxes:
    choice_item = (Panel_item)xv_create(dialog_info->di_panel, PANEL_CHECK_BOX, NULL);
    break;
  }
  if (rows_or_columns == GroupRows) {
    xv_set(choice_item,
           PANEL_LAYOUT,       PANEL_VERTICAL,
           PANEL_CHOICE_NROWS, number_r_c,
           NULL);
  } else {
    xv_set(choice_item,
           PANEL_LAYOUT,       PANEL_HORIZONTAL,
           PANEL_CHOICE_NCOLS, number_r_c,
           NULL);
  }
  xv_set(choice_item,
         XV_X,                    x,
         XV_Y,                    y,
         PANEL_NOTIFY_PROC,       choice_button_pressed,
         XV_KEY_DATA,             ChoiceNumberKey, 0,
         XV_KEY_DATA,             ButtonListKey, empty,
         XV_KEY_DATA_REMOVE_PROC, ButtonListKey, free_choice_button_list,
         NULL);
  set_size(choice_item, width, height);
  return_value = make_dialog_item(TRUE, choice_item, 0, Able);

#ifdef DEBUG
  fprintf(stderr,"adding %s 0x%X to dialog 0x%X, dim (%d,%d) (%d,%d), ",
          (choice_mode == DialogPopUp) ? "dialog popup" :
          ((choice_mode == RadioButtons) ? "radiobuttons" : "checkboxes"),
          return_value, (int)dialog_info, x, y, width, height);
  fprintf(stderr, "%d %s\n", number_r_c, (rows_or_columns == GroupRows) ? "Rows" : "Columns");
#endif

  return return_value;
}


/* Add an exclusives widget to a dialog that is to hold some radiobuttons.
*/
int
add_dialog_exclusives(int dialog, int x, int y, int width, int height,
                      int rows_or_columns, int number_r_c)
{
  return add_choice_item(RadioButtons, (dialog_info_t)dialog, x, y, width, height,
                         rows_or_columns, number_r_c);
}


/* Add a popup menu to a dialog that is to hold some radiobuttons.
   The popup consists of an abbreviated menu button (i.e. a box with an arrow, attached to
   a popup menu) and a statictext, which is used to display the current selection in this menu.
*/
int
add_dialog_popup(int dialog, int x, int y, int width, int height)
{
  return add_choice_item(DialogPopUp, (dialog_info_t)dialog, x, y, width, height,
                         GroupColumns, 1);
}



/* Add a nonexclusives widget to a dialog that is to hold some checkbox items.
*/
int
add_dialog_nonexclusives(int dialog, int x, int y, int width, int height,
                         int rows_or_columns, int number_r_c)
{
  return add_choice_item(CheckBoxes, (dialog_info_t)dialog, x, y, width, height,
                         rows_or_columns, number_r_c);
}


/* Add a radiobutton or a checkbox to a choice item.
*/
static int
add_single_choice(int exclusive, int choice_item, dialog_info_t dialog_info,
                  CLEAN_STRING title, int mark)
{
  char *ctitle;
  int number_of_choices;
  struct choice_button_struct *choice_button_list;
  struct choice_button_struct *choice_button;
  int return_value;
  Panel_item choice;

  ctitle = cstring(title);
  choice = ((dialog_item_t)choice_item)->di_item;
  number_of_choices = (int)xv_get(choice, XV_KEY_DATA, ChoiceNumberKey);
  xv_set(choice,
         PANEL_CHOICE_STRING, number_of_choices, ctitle, /* copied by XView */
         XV_KEY_DATA,         ChoiceNumberKey, number_of_choices + 1,
         NULL);
  if (mark == MarkOn) {
    if (exclusive) {
      xv_set(choice, PANEL_VALUE, number_of_choices, NULL);
    } else {
      xv_set(choice, PANEL_TOGGLE_VALUE, number_of_choices, TRUE, NULL);
    }
  }

  return_value = make_dialog_item(FALSE, choice, number_of_choices, Able);

#ifdef DEBUG
  fprintf(stderr,"adding %s %d to %sexcl. 0x%X, dialog 0x%X,",
          exclusive ? "radiobutton" : "checkbox", number_of_choices,
          exclusive ? "" : "non", (int)choice_item, (int)dialog_info);
  fprintf(stderr," title <%s>, mark %d => 0x%X\n", ctitle, mark, return_value);
#endif

  my_free(ctitle);

  choice_button_list =
    (struct choice_button_struct *)xv_get(choice, XV_KEY_DATA, ButtonListKey);
  choice_button =
    (struct choice_button_struct *)my_malloc(sizeof(struct choice_button_struct));
  choice_button->cb_item          = return_value;
  choice_button->cb_choice_number = number_of_choices;
  choice_button->cb_toggle_value  = (mark == MarkOn);
  choice_button->cb_next          = choice_button_list->cb_next;
  choice_button_list->cb_next     = choice_button;
  return return_value;
}


/* Add a dialog radio button to an exclusives widget.
   When added to a popup, a new maximum width for the popup is calculated
   and if necessary the popup label is set to the radio button's label.
*/
int
add_dialog_radiob(int exclusives, int dialog, CLEAN_STRING title, int mark)
{
  return add_single_choice(TRUE, exclusives, (dialog_info_t)dialog, title, mark);
}


/* Add a dialog button to an nonexclusives widget.
*/
int
add_dialog_checkb(int nonexclusives, int dialog, CLEAN_STRING title, int mark)
{
  return add_single_choice(FALSE, nonexclusives, (dialog_info_t)dialog, title, mark);
}


/* Get the state of a choice subitem.
*/
int
get_mark(int choice_sub_item)
{
  Panel_item exclusives;
  unsigned int sub_item_no;

  exclusives  = ((dialog_item_t)choice_sub_item)->di_item;
  sub_item_no = ((dialog_item_t)choice_sub_item)->di_sub_item_no;

  if ((int)xv_get(exclusives, PANEL_CHOOSE_ONE) == TRUE) {
#ifdef DEBUG
    fprintf(stderr,"getting mark of radio button 0x%X\n", choice_sub_item);
#endif
    return ((unsigned int)xv_get(exclusives, PANEL_VALUE) == sub_item_no) ? MarkOn : MarkOff;

  } else {
#ifdef DEBUG
    fprintf(stderr,"getting mark of checkbox 0x%X\n", choice_sub_item);
#endif
    return ((int)xv_get(exclusives, PANEL_TOGGLE_VALUE, sub_item_no) == TRUE) ?
      MarkOn : MarkOff;
  }
}


/* Press a radio widget.
*/
int
press_radio_widget(int radio, CLEAN_STRING title)
{
  choice_button_t box;
  Panel_item choice_item;
  unsigned int choice_number;

#ifdef DEBUG
  {
    char *ctitle;
    ctitle = cstring(title);
    fprintf(stderr, "press_radio_widget: radio 0x%X, title=<%s>\n", radio, ctitle);
    my_free(ctitle);
  }
#endif

  choice_item   = ((dialog_item_t)radio)->di_item;
  choice_number = ((dialog_item_t)radio)->di_sub_item_no;
  xv_set(choice_item,
         PANEL_VALUE, ((dialog_item_t)radio)->di_sub_item_no,
         NULL);

  for (box = ((choice_button_t)xv_get(choice_item, XV_KEY_DATA, ButtonListKey))->cb_next;
       box != (choice_button_t)0;
       box = box->cb_next) {
      box->cb_toggle_value = (box->cb_choice_number == choice_number);
  }

  return radio;
}


int
check_dialog_item(int check_box, int check)
{
  choice_button_t box;
  Panel_item choice_item;

#ifdef DEBUG
  fprintf(stderr, "check_dialog_item: check box 0x%X, check %d\n", check_box, check);
#endif

  choice_item = ((dialog_item_t)check_box)->di_item;
  xv_set(choice_item,
         PANEL_TOGGLE_VALUE, ((dialog_item_t)check_box)->di_sub_item_no,
                             (check == MarkOn) ? TRUE : FALSE,
         NULL);

  for (box = ((choice_button_t)xv_get(choice_item, XV_KEY_DATA, ButtonListKey))->cb_next;
       box != (choice_button_t)0;
       box = box->cb_next) {
    if (box->cb_item == check_box) {
      box->cb_toggle_value = (check == MarkOn);
    }
  }

  return check_box;
}


/* In XView, a DialogPopup is a single item with no separate exclusives item.
*/
int
get_popup_ex(int popup)
{
#ifdef DEBUG
  fprintf(stderr,"get_popup_ex from popup 0x%X\n", popup);
#endif

  return popup;
}


/* XView handles the maximum width of a DialogPopup (= abbreviated choice) itself.
*/
int
correct_popup_size(int popup)
{
#ifdef DEBUG
  fprintf(stderr,"correct_popup_size for popup 0x%X\n", popup);
#endif

  return popup;
}


static void
control_paint_proc(Panel_item control)
{
  dialog_info_t dialog_info;
  dialog_item_t dialog_item;
  int dialog_event;

  dialog_info = panel_item_to_dialog_info(control);
  dialog_item = (dialog_item_t)xv_get(control, XV_KEY_DATA, DialogItemKey);

#ifdef DEBUG
  fprintf(stderr, "Repainting control_item 0x%X in dialog 0x%X\n",
          (int)dialog_item, (int)dialog_info);
#endif

  dialog_event = (dialog_item->di_sub_item_no == ControlTypeCustom) ? CLEAN_DIALOG_REDRAW :
                                                                      CLEAN_DIALOG_IREDRAW;
  set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_info, dialog_event, (int)dialog_item,
                   0, 0, 0, 0);
}


static Panel_item active_control_item;


static void
control_begin_preview(Panel_item control, Event *event)
{
  static ClickCount click_count = NoClick;
  static Time time_of_last_click;
  static int last_click_x, last_click_y;
  dialog_info_t dialog_info;
  dialog_item_t dialog_item;
  WindowData *wdata;
  int the_event;
  XButtonEvent xevent;
  int x, y;
  Time time;
  int mouse_event;

#ifdef DEBUG
  fprintf(stderr,"control_begin_preview: item 0x%X\n", (int)control);
#endif

  mouse_event = BUTTONDOWN; /* to avoid warning about uninitialized variable */
  active_control_item = control;
  dialog_info = panel_item_to_dialog_info(control);
  dialog_item = (dialog_item_t)xv_get(control, XV_KEY_DATA, DialogItemKey);

  wdata = (WindowData *)xv_get(control, XV_KEY_DATA, UserDataKey);
  the_event = (dialog_item->di_sub_item_no == ControlTypeCustom) ? CLEAN_DIALOG_MOUSE :
                                                                   CLEAN_DIALOG_IMOUSE;
  xevent = event_xevent(event)->xbutton;
  time = xevent.time;
  my_local_mouse_x = x = xevent.x;
  my_local_mouse_y = y = xevent.y;

  switch (click_count) {
  case NoClick:
    mouse_event  = BUTTONDOWN;
    last_click_x = x;
    last_click_y = y;
    click_count  = OneClick;
    break;

  case OneClick:
    if ((time - time_of_last_click <= multi_click_time) &&
        (abs(x - last_click_x) <= double_down_distance) &&
        (abs(y - last_click_y) <= double_down_distance)) {
      mouse_event = DOUBLECLICK;
      click_count = TwoClicks;
    } else {
      mouse_event  = BUTTONDOWN;
      last_click_x = x;
      last_click_y = y;
      click_count  = OneClick;
    }
      break;

  case TwoClicks:
    if ((time - time_of_last_click <= multi_click_time) &&
        (abs(x - last_click_x) <= double_down_distance) &&
        (abs(y - last_click_y) <= double_down_distance)) {
      mouse_event = TRIPLECLICK;
      click_count = NoClick;
    } else {
      mouse_event  = BUTTONDOWN;
      last_click_x = x;
      last_click_y = y;
      click_count  = OneClick;
    }
  }
  time_of_last_click = time;
  my_last_window = (Xv_Window)control;
  set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_info, the_event, (int)dialog_item,
                   mouse_event, x + (wdata->x0), y + (wdata->y0), xevent.state);
  button_down = ButtonStillDownDialog;
  activate_dialog((int)dialog_info);
}


static void
control_update_preview(Panel_item control, Event *event)
{
  dialog_info_t dialog_info;
  dialog_item_t dialog_item;
  WindowData *wdata;
  int the_event;
  XMotionEvent xevent;

#ifdef DEBUG
  fprintf(stderr,"control_update_preview: item 0x%X\n", (int)control);
#endif

  if (control == active_control_item) {
    dialog_info = panel_item_to_dialog_info(control);
    dialog_item = (dialog_item_t)xv_get(control, XV_KEY_DATA, DialogItemKey);

    wdata = (WindowData *)xv_get(control, XV_KEY_DATA, UserDataKey);
    the_event = (dialog_item->di_sub_item_no == ControlTypeCustom) ? CLEAN_DIALOG_MOUSE :
                                                                     CLEAN_DIALOG_IMOUSE;
    my_last_window = (Xv_Window)control;
    xevent = event_xevent(event)->xmotion;
    my_local_mouse_x = xevent.x;
    my_local_mouse_y = xevent.y;
    set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_info, the_event, (int)dialog_item,
                     BUTTONSTILLDOWN, xevent.x + (wdata->x0), xevent.y + (wdata->y0),
                     xevent.state);
  }
}


static void
control_accept_preview(Panel_item control, Event *event)
{
  dialog_info_t dialog_info;
  dialog_item_t dialog_item;
  WindowData *wdata;
  int the_event;

#ifdef DEBUG
  fprintf(stderr,"control_accept_preview: item 0x%X\n", (int)control);
#endif

  if (control == active_control_item) {
    dialog_info = panel_item_to_dialog_info(control);
    dialog_item = (dialog_item_t)xv_get(control, XV_KEY_DATA, DialogItemKey);

    wdata = (WindowData *)xv_get(control, XV_KEY_DATA, UserDataKey);
    the_event = (dialog_item->di_sub_item_no == ControlTypeCustom) ? CLEAN_DIALOG_MOUSE :
                                                                     CLEAN_DIALOG_IMOUSE;
    set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_info, the_event, (int)dialog_item,
                     BUTTONUP,
                     (event_xevent(event)->xbutton).x + (wdata->x0),
                     (event_xevent(event)->xbutton).y + (wdata->y0),
                     (event_xevent(event)->xbutton).state);
  }
  button_down = ButtonUp;
  active_control_item = (Panel_item)0;
}


static void
control_cancel_preview(Panel_item control, Event *event)
{
#ifdef DEBUG
  fprintf(stderr,"control_cancel_preview: item 0x%X\n", (int)control);
#endif
  control_accept_preview(control, event);
}


static Panel_ops control_ops = {
    panel_default_handle_event,   /* handle_event() */
    control_begin_preview,        /* begin_preview() */
    control_update_preview,       /* update_preview() */
    control_cancel_preview,       /* cancel_preview() */
    control_accept_preview,       /* accept_preview() */
    NULL,                         /* accept_menu() */
    NULL,                         /* accept_key() */
    panel_default_clear_item,     /* clear() */
    control_paint_proc,           /* paint() */
    NULL,                         /* resize() */
    NULL,                         /* remove() */
    NULL,                         /* restore() */
    NULL,                         /* layout() */
    NULL,                         /* accept_kbd_focus() */
    NULL,                         /* yield_kbd_focus() */
    NULL                          /* extension: reserved for future use */
};




/* Add a control to the dialog.
   This is an item with an application specified look and feel.
*/
int
add_dialog_control(int dialog, int x, int y, int width, int height, int x0, int y0,
                   int control_type)
{
  Panel panel;
  Panel_item dummy;
  Rect rect;
  WindowData *wdata;
  int return_value;
  XRectangle clipping_rectangles[1];

  panel = ((dialog_info_t)dialog)->di_panel;

  dummy = (Panel_item)xv_create(panel, PANEL_MESSAGE,
                                PANEL_LABEL_STRING, "",
                                NULL);

  rect_construct(&rect, x, y, width, height);

  wdata = (WindowData *)my_malloc(sizeof(WindowData));
  wdata->frame       = (Frame)xv_get(panel, XV_OWNER);
  wdata->canvas      = (Canvas)0;
  wdata->hscrollbar  = (Scrollbar)0;
  wdata->vscrollbar  = (Scrollbar)0;
  wdata->picture     = ((Panel_paint_window *)xv_get(panel, PANEL_FIRST_PAINT_WINDOW))->pw;
  wdata->height      = height;
  wdata->width       = width;
  wdata->both_pixels = 0;
  wdata->x0          = -x;
  wdata->y0          = -y;
  wdata->window_gc   = make_new_gc();
  wdata->curx        = x;
  wdata->cury        = y;
  wdata->pen         = 0;
  wdata->active      = False;

  set_default_font(wdata);

  clipping_rectangles[0].x      = 0;
  clipping_rectangles[0].y      = 0;
  clipping_rectangles[0].width  = width;
  clipping_rectangles[0].height = height;
  XSetClipRectangles(display, wdata->window_gc, x, y, clipping_rectangles, 1, YXBanded);

#if 0
  /* The background of the control should be the same as the one of the panel. */
  /* Does not work for now, because dialogDevice.icl sets it to white again... */
  XSetBackground(display, wdata->window_gc,
                 (unsigned long)xv_get((Cms)xv_get(panel, WIN_CMS), CMS_BACKGROUND_PIXEL));
#endif

  xv_set(dummy,
         PANEL_ITEM_LABEL_RECT, &rect,  /* We have to set BOTH rectangles AFTER creation!! */
         PANEL_ITEM_RECT,       &rect,
         PANEL_OPS_VECTOR,      &control_ops,
         XV_KEY_DATA,           UserDataKey, wdata,
         XV_KEY_DATA,           ControlActiveKey, FALSE,
         NULL);

  /* Note: We abuse di_sub_item_no for the type of control... */
  return_value = make_dialog_item(TRUE, dummy, control_type, Able);

#ifdef DEBUG
  fprintf(stderr,"add_dialog_control: dialog 0x%X, dim (%d,%d) (%d,%d), ",
          dialog, x, y, width, height);
  fprintf(stderr,"x0=%d, y0=%d, control_type=%d => 0x%X\n",
          x0, y0, control_type, return_value);
#endif

  return return_value;
}


int
dialog_item_to_object(int item)
{
#ifdef DEBUG
  fprintf(stderr, "dialog_item_to_object 0x%X => 0x%X\n",
          item, (int)(((dialog_item_t)item)->di_item));
#endif
  return (int)(((dialog_item_t)item)->di_item);
}

void center_frame (Frame frame)
{
	int width,height;

	width=(int)xv_get (frame,XV_WIDTH);
	height=(int)xv_get (frame,XV_HEIGHT);

	xv_set (frame,	XV_X,(WidthOfScreen (screen)-width) >> 1,
					XV_Y,(HeightOfScreen (screen)-height) >> 1,NULL);
}

/* Popup a modal dialog.
*/
int
popup_modaldialog(int dialog)
{
#ifdef DEBUG
    fprintf(stderr, "popup_modaldialog 0x%X\n", dialog);
#endif

  window_fit(((dialog_info_t)dialog)->di_panel);
  window_fit(((dialog_info_t)dialog)->di_frame);

	center_frame (((dialog_info_t)dialog)->di_frame);
  
  xv_set(((dialog_info_t)dialog)->di_frame, XV_SHOW, TRUE, NULL);
  return dialog;
}


static void
apply_button_pressed(Panel_button_item button, Event *event)
{
  dialog_info_t property_dialog;

  property_dialog = panel_item_to_dialog_info(button);

#ifdef DEBUG
  fprintf(stderr,"Apply button pressed in dialog 0x%X.\n", (int)property_dialog);
#endif

  set_global_event(CLEAN_DIALOG_DEVICE, (int)property_dialog, CLEAN_DIALOG_APPLY, 0,
                   0, 0, 0, 0);
  activate_dialog((int)property_dialog);
}


static void
reset_button_pressed(Panel_button_item button, Event *event)
{
  dialog_info_t property_dialog;

  property_dialog = panel_item_to_dialog_info(button);

#ifdef DEBUG
  fprintf(stderr,"Reset button pressed in dialog 0x%X.\n", (int)property_dialog);
#endif

  set_global_event(CLEAN_DIALOG_DEVICE, (int)property_dialog, CLEAN_DIALOG_RESET, 0,
                   0, 0, 0, 0);
  activate_dialog((int)property_dialog);
}


/* Popup a modeless dialog.
*/
int
popup_modelessdialog(int dialog)
{
  dialog_info_t dialog_info;

#ifdef DEBUG
  fprintf(stderr, "popup_modelessdialog 0x%X\n", dialog);
#endif

  dialog_info = (dialog_info_t)dialog;

  if ((dialog_info->di_mode == PropertyDialog) &&
      (dialog_info->di_apply_button == (Panel_button_item)0)) {
#ifdef DEBUG
    fprintf(stderr, "Adding apply and reset buttons.\n");
#endif
    xv_set(dialog_info->di_panel, PANEL_LAYOUT, PANEL_VERTICAL, NULL);
    dialog_info->di_apply_button =
      (Panel_button_item)xv_create(dialog_info->di_panel, PANEL_BUTTON,
                                   PANEL_LABEL_STRING, "Apply",
                                   PANEL_NOTIFY_PROC,  apply_button_pressed,
                                   NULL);
    xv_set(dialog_info->di_panel, PANEL_LAYOUT, PANEL_HORIZONTAL, NULL);
    dialog_info->di_reset_button =
      (Panel_button_item)xv_create(dialog_info->di_panel, PANEL_BUTTON,
                                   PANEL_LABEL_STRING, "Reset",
                                   PANEL_NOTIFY_PROC,  reset_button_pressed,
                                   NULL);
  }
  window_fit(dialog_info->di_panel);
  window_fit(dialog_info->di_frame);

	center_frame (dialog_info->di_frame);

  xv_set(dialog_info->di_frame, XV_SHOW, TRUE, NULL);
  return dialog;
}


/* Popping down a dialog.
*/
int
popdown_dialog(int dialog)
{
#ifdef DEBUG
  fprintf(stderr, "popdown_dialog 0x%X\n", dialog);
#endif

  xv_set(((dialog_info_t)dialog)->di_frame, XV_SHOW, FALSE, NULL);
  return dialog;
}


/* Retrieving the current rect of a dialog item
*/
void
get_current_rect(int dialog_item, int *x, int *y, int *w, int *h)
{
  Rect *rect;
  Panel_item item;

  item = ((dialog_item_t)dialog_item)->di_item;
  rect  = (Rect *)xv_get(item, XV_RECT);
  if (((Xv_pkg *)xv_get(item, XV_TYPE) == PANEL_CHOICE) &&
      ((Panel_setting)xv_get(item, PANEL_DISPLAY_LEVEL) == PANEL_CURRENT)) {
#ifdef DEBUG
  fprintf(stderr, "Using abbreviated choice height hack 1...\n");
#endif
    *h = rect->r_height - 10;
  } else {
    *h = rect->r_height;
  }
  *x    = rect->r_left;
  *y    = rect->r_top;
  *w    = rect->r_width;

#ifdef DEBUG
  fprintf(stderr, "getting current rectangle of dialog item 0x%X: (%d,%d) (%d,%d)\n",
          dialog_item, *x, *y, *w, *h);
#endif
}


/* Set new position and dimensions of a dialog item.
*/
int
repos_widget(int dialog_item, int x, int y, int width, int height)
{
  Panel_item item;
  WindowData *wdata;

  item = ((dialog_item_t)dialog_item)->di_item;
  if (((Xv_pkg *)xv_get(item, XV_TYPE) == PANEL_CHOICE) &&
      ((Panel_setting)xv_get(item, PANEL_DISPLAY_LEVEL) == PANEL_CURRENT)) {
#ifdef DEBUG
  fprintf(stderr, "Using abbreviated choice height hack 2...\n");
#endif
    y -= 5;
  }

#ifdef DEBUG
  fprintf(stderr,"reposition dialog item 0x%X to (%d,%d) (%d,%d)\n",
          dialog_item, x, y, width, height);
#endif

  /* NOTE: Setting XV_RECT does NOT work. Why??? But the way we do it, it's O.K. */
  xv_set(item,
         XV_X,      x,
         XV_Y,      y,
         XV_WIDTH,  width,
         XV_HEIGHT, height,
         NULL);

  /* If this is a control, we have to adjust some more values... */
  wdata = (WindowData *)xv_get(item, XV_KEY_DATA, UserDataKey);
  if (wdata != (WindowData *)0) {
    wdata->height = height;
    wdata->width  = width;
    wdata->x0     = -x;
    wdata->y0     = -y;
    wdata->curx   = x;
    wdata->cury   = y;
    XSetClipOrigin(display, wdata->window_gc, x, y);
  }

  return dialog_item;
}


/* Get the width of the father of a dialog item.
*/
int
get_father_width(int dialog_item)
{
  int width;
  Xv_object father;

  father = (Xv_object)xv_get(((dialog_item_t)dialog_item)->di_item, XV_OWNER);
  window_fit(father);
  width = (int)xv_get(father, XV_WIDTH);

#ifdef DEBUG
  fprintf(stderr,"get_father_width: dialog item 0x%X, father 0x%X, width %d\n",
          dialog_item, (int)father, width);
#endif

  return width;
}


/* Adjust dialog size according to the supplied margins
*/
int
set_dialog_margins(int dialog, int marginx, int marginy)
{
#ifdef DEBUG
  fprintf(stderr,"setting margins of dialog 0x%X to (%d,%d)\n", dialog, marginx, marginy);
#endif

  /* NOT YET */
  return dialog;
}


/* Get Horizontal conversion of mm to pixels.
*/
int
mm_to_pixel_hor(double mm)
{
  return (int)(((double)HeightOfScreen(screen) * mm) / ((double)HeightMMOfScreen(screen))
               + 0.5);
}


/* Get Vertical conversion of mm to pixels.
*/
int
mm_to_pixel_ver(double mm)
{
  return (int)(((double)WidthOfScreen(screen) * mm) / ((double)WidthMMOfScreen(screen))
               + 0.5);
}


/* Enabling and disabling dialog items.
*/
int
enable_dialog_item(int panel_item)
{
#ifdef DEBUG
  fprintf(stderr, "enabling dialog item 0x%X\n", panel_item);
#endif

  return panel_item;
}


int
disable_dialog_item(int panel_item)
{
#ifdef DEBUG
  fprintf(stderr, "disabling dialog item 0x%X\n", panel_item);
#endif

  return panel_item;
}


/* This function handles repainting of the about dialog canvas. For every sequence of
   exposures this function is called only once. After this, the subsequent
   exposures are collected with get_expose_area() (cf. cwindow.c).
*/
static void
about_repaint_proc(Canvas canvas, Xv_Window paint_window, Display *dpy,
                   Window xwin, Xv_xrectlist *area)
{
  dialog_item_t dialog_item;

  dialog_item = (dialog_item_t)xv_get(paint_window, XV_KEY_DATA, DialogItemKey);
  set_global_event(CLEAN_DIALOG_DEVICE, (int)dialog_item, CLEAN_ABOUT_REDRAW, 0,
                   0, 0, 0, 0);

#ifdef DEBUG
  fprintf(stderr,"Repainting about dialog 0x%X: canvas 0x%X, paint window 0x%X, %d rects\n",
          (int)dialog_item, (int)canvas, (int)paint_window, area->count);
#endif
}


static void
about_help_button_pressed(Panel_button_item button, Event *event)
{
#ifdef DEBUG
  fprintf(stderr, "About help button pressed.\n");
#endif
  set_global_event(CLEAN_DIALOG_DEVICE, (int)about_dialog_item,
                   CLEAN_ABOUT_HELP, (int)button,
                   0, 0, 0, 0);
}


/* We can install an about dialog/window on the toplevel widget,
   below the menu bar (if there is one).
*/
int
create_about_dialog(int x0, int y0, int x1, int y1, int help, CLEAN_STRING help_title)
{
  char *htitle;
  Canvas canvas;
  Xv_Window paint_window;
  WindowData *wdata;
  int both_pixels;
  int width, height;
  Panel help_panel;

  width  = x1 - x0;
  height = y1 - y0;

  htitle = cstring(help_title);
#ifdef DEBUG
  fprintf(stderr, "create_about_dialog: (%d,%d) (%d,%d), help %d, help_title=<%s>\n",
          x0, y0, x1, y1, help, htitle);
#endif

  /* Sven: The following is only correct for standard sizes... */
  both_pixels = 2;

	if (width==0 || height==0){
		canvas = NULL;
	} else {
		canvas = (Canvas)xv_create(toplevel, CANVAS,
                             CANVAS_AUTO_SHRINK,     FALSE,
                             CANVAS_AUTO_EXPAND,     FALSE,
                             CANVAS_WIDTH,           width,
                             CANVAS_HEIGHT,          height,
                             XV_WIDTH,               width  + both_pixels,
                             XV_HEIGHT,              height + both_pixels,
                             CANVAS_X_PAINT_WINDOW,  TRUE,
                             WIN_COLLAPSE_EXPOSURES, TRUE,
                             CANVAS_REPAINT_PROC,    about_repaint_proc,
                             NULL);
	}
  xv_set(toplevel, XV_KEY_DATA, ToplevelAboutCanvasKey, canvas, NULL);
	
  if (help == 1) {
  	if (canvas!=NULL)
		help_panel = (Panel)xv_create(toplevel, PANEL,
                                  XV_X,      0,
                                  WIN_BELOW, canvas,
                                  NULL);
    else
		help_panel = (Panel)xv_create(toplevel, PANEL,
                                  XV_X,      0,
								  XV_Y, 36,
                                  NULL);
	
	xv_create(help_panel, PANEL_BUTTON,
              PANEL_LABEL_STRING, htitle, /* copied by XView */
              PANEL_NOTIFY_PROC,  about_help_button_pressed,
              NULL);
    xv_set(toplevel, XV_KEY_DATA, ToplevelHelpPanelKey, help_panel, NULL);
#ifdef DEBUG
    fprintf(stderr, "Help button created\n");
#endif
  } else {
    xv_set(toplevel, XV_KEY_DATA, ToplevelHelpPanelKey, (Panel)0, NULL);
  }

#ifdef DEBUG
  fprintf(stderr, "Canvas 0x%X created\n", (int)canvas);
#endif

	if (canvas!=NULL)
		paint_window = (Xv_Window)xv_get(canvas, CANVAS_NTH_PAINT_WINDOW, 0);
	else
		paint_window=NULL;

  /* set the correct minimum and maximum sizes
     (6 and 7 are additional borderwidths) and windowdata     */
  wdata = (WindowData *)my_malloc(sizeof(WindowData));
  wdata->frame       = toplevel;
  wdata->canvas      = canvas;
  wdata->hscrollbar  = (Scrollbar)0;
  wdata->vscrollbar  = (Scrollbar)0;
  wdata->picture     = paint_window;
  wdata->height      = height;
  wdata->width       = width;
  wdata->both_pixels = both_pixels;
  wdata->x0          = x0;
  wdata->y0          = y0;
  wdata->window_gc   = make_new_gc();
  wdata->curx        = x0;
  wdata->cury        = y0;
  wdata->pen         = 0;
  wdata->active      = True;

  set_default_font(wdata);

	xv_set (toplevel,      XV_KEY_DATA, UserDataKey, wdata, NULL);
	if (canvas!=NULL){
		xv_set(canvas,        XV_KEY_DATA, UserDataKey, wdata, NULL);
		if (paint_window!=NULL)
			xv_set(paint_window,  XV_KEY_DATA, UserDataKey, wdata, NULL);
	}

	my_free(htitle);

	if (paint_window!=NULL)
		about_dialog_item = make_dialog_item(TRUE, paint_window, 0, Able);
	else
		about_dialog_item=NULL;

#ifdef DEBUG
  fprintf(stderr, "About dialog 0x%X created\n", (int)about_dialog_item);
#endif

  return (int)about_dialog_item;
}

/* NOTICES */

/* This is a real hack: XView reuses old notice buttons, so we must create them all
   with one call to xv_create or xv_set. The following variables help with this.
*/

#define MAX_NOTICE_BUTTONS 6

struct my_notice_button_struct {
  char *label;
  int id;
};

static struct my_notice_button_struct notice_button[MAX_NOTICE_BUTTONS];
static int no_of_notice_buttons;


/* Create a notice with a couple of lines of text. Buttons will have
   to be added to the notice's control area.
*/
int
create_notice(CLEAN_STRING text)
{
  Xv_Notice notice;
  char *s;
  int i;

  s = cstring(text);

#ifdef DEBUG
  fprintf(stderr, "creating notice with text <%s>\n", s);
#endif

  notice = (Xv_Notice)xv_create(toplevel, NOTICE,
                                NOTICE_MESSAGE_STRING, s,  /* s is copied by notice package */
                                NULL);
  my_free(s);

  no_of_notice_buttons = 0;
  for (i = 0;  i < MAX_NOTICE_BUTTONS;  i++) {
    notice_button[i].label = (char *)0;
  }

#ifdef DEBUG
  fprintf(stderr, "notice 0x%X created\n", (int)notice);
#endif

  return notice;
}


/* Add a button to a notice widget, The first button added will be the default button.
*/
int
add_n_button(int notice, CLEAN_STRING label, int id)
{
  char *s;

  if (no_of_notice_buttons == MAX_NOTICE_BUTTONS) {
    fprintf(stderr, "Too many notice buttons (maximum is %d)\n", MAX_NOTICE_BUTTONS);
    abort();
  }

  s = cstring(label);
#ifdef DEBUG
  fprintf(stderr, "adding notice button <%s> with id %d to notice %d\n", s, id, notice);
#endif
  notice_button[no_of_notice_buttons].label = s;
  notice_button[no_of_notice_buttons].id    = id;
  no_of_notice_buttons++;

  return notice;
}


/* Take care of handling the notice and return the button id to Clean.
*/
int
handle_notice(int notice)
{
  int notice_status, i;

#ifdef DEBUG
  fprintf(stderr, "handle_notice %d\n", notice);
#endif

  /* Here comes another hack... (I LIKE Xview!!!!): Create all buttons at once */
  switch (no_of_notice_buttons) {
  case 0:
    break;

  case 1:
    xv_set((Xv_Notice)notice,
           NOTICE_BUTTON, notice_button[0].label, notice_button[0].id,
           NULL);
    break;

  case 2:
    xv_set((Xv_Notice)notice,
           NOTICE_BUTTON, notice_button[0].label, notice_button[0].id,
           NOTICE_BUTTON, notice_button[1].label, notice_button[1].id,
           NULL);
    break;

  case 3:
    xv_set((Xv_Notice)notice,
           NOTICE_BUTTON, notice_button[0].label, notice_button[0].id,
           NOTICE_BUTTON, notice_button[1].label, notice_button[1].id,
           NOTICE_BUTTON, notice_button[2].label, notice_button[2].id,
           NULL);
    break;

  case 4:
    xv_set((Xv_Notice)notice,
           NOTICE_BUTTON, notice_button[0].label, notice_button[0].id,
           NOTICE_BUTTON, notice_button[1].label, notice_button[1].id,
           NOTICE_BUTTON, notice_button[2].label, notice_button[2].id,
           NOTICE_BUTTON, notice_button[3].label, notice_button[3].id,
           NULL);
    break;

  case 5:
    xv_set((Xv_Notice)notice,
           NOTICE_BUTTON, notice_button[0].label, notice_button[0].id,
           NOTICE_BUTTON, notice_button[1].label, notice_button[1].id,
           NOTICE_BUTTON, notice_button[2].label, notice_button[2].id,
           NOTICE_BUTTON, notice_button[3].label, notice_button[3].id,
           NOTICE_BUTTON, notice_button[4].label, notice_button[4].id,
           NULL);
    break;

  case 6:
    xv_set((Xv_Notice)notice,
           NOTICE_BUTTON, notice_button[0].label, notice_button[0].id,
           NOTICE_BUTTON, notice_button[1].label, notice_button[1].id,
           NOTICE_BUTTON, notice_button[2].label, notice_button[2].id,
           NOTICE_BUTTON, notice_button[3].label, notice_button[3].id,
           NOTICE_BUTTON, notice_button[4].label, notice_button[4].id,
           NOTICE_BUTTON, notice_button[4].label, notice_button[5].id,
           NULL);
    break;

  default:
    fprintf(stderr, "This should not happen... (handle_notice)\n");
    abort();
    break;
  }

  for (i = 0;  i < MAX_NOTICE_BUTTONS;  i++) {
    if (notice_button[i].label != (char *)0) {
      my_free(notice_button[i].label);
    }
  }

  xv_set((Xv_Notice)notice,
         NOTICE_STATUS,      &notice_status,
         NOTICE_LOCK_SCREEN, TRUE,
         XV_SHOW,            TRUE,
         NULL);

  xv_destroy((Xv_Notice)notice);

#ifdef DEBUG
  fprintf(stderr, "handle_notice returns button id %d\n", notice_status);
#endif

  return notice_status;
}


/* Beep.
*/
int
beep(int dummy)
{
  XBell(display, 0);
  XFlush(display);
  return dummy;
}
