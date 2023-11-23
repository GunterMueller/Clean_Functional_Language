/*
   This module implements a very simple and straightforward fileselector
   for use in Concurrent Clean Event I/O. Functions are provided for
   handling fileselectors for choosing to a file that has to be written
   and for choosing a file that has to be read.

   The interfacing to Clean for this module is provided in xfileselect.fcl.
   These functions are used by the Clean deltaFileSelect module.

   1992: Leon Pillich
   1994: Sven Panne
*/

typedef int MyBoolean;

#include <xview/xview.h>
#include <xview/panel.h>
#include <xview/notice.h>
#include <xview/font.h>
#include <xview/svrimage.h>
#include <xview/scrollbar.h>
/* #include <xview_private/sb_impl.h> */

#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/time.h>

#include "interface.h"
#include "ckernel.h"
#include "ctimer.h"
#include "cfileselect.h"

extern void center_frame (Frame frame);

#define DIRECTORY_LEVEL_CHAR '*'     /* character used to represent directory level */
#define FILE_SELECTOR_WIDTH 384      /* width of the file selector dialog in pixels */
#define NO_OF_FILENAMES_IN_LIST 10   /* number of rows in the file box */
#define PATH_SEPARATOR_CHAR '/'      /* character separating the elements of a path */
#define PATH_SEPARATOR_STRING "/"    /* same as above, but as a string */

/* RWS */
# ifndef FILENAME_MAX
# 	define FILENAME_MAX		255
# endif
/* */

enum file_selector_status {NotYet, LoadOK, SaveOK, Cancelled};

/* Keys for use with XV_KEY_DATA. The actual values are initialized with xv_unique_key. */
static int SaveFlagKey;
static int PanelKey;
static int OldScrollbarEventProcKey;
static int PathsKey;
static int DepthKey;
static int PathTextItemKey;
static int DirectoryListItemKey;
static int FileListItemKey;
static int FileTextItemKey;
static int PathKey;

/* Fonts for file list */
static Xv_Font list_font;
static Xv_Font bold_list_font;


/* data for glyphs */

#if 1
# define W(a,b) (((a)<<8)|(b))
#else
# if defined (SWAP_ICON_BYTES)
# define W(a,b) b,a
# else
# define W(a,b) a,b
# endif
#endif

static unsigned short /*char*/ directory_pr_array[] = {
  /* Format_version=1, Width=16, Height=16, Depth=1, Valid_bits_per_item=16
   */
  W(0x00,0x00),W(0x00,0x00),W(0x00,0x00),W(0x0,0x03C),W(0x00,0x42),W(0xFF,0x81),W(0x80,0x01),W(0x80,0x01),
  W(0x80,0x01),W(0x80,0x01),W(0x80,0x01),W(0x80,0x01),W(0x80,0x01),W(0x80,0x01),W(0x80,0x01),W(0xFF,0xFF)
};

static unsigned short /*char*/ file_pr_array[] = {
  /* Format_version=1, Width=16, Height=16, Depth=1, Valid_bits_per_item=16
   */
  W(0x7F,0xE0),W(0x40,0x30),W(0x40,0x28),W(0x40,0x24),W(0x40,0x3E),W(0x40,0x02),W(0x40,0x02),W(0x40,0x02),
  W(0x40,0x02),W(0x40,0x02),W(0x40,0x02),W(0x40,0x02),W(0x40,0x02),W(0x40,0x02),W(0x40,0x02),W(0x7F,0xFE)
};

static unsigned short /*char*/ unknown_pr_array[] = {
  /* Format_version=1, Width=16, Height=16, Depth=1, Valid_bits_per_item=16
   */
  W(0xFF,0xFF),W(0x80,0x01),W(0x80,0x01),W(0x83,0x81),W(0x84,0x41),W(0x84,0x41),W(0x80,0x41),W(0x80,0x81),
  W(0x81,0x01),W(0x81,0x01),W(0x80,0x01),W(0x81,0x01),W(0x80,0x01),W(0x80,0x01),W(0x80,0x01),W(0xFF,0xFF)
};

static Server_image directory_glyph;
static Server_image file_glyph;
static Server_image unknown_glyph;

/* Return a fresh copy of string consisting of max. n characters */
static char *
duplicate_string_n(char *string, int n)
{
  char *buf;
  
  buf = strncpy((char *)my_malloc(n + 1), string, n);
  buf[n] = '\0';
  return buf;
}

/* Return a fresh copy of string. */
char *
duplicate_string(char *string)
{
  return duplicate_string_n(string, strlen(string));
}

/* Return a fresh string consisting of the concatenation of the three strings. */
char *
append_strings3(char *string1, char *string2, char *string3)
{
  char *buf;

  buf = (char *)my_malloc(strlen(string1) + strlen(string2) + strlen(string3) + 1);
  return strcat(strcat(strcpy(buf, string1), string2), string3);
}

/* Return a fresh string consisting of no_of_dots dot characters with intervening spaces. */
static char *
dots(int no_of_dots)
{
  char *dot_string;
  int len;

  len = (no_of_dots * 2) + 1;
  dot_string = (char *)my_malloc(len);

  dot_string[--len] = '\0';
  while (len >= 2) {
    dot_string[--len] = ' ';
    dot_string[--len] = DIRECTORY_LEVEL_CHAR;
  }
  return dot_string;
}

