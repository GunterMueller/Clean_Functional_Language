implementation module gtk_toggle_button;

import gtk_types;

gtk_toggle_button_get_active :: !GtkWidgetP !GtkSt -> (!Bool,!GtkSt);
gtk_toggle_button_get_active toggle_button gs = code {
	ccall gtk_toggle_button_get_active "p:I:p"
}

gtk_toggle_button_set_active :: !GtkWidgetP !Bool !GtkSt -> GtkSt;
gtk_toggle_button_set_active toggle_button is_active gs = code {
	ccall gtk_toggle_button_set_active "pI:V:p"
}

