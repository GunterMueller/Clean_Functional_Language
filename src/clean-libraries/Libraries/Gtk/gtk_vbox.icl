implementation module gtk_vbox;

import gtk_types;

gtk_vbox_new :: !Int !Int !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_vbox_new homogeneous spacing gs = code {
	ccall gtk_vbox_new "II:p:p"
}
