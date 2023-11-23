implementation module gtk_combo_box;

import gtk_types;

gtk_combo_box_new_text :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_combo_box_new_text gs = code {
	ccall gtk_combo_box_new_text ":p:p"
}

gtk_combo_box_append_text :: !GtkWidgetP !String !GtkSt -> GtkSt;
gtk_combo_box_append_text combo_box text gs = code {
	ccall gtk_combo_box_append_text "ps:V:p"
}

gtk_combo_box_set_active :: !GtkWidgetP !Int !GtkSt -> GtkSt;
gtk_combo_box_set_active combo_box index_ gs = code {
	ccall gtk_combo_box_set_active "pp:V:p"
}

gtk_combo_box_get_active_text :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_combo_box_get_active_text combo_box gs = code {
	ccall gtk_combo_box_get_active_text "p:p:p"
}

gtk_combo_box_get_active :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_combo_box_get_active combo_box gs = code {
	ccall gtk_combo_box_get_active "p:I:p"
}

