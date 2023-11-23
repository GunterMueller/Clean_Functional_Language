definition module gtk_toggle_button;

import gtk_types;

gtk_toggle_button_get_active :: !GtkWidgetP !GtkSt -> (!Bool,!GtkSt);
gtk_toggle_button_set_active :: !GtkWidgetP !Bool !GtkSt -> GtkSt;

