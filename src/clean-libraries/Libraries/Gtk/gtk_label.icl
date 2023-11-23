implementation module gtk_label;

import gtk_types;

gtk_label_new :: !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_label_new str gs = code {
	ccall gtk_label_new "s:p:p"
}

gtk_label_set_text :: !GtkWidgetP !String !GtkSt -> GtkSt;
gtk_label_set_text label str gs = code {
	ccall gtk_label_set_text "ps:V:p"
}

gtk_label_set_text_i :: !GtkWidgetP !Int !GtkSt -> GtkSt;
gtk_label_set_text_i label str gs = code {
	ccall gtk_label_set_text "pp:V:p"
}

gtk_label_get_text :: !GtkWidgetP !GtkSt -> (!Int,!GtkSt);
gtk_label_get_text label gs = code {
	ccall gtk_label_get_text "p:p:p"
}

