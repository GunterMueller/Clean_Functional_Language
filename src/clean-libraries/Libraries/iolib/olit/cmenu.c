/* 
   This module implements support for creating and handling OLIT menus 
   in Concurrent Clean Event I/O. This menu (the menu bar) is placed
   in the applications root window and a copy is made that is
   used (transparently) as a popup menu for every document window
   that is created.

   The interfacing to Clean for this module can be found in xmenu.fcl
   These functions are used by the Clean modules menuDevice,menuInternal
   and deltaMenu.

   1991/1992: Leon Pillich.
*/

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>

#include <Xol/OpenLook.h>
#include <Xol/ControlAre.h>
#include <Xol/MenuButton.h>
#include <Xol/OblongButt.h>
#include <Xol/Nonexclusi.h>
#include <Xol/RectButton.h>
#include <Xol/Menu.h>

#include "clean_devices.h"
#include <stdio.h>
#include <memory.h>
#include <ctype.h>

/* the global device to be passed to Clean */
extern CLEAN_DEVICE global_device;
extern Widget global_widget;

/* global to hold menu bar widget */
Widget global_menu_bar;
Widget global_popup;
Boolean MenuPresent;

extern Widget base; /* main window widget for placing menu bars */
extern Widget toplevel;

/* from clean types */
typedef struct clean_string
{
	int     length;
	char    characters[1];
} *CLEAN_STRING;

char *cstring(CLEAN_STRING);
CLEAN_STRING cleanstring(char *);

/* Deallocating arbitrary widget data.
*/
void DestroyWidgetInfoCB(Widget w,XtPointer to_be_deallocated, XtPointer call);


/* RWS */
int destroy_menu (int menu)
{
	return (destroy_widget (menu));
}
/* */

/*
 * LEON: Destroy a widget of some menu item.
 * This of course also means destroying its mirror.
 */
int destroy_item_widget(Widget item)
{ Widget mirror;

  XtVaGetValues(item, XtNuserData, &mirror, NULL);
  XtDestroyWidget(item);
  XtDestroyWidget(mirror);

  return 0;
}


void PassWidgetCallback(widget,client_data,call_data)
Widget widget;
caddr_t client_data,call_data;
{
  global_widget = widget;
  global_device = (CLEAN_DEVICE)client_data;
}

void PassWidgetCallbackMirror(widget,client_data,call_data)
Widget widget;
caddr_t client_data,call_data;
{
  XtVaGetValues(widget,XtNuserData,&global_widget,NULL);
  global_device = (CLEAN_DEVICE)client_data;
}

Widget show_menu(Widget menu)
{ XtVaGetValues(menu, XtNuserData, &global_popup, NULL);
  global_menu_bar=menu;
  MenuPresent=True;
  XtManageChild(menu);
  return menu;
}

Widget hide_menu(Widget menu)
{ MenuPresent=False;
  XtUnmanageChild(menu);
  return menu;
}

void DestroyMenuBarCB(Widget m, Widget mirror, XtPointer calldata)
{ MenuPresent=False;
  XtDestroyWidget(mirror);
}

/* menus will be added in a menu bar */
Widget add_menu_bar(int dummy)
{ Widget bar;
/*  Arg arg;     Halbe: unused */

  bar=XtCreateWidget("menu",controlAreaWidgetClass,base,NULL,0);
  global_menu_bar=bar;
  global_popup=XtVaCreatePopupShell("Menu",menuShellWidgetClass,base,
                                    XtNmenuAugment, False, NULL);
  XtVaSetValues(bar, XtNuserData, global_popup, NULL);
  XtAddCallback(bar, XtNdestroyCallback,
                (XtCallbackProc)DestroyMenuBarCB, global_popup);
  MenuPresent=True;

#ifdef DEBUG
  fprintf(stderr,"Menu Bar Creation\n");
#endif

  return bar;
}

Widget add_menu(Widget bar, CLEAN_STRING title)
{ Widget m,p,menupane;
  char *s;

  s=cstring(title);
  XtVaGetValues(bar,XtNuserData,&p,NULL);
/* Halbe  XtVaGetValues(p,&XtNmenuPane,&menupane,NULL); */
  XtVaGetValues(p,XtNmenuPane,&menupane,NULL);
  m = XtVaCreateManagedWidget(s,menuButtonGadgetClass,bar,NULL);
  XtVaSetValues(m, XtNuserData,
      XtVaCreateManagedWidget(s,menuButtonGadgetClass,menupane,NULL),NULL);
  XtAddCallback(m, XtNdestroyCallback, DestroyWidgetInfoCB, s);

#ifdef DEBUG
  fprintf(stderr,"Menu creation\n");
#endif

  return m;
}

