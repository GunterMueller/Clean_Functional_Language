implementation module gtk_check_button;

import gtk_types;

gtk_check_button_new_with_label :: !String !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_check_button_new_with_label label gs = code {
	ccall gtk_check_button_new_with_label "s:p:p"
}