static char *
prepend_directory(char *directory, char *name)
{
  return ((directory[0] == '\0') ?
          duplicate_string(name) :
          append_strings3(directory,
                          ((directory[strlen(directory) - 1] == PATH_SEPARATOR_CHAR) ?
                           "" : PATH_SEPARATOR_STRING),
                          name));
}

static char *
last_path_element(char *path)
{
  char *last_separator;

  last_separator = strrchr(path, PATH_SEPARATOR_CHAR);
  return duplicate_string((last_separator[1] == '\0') ?
                          PATH_SEPARATOR_STRING :
                          last_separator + 1);
}

/* Return the depth in the directory hierarchy of path. The root directory gets value 0. */
static int
depth_of_path(char *path)
{
  int depth;
  char *p;

  for (depth = 0, p = path;  *p != '\0';  p++) {
    if (*p == PATH_SEPARATOR_CHAR) {
      depth++;
    }
  }

  /* root directory? */
  if (path + 1 == p) {
    depth = 0;
  }

#ifdef DEBUG
  fprintf(stderr, "Depth of <%s> is %d.\n", path, depth);
#endif

  return depth;
}

static void
free_paths(char **paths)
{
  char **p;

#ifdef DEBUG
  fprintf(stderr, "free_paths 0x%X\n", (int)paths);
#endif

  for (p = paths;  *p != NULL;  p++) {
    my_free(*p);
  }
  my_free(paths);
}

/* called when a path is removed/replaced */
static void
remove_path_key_data(Xv_object object, int key, caddr_t data)
{
  free_paths((char **)data);
}

/* Return the prefix of path consisting of n path elements.
   E.g: path_prefix("/foo/bar/baz",2) => "/foo/bar" */
static char *
path_prefix(char *path, int n)
{
  char *p;

  if (n == 0) {
    return duplicate_string(PATH_SEPARATOR_STRING);
  } else {
    for (p = path;  *p != '\0';  p++) {
      if (n < 0) {
        return duplicate_string_n(path, p - path - 1);
      } else if (*p == PATH_SEPARATOR_CHAR) {
        n--;
      }
    }
    return duplicate_string(path);
  }
}


/* Return null terminated array of paths, consisting of increasingly longer prefixes of path.
   E.g.: "/foo/bar/baz" => "/", "/foo", "/foo/bar", "/foo/bar/baz", NULL */
static char **
path_to_paths(char *path)
{
  int elements;
  int i;
  char **paths;

#ifdef DEBUG
  fprintf(stderr, "path_to_paths <%s>:\n", path);
#endif

  elements = depth_of_path(path) + 2;
  paths = (char **)my_malloc(elements * sizeof(char *));
  for (i = 0;  i < elements - 1;  i++) {
    paths[i] = path_prefix(path, i);
#ifdef DEBUG
    fprintf(stderr, "   %d: <%s>\n", i, paths[i]);
#endif
  }
  paths[elements - 1] = (char *)0;
  return paths;
}

static char *
get_cwd_from_panel(Panel panel)
{
  char **paths;
  int depth;

  paths = (char **)xv_get(panel, XV_KEY_DATA, PathsKey);
  depth = (int)xv_get(panel, XV_KEY_DATA, DepthKey);
  return paths[depth];
}

static int global_return_status;
static char *global_return_full_name;

static void
file_selector_done(int status, char *full_name)
{
#ifdef DEBUG
  fprintf(stderr, "File selector done: status = %d, full_name = <%s>\n", status, full_name);
#endif

  global_return_status    = status;
  global_return_full_name = full_name;
  notify_stop();
}

static int
is_row_a_directory(Panel_list_item file_list_item, int row_number)
{
  return ((Server_image)xv_get(file_list_item, PANEL_LIST_GLYPH, row_number) ==
          directory_glyph);
}

struct dir_entry_struct {
  char *de_name;
  mode_t de_mode;
};

/* Compare two file names. Directories are sorted between the normal files. */
static int
file_name_comparator(const void *entry1, const void *entry2)
{
  return strcmp(((struct dir_entry_struct *)entry1)->de_name,
                ((struct dir_entry_struct *)entry2)->de_name);
}


/* Update the file list to show the contents of directory.
   Returns TRUE if this was successful, FALSE otherwise. */