Widget add_sub_menu(Widget menu, CLEAN_STRING title)
{  Widget p,menupane,sub_menu;
   char *s;

  XtVaGetValues(menu,XtNmenuPane,&menupane,
                     XtNuserData,&p,NULL);

  s=cstring(title);
  sub_menu = XtCreateManagedWidget(s,menuButtonGadgetClass,menupane,NULL,0);
/* Halbe  XtVaGetValues(p,&XtNmenuPane,&menupane,NULL); */
  XtVaGetValues(p,XtNmenuPane,&menupane,NULL);
  XtVaSetValues(sub_menu,XtNuserData,
      XtCreateManagedWidget(s,menuButtonGadgetClass,menupane,NULL,0),NULL);
  XtAddCallback(sub_menu, XtNdestroyCallback, DestroyWidgetInfoCB, s);

#ifdef DEBUG
  fprintf(stderr,"Submenu creation\n");
#endif

  return sub_menu;
}

Widget add_check_item(Widget menu,CLEAN_STRING title,int check)
{ char *s;
  Arg args[5];
  int n=0;
  Widget menupane,menupane2,item,item2,nonex,nonex2,mirror;

  XtVaGetValues(menu,XtNuserData,&mirror,XtNmenuPane,&menupane,NULL);
  XtVaGetValues(mirror,XtNmenuPane,&menupane2,NULL);

  nonex=XtCreateManagedWidget("nonex",nonexclusivesWidgetClass,menupane,NULL,0);
  nonex2=XtCreateManagedWidget("nonex",nonexclusivesWidgetClass,
                               menupane2,NULL,0);
  XtVaSetValues(nonex, XtNuserData, nonex2, NULL);

  if(check) XtSetArg(args[n],XtNset,TRUE); 
  else XtSetArg(args[n],XtNset,FALSE);
  n++;
  s=cstring(title);
  XtSetArg(args[n],XtNlabel,s);n++;

  item = XtCreateManagedWidget("check_item",rectButtonWidgetClass,nonex,args,n);
  item2= XtCreateManagedWidget("check_item",rectButtonWidgetClass,
                               nonex2,args,n);
  XtVaSetValues(item, XtNuserData, item2, NULL);
  XtVaSetValues(item2,XtNuserData, item,  NULL);

  XtAddCallback(item,XtNselect,PassWidgetCallback,
		(XtArgVal)CLEAN_MENU_DEVICE);
  XtAddCallback(item2,XtNselect,PassWidgetCallbackMirror,
		(XtArgVal)CLEAN_MENU_DEVICE);
  XtAddCallback(item,XtNunselect,PassWidgetCallback,
		(XtArgVal)CLEAN_MENU_DEVICE);
  XtAddCallback(item2,XtNunselect,PassWidgetCallbackMirror,
		(XtArgVal)CLEAN_MENU_DEVICE);
  XtAddCallback(item, XtNdestroyCallback, DestroyWidgetInfoCB, s);


#ifdef DEBUG
  fprintf(stderr,"Checkitem creation\n");
#endif

  return item;
}

Widget add_menu_separator(Widget menu)
{ Widget menupane,menupane2,item,item2,mirror;
  
  XtVaGetValues(menu,XtNuserData,&mirror,XtNmenuPane,&menupane,NULL);
  XtVaGetValues(mirror,XtNmenuPane,&menupane2,NULL);

  item = XtCreateManagedWidget(" ",oblongButtonGadgetClass,menupane,NULL,0);
  item2= XtCreateManagedWidget(" ",oblongButtonGadgetClass,menupane2,NULL,0);
 
  XtVaSetValues(item, XtNuserData, item2, NULL);
  XtVaSetValues(item2,XtNuserData, item,  NULL);

  return item;
}

Widget add_menu_item(Widget menu, CLEAN_STRING title)
{ Widget menupane,menupane2,item,item2,mirror;
  char *s;

  XtVaGetValues(menu,XtNuserData,&mirror,XtNmenuPane,&menupane,NULL);
  XtVaGetValues(mirror,XtNmenuPane,&menupane2,NULL);

  s=cstring(title);
  item = XtCreateManagedWidget(s,oblongButtonGadgetClass,menupane,NULL,0);
  item2= XtCreateManagedWidget(s,oblongButtonGadgetClass,menupane2,NULL,0);

  XtVaSetValues(item, XtNuserData, item2, NULL);
  XtVaSetValues(item2,XtNuserData, item,  NULL);

  XtAddCallback(item,XtNselect,PassWidgetCallback,
		(XtArgVal)CLEAN_MENU_DEVICE);
  XtAddCallback(item2,XtNselect,PassWidgetCallbackMirror,
		(XtArgVal)CLEAN_MENU_DEVICE);
  XtAddCallback(item, XtNdestroyCallback, DestroyWidgetInfoCB, s);

#ifdef DEBUG
  fprintf(stderr,"Menu item created %u\n",item);
#endif

  return item;
}

