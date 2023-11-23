/*
   This module implements support functions for creating and handling
   Open Look Notice, Property and (Modal and Modeless) Command
   dialogs. Furthermore a rudimentairy about dialog is implemented 
   as a simple dialog in the applications root window.

   The interfacing functions for Clean for this module can be found
   in xdialog.fcl. These functions are used in the Clean modules
   dialogDevice and deltaDialog.

   1992: Leon Pillich
*/

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>

#include <Xol/OpenLook.h>
#include <Xol/Notice.h>
#include <Xol/PopupWindo.h>
#include <Xol/ControlAre.h>
#include <Xol/BulletinBo.h>
#include <Xol/StaticText.h>
#include <Xol/OblongButt.h>
#include <Xol/TextField.h>
#include <Xol/TextEdit.h>
#include <Xol/Exclusives.h>
#include <Xol/MenuButton.h>
#include <Xol/Nonexclusi.h>
#include <Xol/RectButton.h>
#include <Xol/CheckBox.h>
#include <Xol/Caption.h>
#include <Xol/AbbrevMenu.h>
#include <Xol/Stub.h>

#include "clean_devices.h"
#include "windowdata.h"

#include <stdio.h>
#include <string.h>
#include <math.h>

#define ModalCommandDialog 	0
#define ModelessCommandDialog	1

#define GroupRows		0
#define GroupColumns		1

#define MarkOn			0
#define MarkOff			1

#define ControlTypeCustom	0
#define ControlTypeIcon		1


extern CLEAN_STRING result_clean_string;
extern char *cstring(CLEAN_STRING s);
extern GC make_new_gc(void);

/* the global device to be passed to Clean */
extern CLEAN_DEVICE global_device;
extern Widget global_widget;

/* The base widget */
extern Widget toplevel;
extern Widget base;
extern Display *display;

/* DialogData -> the bulletin board widget contained in the dialog and
   a boolean saying wether the dialog is active or not.
*/
typedef struct dialog_data
{ Boolean active;
  Widget bbord;
} DialogData;


/* The internal focus change event handler. Switches the active flag
   of a dialog's DialogData.
*/
void handle_dialog_focus_events(Widget w,Widget dialog,
                                          XEvent *event,int *done);


/* The selected dialog button and dialog event to pass to Clean.
*/
Widget my_dialog_button;
int my_dialog_event;


/* The mouse event globals from cwindow.c.
*/
extern int my_local_mouse_x;
extern int my_local_mouse_y;
extern int my_mouse_x;
extern int my_mouse_y;
extern int my_mouse_event;
extern CleanModifiers my_state;
extern ButtonDownState button_down;
extern Widget my_last_window;
void calc_keystate(unsigned int,CleanModifiers *);

/* information needed for multiclicks */
extern Time time_of_last_click;
extern int last_click_x, last_click_y;
extern ClickCount click_count;
extern Time multi_click_time;

/* RWS */
int
popdown_dialog (int dialog)
{
	return (popdown (dialog));
}

int dialog_item_to_object (int item)
{
	return (item);
}

int destroy_dialog (int dialog)
{
	return (destroy_widget (dialog));
}

/* */

/* Deallocating arbitrary widget data.
*/
void DestroyWidgetInfoCB(Widget w,XtPointer to_be_deallocated, XtPointer call);

/* Activation for bringing a dialog to front and changing input focus.
   A DialogData field is set to indicate that this is the active (last active)
   dialog.
*/
Widget activate_dialog(Widget dialog)
{ DialogData *ddata;

  XtVaGetValues(dialog,XtNuserData,&ddata,NULL);

  if(!(ddata->active))
  { while(!OlCanAcceptFocus(dialog,CurrentTime));
    XRaiseWindow(display, XtWindow(dialog));
    OlCallAcceptFocus(dialog,CurrentTime);
    ddata->active=True;
  };
  
  return dialog;
}


/* Callback used by dialog buttons.
*/
void DialogButtonCB(Widget w, Widget dialog, XtPointer call_data)
{ global_device=CLEAN_DIALOG_DEVICE;
  global_widget=dialog;

  my_dialog_event =CLEAN_DIALOG_BUTTON;
  my_dialog_button=w;

  activate_dialog(dialog);
}


/* Callback called whenever the user tries to close the dialog by
   destroying it. We don't allow this.
*/
void CloseDialogCB(Widget w,XtPointer mode,
                   OlWMProtocolVerify *callData)
{ 
  if((callData->msgtype)==OL_WM_DELETE_WINDOW)
  { switch((int)mode)
    { case ModalCommandDialog: 
        #ifdef DEBUG
           fprintf(stderr,"Destroy dialog refused.\n");
        #endif
        break;
      case ModelessCommandDialog:
        global_device = CLEAN_DIALOG_DEVICE;
        global_widget = w;
        my_dialog_event = CLEAN_DIALOG_CLOSED;
        #ifdef DEBUG
           fprintf(stderr, "Dialog closed: %d.\n",w);
        #endif
        break;
     };
  };
}


/* Callback called whenever the user tries to close the dialog by
   removing the pushpin. This is not immediately allowed but has
   to be done explicitly by the application. This is only for
   modeless windows.
*/
void PopDownCB(Widget w, XtPointer client_data, Boolean *popdown_allowed)
{ *popdown_allowed = TRUE;
}


/* Before destroying a command dialog, some memory has to be
   deallocated.
*/
void DestroyCommandDialogCB(Widget dialog, DialogData *ddata, XtPointer cdata)
{ char *t;

  XtVaGetValues(dialog, XtNtitle, &t, NULL);
  XtFree(t);
  XtFree((XtPointer)ddata);
}
  

