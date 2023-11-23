/*
   This module implements a very simple and straightforward fileselector
   for use in Concurrent Clean Event I/O. Functions are provided for
   handling fileselectors for choosing to a file that has to be written
   and for choosing a file that has to be read.

   The interfacing to Clean for this module is provided in xfileselect.fcl.
   These functions are used by the Clean deltaFileSelect module.

   1992: Leon Pillich
*/

#include <X11/Intrinsic.h>
#include <X11/StringDefs.h>
#include <Xol/OpenLook.h>
#include <Xol/BaseWindow.h>
#include <Xol/RubberTile.h>
#include <Xol/ScrollingL.h>
#include <Xol/ControlAre.h>
#include <Xol/TextField.h>
#include <Xol/OblongButt.h>
#include <Xol/Notice.h>
/* RWS #include <sys/dir.h> */
#include <dirent.h>
#include <sys/dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <string.h>
#include <memory.h>
#include <stdio.h>
#include <stdlib.h>

#define SEL_OPEN 1
#define SEL_SAVE 2

extern Widget toplevel;

/* the next widgets are from the file selectors widget tree */
Widget file_sel_base,file_list,name_file,ok_button;

/* is the file selector already created? */
int file_selector_created;

/* the access functions for the scrollinglist widget */
OlListToken (*AddItem)();
void        (*DeleteItem)();
void        (*TouchItem)();
void        (*UpdateView)();
void        (*ViewItem)();

/* from clean types */
typedef struct clean_string
{
        int     length;
        char    characters[0];
} *CLEAN_STRING;

extern char *cstring(CLEAN_STRING s);

/* a list to hold the files in the list */
typedef struct _file {
  String filename;
  OlListToken token;
} file;

file *CurrentFiles;
int NrOfFiles;
OlListToken lasttoken;

/* Halbe: the globals to keeptrack of the cwd */
char current_dir[128];
char previous_dir[128];
/* End Halbe */

/* the globals to hold and pass the selection */
char selection[128];
int selection_ok;
extern CLEAN_STRING result_clean_string;
int open_or_save;

/* create and fill a sufficiently large CLEAN_STRING */
CLEAN_STRING make_clean_file_name(s)
char *s;
{ 
  XtFree((XtPointer)result_clean_string);
  result_clean_string=(CLEAN_STRING)XtMalloc(sizeof(int)+strlen(s)+1);
  result_clean_string->length=strlen(s);
  memcpy(result_clean_string->characters,s,strlen(s)+1);

#ifdef DEBUG
  fprintf(stderr,"File selection:%s\n",result_clean_string->characters);
  fflush(stderr);
#endif 

  return result_clean_string;
}


/* Closing the file selector window means cancel */
void CloseFileSelector(w,client_data,call_data)
Widget w;
XtPointer client_data;
OlWMProtocolVerify *call_data;
{
  if((call_data->msgtype)==OL_WM_DELETE_WINDOW)
    selection_ok=-1;
}

/* function invoked when pressing the ok button */
void ok_callback(w,client_data,call_data)
Widget w;
XtPointer client_data,call_data;
{ Arg arg;
  char *s;

  selection_ok=1;

  /* get the correct selection from the text field */
  XtSetArg(arg, XtNstring, &s);
  XtGetValues(name_file, &arg, 1);
  /* RWS getwd(selection); */ /* get current directory in selection */
  getcwd(selection, 128); /* get current directory in selection */
  strcat(selection, "/");
  strcat(selection, s); /* append file name */
}

/* function invoked when pressing the cancel button */
void cancel_callback(w,client_data,call_data)
Widget w;
XtPointer client_data,call_data;
{ selection_ok=-1;
}

