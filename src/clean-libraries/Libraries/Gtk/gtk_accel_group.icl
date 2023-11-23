implementation module gtk_accel_group;

import gtk_types;

gtk_accel_group_new :: !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_accel_group_new gs = code {
	ccall gtk_accel_group_new ":p:p"
}