/* Create a command dialog. This a version of a PopupWindow, without
   Apply, Set... buttons.
   Width=0 or Height=0 => That dimension should be dynamically calculated,
   otherwise it is fixed to the provided value.
   Mode=ModalCommandDialog means that there will be no pushpin and
   that destroying the dialog with the window menu should be impossible.
   Mode=ModelessCommandDialog means that the pushpin will be in and that
   removing the pushpin or destroying the window will generate a close
   dialog event.
*/
Widget create_commanddial(CLEAN_STRING title, int width, int height, int mode)
{ Widget command;
  Widget bord;
  Widget control;
  Arg args[10];
  char *dtitle;
  DialogData *ddata;
  int n=0;

#ifdef DEBUG
  fprintf(stderr,"Command dialog: width=%d,height=%d\n",width,height);
#endif

  dtitle=cstring(title);
  XtSetArg(args[n], XtNtitle, dtitle);n++;
  XtSetArg(args[n], XtNwmProtocolInterested, OL_WM_DELETE_WINDOW);n++;
  if(mode==ModelessCommandDialog)
  { XtSetArg(args[n], XtNpushpin, OL_IN);n++;
  }
  else
  { XtSetArg(args[n], XtNpushpin, OL_NONE);n++;
  };
  command=XtCreatePopupShell(dtitle, popupWindowShellWidgetClass,
                             toplevel, args, n);
  OlAddCallback(command, XtNwmProtocol,
                (XtCallbackProc)CloseDialogCB, (XtPointer)mode);
  OlAddCallback(command, XtNverify, (XtCallbackProc)PopDownCB, NULL);

  XtVaGetValues(command, XtNupperControlArea, &control, NULL);
  XtVaSetValues(control, XtNsameSize, OL_NONE, NULL); 

  n=0;
  if(width!=0)
  { XtSetArg(args[n], XtNwidth, (Dimension)width);n++; 
    XtSetArg(args[n], XtNmaxWidth, (Dimension)width);n++;
    XtSetArg(args[n], XtNminWidth, (Dimension)width);n++;
    XtSetArg(args[n], XtNheight, (Dimension)height);n++;
    XtSetArg(args[n], XtNmaxHeight, (Dimension)height);n++;
    XtSetArg(args[n], XtNminHeight, (Dimension)height);n++;
    XtSetArg(args[n], XtNlayout, OL_IGNORE);n++;
  }
  else
  { XtSetArg(args[n], XtNlayout, OL_MINIMIZE);n++;
  };
  bord=XtCreateManagedWidget("bb",bulletinBoardWidgetClass,control,args,n);
  XtVaSetValues(bord, XtNuserData, command, NULL);

  ddata=(DialogData *)XtMalloc(sizeof(DialogData));
  ddata->active=False;
  ddata->bbord =bord;
  XtVaSetValues(command, XtNuserData, ddata, NULL);
  XtAddEventHandler(command, FocusChangeMask, False,
                    (XtEventHandler)handle_dialog_focus_events, command);
  XtAddCallback(command, XtNdestroyCallback,
                (XtCallbackProc)DestroyCommandDialogCB, ddata);

#ifdef DEBUG
  fprintf(stderr, "Command dialog created:%d %d\n",command,bord);
#endif

  return command;
}


/* We need to be able to set a default button in a command dialog.
*/
Widget set_command_default(Widget dialog, Widget w)
{ XtVaSetValues(w, XtNdefault, TRUE, NULL);
  return dialog;
}


/* Callback function for the apply button in a property dialog.
*/
void PropertyApplyCB(Widget w, Widget property_dialog, XtPointer call_data)
{ global_device   = CLEAN_DIALOG_DEVICE;
  global_widget   = *(Widget *)property_dialog;
  my_dialog_event = CLEAN_DIALOG_APPLY;
  activate_dialog(global_widget);

#ifdef DEBUG
  fprintf(stderr, "Apply button selected, dialog:%d\n",
                  (int)*(Widget *)property_dialog);
#endif
}


/* Callback function for the reset button in a property dialog.
*/
void PropertyResetCB(Widget w, Widget property_dialog, XtPointer call_data)
{ global_device   = CLEAN_DIALOG_DEVICE;
  global_widget   = *(Widget *)property_dialog;
  my_dialog_event = CLEAN_DIALOG_RESET;
  activate_dialog(global_widget);

#ifdef DEBUG
  fprintf(stderr, "Reset button selected, dialog:%d\n",
                  (int)*(Widget *)property_dialog);
#endif
}


/* Before destroying a property dialog some memory has to be deallocated.
*/
void DestroyPropertyDialogCB(Widget dialog, DialogData *ddata, XtPointer cdata)
{ char *t;
  XtCallbackRec *apply;
  XtCallbackRec *reset;

  XtVaGetValues(dialog, XtNtitle, &t,
                        XtNapply, &apply,
                        XtNreset, &reset, NULL);
  XtFree(t);
  XtFree(apply[0].closure);
  XtFree((XtPointer)apply);
  XtFree((XtPointer)reset);
  XtFree((XtPointer)ddata);
} 


