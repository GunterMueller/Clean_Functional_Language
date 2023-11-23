definition module gtk_label;

import gtk_types;

gtk_label_new :: !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_label_set_text :: !GtkWidgetP !String !GtkSt -> GtkSt;
gtk_label_set_text_i :: !GtkWidgetP !Int !GtkSt -> GtkSt;
gtk_label_get_text :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);

