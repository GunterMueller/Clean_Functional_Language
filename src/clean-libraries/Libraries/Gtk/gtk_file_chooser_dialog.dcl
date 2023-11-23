definition module gtk_file_chooser_dialog;

import gtk_types;

:: GtkFileChooserAction:==Int;

GTK_FILE_CHOOSER_ACTION_OPEN :== 0;
GTK_FILE_CHOOSER_ACTION_SAVE :== 1;
GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER :== 2;

gtk_file_chooser_dialog_new_sisii :: !String !GtkWidgetP !GtkFileChooserAction !String !Int !String !Int !Int !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_file_chooser_get_filename :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_file_chooser_set_filename :: !GtkWidgetP !String !GtkSt -> (!Bool,!GtkSt);
gtk_file_chooser_set_current_folder :: !GtkWidgetP !String !GtkSt -> (!Bool,!GtkSt);
gtk_file_chooser_set_current_name :: !GtkWidgetP !String !GtkSt -> (!Bool,!GtkSt);