/* Create a property dialog. This popupwindow is provided with apply
   and reset buttons. Width=0 or height=0 => Dimension is dynamically
   calculated. These dialogs are always modeless and therefore have the
   pushpin in.
*/
Widget create_propertydial(CLEAN_STRING title, int width, int height)
{ Widget property;
  Widget bord;
  Widget control;
  Arg args[15];
  char *dtitle;
  int n=0;
  XtCallbackRec *applycb;
  XtCallbackRec *resetcb;
  DialogData *ddata;

  applycb = (XtCallbackRec *)XtMalloc(sizeof(XtCallbackRec)*2);
  resetcb = (XtCallbackRec *)XtMalloc(sizeof(XtCallbackRec)*2);
  applycb[0].callback = (XtCallbackProc)PropertyApplyCB;
  resetcb[0].callback = (XtCallbackProc)PropertyResetCB;
  resetcb[0].closure = applycb[0].closure = (Widget *)XtMalloc(sizeof(Widget));
/* Halbe */
  applycb[1].callback = applycb[1].closure = resetcb[1].callback = resetcb[1].closure = NULL;
/* */
  dtitle=cstring(title);
  XtSetArg(args[n], XtNtitle, dtitle);n++;
  XtSetArg(args[n], XtNwmProtocolInterested, OL_WM_DELETE_WINDOW);n++;
  if(width!=0)
  { XtSetArg(args[n], XtNwidth, (Dimension)width);n++; 
    XtSetArg(args[n], XtNmaxWidth, (Dimension)width);n++;
    XtSetArg(args[n], XtNminWidth, (Dimension)width);n++;
  };
  if(height!=0)
  { XtSetArg(args[n], XtNheight, (Dimension)height);n++;
    XtSetArg(args[n], XtNmaxHeight, (Dimension)height);n++;
    XtSetArg(args[n], XtNminHeight, (Dimension)height);n++;
  };
  XtSetArg(args[n], XtNpushpin, OL_IN);n++;
  XtSetArg(args[n], XtNapply, applycb);n++;
  XtSetArg(args[n], XtNreset, resetcb);n++;
  property=XtCreatePopupShell(dtitle, popupWindowShellWidgetClass,
                              toplevel, args, n);
  OlAddCallback(property, XtNwmProtocol, (XtCallbackProc)CloseDialogCB,
                (XtPointer)ModelessCommandDialog);
  OlAddCallback(property, XtNverify, (XtCallbackProc)PopDownCB, NULL);
  *(Widget *)(resetcb[0].closure) = property;

  XtVaGetValues(property, XtNupperControlArea, &control, NULL);
  XtVaSetValues(control, XtNsameSize, OL_NONE, NULL); 

/* Halbe: added `, 0' after NULL in XtCreateManagedWidget */

  bord=XtCreateManagedWidget("bb", bulletinBoardWidgetClass, control, NULL, 0);
  XtVaSetValues(bord, XtNuserData, property, NULL);

  ddata=(DialogData *)XtMalloc(sizeof(DialogData));
  ddata->active=False;
  ddata->bbord =bord;
  XtVaSetValues(property, XtNuserData, ddata, NULL);
  XtAddCallback(property, XtNdestroyCallback,
                (XtCallbackProc)DestroyPropertyDialogCB, ddata);
  XtAddEventHandler(property, FocusChangeMask, False,
                    (XtEventHandler)handle_dialog_focus_events, property);

#ifdef DEBUG
  fprintf(stderr, "Property dialog created:%d\n",property);
#endif

  return property;
}


/* Add a simple dialog button to a command (or property) dialog.
   Width=0 or Height=0 means that dimension will be set dynamically
   by the OL toolkit otherwise it will be fixed.
*/
Widget add_dialog_button(Widget dialog, int x, int y,
                         int width, int height, CLEAN_STRING label)
{ Widget button;
  DialogData *ddata;
  char *label_s;
  Arg args[9];
  int n=0;

  label_s=cstring(label);
  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);
  XtSetArg(args[n], XtNx, x);n++;
  XtSetArg(args[n], XtNy, y);n++;
  XtSetArg(args[n], XtNlabel, label_s);n++; 
  if(width!=0)
  { XtSetArg(args[n], XtNwidth, width);n++;
    XtSetArg(args[n], XtNminWidth, width);n++;
    XtSetArg(args[n], XtNmaxWidth, width);n++;
  };
  if(height!=0)
  { XtSetArg(args[n], XtNheight, height);n++;
    XtSetArg(args[n], XtNminHeight, height);n++;
    XtSetArg(args[n], XtNmaxHeight, height);n++;
  }; 
  button=XtCreateManagedWidget(label_s, oblongButtonWidgetClass,
                               ddata->bbord, args, n);
  XtAddCallback(button, XtNselect,
                (XtCallbackProc)DialogButtonCB, dialog);
  XtAddCallback(button, XtNdestroyCallback,
                (XtCallbackProc)DestroyWidgetInfoCB, label_s);

  return button; 
}


/* Add static text to a command or property dialog. Dimension 0 means
   dynamically setting that dimension otherwise it will be fixed.
*/
Widget add_static_text(Widget dialog, int x, int y, int width, int height,
                       CLEAN_STRING text)
{ DialogData *ddata;
  Widget static_text;
  char *s;
  Arg args[14];
  int n=0;
  s=cstring(text);

#ifdef DEBUG
  fprintf(stderr,"Creating static text dialog item:%s\n",cstring(text));
#endif

  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);
  XtSetArg(args[n], XtNx, x);n++;
  XtSetArg(args[n], XtNy, y);n++;
  XtSetArg(args[n], XtNwrap, FALSE);n++;
  XtSetArg(args[n], XtNstrip, FALSE);n++;
  if(width!=0)
  { XtSetArg(args[n], XtNwidth, (Dimension)width);n++;
    XtSetArg(args[n], XtNminWidth, (Dimension)width);n++;
    XtSetArg(args[n], XtNmaxWidth, (Dimension)width);n++;
  };
  if(height!=0)
  { XtSetArg(args[n], XtNheight, (Dimension)height);n++;
    XtSetArg(args[n], XtNminHeight, (Dimension)height);n++;
    XtSetArg(args[n], XtNmaxHeight, (Dimension)height);n++;
  }; 
  XtSetArg(args[n], XtNstring, s);n++;
  static_text=XtCreateManagedWidget("", staticTextWidgetClass, ddata->bbord,
                                    args, n);
  XtAddCallback(static_text, XtNdestroyCallback,
                (XtCallbackProc)DestroyWidgetInfoCB, s);

  return static_text;
}


