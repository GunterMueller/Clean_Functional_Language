definition module gtk_combo_box;

import gtk_types;

gtk_combo_box_new_text :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_combo_box_append_text :: !GtkWidgetP !String !GtkSt -> GtkSt;
gtk_combo_box_set_active :: !GtkWidgetP !Int !GtkSt -> GtkSt;
gtk_combo_box_get_active_text :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_combo_box_get_active :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);