/* function invoked whenever an item from the list is selected */
void selfile_callback(w,client_data,call_data)
Widget w;
XtPointer client_data,call_data;
{ Arg arg;
  OlListToken token = (OlListToken)call_data;
  OlListItem *newItem = OlListItemPointer(token);
  OlListItem *lastItem;
  int correct_token=0;
  void RemoveFileList(file *);
  file *SetFileList(Widget,String);
  int FileIsDir();
  int i;

  /* check if we have a correct token (bug in OLIT?)*/
  for(i=0;(i<NrOfFiles)&&(correct_token==0);i++)
    if(CurrentFiles[i].token==token) correct_token=1;
  if(correct_token==0) return;
  
  /* get item belonging to token */
  newItem=OlListItemPointer(token);

  /* deselect last item */
  if(lasttoken)
  { lastItem = OlListItemPointer(lasttoken);
    if(lastItem->attr & OL_LIST_ATTR_CURRENT)
      lastItem->attr &= ~OL_LIST_ATTR_CURRENT;
    (*TouchItem)(w, lasttoken);
  };

  if(FileIsDir(newItem->label))
  { chdir(newItem->label);
    { RemoveFileList(CurrentFiles);
      CurrentFiles=SetFileList(file_list, ".");
    };
    XtSetArg(arg, XtNstring, "");
    XtSetValues(name_file, &arg, 1);
    return;
  };

  /* set current item when opening a file (read) */
  if(open_or_save==SEL_OPEN)
  { newItem->attr |= OL_LIST_ATTR_CURRENT;
    (*TouchItem)(w, token);
    lasttoken=token;

    /* copy item text to text field widget */
    XtSetArg(arg, XtNstring, newItem->label);
    XtSetValues(name_file, &arg, 1);
  };
}

static int overwrite_ok;

/* give a warning when overwriting an existing file */
void notice_callback(w, clientdata, calldata)
Widget w;
int clientdata;
XtPointer calldata;
{ if(clientdata==1) overwrite_ok=1;
  else overwrite_ok=-1;
}

void check_file_existence()
{ static Widget notice=NULL;
  static Widget textarea,controlarea,cancel_btn;
  char *fname;
  Arg args[5];
  int n;
  XEvent event;

  /* check if file exists */
  n=0;
  XtSetArg(args[n],XtNstring,&fname);n++;
  XtGetValues(name_file,args,n);
  if(!access(fname,F_OK)) return; /* file exists */  

  if(!notice)  /* if notice not yet created, create! */
  {
    notice=XtCreatePopupShell("notis", noticeShellWidgetClass,
                              file_sel_base, NULL, 0);
    n=0;
    XtSetArg(args[n], XtNtextArea, &textarea);n++;
    XtSetArg(args[n], XtNcontrolArea, &controlarea);n++;
    XtGetValues(notice, args, n);
    
    n=0;
    XtSetArg(args[n], XtNstring, "\nFile does not exist!\n");n++;
    XtSetArg(args[n], XtNalignment, OL_CENTER);n++;
    XtSetValues(textarea, args, n);

    cancel_btn=XtCreateManagedWidget("Cancel", oblongButtonWidgetClass, 
                                     controlarea, NULL, 0);
    XtAddCallback(cancel_btn, XtNselect, notice_callback, 0);
  };
  XtPopup(notice, XtGrabExclusive);

  overwrite_ok=0;

  while(overwrite_ok==0)
  { XtNextEvent(&event);
    XtDispatchEvent(&event);
  };
  selection_ok=0;
}

