implementation module gtk_button;

import gtk_types;

gtk_button_new_with_label :: !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_button_new_with_label label gs = code {
	ccall gtk_button_new_with_label "s:p:p"
}

