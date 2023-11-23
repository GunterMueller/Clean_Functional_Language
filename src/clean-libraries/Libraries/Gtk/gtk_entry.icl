implementation module gtk_entry;

import gtk_types;

gtk_entry_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_entry_new gs = code {
	ccall gtk_entry_new ":p:p"
}

gtk_entry_set_max_length :: !GtkWidgetP !Int !GtkSt -> GtkSt;
gtk_entry_set_max_length entry max gs = code {
	ccall gtk_entry_new_with_max_length "pI:V:p"
}

gtk_entry_set_text :: !GtkWidgetP !String !GtkSt -> GtkSt;
gtk_entry_set_text entry text gs = code {
	ccall gtk_entry_set_text "ps:V:p"
}

gtk_entry_get_text :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_entry_get_text entry gs = code {
	ccall gtk_entry_get_text "p:p:p"
}