void check_overwrite()
{ static Widget notice=NULL;
  static Widget notice_permission=NULL;
  static Widget textarea,controlarea,yes_btn,no_btn;
  static Widget textarea_p,controlarea_p,cancel_btn;
  char *fname;
  Arg args[5];
  int n;
  XEvent event;

  /* check if file exists */
  n=0;
  XtSetArg(args[n],XtNstring,&fname);n++;
  XtGetValues(name_file,args,n);
  if(access(fname,F_OK)) return; /* does not exist yet */

  if(access(fname,W_OK)) /* no write permission */
  { if(!notice_permission)   /* if notice not yet created, create! */
    { notice_permission=XtCreatePopupShell("notis", noticeShellWidgetClass,
                                           file_sel_base, NULL, 0);
      n=0;
      XtSetArg(args[n], XtNtextArea, &textarea_p);n++;
      XtSetArg(args[n], XtNcontrolArea, &controlarea_p);n++;
      XtGetValues(notice_permission, args, n);

      n=0;
      XtSetArg(args[n], XtNstring, "\nNo permission to write this file!\n");
      n++;
      XtSetArg(args[n], XtNalignment, OL_CENTER);n++;
      XtSetValues(textarea_p, args, n);

      cancel_btn=XtCreateManagedWidget("Cancel", oblongButtonWidgetClass, 
                                       controlarea_p, NULL, 0);
      XtAddCallback(cancel_btn, XtNselect, notice_callback, 0);
    };
    XtPopup(notice_permission,XtGrabExclusive);
  }
  else  /* overwrite, yes or no */
  { if(!notice)  /* if notice not yet created, create! */
    {
      notice=XtCreatePopupShell("notis", noticeShellWidgetClass,
                                file_sel_base, NULL, 0);
      n=0;
      XtSetArg(args[n], XtNtextArea, &textarea);n++;
      XtSetArg(args[n], XtNcontrolArea, &controlarea);n++;
      XtGetValues(notice, args, n);

      n=0;
      XtSetArg(args[n], XtNstring, "\nFile exists. Do you want to overwrite?\n");
      n++;
      XtSetArg(args[n], XtNalignment, OL_CENTER);n++;
      XtSetValues(textarea, args, n);

      yes_btn=XtCreateManagedWidget("Yes", oblongButtonWidgetClass, 
                          controlarea, NULL, 0);
      no_btn=XtCreateManagedWidget("No", oblongButtonWidgetClass,
                          controlarea, NULL, 0);
      XtAddCallback(yes_btn, XtNselect, notice_callback, 1);
      XtAddCallback(no_btn, XtNselect, notice_callback, 0);
    };
    XtPopup(notice, XtGrabExclusive);
  };

  overwrite_ok=0;

  while(overwrite_ok==0)
  { XtNextEvent(&event);
    XtDispatchEvent(&event);
  };
  if(overwrite_ok==1) selection_ok=1;
  else selection_ok=0;
}

void select_file(selector_title,ok_text,fname)
char *selector_title;
char *ok_text;
char *fname;
{ Arg arg;
  XEvent event;
  file *these_files;
  file *SetFileList(Widget,String);
  void RemoveFileList(file *);
  void create_file_selector(void);

  if(!file_selector_created)
    create_file_selector();

  /* set file selector title, button titles, default file name */
  XtSetArg(arg, XtNtitle, selector_title);
  XtSetValues(file_sel_base, &arg, 1);
  XtSetArg(arg, XtNstring, fname);
  XtSetValues(name_file, &arg, 1);
  XtSetArg(arg, XtNlabel, ok_text);
  XtSetValues(ok_button, &arg, 1);
 
  CurrentFiles=these_files=SetFileList(file_list,".");

  /* we have no selection yet */
  selection_ok=0;

  /* pop up the file selector dialog */
  XtPopup(file_sel_base,XtGrabExclusive);

  /* wait for a selection */
  while(selection_ok==0)
  { XtNextEvent(&event);
    XtDispatchEvent(&event);
    if((selection_ok==1)&&
       (open_or_save==SEL_SAVE)) check_overwrite();
 /*   else if((selection_ok==1)&&
       (open_or_save==SEL_OPEN)) check_file_existence();*/
  };

  /* pop down the file selector dialog */
  XtPopdown(file_sel_base);

  /* free memory occupied by the file list */
  RemoveFileList(CurrentFiles);
}