static int
update_file_list(Panel panel, char *directory)
{
  DIR *dirp;
  struct dirent *d;
  int alloced;
  struct dir_entry_struct *directory_entry;
  int number_of_directory_entries;
  char *full_name;
  Panel_list_item file_list_item;
  int success;
  struct stat stat_buf;
  Xv_Font entry_font;
  Server_image entry_glyph;
  int row_number;

#ifdef DEBUG
  fprintf(stderr, "Panel 0x%X: updating file list <%s>\n", (int)panel, directory);
#endif

  /* The file names (without directory part) are stored in a dynamically adjusted table. */
  alloced = 10;
  directory_entry =
    (struct dir_entry_struct *)my_malloc(alloced * sizeof(struct dir_entry_struct));

  number_of_directory_entries = 0;
  dirp = opendir(directory);
  if (dirp == (DIR *)0) {
    success = FALSE;
  } else {
    while ((d = readdir(dirp)) != (struct dirent *)0){
		if (!strcmp (d->d_name,".") || !strcmp (d->d_name,".."))
			continue;
		else
	  {
		char *name;

        /* Fill directory entry */
        name = duplicate_string (d->d_name);
        full_name = prepend_directory (directory,name);
        directory_entry[number_of_directory_entries].de_name = name;
        if (stat (full_name,&stat_buf) < 0){
          directory_entry[number_of_directory_entries].de_mode = 0;
        } else {
          directory_entry[number_of_directory_entries].de_mode = stat_buf.st_mode;
        }

        /* Reallocate table if neccessary */
        if (number_of_directory_entries == alloced - 1) {
          alloced *= 2;
          directory_entry =
            (struct dir_entry_struct *)my_realloc(directory_entry,
                                                  alloced * sizeof(struct dir_entry_struct));
        }
        number_of_directory_entries++;
        my_free(full_name);
      }
    }
    success = TRUE;
	closedir(dirp);
  }

  if (success) {

    /* We want the file list in alphabetical order. */
    qsort(directory_entry, number_of_directory_entries, sizeof(struct dir_entry_struct),
          file_name_comparator);

    file_list_item = (Panel_list_item)xv_get(panel, XV_KEY_DATA, FileListItemKey);
    xv_set(file_list_item,
           PANEL_LIST_DELETE_ROWS, 0, (int)xv_get(file_list_item, PANEL_LIST_NROWS),
           NULL);

    for (row_number = 0;  row_number < number_of_directory_entries;  row_number++) {
      switch (directory_entry[row_number].de_mode & S_IFMT) {
      case S_IFDIR:
        entry_font  = bold_list_font;
        entry_glyph = directory_glyph;
        break;
      case S_IFREG:
        entry_font  = list_font;
        entry_glyph = file_glyph;
        break;
      default:
        entry_font  = list_font;
        entry_glyph = unknown_glyph;
        break;
      }

      xv_set(file_list_item,
             PANEL_LIST_INSERT, row_number,
             PANEL_LIST_STRING, row_number, directory_entry[row_number].de_name,
             PANEL_LIST_FONT,   row_number, entry_font,
             PANEL_LIST_GLYPH,  row_number, entry_glyph,
             PANEL_PAINT,       PANEL_NONE, /* don't update list now */
             NULL);
    }

    /* Now we are ready to show the list */
    panel_paint(file_list_item, PANEL_CLEAR);

    /* The scrollbar is set to the top to, because it can be so far down that a
       non-empty directory appears empty at the first view. */
    xv_set((Scrollbar)xv_get(file_list_item, PANEL_LIST_SCROLLBAR),
           SCROLLBAR_VIEW_START, 0,
           NULL);

  }

  /* clean up memory */
  for (row_number = 0;  row_number < number_of_directory_entries;  row_number++) {
    my_free(directory_entry[row_number].de_name);
  }
  my_free(directory_entry);

  return success;
}

static void
enter_new_directory(Panel panel, char *new_directory, int only_depth_change)
{
  Xv_Notice notice;
  int depth;
  char *tmp1;
  char *tmp2;

#ifdef DEBUG
  fprintf(stderr, "Panel 0x%X: %sentering directory <%s>\n",
          (int)panel, only_depth_change ? "re-" : "", new_directory);
#endif

  if (update_file_list(panel, new_directory) == TRUE) {

    if (only_depth_change == FALSE) {
      xv_set(panel,
           XV_KEY_DATA,             PathsKey, path_to_paths(new_directory),
           XV_KEY_DATA_REMOVE_PROC, PathsKey, remove_path_key_data,
           NULL);
    }

    depth = depth_of_path(new_directory);
    xv_set(panel, XV_KEY_DATA, DepthKey, depth, NULL);

    /* Update the Path: line */
    xv_set((Panel_text_item)xv_get(panel, XV_KEY_DATA, PathTextItemKey),
           PANEL_VALUE, new_directory,
           NULL);

    /* Update the directory box */
    tmp1 = dots(depth);
    tmp2 = last_path_element(((char **)xv_get(panel, XV_KEY_DATA, PathsKey))[depth]);
    xv_set((Panel_list_item)xv_get(panel, XV_KEY_DATA, DirectoryListItemKey),
           PANEL_LIST_STRINGS, tmp1, tmp2, " ", NULL,  /* copied by XView */
           NULL);
    my_free(tmp1);
    my_free(tmp2);

  } else {

    notice = (Xv_Notice)xv_create(panel, NOTICE,
                                  NOTICE_MESSAGE_STRING,
                                     "This directory is unreadable.\nPlease try another one.",
                                  NOTICE_BUTTON,         "Cancel", 123,
                                  NOTICE_LOCK_SCREEN,    TRUE,
                                  XV_SHOW,               TRUE,
                                  NULL);
    xv_destroy(notice);
  }
}