Widget enable_menu_widget(Widget w)
{ Widget mirror;

  XtVaGetValues(w,XtNuserData,&mirror,NULL);
  XtSetSensitive(w,TRUE);
  XtSetSensitive(mirror,TRUE);

#ifdef DEBUG
  fprintf(stderr, "Widget enabled\n");
#endif

  return w;
}

Widget disable_menu_widget(Widget w)
{ Widget mirror;

  XtVaGetValues(w,XtNuserData,&mirror,NULL);
  XtSetSensitive(w,FALSE);
  XtSetSensitive(mirror,FALSE);

#ifdef DEBUG
  fprintf(stderr, "Widget disabled\n");
#endif

  return w;
}

Widget check_widget(Widget w,int check)
{ Widget mirror;

  XtVaGetValues(w,XtNuserData,&mirror,NULL);

  if(check)
  { XtVaSetValues(w,XtNset,TRUE,NULL);
    XtVaSetValues(mirror,XtNset,TRUE,NULL);
  }
  else
  { XtVaSetValues(w,XtNset,FALSE,NULL);
    XtVaSetValues(mirror,XtNset,FALSE,NULL);
  }

#ifdef DEBUG
  fprintf(stderr,"Widget checked\n");
#endif

  return w;
}

Widget set_widget_title(Widget w,CLEAN_STRING title)
{ Widget mirror;
  char *s;

  XtVaGetValues(w,XtNuserData,&mirror,XtNlabel,&s,NULL);
  XtFree(s);
  s=cstring(title);
  XtVaSetValues(w,XtNlabel,s,NULL);
  XtVaSetValues(mirror,XtNlabel,s,NULL);  
  XtAddCallback(w, XtNdestroyCallback, DestroyWidgetInfoCB, s);

#ifdef DEBUG
  fprintf(stderr,"Title changed to %s\n",title->characters);
#endif

  return w;
}

/* installing a key shortcut using */
Widget install_shortcut(Widget w, CLEAN_STRING c)
{ Widget mirror;
  char ch=(char)tolower((c->characters)[0]);
  char shortcut[]="c<x>";
  char representation[]=" ^x";

  shortcut[2]=ch;
  representation[2]=ch;
  XtVaGetValues(w,XtNuserData,&mirror,NULL);
/* RWS
	For some reason this produces an error with OpenLook
    on Solaris ("Duplicate accelerator"), so we don't
.	install an accelerator for the menu bar in the
    main window. */
# ifndef SOLARIS
  XtVaSetValues(w,XtNaccelerator,shortcut,
                  XtNacceleratorText,representation,NULL);
# endif

  XtVaSetValues(mirror,XtNaccelerator,shortcut,
                       XtNacceleratorText,representation,NULL);

#ifdef DEBUG
  fprintf(stderr,"Shortcut: %s installed (0x%X, %s)\n",shortcut,
					w, XtName (w));
  fflush(stderr);
#endif
  return w;
}

/* we need to get information about menu items to reconstuct the MenuElement */
extern CLEAN_STRING result_clean_string;

void get_item_info(Widget item, int *ability, int *state, 
                   CLEAN_STRING *title, CLEAN_STRING *shortcut)
{ Boolean sensitive;
  Boolean set;
  char *s;
  char *key;
  Arg args[4];
  int n;
  static struct clean_string keyshortcut;

  /* get resources values */
  n=0;
  XtSetArg(args[n], XtNlabel, &s);n++;
  XtSetArg(args[n], XtNaccelerator, &key);n++;
  XtSetArg(args[n], XtNsensitive, &sensitive);n++;
  if(XtIsSubclass(item, oblongButtonGadgetClass))
    *state=-1;
  else
  { XtSetArg(args[n], XtNset, &set);n++;
    *state=0;
  };
  XtGetValues(item, args, n);

  /* set return parameters */
  if(key==NULL)
    keyshortcut.length=0;
  else
  { 
    keyshortcut.length=1;
    (keyshortcut.characters)[0]=key[2];
  };
  *shortcut=&keyshortcut;
  if(sensitive) *ability=1;
  else *ability=0;
  if((*state)!=-1)
  { if(set) *state=1;
    else *state=0;
  };
  *title=cleanstring(s);
}

void get_submenu_info(Widget submenu, CLEAN_STRING *title, int *ability)
{ Boolean sensitive;
  char *s;
  
  XtVaGetValues(submenu, XtNlabel, &s, XtNsensitive, &sensitive, NULL);
  if(sensitive) *ability=1; else *ability=0;
  *title=cleanstring(s);
}