void create_file_selector(void)
{ int n;
  Widget file_selector,ca1,ca2,cancel_button;
  Arg args[10];
  
  /* create a window for the file selector */
  n=0;
  XtSetArg(args[n], XtNwmProtocolInterested, OL_WM_DELETE_WINDOW);n++;
  file_sel_base=XtCreatePopupShell("fsel",baseWindowShellWidgetClass,
                                   toplevel,args,n);
  file_selector=XtCreateManagedWidget("rt", rubberTileWidgetClass,
                                      file_sel_base,NULL,0);

  /* add the file selector close callback */
  OlAddCallback(file_sel_base, XtNwmProtocol, CloseFileSelector, NULL);

  /* add a scrollinglist to display the files in the current directory */
  n=0;
  XtSetArg(args[n],XtNviewHeight,10);n++;
  XtSetArg(args[n],XtNselectable,FALSE);n++;
  file_list=XtCreateManagedWidget("fl",scrollingListWidgetClass,
                                  file_selector,args,n);
  n=0;
  XtSetArg(args[n], XtNapplAddItem,    &AddItem); n++;
  XtSetArg(args[n], XtNapplTouchItem,  &TouchItem); n++;
  XtSetArg(args[n], XtNapplUpdateView, &UpdateView); n++;
  XtSetArg(args[n], XtNapplDeleteItem, &DeleteItem); n++;
  XtSetArg(args[n], XtNapplViewItem,   &ViewItem); n++;
  XtGetValues(file_list,args,n);

  /* create a control area for adding the file name text widget and
     the button widgets */
  ca1=XtCreateManagedWidget("ca1", controlAreaWidgetClass,file_selector,
                           NULL,0);

  /* the text field widgets holds the name of the selected file or the
     file to be created */
  name_file=XtCreateManagedWidget("nf", textFieldWidgetClass, ca1, args, n);

  /* The final buttons: an ok button (with changeable text) and 
     a cancel button */
  ca2=XtCreateManagedWidget("ca2",controlAreaWidgetClass,file_selector,
                            NULL,0);
  n=0;
  XtSetArg(args[n],XtNdefault,TRUE);n++;
  ok_button=XtCreateManagedWidget("ok", oblongButtonWidgetClass,
                                  ca2, args, n);
  XtAddCallback(ok_button, XtNselect, ok_callback, NULL);
  cancel_button=XtCreateManagedWidget("Cancel", oblongButtonWidgetClass,
                                      ca2, NULL, 0);
  XtAddCallback(cancel_button, XtNselect, cancel_callback, NULL);

  /* add a callback to the file list to set the current item */
  XtAddCallback(file_list, XtNuserMakeCurrent, selfile_callback, 
                NULL);
}

void RemoveFileList(file *files)
{ int i;

  (*UpdateView)(file_list, FALSE);

  XtFree(files[0].filename);
  for(i=1;i<NrOfFiles;i++)
  { (*DeleteItem)(file_list, files[i].token);
    XtFree(files[i].filename);
  };
  (*UpdateView)(file_list, TRUE);
  XtFree((XtPointer)CurrentFiles);
  NrOfFiles=0;
  CurrentFiles=NULL;
}

int FileIsDir(char *fname)
{ static struct stat file_state;

  stat(fname,&file_state);
  return S_ISDIR(file_state.st_mode);
}

int FileAllowed(char *fname)
{ static struct stat f;
  mode_t m;
  stat(fname,&f);
  m=f.st_mode;

  if(getuid()==f.st_uid)
  { if(S_ISDIR(m)) return ((m&S_IXUSR)&&(m&S_IRUSR));
    if(open_or_save==SEL_OPEN) return (m&S_IRUSR);
    else return (m&S_IWUSR);
  };

  if(getgid()==f.st_gid)
  { if(S_ISDIR(m)) return ((m&S_IXGRP)&&(m&S_IRGRP));
    if(open_or_save==SEL_OPEN) return (m&S_IRGRP);
    else return (m&S_IWGRP);
  };

  if(S_ISDIR(m)) return ((m&S_IXOTH)&&(m&S_IROTH));
  if(open_or_save==SEL_OPEN) return (m&S_IROTH);
  else return (m&S_IWOTH);
  
}

int file_cmp(file *a,file *b)
{ return strcmp(a->filename,b->filename);
}