/* Add edit text to a command or property dialog. Dimension 0 means
   dynamically setting that dimension otherwise it will be fixed.
*/
Widget add_edit_text(Widget dialog, int x, int y, int width, int height,
                     int lines, CLEAN_STRING text)
{ Widget edittext;
  DialogData *ddata;
  char *s;
  Arg args[10];
  int n=0;

  s=cstring(text);
  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);
  XtSetArg(args[n], XtNx, x);n++;
  XtSetArg(args[n], XtNy, y);n++;
  if((lines==1)||(lines==0))
  { 
    XtSetArg(args[n], XtNstring, s);n++;
    XtSetArg(args[n], XtNwidth, (Dimension)width);n++;
    if(height!=0)
    { XtSetArg(args[n], XtNheight, (Dimension)height);n++;
      XtSetArg(args[n], XtNminHeight, (Dimension)height);n++;
      XtSetArg(args[n], XtNmaxHeight, (Dimension)height);n++;
    }; 
    edittext=XtCreateManagedWidget("", textFieldWidgetClass, ddata->bbord,
                                   args, n);
  }
  else
  { XtSetArg(args[n], XtNborderWidth, 1);n++;
    XtSetArg(args[n], XtNlinesVisible, lines);n++;
    XtSetArg(args[n], XtNsource, s);n++;
    XtSetArg(args[n], XtNwidth, (Dimension)width);n++;
    edittext=XtCreateManagedWidget("", textEditWidgetClass, ddata->bbord,
                                   args,n);
  };
  XtAddCallback(edittext, XtNdestroyCallback,
                (XtCallbackProc)DestroyWidgetInfoCB, s);

  return edittext;
}


/* Add a exclusives widget to a dialog that is to hold some
   radiobuttons.
*/
Widget add_dialog_exclusives(Widget dialog, int x, int y, int width,
                             int height, int rowsorcolumns, int numberrc)
{ DialogData *ddata;
  Arg args[10];
  int n=0;

  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);
  XtSetArg(args[n], XtNx, x);n++;
  XtSetArg(args[n], XtNy, y);n++;
  switch(rowsorcolumns)
  { case GroupRows:
      XtSetArg(args[n], XtNlayoutType, OL_FIXEDROWS);
      break;
    case GroupColumns:
      XtSetArg(args[n], XtNlayoutType, OL_FIXEDCOLS);
  };n++;
  XtSetArg(args[n], XtNmeasure, numberrc);n++; 
  if(width!=0)
  { XtSetArg(args[n], XtNwidth, width);n++;
    XtSetArg(args[n], XtNminWidth, width);n++;
    XtSetArg(args[n], XtNmaxWidth, width);n++;
  };
  if(height!=0)
  { XtSetArg(args[n], XtNheight, height);n++;
    XtSetArg(args[n], XtNminHeight, height);n++;
    XtSetArg(args[n], XtNmaxHeight, height);n++;
  }; 
  
  return XtCreateManagedWidget("ex", exclusivesWidgetClass, ddata->bbord, 
                               args,n);
}

/* The popup caption has to be of the same width as the widest string in
   the popup and therefore we have to count the maximum.
*/
int popup_max_width;


/* Add a popup menu to a dialog that is to hold some
   radiobuttons. The popup consists of an abrreviated menu button (i.e.
   a box with an arrow, attached to a popup menu) and a statictext, which
   is used to display the current selection in this menu.
*/
Widget add_dialog_popup(Widget dialog, int x, int y, int width, int height)
{ DialogData *ddata;
  Widget ex,popup,pane;
  Widget pmenu;
  Widget label;
  Dimension abbrev_width,abbrev_height;

  popup_max_width=0;
  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);

  popup=XtVaCreateManagedWidget("popup",bulletinBoardWidgetClass,ddata->bbord,
                                XtNborderWidth,1,
                                XtNlayout,OL_IGNORE,
                                XtNx,x,XtNy,y,NULL);
  pmenu=XtVaCreateManagedWidget("pmenu",abbrevMenuButtonWidgetClass,popup,
                                NULL);
  XtVaGetValues(pmenu, XtNmenuPane, &pane, XtNwidth, &abbrev_width,
                       XtNheight, &abbrev_height,NULL);
  label=XtVaCreateManagedWidget("l",staticTextWidgetClass, popup,
                                XtNwrap, False,
                                XtNx, (int)abbrev_width+4, NULL);
  
  ex = XtVaCreateManagedWidget("ex", exclusivesWidgetClass, pane,
                               XtNlayoutType, OL_FIXEDCOLS,
                               XtNuserData, label,
                               XtNmeasure, 1, NULL);
  XtVaSetValues(popup, XtNuserData, ex, XtNheight, abbrev_height, NULL);
  return popup;
}

Widget get_popup_ex(Widget popup)
{ Widget ex;
  XtVaGetValues(popup,XtNuserData,&ex,NULL);
  return ex;
}

Widget correct_popup_size(Widget popup)
{ 
  XtVaSetValues(popup, XtNwidth, (Dimension)(popup_max_width+16), NULL);

  return popup;
}


/* The function called whenever a radio button is selected.
*/
void DialogRadioCB(Widget w, Widget dialog, XtPointer call_data)
{ char *s;
  Widget caption;
/*  Dimension caption_width; Halbe */

  XtVaGetValues(XtParent(w), XtNuserData, &caption, NULL);
  if(caption!=NULL)
  { XtVaGetValues(w, XtNlabel, &s, NULL);
    XtVaSetValues(caption, XtNstring, s, NULL);
  };

  global_device=CLEAN_DIALOG_DEVICE;
  global_widget=dialog;

  my_dialog_event=CLEAN_DIALOG_RADIOB;
  my_dialog_button=w;
  activate_dialog(global_widget);
}

/* Add a dialog radio button to an exclusives widget.
   When added to a popup, a new maximum width for the popup is calculated
   and if necessary the popup label is set to the radio button's label. 
*/
Widget add_dialog_radiob(Widget exclusives, Widget dialog, CLEAN_STRING title,
                         int mark)
{ Widget item,caption;
  char *s;
  Arg args[5];
  int n=0;
  Dimension width;
 
  s=cstring(title);
  XtVaGetValues(exclusives, XtNuserData, &caption, NULL);
  XtSetArg(args[n], XtNlabel, s);n++;
  switch(mark)
  { case MarkOn:
      XtSetArg(args[n], XtNset, TRUE);
      if(caption!=NULL)
        XtVaSetValues(caption, XtNstring,s,NULL);
      break;
    case MarkOff:
      XtSetArg(args[n], XtNset, FALSE);
  };n++;
  
  item = XtCreateManagedWidget("rb", rectButtonWidgetClass, exclusives,
                               args,n);
  if(caption!=NULL)
  { XtVaGetValues(item, XtNwidth, &width, NULL);
    if( (int)width>popup_max_width ) popup_max_width=(int)width;
  };
  
  XtAddCallback(item, XtNselect,
                (XtCallbackProc)DialogRadioCB, dialog);
  XtAddCallback(item, XtNdestroyCallback,
                (XtCallbackProc)DestroyWidgetInfoCB, s);

  return item;
}