static void
change_path_button_pressed(Panel_button_item button, Event *event)
{
  Panel panel;
  char *path_text;
  char *full_path;
  char *p;
  char *q;

#ifdef DEBUG
  fprintf(stderr, "Change Path button pressed.\n");
#endif

  panel = (Panel)xv_get(button, PANEL_PARENT_PANEL);
  path_text =
    (char *)xv_get((Panel_text_item)xv_get(panel, XV_KEY_DATA, PathTextItemKey), PANEL_VALUE);

  if (path_text[0] == PATH_SEPARATOR_CHAR) {
    /* absolute path specified */
    full_path = duplicate_string(path_text);
  } else {
    /* relative path specified, make it absolute */
    full_path = prepend_directory(get_cwd_from_panel(panel), path_text);
  }

  /* remove consecutive path separators */
  for (p = q = full_path;  *p != '\0';  p++) {
    *q = *p;
    if ((*p != PATH_SEPARATOR_CHAR) || (*(p+1) != PATH_SEPARATOR_CHAR)) {
      q++;
    }
  }
  *q = '\0';

  /* remove a path separator at the end */
  if ((q != full_path) && (q[-1] == PATH_SEPARATOR_CHAR)) {
    q[-1] = '\0';
  }

  /* root directory? */
  if (full_path[0] == '\0') {
    strcpy(full_path, PATH_SEPARATOR_STRING);
  }

  enter_new_directory(panel, full_path, FALSE);
  my_free(full_path);
}


static int
check_file_existence(char *full_name, Panel panel)
{
  Xv_Notice notice;

#ifdef DEBUG
  fprintf(stderr, "check_file_existence <%s>\n", full_name);
#endif

  if (access(full_name, F_OK) == 0) {
    /* File exists */
    return TRUE;
  } else {
    /* File does not exist */
    notice = (Xv_Notice)xv_create(panel, NOTICE,
                                  NOTICE_MESSAGE_STRING, "The selected file does not exist!",
                                  NOTICE_BUTTON,         "Cancel", 123,
                                  NOTICE_LOCK_SCREEN,    TRUE,
                                  XV_SHOW,               TRUE,
                                  NULL);
    xv_destroy(notice);
    return FALSE;
  }
}


static int
check_overwrite(char *full_name, Panel panel)
{
  Xv_Notice notice;
  int notice_status;

#ifdef DEBUG
  fprintf(stderr, "check_overwrite <%s>\n", full_name);
#endif

  if (access(full_name, F_OK) == 0) {
    /* File exists */
    if (access(full_name, W_OK) == 0) {
      /* File exists and is writable */
      notice = (Xv_Notice)xv_create(panel, NOTICE,
                                    NOTICE_MESSAGE_STRINGS,
                                       "The selected file already exists.",
                                       "Do you want to overwrite it?",
                                       NULL,
                                    NOTICE_BUTTON,         "Cancel",    123,
                                    NOTICE_BUTTON,         "Overwrite", 456,
                                    NOTICE_STATUS,         &notice_status,
                                    NOTICE_LOCK_SCREEN,    TRUE,
                                    XV_SHOW,               TRUE,
                                    NULL);
      xv_destroy(notice);
      return (notice_status == 456);
    } else {
      /* File exists and is not writable */
      notice = (Xv_Notice)xv_create(panel, NOTICE,
                                    NOTICE_MESSAGE_STRING,
                                       "You have no write permission\nfor the selected file!",
                                    NOTICE_BUTTON,         "Cancel", 123,
                                    NOTICE_LOCK_SCREEN,    TRUE,
                                    XV_SHOW,               TRUE,
                                    NULL);
      xv_destroy(notice);
      return FALSE;
    }
  } else {
    /* File does not exist */
    return TRUE;
  }
}

static char last_directory[FILENAME_MAX+1]={0};

static void
file_selected(Panel panel)
{
  Panel_text_item file_text_item;
  char *full_name,*directory_name;

  file_text_item = (Panel_text_item)xv_get(panel, XV_KEY_DATA, FileTextItemKey);
  directory_name=get_cwd_from_panel (panel);
  full_name = prepend_directory(directory_name,(char *)xv_get(file_text_item,PANEL_VALUE));

  if ((int)xv_get(panel, XV_KEY_DATA, SaveFlagKey)) {
    if (check_overwrite(full_name, panel)) {
		strcpy (last_directory,directory_name);
      file_selector_done((int)SaveOK, full_name);
    }
  } else {
    if (check_file_existence(full_name, panel)) {
		strcpy (last_directory,directory_name);
      file_selector_done((int)LoadOK, full_name);
    }
  }
}

static void
open_or_save_button_pressed(Panel_button_item button, Event *event)
{
#ifdef DEBUG
  fprintf(stderr, "Open/Save button pressed.\n");
#endif
  file_selected((Panel)xv_get(button, PANEL_PARENT_PANEL));
}

static void
cancel_button_pressed(Panel_button_item button, Event *event)
{
#ifdef DEBUG
  fprintf(stderr, "Cancel button pressed.\n");
#endif
  file_selector_done((int)Cancelled, duplicate_string(""));
}