typedef int (*QSortCompareProc)(const void *, const void *);

file *SetFileList(Widget sl, String directory)
{
  OlListItem    item;
  DIR           *dirp;
/* RWS  struct direct *dp; */
  struct dirent *dp;
  file          *filep;
  int           count=0;
  int           len;
  int           current_max_files = 500;

  /* Open directory for reading */
  if(directory == NULL)
    directory = ".";
  dirp = opendir(directory);
  if(dirp == NULL) {
    perror(directory);
    exit(-1);
  }

  /* Read directory entries */
  filep= (file *)XtMalloc(current_max_files * sizeof(file));
  for (dp = readdir(dirp); dp != NULL; dp = readdir(dirp))
  { 
    /* check for permissions */
    if((open_or_save==SEL_OPEN)&&(FileAllowed(dp->d_name)) ||
       (open_or_save==SEL_SAVE)&&!(FileIsDir(dp->d_name)&&
                                   !FileAllowed(dp->d_name)))
    { filep[count].filename =XtNewString(dp->d_name);
      count++;
      if(count==current_max_files)  
      { current_max_files += 500;
        filep=(file *)XtRealloc((XtPointer)filep, current_max_files * sizeof(file));
      };
    };
  };
  closedir(dirp);
  NrOfFiles=count;

  /* Sort the list of files */
  qsort(filep,NrOfFiles,sizeof(file), (QSortCompareProc) file_cmp);

  /* Put directory entries in scrolllist */
  (*UpdateView)(sl, FALSE);
  for(count=1;count<NrOfFiles;count++)
  { item.label_type = OL_STRING;
    item.attr       = (short)count;
    len             = strlen(filep[count].filename);

    /* check for directory */
    if(FileIsDir(filep[count].filename))
    { item.label = (char *)XtMalloc(len+2);
      memcpy(item.label,filep[count].filename,len);
      memcpy(item.label+len,"/",2);
    }
    else
     item.label = filep[count].filename;
  
    item.mnemonic = NULL;
    filep[count].token = (*AddItem)(sl,0,0,item);
  }
  (*UpdateView)(sl, TRUE);

  return filep;
}

/* The next two functions can be accessed from Clean */
void select_input_file(dummy, ready,file_name)
int dummy; /* needed for fcl compiler */
int *ready;
CLEAN_STRING *file_name;
{ 
  /* no selection made yet */
  selection_ok=0;
  selection[0]=(char)0;
  lasttoken=NULL;

/* Halbe */
  getcwd(current_dir, 128);
  chdir(previous_dir);
/* */
  /* activate the actual file selector */
  open_or_save=SEL_OPEN;
  select_file("Open File","Open","");

  *ready=selection_ok;       /* Halbe changed selection_ok=1 to selection_ok==1 */
  if(selection_ok==1) *file_name=make_clean_file_name(selection);
  else *file_name=make_clean_file_name(" ");

/* Halbe */
  getcwd(previous_dir, 128);
  chdir(current_dir);
/* */
}
  
void select_output_file(sel_name,def_fname,ready,file_name)
CLEAN_STRING sel_name;
CLEAN_STRING def_fname;
int *ready;
CLEAN_STRING *file_name;
{
  /* no selection made yet */
  selection_ok=0;
  selection[0]=(char)0;
  lasttoken=NULL;

/* Halbe */
  getcwd(current_dir, 128);
  chdir(previous_dir);
/* */
  /* activate the actual file selector */
  open_or_save=SEL_SAVE;
  select_file(cstring(sel_name),"Save",cstring(def_fname));

  *ready=selection_ok;       /* Halbe changed selection_ok=1 to selection_ok==1 */
  if(selection_ok==1) *file_name=make_clean_file_name(selection);
  else *file_name=make_clean_file_name(" ");

/* Halbe */
  getcwd(previous_dir, 128);
  chdir(current_dir);
/* */
}

void init_file_selector(void)
{ 
  file_selector_created=0;
}
