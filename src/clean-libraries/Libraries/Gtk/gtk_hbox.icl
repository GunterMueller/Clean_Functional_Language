implementation module gtk_hbox;

import gtk_types;

gtk_hbox_new :: !Int !Int !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_hbox_new homogeneous spacing gs = code {
	ccall gtk_hbox_new "II:p:p"
}