/* Handle selection/deselection of rows in the file box */
static int
file_list_notify_proc(Panel_list_item file_list_item, char *string, Xv_opaque client_data,
                      int op, Event *event, int row)
{
  static struct timeval time_of_last_click;
  static int last_row = -1;  /* Impossible value */
  static int can_be_double_click = FALSE;  /* The very first click is never a double click */
  int msec_diff;
  Panel panel;
  char *buf;

#ifdef DEBUG
  fprintf(stderr, "Panel list item %d, str <%s>, data %d, op %d, row %d, type %d\n",
          file_list_item, string, (int)client_data, op, row, (int)(event_xevent(event)->type));
#endif

  panel = (Panel)xv_get(file_list_item, PANEL_PARENT_PANEL);

  /* Clicks on different rows can never be a double click.
     If the user selects another row, the current one is deselected, but the new one
     is already selected. This can't be a double click, either.
  */
  if ((last_row != row) || ((op == PANEL_LIST_OP_DESELECT) &&
                            ((int)xv_get(file_list_item, PANEL_LIST_FIRST_SELECTED) >= 0))) {
    can_be_double_click = FALSE;
  }
  last_row = row;

  /* If item represents a file, update the File: line. */
  if ((op == PANEL_LIST_OP_SELECT) && !is_row_a_directory(file_list_item, row)) {
    xv_set((Panel_text_item)xv_get(panel, XV_KEY_DATA, FileTextItemKey),
           PANEL_VALUE, string,
           NULL);
  }

  /* The interesting events are the selection or the deselection of a list item. */
  if ((op == PANEL_LIST_OP_DESELECT) || (op == PANEL_LIST_OP_SELECT)) {

    /* If this can't be a double click, the next time it can. */
    if (can_be_double_click == FALSE) {
      can_be_double_click = TRUE;
      msec_diff = multi_click_time + 1;
    } else {
      msec_diff  = (event_time(event).tv_sec  - time_of_last_click.tv_sec ) * 1000 +
                   (event_time(event).tv_usec - time_of_last_click.tv_usec) / 1000;
    }

#ifdef DEBUG
    fprintf(stderr, "last: %d, %d   now: %d, %d   msec_diff %d, double click would be %d\n",
            time_of_last_click.tv_sec, time_of_last_click.tv_usec,
            event_time(event).tv_sec, event_time(event).tv_usec,
            msec_diff, multi_click_time);
#endif

    /* test for double click */
    if (msec_diff < multi_click_time) {

      /* It's a double click, so the next click is not a double click! */
      can_be_double_click = FALSE;

      /* double-clicking on a directory descends to it */
      if (is_row_a_directory(file_list_item, row)) {
        buf = prepend_directory(get_cwd_from_panel(panel), string);
        enter_new_directory(panel, buf, FALSE);
        my_free(buf);
      } else {
        /* double-clicking on a file */
        file_selected(panel);
      }
    } else {
      /* Remember the time of this click. Perhaps it becomes a double click */
      time_of_last_click.tv_sec  = event_time(event).tv_sec;
      time_of_last_click.tv_usec = event_time(event).tv_usec;
    }
  }

  return XV_OK;
}


static Menu
dir_menu_gen_proc(Menu menu, Menu_generate op)
{
  int i;
  Menu_item menu_item;
  Panel panel;
  char **paths;
  char *str;
  int depth;

#ifdef DEBUG
  fprintf(stderr, "dir_menu_gen_proc: menu 0x%X, op %d\n", (int)menu, (int)op);
#endif

  if (op == MENU_DISPLAY) {

    /* remove all menu items except for the title */
    for (i = (int)xv_get(menu, MENU_NITEMS);  i > 1;  i--) {
      menu_item = (Menu_item)xv_get(menu, MENU_NTH_ITEM, i);
      xv_set(menu, MENU_REMOVE, i, NULL);
#ifdef DEBUG
      fprintf(stderr, "Destroying menu item <%s>\n", (char *)xv_get(menu_item, MENU_STRING));
#endif
      xv_destroy_safe(menu_item);
    }

    /* reconstruct directory menu */
    panel = (Panel)xv_get(menu, XV_KEY_DATA, PanelKey);
    paths = (char **)xv_get(panel, XV_KEY_DATA, PathsKey);

    if (paths == (char **)0) {
      /* no paths yet */
      menu_item = (Menu_item)xv_create(XV_NULL, MENUITEM,
                                       MENU_STRING,   "no directories yet",
                                       MENU_INACTIVE, TRUE,
                                       NULL);
      xv_set(menu, MENU_APPEND_ITEM, menu_item, NULL);

    } else {

      depth = (int)xv_get(panel, XV_KEY_DATA, DepthKey);

      for (i = 0;  paths[i] != (char *)0;  i++) {
        str = last_path_element(paths[i]);
#ifdef DEBUG
        fprintf(stderr, "Appending menu item <%s>, path <%s>\n", str, paths[i]);
#endif
        menu_item = (Menu_item)xv_create(XV_NULL, MENUITEM,
                                         MENU_STRING, str,           /* NOT copied by XView! */
                                         MENU_RELEASE, /* destroy item when parent is destr. */
                                         MENU_RELEASE_IMAGE,  /* release string at destruct. */
                                         XV_KEY_DATA, PathKey, paths[i],
                                         NULL);
        xv_set(menu, MENU_APPEND_ITEM, menu_item, NULL);
        if (i == depth) {
          xv_set(menu, MENU_DEFAULT_ITEM, menu_item, NULL);
          xv_set(menu_item, MENU_INACTIVE, TRUE, NULL);
        }
      }
    }
  }
  return menu;
}


static void
dir_menu_notify_proc(Menu menu, Menu_item menu_item)
{
#ifdef DEBUG
  fprintf(stderr, "dir_menu_notify_proc: menu 0x%X, menu_item <%s>, path <%s>\n",
          (int)menu,
          (char *)xv_get(menu_item, MENU_STRING),
          (char *)xv_get(menu_item, XV_KEY_DATA, PathKey));
#endif
  enter_new_directory((Panel)xv_get(menu, XV_KEY_DATA, PanelKey),
                      (char *)xv_get(menu_item, XV_KEY_DATA, PathKey),
                      TRUE);
}


