implementation module g_signal;

import gtk_types;

g_signal_connect_data :: !GtkWidgetP !String !Int !Int !Int !Int !GtkSt -> (!Int,!GtkSt);
g_signal_connect_data instance_ detailed_signal c_handler data destroy_data connect_flags gs = code {
	ccall g_signal_connect_data "pspppp:I:p"
}
 