/* Add a nonexclusives widget to a dialog that is to hold some
   check items.
*/
Widget add_dialog_nonexclusives(Widget dialog, int x, int y, int width,
                                int height, int rowsorcolumns, int numberrc)
{ DialogData *ddata;
  Arg args[10];
  int n=0;

  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);
  XtSetArg(args[n], XtNx, x);n++;
  XtSetArg(args[n], XtNy, y);n++;
  switch(rowsorcolumns)
  { case GroupRows:
      XtSetArg(args[n], XtNlayoutType, OL_FIXEDROWS);
      break;
    case GroupColumns:
      XtSetArg(args[n], XtNlayoutType, OL_FIXEDCOLS);
  };n++;
  XtSetArg(args[n], XtNmeasure, numberrc);n++; 
  if(width!=0)
  { XtSetArg(args[n], XtNwidth, width);n++;
    XtSetArg(args[n], XtNminWidth, width);n++;
    XtSetArg(args[n], XtNmaxWidth, width);n++;
  };
  if(height!=0)
  { XtSetArg(args[n], XtNheight, height);n++;
    XtSetArg(args[n], XtNminHeight, height);n++;
    XtSetArg(args[n], XtNmaxHeight, height);n++;
  }; 
  
  return XtCreateManagedWidget("ex", nonexclusivesWidgetClass, ddata->bbord, 
                               args,n);
}


/* The function called whenever a radio button is selected.
*/
void DialogCheckCB(Widget w, Widget dialog, XtPointer call_data)
{ global_device=CLEAN_DIALOG_DEVICE;
  global_widget=dialog;

  my_dialog_event=CLEAN_DIALOG_CHECKB;
  my_dialog_button=w;
  activate_dialog(global_widget);
}


/* Add a dialog button to an nonexclusives widget.
*/
Widget add_dialog_checkb(Widget nonexclusives, Widget dialog,
                         CLEAN_STRING title, int mark)
{ Widget item;
  char *s;
  Arg args[5];
  int n=0;

  s=cstring(title);
  XtSetArg(args[n], XtNlabel, s);n++;
  XtSetArg(args[n], XtNposition, OL_RIGHT);n++;
  XtSetArg(args[n], XtNlabelJustify, OL_LEFT);n++;
  switch(mark)
  { case MarkOn:
      XtSetArg(args[n], XtNset, TRUE);
      break;
    case MarkOff:
      XtSetArg(args[n], XtNset, FALSE);
  };n++;
  
  item = XtCreateManagedWidget("rb", checkBoxWidgetClass, nonexclusives,
                               args,n);
  XtAddCallback(item, XtNselect, (XtCallbackProc)DialogCheckCB, dialog);
  XtAddCallback(item, XtNunselect, (XtCallbackProc)DialogCheckCB, dialog);
  XtAddCallback(item, XtNdestroyCallback,
                (XtCallbackProc)DestroyWidgetInfoCB, s);

  return item;
}


/* The redraw function of a control dialog item (see below) generates
   a dialog redraw control event for the application.
*/
void RedrawControlCB(Widget w, XEvent *event, Region region)
{ WindowData *wdata;

  XtVaGetValues(w, XtNuserData, &wdata, NULL);

  global_device    = CLEAN_DIALOG_DEVICE;
  global_widget    = wdata->hscrollbar;
  if((int)(wdata->vscrollbar)==ControlTypeCustom)
    my_dialog_event  = CLEAN_DIALOG_REDRAW;
  else
    my_dialog_event  = CLEAN_DIALOG_IREDRAW;
  my_dialog_button = w;
} 


/* For every control dialog item an event handler is installed that
   takes care of passing the mouse event information any mouse event
   happened on the control to Clean.
*/
void handle_dialog_mouse_events(Widget w,Widget dialog,XEvent *event,int *done)
{ WindowData *wdata;
  int x,y;
  Time time;

  XtVaGetValues(w, XtNuserData, &wdata, NULL);

  switch(event->type)
  { /* mouse events */ 
    case ButtonPress:
      time = (event->xbutton).time;
      my_local_mouse_x = x = (event->xbutton).x;
      my_local_mouse_y = y = (event->xbutton).y;
      my_mouse_x = x+(wdata->x0);
      my_mouse_y = y+(wdata->y0);

      /* check for multiclicks */
      switch(click_count)
      { case NoClick:
          my_mouse_event = BUTTONDOWN;
          last_click_x = x;
          last_click_y = y;
          click_count = OneClick;
          break;
        case OneClick:
          if( (time-time_of_last_click <= multi_click_time) &&
              (x == last_click_x) &&
              (y == last_click_y) )
          { my_mouse_event = DOUBLECLICK;
            click_count = TwoClicks;
          }
          else
          { my_mouse_event = BUTTONDOWN;
            last_click_x = x;
            last_click_y = y;
            click_count = OneClick;
          };
          break;
        case TwoClicks:
          if( (time-time_of_last_click <= multi_click_time) &&
              (x == last_click_x) &&
              (y == last_click_y) )
          { my_mouse_event = TRIPLECLICK;
            click_count = NoClick;
          }
          else
          { my_mouse_event = BUTTONDOWN;
            last_click_x = x;
            last_click_y = y;
            click_count = OneClick;
          };
      };

      time_of_last_click = time;
      calc_keystate((event->xbutton).state,&my_state);
      button_down=ButtonStillDownDialog;
      global_device=CLEAN_DIALOG_DEVICE;
      global_widget=dialog;
      my_last_window=global_widget;
      my_dialog_event=CLEAN_DIALOG_MOUSE;
      my_dialog_button=w;
      activate_dialog(global_widget);

      break;

    case ButtonRelease:
      my_mouse_event=BUTTONUP;
      my_mouse_x=(event->xbutton).x+(wdata->x0);
      my_mouse_y=(event->xbutton).y+(wdata->y0);
      calc_keystate((event->xbutton).state,&my_state);
      button_down=ButtonUp;
      global_device=CLEAN_DIALOG_DEVICE;
      global_widget=dialog;
      my_dialog_event=CLEAN_DIALOG_MOUSE;
      my_dialog_button=w;
      break;

    case MotionNotify:
      if(button_down==ButtonStillDownDialog)
      { my_local_mouse_x = (event->xmotion).x;
        my_local_mouse_y = (event->xmotion).y;
        my_mouse_x=my_local_mouse_x+(wdata->x0);
        my_mouse_y=my_local_mouse_y+(wdata->y0);
        my_mouse_event=BUTTONSTILLDOWN;
        calc_keystate((event->xmotion).state,&my_state);
        global_device=CLEAN_DIALOG_DEVICE;
        global_widget=dialog;
        my_last_window=global_widget;
        my_dialog_event=CLEAN_DIALOG_MOUSE;
        my_dialog_button=w;
      };

      break;
  };

  if((int)(wdata->vscrollbar)==ControlTypeIcon)
      if(my_dialog_event==CLEAN_DIALOG_MOUSE)
        my_dialog_event=CLEAN_DIALOG_IMOUSE;

#ifdef DEBUG
  fprintf(stderr,"Mouse event on dialog control catched\n");
#endif
}


