implementation module gtk_radio_button;

import gtk_types;

gtk_radio_button_new_with_label :: !GtkWidgetP !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_radio_button_new_with_label radio_group_member label gs = code {
	ccall gtk_radio_button_new_with_label "ps:p:p"
}

gtk_radio_button_new_with_label_from_widget :: !GtkWidgetP !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_radio_button_new_with_label_from_widget radio_group_member label gs = code {
	ccall gtk_radio_button_new_with_label_from_widget "ps:p:p"
}

gtk_radio_button_get_group :: !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_radio_button_get_group radio_button gs = code {
	ccall gtk_radio_button_get_group "p:p:p"
}

