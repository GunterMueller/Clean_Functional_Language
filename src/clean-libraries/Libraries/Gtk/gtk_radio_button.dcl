definition module gtk_radio_button;

import gtk_types;

gtk_radio_button_new_with_label :: !GtkWidgetP !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_radio_button_new_with_label_from_widget :: !GtkWidgetP !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_radio_button_get_group :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);

