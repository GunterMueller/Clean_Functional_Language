implementation module gtk_viewport;

import gtk_types;

gtk_viewport_new :: !GtkWidgetP !GtkWidgetP !GtkSt -> (!GtkWidgetP,!GtkSt);
gtk_viewport_new hadjustment vadjustment gs = code {
	ccall gtk_viewport_new "pp:p:p"
}

