definition module gtk_entry;

import gtk_types;

gtk_entry_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_entry_set_max_length :: !GtkWidgetP !Int !GtkSt -> GtkSt;
gtk_entry_set_text :: !GtkWidgetP !String !GtkSt -> GtkSt;
gtk_entry_get_text :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);