/* Called when directory list scrollbar is used */
static void
my_normalize_scrollbar(Scrollbar scrollbar, long unsigned voffset, Scroll_motion motion,
                       long unsigned *vstart)
{
  Panel panel;
  int depth;
  char **paths;

#ifdef DEBUG
  fprintf(stderr, "Normalize Scrollbar 0x%X, motion %d\n", (int)scrollbar, (int)motion);
#endif

  panel = (Panel)xv_get(scrollbar, SCROLLBAR_NOTIFY_CLIENT);
  depth = (int)xv_get(panel, XV_KEY_DATA, DepthKey);
  paths = (char **)xv_get(panel, XV_KEY_DATA, PathsKey);

  /* Scrollbar stays at top, in any case! */
  *vstart = 0;

  if (paths == (char **)0) return;  /* no paths yet */

  switch (motion) {
  case SCROLLBAR_PAGE_FORWARD:
  case SCROLLBAR_LINE_FORWARD:
    if (paths[depth + 1] == (char *)0) return;
    depth++;
    break;

  case SCROLLBAR_POINT_TO_MIN:
  case SCROLLBAR_TO_END:
    if (paths[depth + 1] == (char *)0) return;
    while (paths[depth + 1] != (char *)0) {
      depth++;
    }
    break;

  case SCROLLBAR_PAGE_BACKWARD:
  case SCROLLBAR_LINE_BACKWARD:
    if (depth == 0) return;
    depth--;
    break;

  case SCROLLBAR_MIN_TO_POINT:
  case SCROLLBAR_TO_START:
    if (depth == 0) return;
    depth = 0;
    break;

  default: /* Do nothing */
    return;
    break;
  }

  enter_new_directory(panel, paths[depth], TRUE);
}


/* We only want events for the directory list scrollbar, not for the directory list item */
static void
my_directory_list_handle_event_proc(Panel_list_item directory_list, Event *event)
{
  static int sb_active = FALSE;
  Rect *sb_rect;

  sb_rect = (Rect *)xv_get(xv_get(directory_list, PANEL_LIST_SCROLLBAR), XV_RECT);
  if (event_action(event) != SCROLLBAR_REQUEST &&
      (sb_active ||
       (event_is_button(event) && event_is_down(event) &&
        rect_includespoint(sb_rect, event_x(event), event_y(event))))) {
    if (event_is_button(event)) {
      sb_active = event_is_down(event);
    }
#ifdef DEBUG
    fprintf(stderr, "Event for directory list scrollbar: passed !\n");
#endif

    /* Call XView's own event routine */
    ((void (*)(Panel_item, Event *)) xv_get((Panel)xv_get(directory_list, PANEL_PARENT_PANEL),
                                            XV_KEY_DATA, OldScrollbarEventProcKey))
      (directory_list, event);
  }
#ifdef DEBUG
  fprintf(stderr, "Event for directory list: ignored!\n");
#endif
}


/* We destroy the frame if it is dismissed, so everything is tidy... */
static void
frame_event_proc(Xv_Window frame, Event *event, Notify_arg arg)
{
  if (event_action(event) == ACTION_DISMISS) {
#ifdef DEBUG
    fprintf(stderr, "Frame 0x%X dismissed\n", (int)frame);
#endif
    xv_destroy_safe(frame);
    file_selector_done((int)Cancelled, duplicate_string(""));
  }
}