/* Deacclocate all picture data associated with a dialog control. 
*/
void DestroyDialogControlCB(Widget control, WindowData *wdata, XtPointer cdata)
{ extern void FreePictureData(WindowData *);

  FreePictureData(wdata);
}


/* Add a control to the dialog. This is an item with an application
   specified look and feel and therefore we have to attach a picture
   domain and a mouse event handler to it.
*/
Widget add_dialog_control(Widget dialog,  int x, int y, int width, int height,  
                          int x0, int y0, int control_type)
{ Widget stub; 
  DialogData *ddata;
  WindowData *wdata;
  extern void set_default_font(WindowData *wdata);

  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);
  wdata=(WindowData *)XtMalloc(sizeof(WindowData));
  stub=XtVaCreateManagedWidget("stubcontrol", stubWidgetClass, ddata->bbord,
                               XtNx, x,
                               XtNy, y,
                               XtNwidth, width,
                               XtNheight, height,
                               XtNuserData, wdata,
                               XtNexpose, RedrawControlCB,
                               NULL);
  wdata->hscrollbar=dialog; /* misused for passing the dialog to expose
                               event handler */
  wdata->vscrollbar=(Widget)control_type; /* misused for keeping track
                                             whether it's a control or icon */
  wdata->picture=stub;
  wdata->height=height;
  wdata->width=width;
  wdata->x0=x0;
  wdata->y0=y0;
  wdata->window_gc=make_new_gc();
  wdata->curx=0;
  wdata->cury=0;
  wdata->pen=0;
  set_default_font(wdata);

  /* Add an event handler for the mouse events (i.e. control feel) */
  XtAddEventHandler(stub,ButtonPressMask|ButtonReleaseMask|
                         ButtonMotionMask,
                    False,(XtEventHandler)handle_dialog_mouse_events,dialog);
  XtAddCallback(stub, XtNdestroyCallback,
                (XtCallbackProc)DestroyDialogControlCB, wdata);

#ifdef DEBUG
  fprintf(stderr, "Dialog control created.\n");
#endif

  return stub;
}


/* Get the state: set or unset of a checkboxwidget or rectbuttonwidget.
*/
int get_mark(Widget w)
{ Boolean set;

  XtVaGetValues(w, XtNset, &set, NULL);
  if(set) return MarkOn;
  else return MarkOff;
}


/* Press a radio widget. This means first unmark all radio widgets
   and then mark the one specified.
*/
Widget press_radio_widget(Widget radio, CLEAN_STRING title)
{ Widget exclusives=XtParent(radio);
  Widget *children;
  Widget caption;     /* Halbe */
  Cardinal nchild;
  int i;

  if(!XtIsSubclass(exclusives, exclusivesWidgetClass)) return radio;

  XtVaSetValues(exclusives, XtNnoneSet, TRUE, NULL);
  XtVaGetValues(exclusives, XtNnumChildren, &nchild,
                            XtNchildren, &children, NULL);
  for(i=0;i<(int)nchild;i++) 
  { XtVaSetValues(children[i], XtNset, FALSE, NULL);
  };
  XtVaSetValues(radio, XtNset, TRUE, NULL);
  XtVaSetValues(exclusives, XtNnoneSet, FALSE, NULL);

/* Halbe: */
  XtVaGetValues(exclusives, XtNuserData, &caption, NULL);
  if(caption!=NULL)
    XtVaSetValues(caption, XtNstring, cstring(title), NULL);
/* */

  return radio;
}


/* Access the text in a text edit field.
*/
CLEAN_STRING get_edit_text(Widget textfield)
{ char *text;

  XtFree((XtPointer)result_clean_string);
  if(XtIsSubclass(textfield, textFieldWidgetClass))
    XtVaGetValues(textfield, XtNstring, &text, NULL);
  else
    XtVaGetValues(textfield, XtNsource, &text, NULL);
  result_clean_string=(CLEAN_STRING)XtMalloc(sizeof(int)+strlen(text)+1);
  result_clean_string->length=strlen(text);
  memcpy(result_clean_string->characters,text,strlen(text)+1); 

  return result_clean_string;
}