static Frame
create_file_selector_frame(int save_flag, char *prompt, char *cwd, char *default_file)
{
  Frame file_selector_frame;
  Panel panel;
  Panel_button_item change_button;
  Panel_text_item path_text_item;
  Panel_list_item directory_list_item;
  Scrollbar scrollbar;
  /* RWS Xv_scrollbar_info *scrollbar_i; */
  Menu directory_menu;
  Panel_list_item file_list_item;
  Panel_text_item file_text_item;

  /* the frame label string is copied by XView */
  file_selector_frame = (Frame)xv_create(toplevel, FRAME,
                                         FRAME_SHOW_RESIZE_CORNER, FALSE,
                                         FRAME_LABEL,              save_flag ?
                                                                   "Save File" :
                                                                   "Open File",
                                         WIN_EVENT_PROC,           frame_event_proc,
                                         NULL);

  panel = (Panel)xv_create(file_selector_frame, PANEL,
                           PANEL_LAYOUT, PANEL_HORIZONTAL,
                           NULL);

/* Shouldn't this be a command frame?
  file_selector_frame = (Frame)xv_create(toplevel, FRAME_CMD,
                                         FRAME_LABEL, "Load File",
                                         NULL);

  panel = (Panel)xv_get(file_selector_frame, FRAME_CMD_PANEL);
*/

  xv_create(panel, PANEL_MESSAGE,
            PANEL_LABEL_STRING, "Path:",
            PANEL_LABEL_BOLD,   TRUE,
            NULL);

  change_button = (Panel_button_item)xv_create(panel, PANEL_BUTTON,
                                               XV_X,               FILE_SELECTOR_WIDTH - 91,
                                               PANEL_LABEL_STRING, "Change Path",
                                               PANEL_NOTIFY_PROC,  change_path_button_pressed,
                                               NULL);

  xv_set(panel, PANEL_LAYOUT, PANEL_VERTICAL, NULL);

  path_text_item =
    (Panel_text_item)xv_create(panel, PANEL_TEXT,
                               PANEL_LAYOUT,              PANEL_VERTICAL,
                               PANEL_VALUE,               cwd,
                               PANEL_VALUE_DISPLAY_WIDTH, FILE_SELECTOR_WIDTH,
                               PANEL_VALUE_STORED_LENGTH, FILENAME_MAX,
                               NULL);

  /* Here comes the directory box... */
  directory_list_item =
    (Panel_list_item)xv_create(panel, PANEL_LIST,
                               PANEL_LIST_WIDTH,        FILE_SELECTOR_WIDTH,
                               PANEL_LIST_DISPLAY_ROWS, 2,
                               PANEL_CHOOSE_NONE,       TRUE,
                               PANEL_LIST_STRINGS,      " ",
                                                        " ",
                                                        " ",
                                                        NULL,
                               NULL);

  /* we want to manage the directory list ourselves... */
  scrollbar = (Scrollbar)xv_get(directory_list_item, PANEL_LIST_SCROLLBAR);
  xv_set(panel,
         XV_KEY_DATA, OldScrollbarEventProcKey, xv_get(directory_list_item, PANEL_EVENT_PROC),
         NULL);
  xv_set(directory_list_item, PANEL_EVENT_PROC, my_directory_list_handle_event_proc, NULL);
  xv_set(scrollbar, SCROLLBAR_NORMALIZE_PROC, my_normalize_scrollbar, NULL);

  /* Here comes the real hacker's stuff... */
  /* RWS scrollbar_i = SCROLLBAR_PRIVATE(scrollbar); */

  directory_menu = NULL; /* RWS scrollbar_i->menu; */
  if (directory_menu != XV_NULL)
    xv_destroy_safe(directory_menu);

  /* RWS scrollbar_i->menu = xv_create(XV_NULL, MENU,
                                MENU_TITLE_ITEM, "Directories",   \* NOT copied by XView! *\
                                MENU_GEN_PROC,    dir_menu_gen_proc,
                                MENU_NOTIFY_PROC, dir_menu_notify_proc,
                                XV_KEY_DATA,      PanelKey, panel,
                                NULL);
*/

  /* Now the file list... */
  file_list_item =
    (Panel_list_item)xv_create(panel, PANEL_LIST,
                               PANEL_LIST_WIDTH,        FILE_SELECTOR_WIDTH,
                               PANEL_LIST_DISPLAY_ROWS, NO_OF_FILENAMES_IN_LIST,
                               PANEL_CHOOSE_NONE,       TRUE,
                               PANEL_READ_ONLY,         TRUE,
                               PANEL_NOTIFY_PROC,       file_list_notify_proc,
                               NULL);

  file_text_item =
    (Panel_text_item)xv_create(panel, PANEL_TEXT,
                               PANEL_LAYOUT,              PANEL_VERTICAL,
                               PANEL_LABEL_STRING,        prompt,
                               PANEL_VALUE_DISPLAY_WIDTH, FILE_SELECTOR_WIDTH,
                               PANEL_VALUE_STORED_LENGTH, FILENAME_MAX,
                               PANEL_VALUE,               default_file,
                               NULL);

  xv_set(panel,
         PANEL_DEFAULT_ITEM, xv_create(panel, PANEL_BUTTON,
                                       XV_X,               (FILE_SELECTOR_WIDTH / 2) - 24 - 46,
                                       PANEL_LABEL_STRING, save_flag ? "Save" : "Open",
                                       PANEL_NOTIFY_PROC,  open_or_save_button_pressed,
                                       NULL),
         NULL);

  xv_set(panel, PANEL_LAYOUT, PANEL_HORIZONTAL, NULL);

  xv_create(panel, PANEL_BUTTON,
            XV_X,                (FILE_SELECTOR_WIDTH / 2)  + 24,
            PANEL_LABEL_STRING, "Cancel",
            PANEL_NOTIFY_PROC,  cancel_button_pressed,
            NULL);

  xv_set(panel,
         XV_KEY_DATA, SaveFlagKey,          save_flag,
         XV_KEY_DATA, PathsKey,             (char **)0,
         XV_KEY_DATA, PathTextItemKey,      path_text_item,
         XV_KEY_DATA, DirectoryListItemKey, directory_list_item,
         XV_KEY_DATA, FileListItemKey,      file_list_item,
         XV_KEY_DATA, FileTextItemKey,      file_text_item,
         NULL);

  window_fit(panel);
  window_fit(file_selector_frame);

	center_frame (file_selector_frame);

  xv_set(file_selector_frame, XV_SHOW, TRUE, NULL);
  enter_new_directory(panel, cwd, FALSE);

  return file_selector_frame;
}