/* Change the text in a text edit field.
*/
Widget set_edit_text(Widget textfield, CLEAN_STRING text)
{ char *s;

  if(XtIsSubclass(textfield, textFieldWidgetClass))
  { XtVaGetValues(textfield, XtNstring, &s, NULL);
    XtFree(s);
    XtVaSetValues(textfield, XtNstring, cstring(text), NULL);
  }
  else        /* Halbe: Toolkit Warnings, XtFree levert Segmentation fault */
  {           /* textEditWidgetClass */
    XtVaGetValues(textfield, XtNsource, &s, NULL);
    XtVaSetValues(textfield, XtNsource, cstring(text), NULL);
/*    XtFree(s);  */
  }
  return textfield;
}
  

/* Set static text.
*/
Widget set_static_text(Widget statictext, CLEAN_STRING text)
{ char *s;

  XtVaGetValues(statictext, XtNstring, &s, NULL);
  XtVaSetValues(statictext, XtNstring, cstring(text), NULL);
/*  XtFree(s);          Halbe */
  return statictext;
}

/* Return the actual button pressed in the dialog.
*/
void get_dialog_event(int dummy, int *dial_event, Widget *button)
{ *dial_event=my_dialog_event;
  *button    =my_dialog_button;
}


/* Popup a modal dialog.
*/
Widget popup_modaldialog(Widget dialog)
{ XtPopup(dialog, XtGrabExclusive);
  activate_dialog(dialog);
  return dialog;
}


/* Popup a modeless dialog.
*/
Widget popup_modelessdialog(Widget dialog)
{ XtPopup(dialog, XtGrabNone);
  activate_dialog(dialog);
  return dialog;
}

/* NOTICES
*/

/* Create a notice (alert widget) with a couple of lines 
   of text.
   Buttons will have to be added to the notice's control
   area.
*/
Widget create_notice(CLEAN_STRING text)
{ Widget notice;
  Widget statictext;
  char *s;

  s=cstring(text);
  notice = XtCreatePopupShell("", noticeShellWidgetClass, toplevel,
                              NULL, 0);
  XtVaGetValues(notice, XtNtextArea, &statictext, NULL);
  XtVaSetValues(statictext, XtNstring, s,
                            XtNstrip, FALSE, NULL);
  XtAddCallback(notice, XtNdestroyCallback,
                (XtCallbackProc)DestroyWidgetInfoCB, s);

  return notice;
}

/* These globals hold the notice button id to return to Clean
   and administrate whether a notice is being handled or not.
*/
int my_notice_button_id;
Boolean doing_notice;

/* Callback used by notice dialogs.
*/ 
void NoticeCB(Widget w, XtPointer id, XtPointer call_data)
{ my_notice_button_id = (int)id;
  doing_notice        = FALSE;
}


/* Add a button to a notice widget, The first button added will
   be the default button.
*/
Widget add_n_button(Widget notice, CLEAN_STRING label, int id)
{ Widget button;
  Widget control; 
  char *s;
  
  s=cstring(label);
  XtVaGetValues(notice, XtNcontrolArea, &control, NULL);
  button = XtCreateManagedWidget(s, oblongButtonWidgetClass, 
                                 control, NULL, 0);
  XtAddCallback(button, XtNselect,
                (XtCallbackProc)NoticeCB, (XtPointer)id);
  XtAddCallback(button, XtNdestroyCallback,
                (XtCallbackProc)DestroyWidgetInfoCB, s);

  return notice;
}


/* The notice event loop. It only takes care of handling this notice
   and it returns the button id to Clean.
*/
int handle_notice(Widget notice)
{ XEvent event;
  
  XtPopup(notice, XtGrabExclusive);
  doing_notice=TRUE;
  while(doing_notice)
  { XtNextEvent(&event);
    XtDispatchEvent(&event);
  };

  return my_notice_button_id;
}


/* Beep.
*/ 
int beep(int dummy)
{ XBell(display,0);
  return dummy;
}


/* Retrieving the current rect of a widget.
*/
void get_current_rect(Widget widget, int *x, int *y, int *w, int *h)
{ int wx,wy;
  Dimension ww,wh;
  Widget dialog;
  Widget father=XtParent(widget);

  XtVaGetValues(father, XtNuserData, &dialog, NULL);
  XtRealizeWidget(dialog);

  XtVaGetValues(widget, XtNx, &wx, XtNy, &wy, XtNwidth, &ww, XtNheight, &wh,
                NULL);
  *x=wx;
  *y=wy;
  *w=(int)ww;
  *h=(int)wh;
}


/* Retrieving the current rect of a menu Button widget.
*/
void get_current_popup_rect(Widget ex, int *x, int *y, int *w, int *h)
{ int wx,wy;
  Dimension ww,wh;
  Widget dialog;
  Widget menu,father;

  XtVaGetValues(ex, XtNuserData, &menu, NULL);
  father=XtParent(menu);
  XtVaGetValues(father, XtNuserData, &dialog, NULL);
  XtRealizeWidget(dialog);

  XtVaGetValues(menu, XtNx, &wx, XtNy, &wy, XtNwidth, &ww, XtNheight, &wh,
                NULL);
  *x=wx;
  *y=wy;
  *w=(int)ww;
  *h=(int)wh;
}


/* Set new position and dimensions of a widget.
*/
Widget repos_widget(Widget widget, int x, int y, int w, int h)
{ XtVaSetValues(widget, XtNx, x, XtNy, y, XtNwidth, w, XtNheight, h, NULL);
  return widget;
}


/* Get the width of the father of a dialog item.
*/
int get_father_width(Widget w)
{ Widget father=XtParent(w);
  Widget dialog;
  Dimension width;
  
  XtVaGetValues(father, XtNuserData, &dialog, NULL);
  XtRealizeWidget(dialog);
  XtVaGetValues(dialog, XtNwidth, &width, NULL);

#ifdef DEBUG
  fprintf(stderr,"Father width: %d\n",(int)width);
#endif

  return (int)width;
}


/* Adjust dialog size according to the supplied margins */
Widget set_dialog_margins(Widget dialog,int marginx, int marginy)
{ DialogData *ddata;
  Dimension w,h;
  OlDefine layout;

  XtVaGetValues(dialog, XtNuserData, &ddata, NULL);
  XtVaGetValues(ddata->bbord, XtNlayout, &layout,
                              XtNwidth, &w, XtNheight, &h, NULL);
  if(layout==OL_MINIMIZE)
  { XtVaSetValues(ddata->bbord, XtNlayout, OL_IGNORE, NULL);
    XtVaSetValues(ddata->bbord, XtNwidth, w+(Dimension)marginx,
                                XtNminWidth, w+(Dimension)marginx,
                                XtNheight, h+(Dimension)marginy,
                                XtNminHeight, h+(Dimension)marginy,NULL);
  };
  return dialog;
}


/* Get Horizontal conversion of mm to pixels.
*/
int mm_to_pixel_hor(double mm)
{ 
  return OlMMToPixel(OL_HORIZONTAL, mm);
}


/* Get Vertical conversion of mm to pixels.
*/
int mm_to_pixel_ver(double mm)
{ 
  return OlMMToPixel(OL_VERTICAL, mm);
}

/* This function handles focus changes, which in terms of
   Clean Event IO events means activation/decativation events.
   We are only interested in Nonlinear notify events,
   don't ask me why.
*/
void handle_dialog_focus_events(Widget w,Widget dialog,
                                          XEvent *event,int *done)
{ DialogData *ddata;

  switch(event->type)
  { case FocusIn:
      XtVaGetValues(dialog,XtNuserData,&ddata,NULL);
      if(!(ddata->active))
      { global_device=CLEAN_DIALOG_DEVICE;
        global_widget=dialog;
        my_dialog_event=CLEAN_DIALOG_ACTIVATE;
      };        
      ddata->active=True;
      break;
    case FocusOut:
      XtVaGetValues(dialog,XtNuserData,&ddata,NULL);
      ddata->active=False;
      break;
  };

#ifdef DEBUG
    fprintf(stderr,"Dialog focus i/o event\n");
#endif
}


/* Generate ButtonStillDownEvent for dialog. */
void ButtonDialogStillDownEvent(void)
{ WindowData *wdata;
  Window d;
  int dd;
  unsigned int keys_buttons;

  XtVaGetValues(my_dialog_button, XtNuserData, &wdata, NULL);

  if(XQueryPointer(display,XtWindow(my_last_window),&d,&d,
                  &dd,&dd,&dd,&dd,&keys_buttons))
    calc_keystate(keys_buttons,&my_state);

  my_mouse_x = my_local_mouse_x + wdata->x0;
  my_mouse_y = my_local_mouse_y + wdata->y0;
  my_mouse_event=BUTTONSTILLDOWN;
  global_widget=my_last_window;
  global_device=CLEAN_DIALOG_DEVICE;
  my_dialog_event=CLEAN_DIALOG_MOUSE;
} 


/* Enabling and disabling dialog items. */
Widget enable_dialog_item(Widget w)
{ XtSetSensitive(w,True);
  return w;
}

Widget disable_dialog_item(Widget w)
{ XtSetSensitive(w,False);
  return w;
}


/* Redrawing an about dialog.
*/
void RedrawAboutCB(Widget w, XEvent *event, Region region)
{ global_device = CLEAN_DIALOG_DEVICE;
  global_widget = w;
  my_dialog_event = CLEAN_ABOUT_REDRAW;
}

/* Callback for the (optional) help button in an about dialog.
*/
void AboutHelpCB(Widget w, XtPointer about, XtPointer calldata)
{ global_device = CLEAN_DIALOG_DEVICE;
  global_widget = (Widget)about;
  my_dialog_event = CLEAN_ABOUT_HELP;
} 

/* We can install an about dialog/window on the toplevel widget,
   below the menu bar (if there is one).
*/
Widget create_about_dialog(int x0,int y0,int x1,int y1,int help,
                           CLEAN_STRING help_title)
{ Widget picture,helpb;
  int width,height;
  Dimension hwidth;
  WindowData *wdata;
  char *s;
  extern void set_default_font(WindowData *wdata);

  width=x1-x0;
  height=y1-y0;
  wdata=(WindowData *)XtMalloc(sizeof(WindowData));
  picture=XtVaCreateManagedWidget("about", stubWidgetClass, base,
                                   XtNx,10,
                                   XtNy,40,
                                   XtNwidth, (Dimension)width,
                                   XtNheight, (Dimension)height,
                                   XtNuserData, wdata,
                                   XtNexpose, RedrawAboutCB,NULL);
  XtAddCallback(picture, XtNdestroyCallback,
                (XtCallbackProc)DestroyDialogControlCB, wdata);
  wdata->picture=picture;
  wdata->height=height;
  wdata->width=width;
  wdata->x0=x0;
  wdata->y0=y0;
  wdata->window_gc=make_new_gc();
  wdata->curx=0;
  wdata->cury=0;
  wdata->pen=0;
  set_default_font(wdata);
  
  /* dummy widget to the right side of this picture */
  XtVaCreateManagedWidget("",stubWidgetClass,base,XtNx,10+(Dimension)width,
                          XtNy,40,XtNwidth,10,XtNheight,(Dimension)height,NULL);

  if(help==1) 
  { s=cstring(help_title);
    helpb=XtVaCreateManagedWidget(s, oblongButtonWidgetClass,base,
                                  XtNy,70+height,NULL);
    XtAddCallback(helpb, XtNselect, (XtCallbackProc)AboutHelpCB, picture);
    XtAddCallback(helpb, XtNdestroyCallback,
                  (XtCallbackProc)DestroyWidgetInfoCB, s);
    XtVaGetValues(helpb,XtNwidth,&hwidth,NULL);
    XtVaSetValues(helpb,XtNx,10+((Dimension)width-hwidth)/2, NULL);
  };

  return picture;
} 

Widget check_dialog_item(Widget w,int check)
{
  if(check)
   XtVaSetValues(w,XtNset,TRUE,NULL);
  else
   XtVaSetValues(w,XtNset,FALSE,NULL);

  return w;   /* Halbe */
}