void
init_file_selector(void)
{
  /* create unique keys for use with XV_KEY_DATA */
  SaveFlagKey              = xv_unique_key();
  PanelKey                 = xv_unique_key();
  OldScrollbarEventProcKey = xv_unique_key();
  PathsKey                 = xv_unique_key();
  DepthKey                 = xv_unique_key();
  PathTextItemKey          = xv_unique_key();
  DirectoryListItemKey     = xv_unique_key();
  FileListItemKey          = xv_unique_key();
  FileTextItemKey          = xv_unique_key();
  PathKey                  = xv_unique_key();

  /* get fonts for use in scrolling list */
  list_font      = (Xv_font)xv_find(XV_NULL, FONT,
                                    FONT_FAMILY, FONT_FAMILY_DEFAULT,
                                    FONT_STYLE,  FONT_STYLE_NORMAL,
                                    NULL);

  bold_list_font = (Xv_font)xv_find(XV_NULL, FONT,
                                    FONT_FAMILY, FONT_FAMILY_DEFAULT,
                                    FONT_STYLE,  FONT_STYLE_BOLD,
                                    NULL);

  if ((list_font == (Xv_font)0) || (bold_list_font == (Xv_font)0)) {
    fprintf(stderr, "Couldn't find fonts for file selector.\n");
    abort();
  }

  /* create glyphs for use in scrolling list */
  directory_glyph = (Server_image)xv_create(XV_NULL, SERVER_IMAGE,
                                            XV_WIDTH,           16,
                                            XV_HEIGHT,          16,
                                            SERVER_IMAGE_DEPTH, 1,
                                            SERVER_IMAGE_BITS,  directory_pr_array,
                                            NULL);

  file_glyph      = (Server_image)xv_create(XV_NULL, SERVER_IMAGE,
                                            XV_WIDTH,           16,
                                            XV_HEIGHT,          16,
                                            SERVER_IMAGE_DEPTH, 1,
                                            SERVER_IMAGE_BITS,  file_pr_array,
                                            NULL);

  unknown_glyph   = (Server_image)xv_create(XV_NULL, SERVER_IMAGE,
                                            XV_WIDTH,           16,
                                            XV_HEIGHT,          16,
                                            SERVER_IMAGE_DEPTH, 1,
                                            SERVER_IMAGE_BITS,  unknown_pr_array,
                                            NULL);
  if ((directory_glyph == (Server_image)0) || (file_glyph    == (Server_image)0) ||
      (unknown_glyph == (Server_image)0)) {
    fprintf(stderr, "Couldn't create glyphs for file selector.\n");
    abort();
  }
}


/* Return two fresh strings, representing the directory part and the file name part of name */
static void
split_name(char *name, char **directory_name, char **file_name)
{
  char cwd[FILENAME_MAX+1];
  char *full_name,*last_separator;

  if (name[0] == PATH_SEPARATOR_CHAR) {
    full_name = duplicate_string(name);
  } else {
	if (last_directory[0]=='\0')
   		getcwd (cwd,sizeof (cwd));
	else
		strcpy (cwd,last_directory);
	
    full_name = prepend_directory(cwd, name);
  }
  last_separator = strrchr(full_name, PATH_SEPARATOR_CHAR);
  if (last_separator == (char *)0) {
    /* this should not happen, but anyway... */
    *file_name      = full_name;
    *directory_name = duplicate_string(".");
  } else {
    *file_name      = duplicate_string(last_separator + 1);
    *directory_name = full_name;
    *last_separator = '\0';
  }
}

void
select_input_file (int dummy, /* needed for fcl compiler */
                  int *ready, CLEAN_STRING *full_name)
{
  Frame file_selector_frame;
  char cwd[FILENAME_MAX+1];

  xv_set(toplevel, FRAME_BUSY, TRUE, NULL);
	
	if (last_directory[0]=='\0')
   		getcwd (cwd,sizeof (cwd));
	else
		strcpy (cwd,last_directory);

  file_selector_frame = create_file_selector_frame(FALSE, "Open File:", cwd, "");

#if 1
  global_return_status = NotYet;
  allow_timer(FALSE);
  while (global_return_status == NotYet) {
    XFlush(display);
    notify_start();
    XFlush(display);
  }
  allow_timer(TRUE);
#else
  XFlush(display);
  xv_window_loop(file_selector_frame);
  XFlush(display);
#endif
  xv_set(file_selector_frame, XV_SHOW, FALSE, NULL);
  xv_destroy_safe(file_selector_frame);
  xv_set(toplevel, FRAME_BUSY, FALSE, NULL);

  *ready = (global_return_status == (int)LoadOK);
  *full_name = cleanstring(global_return_full_name);
  my_free(global_return_full_name);
}

void
select_output_file (CLEAN_STRING prompt, CLEAN_STRING default_file_name,
                   int *ready, CLEAN_STRING *full_name)
{
  Frame file_selector_frame;
  char *tmp;
  char *directory_name;
  char *file_name;

  xv_set(toplevel, FRAME_BUSY, TRUE, NULL);

  tmp = cstring(default_file_name);
  split_name(tmp, &directory_name, &file_name);
  my_free(tmp);

  tmp = cstring(prompt);
  if (tmp[0] == '\0') {
    tmp = duplicate_string("Save File As:");
  }
  file_selector_frame = create_file_selector_frame(TRUE, tmp, directory_name, file_name);
  my_free(tmp);

  global_return_status = NotYet;
  allow_timer(FALSE);
  while (global_return_status == NotYet) {
    XFlush(display);
    notify_start();
    XFlush(display);
  }
  allow_timer(TRUE);
  xv_set(file_selector_frame, XV_SHOW, FALSE, NULL);
  xv_destroy_safe(file_selector_frame);
  xv_set(toplevel, FRAME_BUSY, FALSE, NULL);

  *ready = (global_return_status == (int)SaveOK);
  *full_name = cleanstring(global_return_full_name);
  my_free(global_return_full_name);
}
